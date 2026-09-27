#!/usr/bin/env python3
"""Generate the game's audio placeholders procedurally (no external deps).

Outputs:
  assets/audio/music/fight.(ogg|wav)        looping fight theme
  assets/audio/ambience/crowd.(ogg|wav)     looping crowd murmur
  assets/audio/sfx/crowd_roar.(ogg|wav)     KO / victory roar
  assets/audio/sfx/click.(ogg|wav)          UI click

If ffmpeg is available the WAVs are encoded to OGG and the WAVs discarded.
Run:  python3 tools/gen_audio.py
"""

import math
import os
import random
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
random.seed(20260927)


def one_pole_lp(samples, cutoff):
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / SR)
    out = [0.0] * len(samples)
    y = 0.0
    for i, x in enumerate(samples):
        y += a * (x - y)
        out[i] = y
    return out


def highpass(samples, cutoff):
    low = one_pole_lp(samples, cutoff)
    return [samples[i] - low[i] for i in range(len(samples))]


def soft_clip(x):
    return math.tanh(x * 1.15)


def normalize(samples, peak=0.85):
    hi = max(1e-9, max(abs(s) for s in samples))
    scale = peak / hi
    return [s * scale for s in samples]


def normalize_stereo(left, right, peak=0.85):
    hi = max(1e-9, max(max(abs(s) for s in left), max(abs(s) for s in right)))
    scale = peak / hi
    return [s * scale for s in left], [s * scale for s in right]


def mix(dest, source, start, gain=1.0, pan=0.0):
    left_gain = gain * math.sqrt(0.5 * (1.0 - pan))
    right_gain = gain * math.sqrt(0.5 * (1.0 + pan))
    for i, s in enumerate(source):
        j = start + i
        if j >= len(dest[0]):
            break
        dest[0][j] += s * left_gain
        dest[1][j] += s * right_gain


def write_wav(path, left, right):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        frames = bytearray()
        for l, r in zip(left, right):
            frames += struct.pack("<hh", int(max(-1, min(1, l)) * 32767),
                                  int(max(-1, min(1, r)) * 32767))
        f.writeframes(bytes(frames))


def encode(path_wav, final, keep):
    if not shutil.which("ffmpeg"):
        return path_wav
    codecs = [
        ("ogg", ["-c:a", "libvorbis", "-q:a", "5"]),
        ("ogg", ["-c:a", "vorbis", "-strict", "-2", "-q:a", "5"]),
        ("mp3", ["-c:a", "libmp3lame", "-b:a", "160k"]),
    ]
    base = os.path.splitext(final)[0]
    os.makedirs(os.path.dirname(base), exist_ok=True)
    for extension, codec in codecs:
        target = base + "." + extension
        if os.path.exists(target):
            os.remove(target)
        result = subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", path_wav] + codec + [target],
            capture_output=True,
        )
        if result.returncode == 0:
            if not keep:
                os.remove(path_wav)
            return target
    return path_wav


# ---------------------------------------------------------------- instruments

def kick(dur=0.32):
    n = int(dur * SR)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        freq = 45.0 + 95.0 * math.exp(-t * 32.0)
        phase += 2.0 * math.pi * freq / SR
        env = math.exp(-t * 13.0)
        click = random.uniform(-1.0, 1.0) * math.exp(-t * 260.0) * 0.3
        out[i] = soft_clip(math.sin(phase) * env * 0.95 + click)
    return out


def snare(dur=0.24):
    n = int(dur * SR)
    noise = highpass([random.uniform(-1.0, 1.0) for _ in range(n)], 900.0)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        body = math.sin(2.0 * math.pi * 186.0 * t) * math.exp(-t * 38.0) * 0.5
        out[i] = soft_clip(noise[i] * math.exp(-t * 21.0) * 0.85 + body)
    return out


def hat(dur, decay, gain=0.32):
    n = int(dur * SR)
    noise = highpass([random.uniform(-1.0, 1.0) for _ in range(n)], 6500.0)
    return [noise[i] * math.exp(-i / SR * decay) * gain for i in range(n)]


def bass(freq, dur):
    n = int(dur * SR)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        phase += freq / SR
        square = 1.0 if (phase % 1.0) < 0.5 else -1.0
        saw = 2.0 * (phase % 1.0) - 1.0
        env = min(1.0, t * 90.0) * math.exp(-t * 3.2)
        out[i] = (0.68 * square + 0.32 * saw) * env * 0.42
    return one_pole_lp(out, 950.0)


def lead(freq, dur):
    n = int(dur * SR)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        phase += freq / SR
        frac = phase % 1.0
        tri = 4.0 * abs(frac - 0.5) - 1.0
        env = min(1.0, t * 140.0) * math.exp(-t * 9.0)
        out[i] = tri * env * 0.16
    return out


# ------------------------------------------------------------------- music

def build_fight():
    bpm = 140.0
    beat_sec = 60.0 / bpm
    beat = SR * beat_sec
    bars = 8
    total = int(bars * 4 * beat) + SR
    left = [0.0] * total
    right = [0.0] * total
    track = (left, right)

    e1 = 41.203
    riff = [0, 0, 12, 0, 3, 3, 7, 3]
    lead_notes = [0, 7, 12, 15, 12, 7, 12, 19]
    chord = [0, 7, 12, 15]

    for bar in range(bars):
        base = int(bar * 4 * beat)
        last_bar = bar == bars - 1
        fill = bar in (3, 7)
        for step in range(16):
            pos = base + int(step * beat / 4.0)
            if step in (0, 6, 10) or (step == 14 and fill):
                mix(track, kick(), pos, 1.0)
            if step in (4, 12):
                mix(track, snare(), pos, 0.8 if not last_bar else 0.95, 0.05)
            if fill and step in (13, 14, 15):
                mix(track, snare(), pos, 0.45 + 0.15 * step, -0.08)
            if step % 2 == 0:
                open_hat = step == 0 and bar % 4 == 0
                mix(track, hat(0.42 if open_hat else 0.045,
                               5.0 if open_hat else 48.0,
                               0.2 if open_hat else 0.26),
                    pos, 1.0, -0.15 if step % 4 == 0 else 0.15)
        if bar >= 4:
            for step in range(0, 16, 2):
                note = lead_notes[(step // 2) % len(lead_notes)]
                pos = base + int(step * beat / 4.0)
                mix(track, lead(e1 * 2.0 ** ((note + 24) / 12.0), beat_sec / 2.4),
                    pos, 0.9, 0.25 if step % 4 == 0 else -0.25)
        for step in range(0, 16, 2):
            note = riff[(step // 2) % len(riff)]
            pos = base + int(step * beat / 4.0)
            mix(track, bass(e1 * 2.0 ** (note / 12.0), beat_sec / 2.1), pos, 1.0)
        if bar % 2 == 1:
            for i, note in enumerate(chord):
                pos = base + int(i * 2 * beat / 2.0)
                mix(track, lead(e1 * 2.0 ** ((note + 36) / 12.0), beat_sec / 3.0),
                    pos, 0.35, -0.3 + i * 0.2)
    # tail folds back so the loop seam is seamless
    head = SR
    for channel in (left, right):
        for i in range(head):
            channel[i] += channel[total - head + i]
    return normalize_stereo(left[:total - head], right[:total - head], 0.82)


# ------------------------------------------------------------------- crowd

def crowd_blob(base_freq, dur, level):
    n = int(dur * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        flutter = 0.6 + 0.4 * math.sin(2.0 * math.pi * 7.3 * t + base_freq)
        voice = math.sin(2.0 * math.pi * base_freq * t) * flutter
        out[i] = voice * math.exp(-t * 6.0) * level
    return highpass(one_pole_lp(out, 2400.0), 300.0)


def build_crowd():
    dur = 8.0
    total = int(dur * SR)
    left = [0.0] * total
    right = [0.0] * total
    track = (left, right)
    murmur = highpass(one_pole_lp(
        [random.uniform(-1.0, 1.0) for _ in range(total)], 1500.0), 220.0)
    for i in range(total):
        t = i / SR
        swell = 0.55 + 0.2 * math.sin(2.0 * math.pi * 0.11 * t)
        swell += 0.15 * math.sin(2.0 * math.pi * 0.37 * t + 1.2)
        left[i] = murmur[i] * swell * 0.16
        right[i] = murmur[i] * (1.1 - swell) * 0.16
    t = 0.3
    while t < dur - 0.5:
        f0 = random.uniform(150.0, 340.0)
        blob = crowd_blob(f0, random.uniform(0.12, 0.3), random.uniform(0.25, 0.6))
        mix(track, blob, int(t * SR), 1.0, random.uniform(-0.8, 0.8))
        t += random.uniform(0.35, 1.1)
    t = 1.5
    while t < dur - 1.0:
        n = int(0.16 * SR)
        whistle = [math.sin(2.0 * math.pi * (2600.0 + 220.0 * math.sin(2.0 * math.pi * 11.0 * i / SR)) * i / SR)
                   * math.exp(-i / SR * 14.0) * 0.05 for i in range(n)]
        mix(track, whistle, int(t * SR), 1.0, random.uniform(-0.6, 0.6))
        t += random.uniform(1.2, 2.6)
    xf = int(0.5 * SR)
    for channel in (left, right):
        for i in range(xf):
            channel[total - xf + i] = channel[total - xf + i] * (1.0 - i / xf) + channel[i] * (i / xf)
    return normalize_stereo(left, right, 0.5)


def build_roar():
    dur = 3.4
    total = int(dur * SR)
    left = [0.0] * total
    right = [0.0] * total
    track = (left, right)
    noise = highpass(one_pole_lp(
        [random.uniform(-1.0, 1.0) for _ in range(total)], 2600.0), 180.0)
    for i in range(total):
        t = i / SR
        attack = 1.0 - math.exp(-t * 9.0)
        decay = math.exp(-max(0.0, t - 0.9) * 1.6)
        wobble = 0.85 + 0.15 * math.sin(2.0 * math.pi * 6.5 * t)
        sample = noise[i] * attack * decay * wobble
        left[i] += sample * 0.5
        right[i] += sample * 0.48
    t = 0.25
    while t < dur - 0.2:
        clap = highpass([random.uniform(-1.0, 1.0) for _ in range(int(0.05 * SR))], 1500.0)
        clap = [s * math.exp(-i / SR * 80.0) * 0.5 for i, s in enumerate(clap)]
        mix(track, clap, int(t * SR), random.uniform(0.4, 0.9), random.uniform(-0.9, 0.9))
        t += random.uniform(0.08, 0.35)
    return normalize_stereo(left, right, 0.8)


def build_click():
    dur = 0.07
    n = int(dur * SR)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        freq = 1500.0 - 700.0 * (t / dur)
        phase += 2.0 * math.pi * freq / SR
        env = math.exp(-t * 60.0)
        tick = random.uniform(-1.0, 1.0) * math.exp(-t * 320.0) * 0.35
        out[i] = (math.sin(phase) * 0.8 + tick) * env
    out = normalize(out, 0.5)
    return out, list(out)


# --------------------------------------------------------------------- main

def main():
    keep = "--keep" in sys.argv
    tmp = tempfile.mkdtemp(prefix="clanker_audio_")
    jobs = [
        ("fight", build_fight, os.path.join(ROOT, "assets/audio/music/fight.wav")),
        ("crowd", build_crowd, os.path.join(ROOT, "assets/audio/ambience/crowd.wav")),
        ("crowd_roar", build_roar, os.path.join(ROOT, "assets/audio/sfx/crowd_roar.wav")),
        ("click", build_click, os.path.join(ROOT, "assets/audio/sfx/click.wav")),
    ]
    for name, builder, final in jobs:
        print("generating %s..." % name)
        left, right = builder()
        work = final if keep else os.path.join(tmp, os.path.basename(final))
        write_wav(work, left, right)
        out = encode(work, final, keep)
        print("  -> %s (%.1fs)" % (os.path.relpath(out, ROOT), len(left) / SR))
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
