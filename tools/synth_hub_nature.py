"""Renders the hub's river / waterfall bed and a set of songbird calls.

Standard library only, so it runs on any Python 3.
    python tools/synth_hub_nature.py

Writes to assets/audio/ambience/:
  hub_river_loop.wav   stereo, seamless loop: falls roar + stream babble
  bird_<n>.wav         mono one-shot calls the AudioDirector scatters at random

Every recipe is seeded, so re-running produces identical files.
"""

import math
import os
import random
import struct
import wave

SR = 32000
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ambience")


def write_wav(path, left, right=None, peak=0.89):
    frames = len(left)
    top = max(max(abs(s) for s in left), max((abs(s) for s in right), default=0.0) if right else 0.0)
    scale = peak / top if top > 0 else 1.0
    with wave.open(path, "wb") as out:
        out.setnchannels(2 if right else 1)
        out.setsampwidth(2)
        out.setframerate(SR)
        data = bytearray()
        for i in range(frames):
            data += struct.pack("<h", int(max(-1.0, min(1.0, left[i] * scale)) * 32767))
            if right:
                data += struct.pack("<h", int(max(-1.0, min(1.0, right[i] * scale)) * 32767))
        out.writeframes(bytes(data))


def one_pole(signal, coeff):
    out = [0.0] * len(signal)
    y = 0.0
    for i, x in enumerate(signal):
        y += (x - y) * coeff
        out[i] = y
    return out


def coeff_for(cutoff):
    return 1.0 - math.exp(-math.tau * cutoff / SR)


def pink(n, rng):
    """Paul Kellet's economy pink noise."""
    b0 = b1 = b2 = 0.0
    out = [0.0] * n
    for i in range(n):
        w = rng.uniform(-1.0, 1.0)
        b0 = 0.99765 * b0 + w * 0.0990460
        b1 = 0.96300 * b1 + w * 0.2965164
        b2 = 0.57000 * b2 + w * 1.0526913
        out[i] = (b0 + b1 + b2 + w * 0.1848) * 0.18
    return out


def slow_wobble(n, rng, rate, depth):
    """Smoothed random walk used for gusting water volume."""
    out = [0.0] * n
    target = 1.0
    value = 1.0
    step = coeff_for(rate)
    hold = 0
    for i in range(n):
        if hold <= 0:
            target = 1.0 + rng.uniform(-depth, depth)
            hold = int(SR / max(0.05, rate) * rng.uniform(0.6, 1.4))
        hold -= 1
        value += (target - value) * step
        out[i] = value
    return out


# ---------------------------------------------------------------------------
# River bed
# ---------------------------------------------------------------------------

def bubble(buf, start, freq, dur, amp, pan_l, pan_r, left, right):
    """A stream 'blip': a sine that rises as the bubble collapses."""
    n = int(dur * SR)
    phase = 0.0
    for k in range(n):
        idx = start + k
        if idx >= len(left):
            break
        t = k / SR
        f = freq * (1.0 + 2.6 * (t / dur) ** 1.4)
        phase += f / SR
        env = math.sin(math.pi * min(1.0, t / dur)) * math.exp(-5.0 * t / dur)
        s = math.sin(phase * math.tau) * env * amp
        left[idx] += s * pan_l
        right[idx] += s * pan_r


def render_river(seconds=36.0, fade=3.0):
    rng = random.Random(4417)
    total = int((seconds + fade) * SR)

    # Falls: pink noise, darkened, with a slow surge. Left channel is nearer the falls.
    roar_l = one_pole(one_pole(pink(total, rng), coeff_for(2400)), coeff_for(3200))
    roar_r = one_pole(one_pole(pink(total, rng), coeff_for(2000)), coeff_for(2800))
    rumble = one_pole(one_pole(pink(total, rng), coeff_for(180)), coeff_for(220))
    surge = slow_wobble(total, rng, 0.35, 0.18)

    # Hiss of spray: bright noise band.
    white = [rng.uniform(-1.0, 1.0) for _ in range(total)]
    hi = one_pole(white, coeff_for(7000))
    lo = one_pole(white, coeff_for(2200))
    spray = [hi[i] - lo[i] for i in range(total)]

    left = [0.0] * total
    right = [0.0] * total
    for i in range(total):
        s = surge[i]
        left[i] = roar_l[i] * 0.62 * s + rumble[i] * 1.8 + spray[i] * 0.10 * s
        right[i] = roar_r[i] * 0.48 * s + rumble[i] * 1.6 + spray[i] * 0.08 * s

    # Babbling stream: dense bubbles, gently clustered.
    t = 0.0
    while t < seconds + fade:
        density = 26.0 + 18.0 * math.sin(t * 0.7) + 10.0 * math.sin(t * 2.3 + 1.0)
        t += rng.expovariate(max(6.0, density))
        start = int(t * SR)
        freq = rng.uniform(380.0, 1350.0)
        dur = rng.uniform(0.012, 0.045)
        amp = rng.uniform(0.02, 0.07)
        pan = rng.uniform(0.15, 0.85)
        bubble(None, start, freq, dur, amp, math.cos(pan * math.pi * 0.5),
               math.sin(pan * math.pi * 0.5), left, right)

    # Gurgle band that swells with the stream.
    gurgle_mod = slow_wobble(total, rng, 1.8, 0.7)
    band = one_pole(white, coeff_for(1300))
    band_lo = one_pole(white, coeff_for(420))
    for i in range(total):
        g = (band[i] - band_lo[i]) * 0.16 * max(0.0, gurgle_mod[i])
        left[i] += g * 0.8
        right[i] += g

    # Seamless loop: fold the tail over the head with an equal-power crossfade.
    loop_n = int(seconds * SR)
    fade_n = int(fade * SR)
    out_l = left[:loop_n]
    out_r = right[:loop_n]
    for k in range(fade_n):
        a = k / fade_n
        w_in = math.sin(a * math.pi * 0.5)
        w_out = math.cos(a * math.pi * 0.5)
        out_l[k] = out_l[k] * w_in + left[loop_n + k] * w_out
        out_r[k] = out_r[k] * w_in + right[loop_n + k] * w_out
    return out_l, out_r


# ---------------------------------------------------------------------------
# Birds
# ---------------------------------------------------------------------------

def tone(out, start, dur, f_fn, amp, vibrato=0.0, vib_rate=0.0, harm=0.12):
    n = int(dur * SR)
    phase = 0.0
    for k in range(n):
        idx = start + k
        if idx >= len(out):
            break
        t = k / SR
        u = t / dur
        f = f_fn(u) * (1.0 + vibrato * math.sin(math.tau * vib_rate * t))
        phase += f / SR
        env = math.sin(math.pi * u) ** 0.7
        s = math.sin(phase * math.tau) + harm * math.sin(2.0 * phase * math.tau)
        out[idx] += s * env * amp


def sweep(a, b, curve=1.0):
    return lambda u: a + (b - a) * (u ** curve)


def arc(a, peak, b):
    return lambda u: a + (peak - a) * math.sin(math.pi * u) + (b - a) * u


def bird_canvas(seconds):
    return [0.0] * int(seconds * SR)


def room(signal, wet=0.18):
    """Short forest reflections so calls sit in the canopy instead of the ear."""
    out = list(signal) + [0.0] * int(0.35 * SR)
    for delay_ms, g in ((37, 0.42), (61, 0.31), (97, 0.22), (151, 0.14)):
        d = int(delay_ms / 1000.0 * SR)
        for i in range(len(signal)):
            out[i + d] += signal[i] * g * wet * 2.5
    return one_pole(out, coeff_for(9000))


def bird_whistle(rng):
    """Two falling whistles, like a tropical dove-thrush."""
    buf = bird_canvas(1.4)
    base = rng.uniform(2400.0, 3100.0)
    tone(buf, 0, 0.32, sweep(base * 1.12, base * 0.82, 1.3), 0.5, 0.01, 7.0)
    tone(buf, int(0.42 * SR), 0.38, sweep(base * 1.05, base * 0.7, 1.2), 0.45, 0.012, 6.0)
    return buf


def bird_trill(rng):
    """Fast repeated chips — a small warbler."""
    buf = bird_canvas(1.3)
    base = rng.uniform(3800.0, 5200.0)
    count = rng.randint(9, 15)
    gap = rng.uniform(0.045, 0.065)
    for i in range(count):
        drift = 1.0 - 0.012 * i
        tone(buf, int(i * gap * SR), gap * 0.7, arc(base * drift, base * 1.25 * drift, base * 0.9 * drift),
             0.38 * (0.75 + 0.25 * math.sin(i * 0.8)))
    return buf


def bird_warble(rng):
    """Wandering melodic phrase, like a bulbul."""
    buf = bird_canvas(1.8)
    t = 0.0
    notes = rng.randint(5, 8)
    f = rng.uniform(1900.0, 2600.0)
    for _ in range(notes):
        dur = rng.uniform(0.07, 0.16)
        nxt = f * rng.choice([0.84, 0.89, 1.12, 1.19, 1.26])
        tone(buf, int(t * SR), dur, sweep(f, nxt, 0.8), 0.42, 0.02, 24.0)
        f = min(4200.0, max(1600.0, nxt))
        t += dur + rng.uniform(0.02, 0.07)
    return buf


def bird_chirp_pair(rng):
    """Bright up-slurred 'tsee-wit', a sunbird."""
    buf = bird_canvas(0.9)
    base = rng.uniform(4200.0, 5600.0)
    tone(buf, 0, 0.12, sweep(base * 0.7, base * 1.2, 0.7), 0.5)
    tone(buf, int(0.17 * SR), 0.09, arc(base * 1.1, base * 1.35, base * 0.8), 0.46)
    tone(buf, int(0.3 * SR), 0.07, sweep(base * 0.9, base * 1.25), 0.3)
    return buf


def bird_coo(rng):
    """Low soft hoots from deeper in the forest."""
    buf = bird_canvas(2.0)
    base = rng.uniform(420.0, 560.0)
    for i, (start, dur) in enumerate(((0.0, 0.28), (0.42, 0.22), (0.7, 0.5))):
        tone(buf, int(start * SR), dur, arc(base, base * 1.08, base * 0.94), 0.55, 0.006, 5.0, harm=0.25)
    return one_pole(buf, coeff_for(1800))


def render_birds():
    rng = random.Random(9021)
    makers = [
        bird_whistle, bird_trill, bird_warble, bird_chirp_pair,
        bird_whistle, bird_trill, bird_warble, bird_chirp_pair,
        bird_coo, bird_warble,
    ]
    return [room(make(rng)) for make in makers]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    left, right = render_river()
    write_wav(os.path.join(OUT_DIR, "hub_river_loop.wav"), left, right, peak=0.72)
    print("hub_river_loop.wav", len(left) / SR, "s")
    for i, call in enumerate(render_birds(), start=1):
        name = "bird_%d.wav" % i
        write_wav(os.path.join(OUT_DIR, name), call, peak=0.8)
        print(name, round(len(call) / SR, 2), "s")


if __name__ == "__main__":
    main()
