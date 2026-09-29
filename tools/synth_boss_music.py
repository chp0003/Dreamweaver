"""Renders the Shadow Weaver duel loop to assets/audio/music/boss_shadow_weaver.wav.

    python tools/synth_boss_music.py

16 bars at 128 BPM in D phrygian: sub drone, a dissonant pad walking
D - Eb - D - Ab (the tritone), taiko war drums, a clanging ostinato, and a low
choir with whispers over the second half. The reverb tail is wrapped back onto
the start so the file loops without a seam.
"""

import math
import os
import random
import struct
import wave

import synth_shadow_sfx as sx

SR = 32000
sx.SR = SR

BPM = 128.0
BEAT = 60.0 / BPM
STEP = BEAT / 4.0
BARS = 16
LOOP_SECONDS = BARS * 4 * BEAT
N = int(LOOP_SECONDS * SR)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "music", "boss_shadow_weaver.wav")

# Pad roots per four-bar block, in Hz (D2, Eb2, D2, Ab1).
ROOTS = [73.42, 77.78, 73.42, 51.91]


def place(buffer, sound, at_seconds, level=1.0):
    start = int(at_seconds * SR)
    for j, s in enumerate(sound):
        k = (start + j) % len(buffer)
        buffer[k] += s * level


def taiko(rng, pitch=52.0, dur=0.9):
    n = int(dur * SR)
    body = sx.osc(lambda t: sx.exp_sweep(pitch * 1.9, pitch, t / 0.08), n)
    body = sx.shape_env(body, lambda t: sx.env_ad(t, 0.002, 0.45, 3.5))
    skin = sx.svf(sx.noise_buffer(n, rng), sx.const(700.0), 0.9, "lp")
    skin = sx.shape_env(skin, lambda t: sx.env_ad(t, 0.001, 0.06))
    return sx.drive(sx.mix(body, sx.gain(skin, 0.6)), 2.2)


def rim(rng, dur=0.35):
    n = int(dur * SR)
    tom = sx.osc(lambda t: sx.exp_sweep(260.0, 150.0, t / 0.1), n)
    tom = sx.shape_env(tom, lambda t: sx.env_ad(t, 0.001, 0.14, 3.5))
    crack = sx.svf(sx.noise_buffer(n, rng), sx.const(1800.0), 0.8, "bp")
    crack = sx.shape_env(crack, lambda t: sx.env_ad(t, 0.001, 0.07))
    return sx.mix(sx.gain(tom, 0.7), crack)


def clang(freq, dur=0.32):
    tone = sx.dark_fm(dur, sx.const(freq), 1.414, lambda t: 2.4 * math.exp(-8.0 * t))
    tone = sx.svf(tone, sx.const(900.0), 0.8, "lp")
    return sx.shape_env(tone, lambda t: sx.env_ad(t, 0.002, 0.22, 3.0))


def bell(freq, dur=4.0):
    tone = sx.dark_fm(dur, sx.const(freq), 1.414, lambda t: 1.6 * math.exp(-1.2 * t))
    return sx.shape_env(tone, lambda t: sx.env_ad(t, 0.003, 3.2, 2.5))


def build():
    rng = random.Random(77)
    out = [0.0] * N
    block = int(4 * 4 * BEAT * SR)

    # Sub drone, ducked by the kick below.
    # Whole cycles per loop, so the drone's phase meets itself at the seam.
    drone = sx.osc(sx.const(round(36.71 * LOOP_SECONDS) / LOOP_SECONDS), N)
    detuned = sx.osc(sx.const(round(36.82 * LOOP_SECONDS) / LOOP_SECONDS), N, "saw")
    drone = [s + 0.3 * d for s, d in zip(drone, detuned)]
    drone = sx.svf(drone, sx.const(110.0), 0.8, "lp")

    # Pad: root, minor second and tritone, detuned saws through a slow filter.
    pad = [0.0] * N
    for b, root in enumerate(ROOTS):
        seg = sx.cluster((root, root * 1.0595, root * 1.414, root * 2.0), block, "saw", 0.006, rng)
        seg = sx.svf(seg, lambda t: 260.0 + 340.0 * (0.5 - 0.5 * math.cos(math.tau * t / (block / SR))), 1.2, "lp")
        seg = sx.shape_env(seg, lambda t: min(1.0, t / 0.4, (block / SR - t) / 0.4 + 0.25))
        for j, s in enumerate(seg):
            pad[(b * block + j) % N] += s

    # Drums: half-time taiko with a fill closing every fourth bar.
    drums = [0.0] * N
    kick_times = []
    for bar in range(BARS):
        bar_t = bar * 4 * BEAT
        for step in (0, 6, 10):
            kick_times.append(bar_t + step * STEP)
            place(drums, taiko(rng, 50.0 if step == 0 else 58.0), bar_t + step * STEP, 1.0 if step == 0 else 0.75)
        for step in (4, 12):
            place(drums, rim(rng), bar_t + step * STEP, 0.55)
        if bar % 4 == 3:
            for k, step in enumerate((13, 14, 15)):
                place(drums, taiko(rng, 70.0 + 8.0 * k, 0.5), bar_t + step * STEP, 0.6)

    duck = [1.0] * N
    for kt in kick_times:
        start = int(kt * SR)
        for j in range(int(0.3 * SR)):
            k = (start + j) % N
            duck[k] = min(duck[k], 0.35 + 0.65 * (j / (0.3 * SR)))

    # Ostinato in eighths: root, root, b2, root, 5, root, b2, b5.
    ost = [0.0] * N
    figure = [1.0, 1.0, 1.0595, 1.0, 1.498, 1.0, 1.0595, 1.414]
    for bar in range(BARS):
        root = ROOTS[bar // 4] * 2.0
        level = 0.35 if bar < 4 else 0.6
        for k in range(8):
            place(ost, clang(root * figure[k]), bar * 4 * BEAT + k * BEAT / 2.0, level)

    # Second half: choir and whispers.
    choir = [0.0] * N
    half = N // 2
    choir_len = LOOP_SECONDS / 2.0
    for k, ratio in enumerate((1.0, 1.0595, 1.498)):
        voice = sx.demon_growl(choir_len, random.Random(900 + k), sx.const(73.42 * ratio),
                               sx.VOWEL_OO, 0.03, 4.0, 0.3, 0.15)
        voice = sx.shape_env(voice, lambda t: min(1.0, t / 2.0) * min(1.0, (choir_len - t) / 1.5))
        for j, s in enumerate(voice):
            choir[half + j] += s
    whispers = sx.whisper(choir_len, rng, 6.0, 600.0, 2400.0)
    whispers = sx.shape_env(whispers, lambda t: 0.5 + 0.5 * math.sin(math.tau * t / 7.5 - 1.5))
    for j, s in enumerate(whispers):
        choir[half + j] += s * 0.5

    bells = [0.0] * N
    place(bells, bell(73.42), 0.0, 1.0)
    place(bells, bell(51.91), LOOP_SECONDS / 2.0, 1.0)

    for i in range(N):
        out[i] = (drone[i] * 0.55 * duck[i] + pad[i] * 0.12 * duck[i] + drums[i] * 0.9
                  + ost[i] * 0.22 + choir[i] * 0.12 + bells[i] * 0.3)

    wet = sx.reverb(out, 0.84, 0.28, 3.0, 1.5)
    looped = wet[:N]
    for j, s in enumerate(wet[N:]):
        looped[j % N] += s
    looped = sx.dc_block(looped)
    peak = max(abs(s) for s in looped)
    looped = [math.tanh(s / peak * 1.3) * 0.86 for s in looped]
    # Pad and filter state don't wrap; bend the last 30 ms onto the first sample.
    seam = int(0.03 * SR)
    gap = looped[0] - looped[-1]
    for j in range(seam):
        looped[N - seam + j] += gap * (j + 1) / seam
    return looped


def main():
    signal = build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in signal)
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print("boss_shadow_weaver.wav %.1fs" % (len(signal) / SR))


if __name__ == "__main__":
    main()
