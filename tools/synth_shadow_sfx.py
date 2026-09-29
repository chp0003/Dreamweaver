"""Renders the Shadow Weaver / shadow minion combat sound effects.

Standard library only, so it runs on any Python 3.
    python tools/synth_shadow_sfx.py

Writes 16-bit mono WAVs to assets/audio/sfx/. Every recipe is seeded, so
re-running produces identical files.

The palette is deliberately hostile: sub-bass, tritones and minor seconds,
raspy growls with a sub-octave underneath, whispers and cavern reverb. Bright
sine chirps and major intervals read as "cute" and are avoided.
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

def samples(seconds):
    return int(seconds * SR)


def silence(seconds):
    return [0.0] * samples(seconds)


def lerp(a, b, t):
    return a + (b - a) * t


def exp_sweep(a, b, t):
    """Exponential glide from a to b as t runs 0..1."""
    return a * (b / a) ** max(0.0, min(1.0, t))


def env_ad(t, attack, decay_time, curve=4.0):
    if t < 0.0:
        return 0.0
    if t < attack:
        return t / attack if attack > 0 else 1.0
    return math.exp(-curve * (t - attack) / max(1e-4, decay_time))


def env_swell(t, dur, power=1.6):
    return (max(0.0, min(1.0, t / dur))) ** power


def noise_buffer(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def osc(freq_fn, n, shape="sine", phase=0.0):
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        f = freq_fn(t)
        phase = (phase + f / SR) % 1.0
        if shape == "sine":
            out[i] = math.sin(phase * math.tau)
        elif shape == "saw":
            out[i] = 2.0 * phase - 1.0
        elif shape == "square":
            out[i] = 1.0 if phase < 0.5 else -1.0
        elif shape == "tri":
            out[i] = 4.0 * abs(phase - 0.5) - 1.0
    return out


def svf(signal, cutoff_fn, q=0.707, mode="lp"):
    """Zavalishin TPT state-variable filter with a per-sample cutoff."""
    ic1 = ic2 = 0.0
    k = 1.0 / q
    out = [0.0] * len(signal)
    for i, x in enumerate(signal):
        fc = min(cutoff_fn(i / SR), SR * 0.45)
        g = math.tan(math.pi * max(10.0, fc) / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
        v3 = x - ic2
        v1 = a1 * ic1 + a2 * v3
        v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        if mode == "lp":
            out[i] = v2
        elif mode == "bp":
            out[i] = v1
        else:
            out[i] = x - k * v1 - v2
    return out


def const(value):
    return lambda _t: value


def shape_env(signal, env_fn):
    return [s * env_fn(i / SR) for i, s in enumerate(signal)]


def drive(signal, amount):
    norm = math.tanh(amount)
    return [math.tanh(s * amount) / norm for s in signal]


def gain(signal, g):
    return [s * g for s in signal]


def mix(*layers):
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out


def offset(signal, seconds):
    return silence(seconds) + signal


def reverse(signal):
    return signal[::-1]


def formant_voice(source, formants):
    """Parallel band-passes that turn a buzzy source into a vowel."""
    layers = [gain(svf(source, const(f), q, "bp"), g) for f, q, g in formants]
    return mix(*layers)


def reverb(signal, room=0.78, wet=0.3, tail=0.8, size=1.0):
    """Schroeder reverb: four combs into two all-passes. `size` > 1 is a cavern."""
    padded = signal + silence(tail)
    n = len(padded)
    combs = [int(d * size) for d in (1557, 1617, 1491, 1422)]
    wet_sum = [0.0] * n
    for delay in combs:
        buf = [0.0] * delay
        idx = 0
        lp = 0.0
        for i in range(n):
            y = buf[idx]
            lp = y * 0.6 + lp * 0.4
            buf[idx] = padded[i] + lp * room
            idx = (idx + 1) % delay
            wet_sum[i] += y * 0.25
    for delay in (225, 556):
        buf = [0.0] * delay
        idx = 0
        for i in range(n):
            b = buf[idx]
            y = -wet_sum[i] + b
            buf[idx] = wet_sum[i] + b * 0.5
            idx = (idx + 1) % delay
            wet_sum[i] = y
    return [padded[i] * (1.0 - wet) + wet_sum[i] * wet for i in range(n)]


def cavern(signal, wet=0.38, tail=1.4):
    return reverb(signal, 0.86, wet, tail, 1.7)


def grains(n, rng, count, start, end, make_grain):
    """Scatters short events (debris, crackle, clicks) through a buffer."""
    out = [0.0] * n
    for _ in range(count):
        at = samples(rng.uniform(start, end))
        grain = make_grain(rng)
        for j, s in enumerate(grain):
            if at + j < n:
                out[at + j] += s
    return out


def follower(signal, cutoff=30.0):
    return svf([abs(s) for s in signal], const(cutoff), 0.7, "lp")


def smooth_random(n, rng, hold, cutoff):
    """Random steps every `hold` samples, low-passed into a wandering curve."""
    steps = [0.0] * n
    level = 0.0
    for i in range(n):
        if i % hold == 0:
            level = rng.uniform(-1.0, 1.0)
        steps[i] = level
    return svf(steps, const(cutoff), 0.7, "lp")


def dc_block(signal, r=0.995):
    out = [0.0] * len(signal)
    prev_x = prev_y = 0.0
    for i, x in enumerate(signal):
        prev_y = x - prev_x + r * prev_y
        prev_x = x
        out[i] = prev_y
    return out


def finish(signal, peak_db=-1.0, fade=0.012):
    # Driven formant growls come out lopsided; centre them before normalising.
    signal = dc_block(signal)
    peak = max(1e-6, max(abs(s) for s in signal))
    target = 10 ** (peak_db / 20.0)
    scaled = [s * target / peak for s in signal]
    fade_n = min(len(scaled), samples(fade))
    for i in range(fade_n):
        scaled[len(scaled) - 1 - i] *= i / fade_n
    # Strip trailing silence left by reverb tails.
    end = len(scaled)
    while end > 1 and abs(scaled[end - 1]) < 0.0015:
        end -= 1
    return scaled[:end]


def write_wav(name, signal):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".wav")
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in signal)
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(frames)
    print("%-22s %.2fs" % (name, len(signal) / SR))


# ---------------------------------------------------------------------------
# Shared layers
# ---------------------------------------------------------------------------

VOWEL_DEEP = [(380.0, 5.0, 1.0), (720.0, 6.0, 0.55), (1900.0, 7.0, 0.18)]
VOWEL_AW = [(560.0, 5.0, 1.0), (880.0, 6.0, 0.5), (2300.0, 8.0, 0.16)]
VOWEL_OO = [(300.0, 5.0, 1.0), (640.0, 6.0, 0.4), (2200.0, 8.0, 0.1)]


def boom(dur, f_from, f_to, decay, drive_amount=2.0):
    n = samples(dur)
    body = osc(lambda t: exp_sweep(f_from, f_to, t / (decay * 0.8)), n)
    body = shape_env(body, lambda t: env_ad(t, 0.004, decay))
    return drive(body, drive_amount)


def whoosh(dur, rng, f_from, f_to, q=1.4, attack=0.35, curve=3.0):
    n = samples(dur)
    src = noise_buffer(n, rng)
    band = svf(src, lambda t: exp_sweep(f_from, f_to, t / dur), q, "bp")
    return shape_env(band, lambda t: env_ad(t, dur * attack, dur * (1.0 - attack), curve))


def suck(dur, rng, f_from=250.0, f_to=2600.0):
    """Reverse-swell of air that snaps off: the sound of something inhaling."""
    n = samples(dur)
    band = svf(noise_buffer(n, rng), lambda t: exp_sweep(f_from, f_to, t / dur), 1.6, "bp")
    return shape_env(band, lambda t: env_swell(t, dur, 2.6))


def crackle(dur, rng, count, start=0.0, end=None, hp=2500.0):
    n = samples(dur)
    end = dur * 0.6 if end is None else end

    def click(r):
        m = samples(r.uniform(0.002, 0.008))
        return [r.uniform(-1, 1) * math.exp(-6.0 * j / m) * r.uniform(0.3, 1.0) for j in range(m)]

    raw = grains(n, rng, count, start, end, click)
    return svf(raw, const(hp), 0.7, "hp")


def cluster(freqs, n, shape="saw", detune=0.004, rng=None):
    rng = rng or random.Random(0)
    return mix(*[osc(const(f * rng.uniform(1.0 - detune, 1.0 + detune)), n, shape) for f in freqs])


def demon_growl(dur, rng, pitch_fn, vowel=VOWEL_DEEP, jitter=0.1, rough=28.0, rasp=0.7, sub=0.6):
    """Saw throat through a low formant bank, a square sub-octave underneath and
    breath noise riding the voice's own loudness. The sub and rasp are what make
    it read as a large creature rather than a squeaky one."""
    n = samples(dur)
    wobble = smooth_random(n, rng, 180, 45.0)

    def pitch(t):
        i = min(n - 1, int(t * SR))
        return pitch_fn(t) * (1.0 + jitter * wobble[i] + 0.05 * math.sin(math.tau * rough * t))

    throat = formant_voice(osc(pitch, n, "saw"), vowel)
    under = svf(osc(lambda t: pitch(t) * 0.5, n, "square"), const(260.0), 0.8, "lp")
    level = follower(throat, 25.0)
    breath = svf(noise_buffer(n, rng), const(1100.0), 0.9, "bp")
    flutter = [0.55 + 0.45 * math.sin(math.tau * rough * 1.7 * i / SR) for i in range(n)]
    breath = [b * level[i] * 6.0 * flutter[i] for i, b in enumerate(breath)]
    return mix(throat, gain(under, sub), gain(breath, rasp))


def whisper(dur, rng, density=9.0, low=900.0, high=3400.0):
    """Unintelligible hissing syllables: noise through hopping formants."""
    n = samples(dur)
    src = noise_buffer(n, rng)
    hop = max(1, int(SR / density))
    centres = [rng.uniform(low, high) for _ in range(n // hop + 2)]
    voiced = svf(src, lambda t: centres[min(len(centres) - 1, int(t * SR) // hop)], 4.0, "bp")
    syllables = [max(0.0, s) for s in smooth_random(n, rng, hop, density * 1.4)]
    return [v * syllables[i] * 3.0 for i, v in enumerate(voiced)]


def dark_fm(dur, carrier_fn, ratio=1.414, index_fn=lambda t: 3.0):
    """Inharmonic FM (tritone ratio) for a clangorous, unpleasant tone."""
    n = samples(dur)
    out = [0.0] * n
    mod_phase = car_phase = 0.0
    for i in range(n):
        t = i / SR
        c = carrier_fn(t)
        mod_phase = (mod_phase + c * ratio / SR) % 1.0
        car_phase = (car_phase + (c + math.sin(mod_phase * math.tau) * c * index_fn(t)) / SR) % 1.0
        out[i] = math.sin(car_phase * math.tau)
    return out


def screech(dur, rng, f_centre, swell=0.6):
    """Two sines a minor second apart beating against a resonant noise band."""
    n = samples(dur)
    a = osc(lambda t: f_centre * (1.0 + 0.012 * math.sin(math.tau * 5.3 * t)), n)
    b = osc(lambda t: f_centre * 1.0595 * (1.0 - 0.01 * math.sin(math.tau * 4.1 * t)), n)
    band = svf(noise_buffer(n, rng), lambda t: f_centre * (1.0 + 0.2 * t / dur), 14.0, "bp")
    return shape_env(mix(a, b, gain(band, 2.5)), lambda t: env_swell(t, dur * swell, 1.4))


# ---------------------------------------------------------------------------
# Shadow Weaver
# ---------------------------------------------------------------------------

def weaver_windup():
    rng = random.Random(11)
    dur = 0.95
    n = samples(dur)
    inhale = suck(dur, rng, 220.0, 2400.0)
    tension = cluster((41.2, 43.65, 58.27), n, "saw", rng=rng)
    tension = svf(tension, lambda t: exp_sweep(90.0, 520.0, t / dur), 1.8, "lp")
    tension = shape_env(tension, lambda t: env_swell(t, dur, 1.3))
    breath = demon_growl(dur, rng, lambda t: lerp(46.0, 52.0, t / dur), VOWEL_OO, rasp=1.1, sub=0.3)
    breath = shape_env(breath, lambda t: env_swell(t, dur, 2.0))
    return finish(cavern(mix(gain(inhale, 0.9), gain(tension, 0.8), gain(breath, 0.45)), 0.3, 0.7), -2.0)


def weaver_hiss():
    """Short sharp tell before claws and dashes: a snake-like intake and snarl."""
    rng = random.Random(10)
    dur = 0.5
    n = samples(dur)
    hiss = shape_env(svf(noise_buffer(n, rng), lambda t: exp_sweep(2600.0, 4800.0, t / dur), 1.2, "bp"),
                     lambda t: env_swell(t, dur * 0.8, 1.8) * env_ad(t - dur * 0.8, 0.0, 0.08, 5.0)
                     if t > dur * 0.8 else env_swell(t, dur * 0.8, 1.8))
    snarl = demon_growl(dur, rng, lambda t: lerp(58.0, 66.0, t / dur), VOWEL_AW, 0.14, 34.0, 0.9)
    snarl = drive(shape_env(snarl, lambda t: env_swell(t, dur, 1.5)), 3.0)
    return finish(reverb(mix(gain(hiss, 0.7), gain(snarl, 0.55)), 0.7, 0.2, 0.4), -3.0)


def weaver_claw():
    rng = random.Random(12)
    dur = 0.55
    n = samples(dur)
    swipe = whoosh(dur, rng, 2400.0, 280.0, 1.1, 0.07, 4.5)
    rip = svf(noise_buffer(n, rng), const(900.0), 1.3, "bp")
    rip = shape_env(rip, lambda t: env_ad(t - 0.05, 0.004, 0.16) * (0.5 + 0.5 * math.sin(math.tau * 62.0 * t)))
    tear = shape_env(crackle(dur, rng, 55, 0.04, 0.22, 1800.0), lambda t: env_ad(t, 0.02, 0.2))
    thump = boom(0.35, 110.0, 38.0, 0.16, 2.6)
    return finish(reverb(mix(swipe, gain(rip, 0.9), gain(tear, 0.5), gain(offset(thump, 0.05), 0.9)), 0.7, 0.2, 0.4))


def weaver_lunge():
    rng = random.Random(13)
    dur = 0.85
    rush = whoosh(dur, rng, 180.0, 1100.0, 1.4, 0.35, 3.0)
    snarl = demon_growl(dur, rng, lambda t: lerp(52.0, 70.0, t / dur), VOWEL_AW, 0.16, 30.0, 1.0)
    snarl = drive(shape_env(snarl, lambda t: env_ad(t, 0.1, 0.6)), 4.0)
    thump = boom(0.4, 90.0, 32.0, 0.2, 2.5)
    return finish(cavern(mix(rush, gain(snarl, 0.8), gain(offset(thump, 0.2), 0.6)), 0.22, 0.6))


def weaver_slam():
    rng = random.Random(14)
    dur = 2.0
    n = samples(dur)
    low = boom(dur, 90.0, 24.0, 1.0, 3.5)
    crack = svf(noise_buffer(n, rng), lambda t: exp_sweep(1800.0, 180.0, t / 0.3), 0.8, "lp")
    crack = shape_env(crack, lambda t: env_ad(t, 0.002, 0.25))
    rumble = svf(noise_buffer(n, rng), const(90.0), 0.9, "lp")
    rumble = shape_env(rumble, lambda t: env_ad(t, 0.05, 1.6, 2.6))

    def rock(r):
        m = samples(r.uniform(0.015, 0.05))
        f = r.uniform(300, 1300)
        return [math.sin(math.tau * f * j / SR) * math.exp(-5.0 * j / m) * r.uniform(0.2, 0.6) for j in range(m)]

    debris = shape_env(grains(n, rng, 44, 0.08, 1.2, rock), lambda t: env_ad(t, 0.05, 1.0))
    groan = shape_env(screech(dur, rng, 190.0, 0.05), lambda t: env_ad(t, 0.05, 1.2, 3.0))
    return finish(cavern(mix(low, gain(crack, 0.9), gain(rumble, 2.8), gain(debris, 0.45), gain(groan, 0.08)), 0.34, 1.2))


def weaver_cast():
    rng = random.Random(15)
    dur = 0.8
    n = samples(dur)
    clang = dark_fm(dur, lambda t: exp_sweep(72.0, 98.0, t / dur), 1.414, lambda t: 4.5 * (1.0 - t / dur) + 0.6)
    clang = shape_env(svf(clang, const(1400.0), 0.8, "lp"), lambda t: env_ad(t, 0.12, 0.6, 2.6))
    voices = shape_env(whisper(dur, rng, 11.0), lambda t: env_swell(t, dur * 0.7, 1.2))
    rise = shape_env(suck(dur, rng, 400.0, 1800.0), lambda t: 0.6)
    return finish(cavern(mix(gain(clang, 0.7), gain(voices, 0.55), gain(rise, 0.5)), 0.32, 0.7), -2.0)


def weaver_bolt_fire():
    rng = random.Random(16)
    dur = 0.5
    n = samples(dur)
    spit = whoosh(dur, rng, 1600.0, 260.0, 1.3, 0.03, 5.0)
    thump = boom(0.3, 95.0, 38.0, 0.12, 2.4)
    hiss = shape_env(svf(noise_buffer(n, rng), const(3200.0), 1.0, "bp"), lambda t: env_ad(t, 0.002, 0.2, 5.0))
    howl = shape_env(dark_fm(dur, lambda t: exp_sweep(260.0, 120.0, t / dur), 1.414, lambda t: 2.0),
                     lambda t: env_ad(t, 0.005, 0.25, 4.0))
    return finish(reverb(mix(spit, gain(thump, 0.9), gain(hiss, 0.3), gain(howl, 0.18)), 0.72, 0.22, 0.4), -3.0)


def weaver_bolt_impact():
    rng = random.Random(17)
    dur = 0.7
    n = samples(dur)
    burst = svf(noise_buffer(n, rng), lambda t: exp_sweep(2400.0, 160.0, t / 0.4), 0.9, "lp")
    burst = shape_env(burst, lambda t: env_ad(t, 0.002, 0.35))
    thud = boom(dur, 120.0, 32.0, 0.22, 2.8)
    sizzle = shape_env(crackle(dur, rng, 30, 0.01, 0.45, 1500.0), lambda t: env_ad(t, 0.0, 0.4))
    return finish(reverb(mix(burst, gain(thud, 1.0), gain(sizzle, 0.4)), 0.8, 0.25, 0.6), -2.0)


def weaver_dash():
    rng = random.Random(18)
    dur = 0.6
    n = samples(dur)
    vanish = suck(dur * 0.55, rng, 160.0, 1900.0)
    burst = whoosh(dur, rng, 1400.0, 180.0, 1.2, 0.05, 3.5)
    arrive = boom(0.35, 80.0, 30.0, 0.18, 3.0)
    ghost = shape_env(whisper(dur, rng, 14.0, 1400.0, 4200.0), lambda t: env_ad(t, 0.1, 0.4))
    return finish(cavern(mix(gain(vanish, 0.8), offset(gain(burst, 0.8), dur * 0.5),
                             offset(gain(arrive, 0.9), dur * 0.5), gain(ghost, 0.35)), 0.3, 0.8), -2.0)


def weaver_nova():
    rng = random.Random(19)
    dur = 2.4
    n = samples(dur)
    low = boom(dur, 110.0, 20.0, 1.2, 3.6)
    dread = cluster((55.0, 58.27, 77.78, 82.41), n, "saw", rng=rng)
    dread = shape_env(svf(dread, lambda t: exp_sweep(1600.0, 160.0, t / dur), 1.4, "lp"),
                      lambda t: env_ad(t, 0.01, 1.8, 2.4))
    shriek = shape_env(screech(dur, rng, 1480.0, 0.02), lambda t: env_ad(t, 0.01, 0.9, 3.0))
    wash = shape_env(svf(noise_buffer(n, rng), lambda t: exp_sweep(4000.0, 500.0, t / dur), 0.8, "hp"),
                     lambda t: env_ad(t, 0.005, 1.0, 3.0))
    crack = shape_env(svf(noise_buffer(n, rng), const(700.0), 0.7, "lp"), lambda t: env_ad(t, 0.001, 0.25))
    return finish(cavern(mix(low, gain(dread, 0.35), gain(shriek, 0.12), gain(wash, 0.4), gain(crack, 0.9)), 0.4, 1.6))


def weaver_summon():
    rng = random.Random(20)
    dur = 1.9
    n = samples(dur)
    drone = cluster((36.71, 38.89, 51.91), n, "saw", rng=rng)
    drone = svf(drone, lambda t: exp_sweep(120.0, 900.0, t / dur), 2.2, "lp")
    drone = shape_env(drone, lambda t: env_swell(t, dur * 0.7, 1.2) * env_ad(t, 0.0, dur * 1.1, 1.2))
    choir = mix(*[
        demon_growl(dur, random.Random(200 + k), const(f), VOWEL_OO, 0.03, 5.0, 0.4, 0.2)
        for k, f in enumerate((73.4, 77.8, 103.8))
    ])
    choir = shape_env(choir, lambda t: env_swell(t, dur * 0.8, 1.5))
    voices = shape_env(whisper(dur, rng, 7.0, 700.0, 2600.0), lambda t: env_swell(t, dur * 0.6, 1.0))
    return finish(cavern(mix(gain(drone, 0.45), gain(choir, 0.35), gain(voices, 0.5)), 0.42, 1.4), -1.5)


def weaver_blind():
    rng = random.Random(21)
    dur = 1.6
    n = samples(dur)
    shriek = screech(0.45, rng, 2217.0, 1.0)
    shriek = shriek + silence(dur - 0.45)
    drop = offset(boom(dur - 0.45, 70.0, 18.0, 0.9, 3.4), 0.45)
    snap = offset(shape_env(svf(noise_buffer(n, rng), const(900.0), 0.7, "lp"),
                            lambda t: env_ad(t, 0.001, 0.2)), 0.45)
    dark = offset(shape_env(whisper(dur - 0.5, rng, 6.0, 500.0, 1600.0), lambda t: env_ad(t, 0.2, 0.8, 2.0)), 0.5)
    return finish(cavern(mix(gain(shriek, 0.35), drop, gain(snap, 0.8), gain(dark, 0.5)), 0.4, 1.2), -1.5)


def weaver_hurt():
    rng = random.Random(22)
    dur = 0.6
    voice = demon_growl(dur, rng, lambda t: exp_sweep(92.0, 54.0, t / dur), VOWEL_AW, 0.16, 32.0, 1.0)
    voice = drive(shape_env(voice, lambda t: env_ad(t, 0.02, 0.4, 3.0)), 4.0)
    hit = boom(0.3, 120.0, 40.0, 0.14, 2.4)
    return finish(reverb(mix(gain(voice, 0.85), gain(hit, 0.6)), 0.78, 0.22, 0.5), -2.0)


def weaver_stagger():
    rng = random.Random(23)
    dur = 1.8
    n = samples(dur)
    crash = shape_env(svf(noise_buffer(n, rng), lambda t: exp_sweep(2400.0, 180.0, t / 0.5), 0.8, "lp"),
                      lambda t: env_ad(t, 0.002, 0.45))
    low = boom(dur, 75.0, 26.0, 0.8, 3.0)
    creak = shape_env(svf(noise_buffer(n, rng), lambda t: exp_sweep(700.0, 260.0, t / dur), 16.0, "bp"),
                      lambda t: env_ad(t, 0.2, 1.2, 2.0) * (0.6 + 0.4 * math.sin(math.tau * 11.0 * t)))
    moan = demon_growl(dur, rng, lambda t: exp_sweep(70.0, 38.0, t / dur), VOWEL_OO, 0.12, 14.0, 0.8)
    moan = drive(shape_env(moan, lambda t: env_ad(t, 0.12, 1.2, 2.2)), 2.5)
    return finish(cavern(mix(crash, low, gain(creak, 1.6), gain(moan, 0.6)), 0.34, 1.2))


def roar_contour(t, dur):
    """Rises into the bellow, then sags as the breath runs out."""
    x = t / dur
    if x < 0.22:
        return lerp(40.0, 72.0, x / 0.22)
    return lerp(72.0, 44.0, (x - 0.22) / 0.78)


def weaver_roar():
    rng = random.Random(24)
    dur = 2.6
    n = samples(dur)
    shape = lambda t: env_ad(t, 0.22, 2.3, 2.0)
    voice = demon_growl(dur, rng, lambda t: roar_contour(t, dur), VOWEL_AW, 0.16, 26.0, 1.2, 0.8)
    voice = drive(shape_env(voice, shape), 5.0)
    layer = demon_growl(dur, random.Random(240), lambda t: roar_contour(t, dur) * 1.498, VOWEL_DEEP, 0.2, 21.0, 0.6)
    layer = drive(shape_env(layer, shape), 3.0)
    rattle = shape_env(svf(noise_buffer(n, rng), const(180.0), 0.8, "lp"),
                       lambda t: shape(t) * (0.5 + 0.5 * math.sin(math.tau * 29.0 * t)))
    quake = boom(dur, 60.0, 22.0, 1.4, 2.0)
    return finish(cavern(mix(gain(voice, 0.8), gain(layer, 0.3), gain(rattle, 1.2), gain(quake, 0.5)), 0.4, 1.8))


def weaver_death():
    rng = random.Random(25)
    dur = 3.6
    n = samples(dur)
    shape = lambda t: env_ad(t, 0.15, 3.0, 2.0)
    voice = demon_growl(dur, rng, lambda t: exp_sweep(110.0, 26.0, t / dur), VOWEL_AW, 0.22, 18.0, 1.2, 0.7)
    voice = drive(shape_env(voice, shape), 4.0)
    ghosts = shape_env(screech(dur, rng, 880.0, 0.1), lambda t: env_ad(t, 0.3, 2.4, 2.0))
    voices = shape_env(whisper(dur, rng, 12.0), lambda t: env_swell(t, dur * 0.5, 1.2) * env_ad(t, 0.0, dur, 1.6))
    collapse = boom(dur, 70.0, 18.0, 1.8, 2.5)
    return finish(cavern(mix(gain(voice, 0.75), gain(ghosts, 0.08), gain(voices, 0.5), gain(collapse, 0.6)), 0.45, 2.2))


# ---------------------------------------------------------------------------
# Shadow minions
# ---------------------------------------------------------------------------

def wet_clicks(dur, rng, count, start, end):
    def click(r):
        m = samples(r.uniform(0.004, 0.015))
        f = r.uniform(180.0, 600.0)
        return [math.sin(math.tau * f * j / SR) * math.exp(-7.0 * j / m) * r.uniform(0.3, 1.0) for j in range(m)]
    return grains(samples(dur), rng, count, start, end, click)


def minion_spawn():
    rng = random.Random(31)
    dur = 1.0
    n = samples(dur)
    ooze = shape_env(svf(noise_buffer(n, rng), lambda t: lerp(120.0, 420.0, t / dur), 1.5, "lp"),
                     lambda t: env_swell(t, dur * 0.6, 1.2) * env_ad(t, 0.0, dur, 1.5))
    clicks = wet_clicks(dur, rng, 34, 0.0, 0.8)
    groan = demon_growl(dur, rng, lambda t: lerp(62.0, 80.0, t / dur), VOWEL_DEEP, 0.14, 24.0, 1.0, 0.4)
    groan = shape_env(groan, lambda t: env_swell(t, dur * 0.8, 2.0))
    return finish(reverb(mix(gain(ooze, 0.8), gain(clicks, 0.3), gain(groan, 0.5)), 0.78, 0.26, 0.5), -3.0)


def minion_attack():
    rng = random.Random(32)
    dur = 0.36
    swipe = whoosh(dur, rng, 2800.0, 500.0, 1.3, 0.1, 4.5)
    snarl = demon_growl(dur, rng, lambda t: exp_sweep(110.0, 82.0, t / dur), VOWEL_AW, 0.16, 36.0, 1.2, 0.4)
    snarl = drive(shape_env(snarl, lambda t: env_ad(t, 0.01, 0.2)), 3.5)
    return finish(mix(swipe, gain(snarl, 0.6)), -4.0)


def minion_dash():
    rng = random.Random(33)
    dur = 0.36
    n = samples(dur)
    rush = whoosh(dur, rng, 350.0, 1600.0, 1.4, 0.4, 4.0)
    hiss = shape_env(svf(noise_buffer(n, rng), const(3800.0), 1.4, "bp"), lambda t: env_swell(t, dur, 2.0))
    return finish(mix(rush, gain(hiss, 0.4)), -4.0)


def minion_cast():
    rng = random.Random(34)
    dur = 0.55
    clang = dark_fm(dur, lambda t: exp_sweep(110.0, 150.0, t / dur), 1.414, lambda t: 3.0 * (1.0 - t / dur))
    clang = shape_env(svf(clang, const(1200.0), 0.8, "lp"), lambda t: env_swell(t, dur * 0.8, 1.6))
    voices = shape_env(whisper(dur, rng, 14.0), lambda t: env_swell(t, dur, 1.2))
    return finish(reverb(mix(gain(clang, 0.5), gain(voices, 0.6)), 0.72, 0.25, 0.4), -5.0)


def minion_hurt():
    rng = random.Random(35)
    dur = 0.34
    shriek = demon_growl(dur, rng, lambda t: exp_sweep(170.0, 120.0, t / dur), VOWEL_AW, 0.2, 44.0, 1.6, 0.3)
    shriek = drive(shape_env(shriek, lambda t: env_ad(t, 0.006, 0.2, 3.0)), 4.0)
    return finish(shriek, -4.0)


def minion_death():
    rng = random.Random(36)
    dur = 1.1
    n = samples(dur)
    collapse = shape_env(svf(noise_buffer(n, rng), lambda t: exp_sweep(1800.0, 160.0, t / dur), 1.0, "lp"),
                         lambda t: env_ad(t, 0.004, 0.7, 3.0))
    gasp = demon_growl(dur, rng, lambda t: exp_sweep(120.0, 38.0, t / dur), VOWEL_OO, 0.2, 20.0, 1.3, 0.5)
    gasp = drive(shape_env(gasp, lambda t: env_ad(t, 0.02, 0.6, 3.0)), 3.0)
    fade = shape_env(whisper(dur, rng, 12.0, 1500.0, 4500.0), lambda t: env_ad(t, 0.1, 0.8, 2.5))
    return finish(reverb(mix(collapse, gain(gasp, 0.6), gain(fade, 0.35)), 0.8, 0.3, 0.7), -3.0)


# ---------------------------------------------------------------------------
# Impacts
# ---------------------------------------------------------------------------

def shadow_hit():
    """S'lang's staff connecting with shadow: a heavy, wet crunch."""
    rng = random.Random(41)
    dur = 0.32
    n = samples(dur)
    thump = boom(dur, 120.0, 42.0, 0.12, 2.8)
    snap = shape_env(svf(noise_buffer(n, rng), const(1600.0), 0.9, "bp"), lambda t: env_ad(t, 0.001, 0.05))
    squelch = shape_env(svf(noise_buffer(n, rng), lambda t: exp_sweep(900.0, 250.0, t / dur), 3.0, "bp"),
                        lambda t: env_ad(t, 0.005, 0.12))
    return finish(mix(thump, gain(snap, 0.7), gain(squelch, 0.6)), -2.0)


def player_hit_heavy():
    """Weaver skills landing on S'lang."""
    rng = random.Random(42)
    dur = 0.55
    n = samples(dur)
    thud = boom(dur, 80.0, 30.0, 0.24, 3.4)
    crunch = shape_env(svf(noise_buffer(n, rng), lambda t: exp_sweep(1400.0, 200.0, t / 0.2), 1.0, "lp"),
                       lambda t: env_ad(t, 0.001, 0.14))
    return finish(reverb(mix(thud, gain(crunch, 0.9)), 0.7, 0.18, 0.3), -2.0)


def perfect_dodge():
    """Time slows: a reversed swell into a low, ringing thrum."""
    rng = random.Random(43)
    dur = 0.9
    n = samples(dur)
    inhale = reverse(shape_env(svf(noise_buffer(n, rng), const(2600.0), 1.2, "bp"), lambda t: env_ad(t, 0.0, 0.5, 4.0)))
    thrum = shape_env(dark_fm(dur, const(65.4), 2.0, lambda t: 1.6 * (1.0 - t / dur)), lambda t: env_ad(t - 0.35, 0.02, 0.5, 3.0))
    return finish(cavern(mix(gain(inhale, 0.5), gain(thrum, 0.8)), 0.35, 0.8), -3.0)


def slang_ward_raise():
    """S'lang's ward: a quick airy swell that locks into a warm fifth."""
    rng = random.Random(51)
    dur = 0.55
    n = samples(dur)
    swell = shape_env(svf(noise_buffer(n, rng), lambda t: 900.0 + 5200.0 * min(1.0, t / 0.12), 1.4, "bp"),
                      lambda t: env_ad(t, 0.08, 0.2, 3.0))
    body = mix(osc(const(293.7), n, "sine"), gain(osc(const(440.0), n, "sine"), 0.7),
               gain(osc(const(587.3), n, "triangle"), 0.35))
    body = shape_env(body, lambda t: env_ad(t - 0.06, 0.02, 0.45, 3.5))
    return finish(reverb(mix(gain(swell, 0.5), gain(body, 0.6)), 0.7, 0.3, 0.5), -4.0)


def slang_ward_block():
    """A blow caught on the ward: a dull knock plus a bright shimmering ring."""
    rng = random.Random(52)
    dur = 0.6
    n = samples(dur)
    knock = shape_env(svf(noise_buffer(n, rng), const(700.0), 0.9, "lp"), lambda t: env_ad(t, 0.001, 0.07, 5.0))
    ring = mix(osc(const(880.0), n, "sine"), gain(osc(const(1318.5), n, "sine"), 0.6),
               gain(osc(const(2217.0), n, "sine"), 0.3))
    ring = shape_env(ring, lambda t: env_ad(t, 0.002, 0.5, 4.0) * (1.0 + 0.25 * math.sin(math.tau * 11.0 * t)))
    return finish(reverb(mix(gain(knock, 0.9), gain(ring, 0.45)), 0.72, 0.28, 0.5), -2.0)


RECIPES = [
    weaver_windup, weaver_hiss, weaver_claw, weaver_lunge, weaver_slam, weaver_cast,
    weaver_bolt_fire, weaver_bolt_impact, weaver_dash, weaver_nova, weaver_summon,
    weaver_blind, weaver_hurt, weaver_stagger, weaver_roar, weaver_death,
    minion_spawn, minion_attack, minion_dash, minion_cast, minion_hurt, minion_death,
    shadow_hit, player_hit_heavy, perfect_dodge, slang_ward_raise, slang_ward_block,
]


if __name__ == "__main__":
    for recipe in RECIPES:
        write_wav(recipe.__name__, recipe())
