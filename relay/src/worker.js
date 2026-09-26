export class Room {
  constructor(state, env) {
    this.state = state;
  }

  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("expected websocket", { status: 426 });
    }

    const existing = this.state.getWebSockets();
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    if (existing.length >= 2) {
      server.accept();
      server.send(JSON.stringify({ t: "full" }));
      server.close(4000, "room full");
      return new Response(null, { status: 101, webSocket: client });
    }

    this.state.acceptWebSocket(server);

    server.send(JSON.stringify({ t: "joined", slot: existing.length }));
    for (const ws of existing) {
      try {
        ws.send(JSON.stringify({ t: "peer_joined" }));
      } catch (err) {}
    }
    if (existing.length === 1) {
      for (const ws of this.state.getWebSockets()) {
        try {
          ws.send(JSON.stringify({ t: "ready" }));
        } catch (err) {}
      }
    }

    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws, message) {
    for (const other of this.state.getWebSockets()) {
      if (other !== ws) {
        try {
          other.send(message);
        } catch (err) {}
      }
    }
  }

  async webSocketClose(ws, code, reason, wasClean) {
    for (const other of this.state.getWebSockets()) {
      if (other !== ws) {
        try {
          other.send(JSON.stringify({ t: "peer_left" }));
        } catch (err) {}
      }
    }
  }

  async webSocketError(ws) {
    await this.webSocketClose(ws, 1011, "error", false);
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
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
