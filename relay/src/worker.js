const STALE_MS = 120000;

export class Room {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.code = "";
    this.profiles = null;
    this.hp = null;
    this.rounds = null;
    this.phase = null;
    this.ready = null;
    this.lastDirectoryAt = 0;
  }

  async _load() {
    if (this.profiles) {
      return;
    }
    this.profiles = (await this.state.storage.get("profiles")) || {};
    this.hp = (await this.state.storage.get("hp")) || {};
    this.rounds = (await this.state.storage.get("rounds")) || {};
    this.phase = (await this.state.storage.get("phase")) || "lobby";
    this.ready = (await this.state.storage.get("ready")) || {};
  }

  async _persist() {
    await this.state.storage.put({
      profiles: this.profiles,
      hp: this.hp,
      rounds: this.rounds,
      phase: this.phase,
      ready: this.ready,
    });
  }

  _isPlayer(ws) {
    return (this.state.getTags(ws) || []).includes("player");
  }

  _slot(ws) {
    for (const tag of this.state.getTags(ws) || []) {
      if (tag.startsWith("slot:")) {
        return Number(tag.slice(5));
      }
    }
    return -1;
  }

  _players() {
    return this.state.getWebSockets().filter((ws) => this._isPlayer(ws));
  }

  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("expected websocket", { status: 426 });
    }
    await this._load();
    const url = new URL(request.url);
    this.code = (url.searchParams.get("room") || "").trim().toUpperCase();
    const role = url.searchParams.get("role") === "spec" ? "spec" : "player";
    const players = this._players();
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    if (role === "player" && players.length >= 2) {
      server.accept();
      server.send(JSON.stringify({ t: "full" }));
      server.close(4000, "room full");
      return new Response(null, { status: 101, webSocket: client });
    }

    if (role === "spec") {
      this.state.acceptWebSocket(server, ["spec"]);
      server.send(JSON.stringify({ t: "joined", slot: -1, role: "spec" }));
      for (const slot of [0, 1]) {
        const profile = this.profiles[slot];
        if (profile) {
          server.send(JSON.stringify({ t: "profile", slot, ...profile }));
        }
      }
      server.send(
        JSON.stringify({
          t: "spectate_state",
          hp: this.hp,
          rounds: this.rounds,
          phase: this.phase,
          ready: this.ready,
        }),
      );
      return new Response(null, { status: 101, webSocket: client });
    }

    if (players.length === 0) {
      this.profiles = {};
      this.hp = {};
      this.rounds = {};
      this.ready = {};
      this.phase = "lobby";
      await this._persist();
    }

    const taken = players.map((ws) => this._slot(ws));
    const slot = taken.includes(0) ? 1 : 0;
    this.state.acceptWebSocket(server, ["player", `slot:${slot}`]);
    server.send(JSON.stringify({ t: "joined", slot }));
    for (const other of players) {
      try {
        other.send(JSON.stringify({ t: "peer_joined" }));
      } catch (err) {}
    }
    if (players.length === 1) {
      for (const ws of players.concat([server])) {
        try {
          ws.send(JSON.stringify({ t: "ready" }));
        } catch (err) {}
      }
    }
    await this._updateDirectory(true);
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    const slot = this._slot(ws);
    if (slot < 0) {
      return;
    }
    await this._load();
    let tagged = message;
    let parsed = null;
    try {
      parsed = JSON.parse(message);
      parsed.slot = slot;
      tagged = JSON.stringify(parsed);
    } catch (err) {}
    for (const other of this.state.getWebSockets()) {
      if (other === ws) {
        continue;
      }
      try {
        other.send(tagged);
      } catch (err) {}
    }
    if (parsed) {
      await this._note(parsed, slot);
    }
  }

  async _note(message, slot) {
    if (message.t === "profile") {
      this.profiles[slot] = {
        name: String(message.name || "Player"),
        color: String(message.color || "ffffff"),
        wins: Number(message.wins || 0),
        losses: Number(message.losses || 0),
      };
      await this._persist();
      await this._updateDirectory(true);
      return;
    }
    if (message.t === "set_ready") {
      this.ready[slot] = Boolean(message.value);
      this.phase = "lobby";
      await this._persist();
      await this._updateDirectory(true);
      return;
    }
    if (message.t === "hit_result") {
      this.hp[slot] = Number(message.hp || 0);
      await this._persist();
      await this._noteFight();
      return;
    }
    if (message.t === "round_end") {
      this.rounds[slot] = Number(this.rounds[slot] || 0) + 1;
      await this._persist();
      await this._updateDirectory(true);
      return;
    }
    if (
      message.t === "input" ||
      message.t === "act" ||
      message.t === "hit" ||
      message.t === "miss" ||
      message.t === "rematch"
    ) {
      await this._noteFight();
      return;
    }
    await this._updateDirectory(false);
  }

  async _noteFight() {
    if (this.phase !== "fighting") {
      this.phase = "fighting";
      await this._persist();
      await this._updateDirectory(true);
      return;
    }
    await this._updateDirectory(false);
  }

  async _updateDirectory(force) {
    const now = Date.now();
    if (!force && now - this.lastDirectoryAt < 5000) {
      return;
    }
    this.lastDirectoryAt = now;
    await this._load();
    const players = this._players();
    const names = [];
    const colors = [];
    for (const ws of players) {
      const profile = this.profiles[this._slot(ws)] || {};
      names.push(profile.name || "Player");
      colors.push(profile.color || "ffffff");
    }
    try {
      const id = this.env.DIRECTORY.idFromName("directory");
      await this.env.DIRECTORY.get(id).fetch("https://directory/update", {
        method: "POST",
        body: JSON.stringify({
          code: this.code,
          present: players.length,
          names,
          colors,
          phase: players.length >= 2 ? this.phase : "lobby",
        }),
      });
    } catch (err) {}
  }

  async webSocketClose(ws) {
    if (!this._isPlayer(ws)) {
      return;
    }
    for (const other of this.state.getWebSockets()) {
      if (other === ws) {
        continue;
      }
      try {
        other.send(JSON.stringify({ t: "peer_left" }));
      } catch (err) {}
    }
    await this._updateDirectory(true);
  }

  async webSocketError(ws) {
    await this.webSocketClose(ws);
  }
}

export class Directory {
  constructor(state, env) {
    this.state = state;
    this.rooms = null;
  }

  async _load() {
    if (!this.rooms) {
      this.rooms = (await this.state.storage.get("rooms")) || {};
    }
  }

  _prune(now) {
    for (const [code, room] of Object.entries(this.rooms)) {
      if (now - room.at > STALE_MS || room.present < 2) {
        delete this.rooms[code];
      }
    }
  }

  async fetch(request) {
    await this._load();
    const url = new URL(request.url);
    const now = Date.now();
    if (url.pathname === "/update") {
      const data = await request.json();
      if (data.present >= 2) {
        this.rooms[data.code] = {
          code: data.code,
          present: data.present,
          names: data.names || [],
          colors: data.colors || [],
          phase: data.phase || "lobby",
          at: now,
        };
      } else {
        delete this.rooms[data.code];
      }
      this._prune(now);
      await this.state.storage.put("rooms", this.rooms);
      return new Response("ok");
    }
    this._prune(now);
    return new Response(JSON.stringify(Object.values(this.rooms)), {
      headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
    });
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/rooms") {
      const id = env.DIRECTORY.idFromName("directory");
      return env.DIRECTORY.get(id).fetch(request);
    }
    if (url.pathname !== "/ws") {
      return new Response("sockem relay ok", { status: 200 });
    }
    const room = (url.searchParams.get("room") || "").trim().toUpperCase();
    if (!/^[A-Z0-9]{4,8}$/.test(room)) {
      return new Response("invalid room", { status: 400 });
    }
    const id = env.ROOMS.idFromName(room);
    return env.ROOMS.get(id).fetch(request);
  },
};
