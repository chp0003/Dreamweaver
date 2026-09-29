"""Turns the raw Shadow Weaver lines into his demon voice.

    powershell -ExecutionPolicy Bypass -File tools/record_weaver_lines.ps1
    python tools/make_weaver_voice.py

Reads assets/audio/_src/voice/*.wav and writes assets/audio/voice/weaver_<line>.wav.
The voice is the line pitched down with a sub-octave copy underneath, lightly
saturated and growled, roughened with breath that follows the words, given
back its consonants with a presence lift, and placed in a stone hall.
"""

import math
import os
import random
import struct
import wave

from synth_shadow_sfx import const, dc_block, follower, reverb, svf

HERE = os.path.dirname(__file__)
SRC_DIR = os.path.join(HERE, "..", "assets", "audio", "_src", "voice")
OUT_DIR = os.path.join(HERE, "..", "assets", "audio", "voice")
OUT_SR = 44100

GRAIN_SECONDS = 0.05
OVERLAP = 4
TIME_STRETCH = 1.05
# The words ride on the lightly shifted main layer; the sub-octave only adds
# weight. Shifting the main layer much further smears the vowels together.
LAYERS = [
    # pitch factor, gain, delay seconds
    (0.76, 1.0, 0.0),
    (0.5, 0.36, 0.003),
]
DRIVE = 1.3
GROWL_DEPTH = 0.08
BREATH = 0.5
PRESENCE = 0.55
REVERB_WET = 0.13


def read_wav(path):
    with wave.open(path, "rb") as w:
        sr = w.getframerate()
        n = w.getnframes()
        raw = w.readframes(n)
        width = w.getsampwidth()
        channels = w.getnchannels()
    if width != 2:
        raise ValueError("expected 16-bit audio: " + path)
    data = struct.unpack("<%dh" % (n * channels), raw)
    mono = [data[i * channels] / 32768.0 for i in range(n)]
    return mono, sr


def trim(signal, threshold=0.01):
    start = 0
    while start < len(signal) and abs(signal[start]) < threshold:
        start += 1
    end = len(signal)
    while end > start and abs(signal[end - 1]) < threshold:
        end -= 1
    pad = int(0.02 * OUT_SR)
    return signal[max(0, start - pad):min(len(signal), end + pad)]


def sample_at(signal, pos):
    i = int(pos)
    if i < 0 or i + 1 >= len(signal):
        return 0.0
    frac = pos - i
    return signal[i] * (1.0 - frac) + signal[i + 1] * frac


def granular_shift(signal, in_sr, pitch, stretch, rng):
    """Overlap-add of Hann grains: each grain replays at `pitch` while the read
    head advances at 1/stretch, so pitch and length are set independently."""
    grain = int(GRAIN_SECONDS * OUT_SR)
    hop = grain // OVERLAP
    out_len = int(len(signal) / in_sr * stretch * OUT_SR) + grain
    out = [0.0] * out_len
    window = [0.5 - 0.5 * math.cos(math.tau * j / grain) for j in range(grain)]
    step = pitch * in_sr / OUT_SR
    norm = 2.0 / OVERLAP * 2.0
    for start in range(0, out_len - grain, hop):
        centre_in = (start + grain * 0.5) / OUT_SR / stretch * in_sr
        centre_in += rng.uniform(-0.004, 0.004) * in_sr
        read = centre_in - grain * 0.5 * step
        for j in range(grain):
            out[start + j] += sample_at(signal, read + j * step) * window[j] / norm
    return out


def demonise(signal, in_sr, seed):
    rng = random.Random(seed)
    layers = []
    for pitch, level, delay in LAYERS:
        shifted = granular_shift(signal, in_sr, pitch, TIME_STRETCH, rng)
        layers.append([0.0] * int(delay * OUT_SR) + [s * level for s in shifted])
    n = max(len(layer) for layer in layers)
    voice = [0.0] * n
    for layer in layers:
        for i, s in enumerate(layer):
            voice[i] += s

    peak = max(1e-6, max(abs(s) for s in voice))
    voice = [math.tanh(s / peak * DRIVE) for s in voice]
    voice = [s * (1.0 - GROWL_DEPTH + GROWL_DEPTH * math.sin(math.tau * 36.0 * i / OUT_SR))
             for i, s in enumerate(voice)]

    level = follower(voice, 22.0)
    breath = svf([rng.uniform(-1.0, 1.0) for _ in range(n)], const(1300.0), 0.9, "bp")
    voice = [s + breath[i] * level[i] * BREATH for i, s in enumerate(voice)]

    body = svf(voice, const(150.0), 0.8, "lp")
    presence = svf(voice, const(2600.0), 0.8, "bp")
    voice = svf(voice, const(7500.0), 0.7, "lp")
    voice = [s + body[i] * 0.6 + presence[i] * PRESENCE for i, s in enumerate(voice)]
    return reverb(voice, 0.8, REVERB_WET, 0.9, 1.3)


def finish(signal, peak_db=-1.5):
    signal = dc_block(signal)
    peak = max(1e-6, max(abs(s) for s in signal))
    target = 10 ** (peak_db / 20.0)
    scaled = [s * target / peak for s in signal]
    end = len(scaled)
    while end > 1 and abs(scaled[end - 1]) < 0.0015:
        end -= 1
    fade = min(end, int(0.02 * OUT_SR))
    for i in range(fade):
        scaled[end - 1 - i] *= i / fade
    return scaled[:end]


def write_wav(path, signal):
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in signal)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(OUT_SR)
        w.writeframes(frames)


VOWEL_AH = [(730.0, 5.0, 1.0), (1150.0, 6.0, 0.5), (2500.0, 8.0, 0.2)]


def synth_cackle(seed):
    """A throaty "ha-ha-ha-haaa": breathy onset, falling vowel, quickening beat.
    Made at speaking pitch so it goes through the same demon chain as speech."""
    rng = random.Random(seed)
    sr = OUT_SR
    out = [0.0] * int(0.15 * sr)
    syllables = 7
    for k in range(syllables):
        last = k == syllables - 1
        pitch = 165.0 - 7.0 * k
        vowel_len = 0.34 if last else 0.13 - 0.006 * k
        h_len = 0.05
        n = int((h_len + vowel_len) * sr)
        noise = [rng.uniform(-1.0, 1.0) for _ in range(n)]
        h = svf(noise, const(1400.0), 1.2, "bp")
        phase = 0.0
        saw = [0.0] * n
        for i in range(n):
            t = i / sr
            glide = pitch * (1.12 - 0.3 * min(1.0, t / (h_len + vowel_len)))
            phase = (phase + glide * (1.0 + 0.02 * rng.uniform(-1, 1)) / sr) % 1.0
            saw[i] = 2.0 * phase - 1.0
        voiced = [0.0] * n
        for f, q, g in VOWEL_AH:
            band = svf(saw, const(f), q, "bp")
            for i in range(n):
                voiced[i] += band[i] * g
        for i in range(n):
            t = i / sr
            h_env = math.exp(-((t - 0.02) / 0.025) ** 2)
            v_on = min(1.0, max(0.0, (t - h_len * 0.6) / 0.015))
            v_off = math.exp(-3.5 * max(0.0, t - h_len) / vowel_len)
            out.append(h[i] * h_env * 0.5 + voiced[i] * v_on * v_off)
        out.extend([0.0] * int((0.05 if k < 3 else 0.035) * sr))
    return out, sr


SYNTH_LINES = {"laugh_3.wav": lambda: synth_cackle(77)}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    names = sorted(f for f in os.listdir(SRC_DIR) if f.endswith(".wav"))
    if not names:
        raise SystemExit("no raw lines in %s - run record_weaver_lines.ps1 first" % SRC_DIR)
    jobs = [(name, lambda name=name: read_wav(os.path.join(SRC_DIR, name))) for name in names]
    jobs += list(SYNTH_LINES.items())
    for index, (name, source) in enumerate(jobs):
        raw, sr = source()
        voice = finish(demonise(trim(raw), sr, 500 + index))
        out = os.path.join(OUT_DIR, "weaver_" + name)
        write_wav(out, voice)
        print("%-26s %.2fs" % (os.path.basename(out), len(voice) / OUT_SR))


if __name__ == "__main__":
    main()
