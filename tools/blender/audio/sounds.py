"""Every sound in the game, synthesized here (docs/ART_BIBLE.md#audio): numpy for the
signal, Blender's aud to write the files into assets/audio/.
  effects   short .wav one-shots (swings, bronze clangs, the thread snapping...)
  ambience  30 s .ogg loops: surf, cicadas, wind, the necropolis, the forge
  music     modal .ogg loops: lyre (plucked strings), aulos (double reed), frame drum
            and drones; Dorian for the living, Phrygian for the dead and the bull
Run with `npm run audio`.
"""
import math
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
import kit  # noqa: E402

SR = 44100
OUT = os.path.join(kit.ASSETS, "audio")
RNG = np.random.default_rng(7)


# --- building blocks -----------------------------------------------------------------------

def t(seconds, sr=SR):
    return np.arange(int(sr * seconds)) / sr


def noise(seconds, sr=SR):
    return RNG.uniform(-1.0, 1.0, int(sr * seconds))


def env(n, attack=0.005, decay=0.2, sr=SR):
    """Fast attack, exponential decay."""
    x = np.arange(n) / sr
    a = np.clip(x / max(attack, 1e-4), 0.0, 1.0)
    return a * np.exp(-np.maximum(0.0, x - attack) / max(decay, 1e-4))


def spectral(x, response, sr=SR):
    """Filters by shaping the spectrum: response(freqs) -> gain."""
    n = len(x)
    size = 1 << int(math.ceil(math.log2(max(2, n))))
    spec = np.fft.rfft(x, size)
    freqs = np.fft.rfftfreq(size, 1.0 / sr)
    return np.fft.irfft(spec * response(freqs), size)[:n]


def lowpass(x, cutoff, order=2, sr=SR):
    return spectral(x, lambda f: 1.0 / (1.0 + (f / cutoff) ** (2 * order)), sr)


def highpass(x, cutoff, order=2, sr=SR):
    return spectral(x, lambda f: 1.0 - 1.0 / (1.0 + (f / max(cutoff, 1)) ** (2 * order)), sr)


def bandpass(x, low, high, sr=SR):
    return highpass(lowpass(x, high, 2, sr), low, 2, sr)


def sweep(f0, f1, seconds, shape="sine", sr=SR):
    x = t(seconds, sr)
    freq = f0 * (f1 / f0) ** (x / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / sr
    if shape == "saw":
        return 2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0
    if shape == "square":
        return np.sign(np.sin(phase))
    return np.sin(phase)


def partials(freqs, amps, decays, seconds, sr=SR):
    """A struck body: inharmonic partials each with its own decay (bronze, bells)."""
    x = t(seconds, sr)
    out = np.zeros_like(x)
    for f, a, d in zip(freqs, amps, decays):
        out += a * np.sin(2 * np.pi * f * x + RNG.uniform(0, 6.28)) * np.exp(-x / d)
    return out


def pluck(freq, seconds=1.6, bright=1.0, sr=SR):
    """A lyre string: harmonics decaying faster the higher they are, a little
    inharmonicity, a burst of finger noise at the start."""
    x = t(seconds, sr)
    out = np.zeros_like(x)
    for k in range(1, 14):
        f = freq * k * (1.0 + 0.0004 * k * k)
        if f > sr / 2.2:
            break
        amp = (1.0 / k ** 1.15) * (bright if k > 3 else 1.0)
        decay = seconds * 0.55 / (1.0 + 0.35 * (k - 1))
        out += amp * np.sin(2 * np.pi * f * x) * np.exp(-x / decay)
    attack = lowpass(noise(0.012, sr), 3500, 2, sr) * 0.3
    out[: len(attack)] += attack
    out *= np.clip(x / 0.002, 0, 1)
    return out


def reed(freq, seconds, vibrato=5.0, depth=0.006, sr=SR):
    """An aulos note: a buzzy double reed, filtered, with vibrato and breath."""
    x = t(seconds, sr)
    f = freq * (1.0 + depth * np.sin(2 * np.pi * vibrato * x))
    phase = 2 * np.pi * np.cumsum(f) / sr
    tone = np.sign(np.sin(phase)) * 0.5 + 0.5 * (2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0)
    tone = lowpass(tone, freq * 4.5, 2, sr)
    breath = bandpass(noise(seconds, sr), freq * 2, freq * 6, sr) * 0.05
    shape = np.minimum(1.0, x / 0.05) * np.minimum(1.0, (seconds - x) / 0.08)
    return (tone + breath) * shape


def drum(seconds=0.6, pitch=90.0, sr=SR):
    """A frame drum (tympanon): a falling thump and a skin slap."""
    body = sweep(pitch * 1.8, pitch, seconds, sr=sr) * env(int(sr * seconds), 0.002, seconds * 0.35, sr)
    slap = bandpass(noise(seconds, sr), 300, 2500, sr) * env(int(sr * seconds), 0.001, 0.03, sr) * 0.4
    return body + slap


def reverb(x, seconds=1.6, mix=0.3, sr=SR):
    n = int(sr * seconds)
    impulse = RNG.uniform(-1, 1, n) * np.exp(-np.arange(n) / (sr * seconds / 5.0))
    impulse = lowpass(impulse, 5000, 1, sr)
    impulse /= np.sqrt(np.sum(impulse ** 2))
    size = 1 << int(math.ceil(math.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(impulse, size), size)[: len(x) + n]
    out = np.zeros(len(x) + n)
    out[: len(x)] += x * (1.0 - mix)
    out += wet * mix
    return out


def mix(*parts):
    length = max(len(p) for p in parts)
    out = np.zeros(length)
    for p in parts:
        out[: len(p)] += p
    return out


def at(base, part, start, sr=SR):
    i = int(start * sr)
    if i >= len(base):
        return
    end = min(len(base), i + len(part))
    base[i:end] += part[: end - i]


def normalize(x, peak=0.89):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def fade(x, inn=0.003, out=0.02, sr=SR):
    n = len(x)
    a, b = int(inn * sr), int(out * sr)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def write_wav(name, x, sr=SR, peak=0.89):
    data = (np.clip(normalize(fade(np.array(x, dtype=np.float64)), peak), -1, 1) * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, f"{name}.wav"), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sr)
        handle.writeframes(data.tobytes())


def write_loop(name, x, sr, peak=0.8):
    """Loops as Ogg Vorbis through Blender's aud (small files); the end is blended
    into the start so the loop has no seam."""
    x = normalize(np.array(x, dtype=np.float64), peak)
    blend = int(sr * 1.5)
    head = x[:blend].copy()
    x = x[blend:]
    x[-blend:] = x[-blend:] * np.linspace(1, 0, blend) + head * np.linspace(0, 1, blend)
    path = os.path.join(OUT, f"{name}.ogg")
    os.makedirs(OUT, exist_ok=True)
    try:
        import aud
        sound = aud.Sound.buffer(x.astype(np.float32).reshape(-1, 1), float(sr))
        sound.write(path, rate=sr, channels=aud.CHANNELS_MONO, format=aud.FORMAT_FLOAT32, container=aud.CONTAINER_OGG,
                    codec=aud.CODEC_VORBIS, bitrate=96000)
        if os.path.getsize(path) < 1000:
            raise RuntimeError("tiny file")
    except Exception as error:
        kit.log("audio", f"aud could not write {name}.ogg ({error}); writing .wav")
        if os.path.exists(path):
            os.remove(path)
        write_wav(name, x, sr, peak)


# --- effects --------------------------------------------------------------------------------

def whoosh(seconds=0.2, lo=400, hi=2600, up=True):
    n = noise(seconds)
    x = t(seconds)
    center = lo + (hi - lo) * (x / seconds if up else 1 - x / seconds)
    out = np.zeros_like(n)
    for k in range(6):
        seg = slice(k * len(n) // 6, (k + 1) * len(n) // 6)
        c = float(np.mean(center[seg]))
        out[seg] = bandpass(n, c * 0.6, c * 1.5)[seg]
    return out * np.sin(np.pi * x / seconds) ** 1.5


def bronze(scale=1.0, seconds=0.5):
    base = 640 * scale
    return partials([base, base * 1.48, base * 2.32, base * 3.11, base * 4.27], [1, 0.6, 0.45, 0.3, 0.2], [0.25, 0.18, 0.12, 0.08, 0.05], seconds)


def thud(pitch=80, seconds=0.25):
    return sweep(pitch * 2.2, pitch, seconds) * env(int(SR * seconds), 0.001, seconds * 0.3)


def chime(base=880, seconds=1.2):
    return partials([base, base * 2.01, base * 3.03, base * 4.2], [1, 0.4, 0.25, 0.1], [0.6, 0.35, 0.25, 0.15], seconds)


def effects():
    S = {}
    S["swing"] = whoosh(0.2, 500, 2800)
    S["hit"] = mix(thud(85, 0.2), bronze(1.0, 0.35) * 0.35, bandpass(noise(0.03), 2000, 5000) * 0.5)
    S["hit_flesh"] = mix(thud(65, 0.3) * 1.2, lowpass(noise(0.12), 900) * env(int(SR * 0.12), 0.001, 0.05) * 0.8)
    S["hurt"] = mix(thud(70, 0.22), lowpass(sweep(160, 95, 0.25, "saw"), 900) * env(int(SR * 0.25), 0.01, 0.1) * 0.5)
    S["bow"] = mix(pluck(165, 0.35, 0.6) * 0.8, whoosh(0.25, 800, 3500) * 0.5)
    S["lunge"] = mix(whoosh(0.3, 300, 3200), chime(1320, 0.5) * 0.25)
    S["bash"] = mix(thud(60, 0.35) * 1.2, bronze(0.55, 0.6) * 0.6)
    S["lash"] = mix(bandpass(noise(0.05), 1500, 7000) * env(int(SR * 0.05), 0.0005, 0.01) * 1.4, sweep(2500, 600, 0.25) * env(int(SR * 0.25), 0.001, 0.08) * 0.3,
                    chime(1760, 0.8) * 0.3)
    roar = sum(lowpass(sweep(f, f * 0.85, 1.0, "saw"), 1200) for f in (110, 138, 165)) / 3
    S["war_cry"] = mix(roar * np.sin(np.pi * t(1.0)) ** 0.5, drum(0.7, 70) * 1.2)
    S["bind"] = mix(chime(990, 1.2) * 0.6, chime(1485, 1.0) * 0.3, whoosh(0.6, 300, 1800) * 0.4)
    rumble = lowpass(noise(1.2), 180) * np.sin(np.pi * t(1.2) / 1.2)
    rattle = np.zeros(int(SR * 1.2))
    for k in range(9):
        at(rattle, bandpass(noise(0.015), 1500, 4000) * 0.5, 0.3 + k * 0.07 + RNG.uniform(0, 0.03))
    S["rise"] = mix(rumble * 1.4, whoosh(1.1, 200, 1400) * 0.6, rattle)
    snap = pluck(1046, 0.25, 1.2) * np.exp(-t(0.25) / 0.04)
    S["death_shade"] = mix(whoosh(0.9, 2000, 300, up=False) * 0.7, snap * 0.8)
    S["death_beast"] = mix(lowpass(sweep(140, 70, 0.6, "saw"), 600) * env(int(SR * 0.6), 0.01, 0.25), thud(55, 0.4))
    snort = np.zeros(int(SR * 0.5))
    for s in (0.0, 0.22):
        at(snort, lowpass(noise(0.15), 700) * np.sin(np.pi * t(0.15) / 0.15), s)
    S["snort"] = snort
    jingle = np.zeros(int(SR * 0.5))
    for k in range(6):
        at(jingle, partials([2400 + RNG.uniform(0, 1500), 5200 + RNG.uniform(0, 1500)], [1, 0.5], [0.06, 0.03], 0.15), k * 0.05 + RNG.uniform(0, 0.02))
    S["coins"] = jingle
    S["drop_gold"] = jingle * 0.6
    S["drop_item"] = mix(thud(110, 0.15), bandpass(noise(0.04), 800, 2500) * 0.2)
    S["pickup"] = mix(bandpass(noise(0.03), 1000, 4000) * 0.3, pluck(523, 0.3, 0.8) * 0.4)
    gulp = np.zeros(int(SR * 0.55))
    for k in range(3):
        at(gulp, lowpass(sweep(300, 180, 0.12), 900) * np.sin(np.pi * t(0.12) / 0.12), 0.05 + k * 0.15)
    S["potion"] = mix(gulp, chime(2093, 0.4) * 0.15)
    d_dorian = [293.66, 329.63, 349.23, 392.0, 440.0, 493.88, 523.25, 587.33]
    arp = np.zeros(int(SR * 1.6))
    for k, i in enumerate((0, 2, 4)):
        at(arp, pluck(d_dorian[i] * 2, 1.2), k * 0.11)
    S["quest"] = reverb(arp, 1.2, 0.25)
    big = np.zeros(int(SR * 2.4))
    for k, i in enumerate((0, 2, 4, 7)):
        at(big, pluck(d_dorian[i] * 2, 1.8), k * 0.12)
    for i in (0, 4, 7):
        at(big, pluck(d_dorian[i], 2.0) * 0.6, 0.6)
    S["quest_done"] = reverb(big, 1.6, 0.3)
    lvl = np.zeros(int(SR * 2.6))
    for k, i in enumerate((0, 1, 2, 3, 4, 5, 6, 7)):
        at(lvl, pluck(d_dorian[i] * 2, 1.4) * 0.8, k * 0.06)
    at(lvl, chime(1174, 1.8) * 0.5, 0.5)
    S["level_up"] = reverb(lvl, 1.8, 0.35)
    S["weave"] = mix(pluck(587.33, 0.8), chime(1760, 0.8) * 0.25)
    S["banner"] = reverb(partials([98, 147.5, 196.6, 263, 331], [1, 0.6, 0.4, 0.25, 0.15], [1.6, 1.2, 0.9, 0.6, 0.4], 2.2), 2.0, 0.35)
    S["talk"] = pluck(392, 0.5, 0.7) * 0.6
    S["ui_open"] = mix(bandpass(noise(0.03), 600, 2500) * 0.4, pluck(440, 0.3, 0.6) * 0.5)
    S["ui_close"] = mix(bandpass(noise(0.03), 500, 2000) * 0.4, pluck(330, 0.3, 0.6) * 0.5)
    S["ui_click"] = bandpass(noise(0.02), 1500, 5000) * env(int(SR * 0.02), 0.0005, 0.006)
    S["ui_hover"] = pluck(1318, 0.12, 0.4) * 0.25
    S["denied"] = lowpass(sweep(140, 110, 0.18, "square"), 700) * env(int(SR * 0.18), 0.002, 0.08) * 0.6
    S["equip"] = mix(bronze(1.3, 0.3) * 0.5, thud(150, 0.1) * 0.5)
    S["lift"] = bandpass(noise(0.08), 800, 3500) * np.sin(np.pi * t(0.08) / 0.08) * 0.5
    S["place"] = thud(130, 0.12) * 0.7
    shatter = np.zeros(int(SR * 0.6))
    for k in range(14):
        at(shatter, partials([1800 + RNG.uniform(0, 3000)], [1], [0.03 + RNG.uniform(0, 0.04)], 0.12) * RNG.uniform(0.3, 1.0), RNG.uniform(0, 0.2))
    S["pot_break"] = mix(shatter, thud(140, 0.15) * 0.6, bandpass(noise(0.08), 1000, 6000) * env(int(SR * 0.08), 0.001, 0.02))
    creak = lowpass(sweep(90, 140, 0.5, "saw"), 1400) * np.sin(np.pi * t(0.5) / 0.5) * 0.5
    S["chest"] = mix(creak, thud(100, 0.2) * 0.6, jingle * 0.3)
    S["shrine"] = mix(lowpass(noise(1.0), 1200) * np.sin(np.pi * t(1.0)) * 0.6, chime(523, 1.6) * 0.5)
    grind = lowpass(noise(2.2), 260) * (0.6 + 0.4 * np.sin(2 * np.pi * 3 * t(2.2)))
    S["gate"] = mix(grind * np.sin(np.pi * t(2.2) / 2.2), np.pad(bronze(0.4, 1.2), (int(SR * 2.0), 0)) * 0.8)
    roar = sum(lowpass(sweep(f, f * 0.8, 2.0, "saw"), 700) * (1 + 0.3 * np.sin(2 * np.pi * 6 * t(2.0))) for f in (55, 69, 82, 110)) / 4
    S["bull_roar"] = mix(roar * np.sin(np.pi * t(2.0) / 2.0) ** 0.6, bronze(0.25, 2.0) * 0.4, lowpass(noise(2.0), 400) * 0.3)
    S["bull_hit"] = mix(thud(45, 0.5) * 1.3, bronze(0.35, 0.8) * 0.7)
    S["bull_crash"] = mix(bronze(0.3, 1.6), bronze(0.47, 1.2) * 0.7, thud(40, 0.6) * 1.4, lowpass(noise(1.0), 2000) * env(int(SR), 0.002, 0.3))
    crackle = np.zeros(int(SR * 1.6))
    for k in range(30):
        at(crackle, bandpass(noise(0.01), 2000, 6000) * RNG.uniform(0.2, 0.7), RNG.uniform(0, 1.5))
    S["furnace"] = mix(lowpass(noise(1.6), 500) * np.sin(np.pi * t(1.6) / 1.6) * 1.2, crackle)
    S["quake"] = mix(thud(32, 0.9) * 1.5, lowpass(noise(1.2), 150) * env(int(SR * 1.2), 0.01, 0.4))
    groan = lowpass(sweep(70, 35, 3.0, "saw"), 500) * np.sin(np.pi * t(3.0) / 3.0)
    S["bull_death"] = mix(groan, np.pad(S["bull_crash"], (int(SR * 1.5), 0)), np.pad(lowpass(noise(2.0), 3000) * np.linspace(1, 0, int(SR * 2.0)) * 0.4, (int(SR * 2.4), 0)))
    for name, x in S.items():
        write_wav(name, x)
    kit.log("audio", f"{len(S)} effects -> assets/audio/*.wav")


# --- ambience ---------------------------------------------------------------------------------

def ambience():
    sr = 22050
    secs = 32.0
    x = t(secs, sr)
    swell = 0.5 + 0.5 * np.sin(2 * np.pi * x / 7.5) ** 2
    surf = lowpass(noise(secs, sr), 900, 1, sr) * swell + bandpass(noise(secs, sr), 1500, 5000, sr) * swell ** 3 * 0.25
    write_loop("shore", surf, sr, 0.6)
    pulses = (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 42 * x))) * (0.55 + 0.45 * np.sin(2 * np.pi * x / 3.3) ** 2)
    cicadas = bandpass(noise(secs, sr), 4200, 7200, sr) * pulses
    cicadas += bandpass(noise(secs, sr), 3500, 6000, sr) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 37 * x + 1))) * 0.4
    write_loop("cicadas", cicadas + lowpass(noise(secs, sr), 400, 1, sr) * 0.15, sr, 0.45)
    gust = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * x / 9.0 + np.sin(2 * np.pi * x / 4.1)))
    write_loop("wind", lowpass(noise(secs, sr), 650, 1, sr) * gust, sr, 0.5)
    drone = sum(np.sin(2 * np.pi * f * x) * a for f, a in ((55, 0.5), (58.3, 0.3), (82.4, 0.25)))
    whispers = bandpass(noise(secs, sr), 900, 2600, sr) * (0.5 + 0.5 * np.sin(2 * np.pi * x / 5.3)) ** 4 * 0.5
    write_loop("necropolis", drone * 0.6 + lowpass(noise(secs, sr), 500, 1, sr) * gust * 0.5 + whispers, sr, 0.5)
    roar = lowpass(noise(secs, sr), 300, 1, sr) * (0.7 + 0.3 * np.sin(2 * np.pi * x / 2.7))
    crackle = np.zeros(len(x))
    for k in range(260):
        at(crackle, bandpass(noise(0.008, sr), 2000, 6000, sr) * RNG.uniform(0.1, 0.6), RNG.uniform(0, secs - 0.01), sr)
    write_loop("forge", roar + crackle, sr, 0.55)
    kit.log("audio", "5 ambience loops -> assets/audio/*.ogg")


# --- music ------------------------------------------------------------------------------------

DORIAN = [0, 2, 3, 5, 7, 9, 10]
PHRYGIAN = [0, 1, 3, 5, 7, 8, 10]


def note(root, mode, degree):
    octave, step = divmod(degree, 7)
    return root * 2 ** ((mode[step] + 12 * octave) / 12.0)


def track(name, seconds, root, mode, melody, beat, voice="lyre", drums=None, drone_level=0.35, sr=22050, seed=1, space=0.3):
    rng = np.random.default_rng(seed)
    out = np.zeros(int(sr * (seconds + 3)))
    x = t(seconds + 3, sr)
    drone = (np.sin(2 * np.pi * root / 2 * x) * 0.6 + np.sin(2 * np.pi * root * 0.75 * x) * 0.3 + np.sin(2 * np.pi * root * x) * 0.2)
    drone *= 0.8 + 0.2 * np.sin(2 * np.pi * x / 6.0)
    out += lowpass(drone, root * 3, 1, sr) * drone_level
    time = 0.0
    i = 0
    while time < seconds - 1.0:
        degree, length = melody[i % len(melody)]
        i += 1
        if degree is not None:
            f = note(root, mode, degree)
            if voice == "lyre":
                at(out, pluck(f, min(2.4, length * beat * 2.5), 0.9, sr) * 0.55, time, sr)
                if rng.random() < 0.35:
                    at(out, pluck(f / 2, 2.0, 0.6, sr) * 0.3, time, sr)
            else:
                at(out, reed(f, length * beat * 0.95, sr=sr) * 0.32, time, sr)
        time += length * beat
    if drums:
        time, k = 0.0, 0
        while time < seconds:
            strength, step = drums[k % len(drums)]
            k += 1
            if strength:
                at(out, drum(0.5, 85 if strength > 0.7 else 120, sr) * strength * 0.55, time, sr)
            time += step * beat
    out = reverb(out, 1.8, space, sr)[: int(sr * (seconds + 1.5))]
    write_loop(name, out, sr, 0.75)


def music():
    D, E = 146.83, 164.81
    village = [(0, 1), (2, 1), (4, 2), (3, 1), (2, 1), (1, 2), (0, 1), (1, 1), (2, 1), (4, 1), (5, 2), (4, 2),
               (7, 1), (6, 1), (4, 2), (2, 1), (3, 1), (1, 2), (0, 3), (None, 1)]
    track("village", 64.0, D, DORIAN, village, 0.42, seed=2)
    field = [(4, 1), (5, 0.5), (4, 0.5), (2, 1), (0, 1), (1, 1), (2, 2), (4, 1), (7, 1), (6, 0.5), (5, 0.5), (4, 2), (2, 1), (1, 1), (0, 2), (None, 1)]
    track("field", 64.0, D, DORIAN, field, 0.36, voice="reed", drums=[(0.8, 1), (0.3, 0.5), (0.3, 0.5), (0.6, 1), (0.3, 1)], drone_level=0.25, seed=3)
    necro = [(0, 3), (None, 1), (1, 2), (None, 2), (4, 3), (3, 1), (1, 4), (None, 2), (-2, 3), (0, 3), (None, 2)]
    track("necropolis", 64.0, E, PHRYGIAN, necro, 0.5, drone_level=0.5, seed=4, space=0.45)
    sanctuary = [(0, 2), (4, 2), (7, 3), (6, 1), (4, 2), (2, 2), (3, 2), (1, 2), (0, 4), (None, 2)]
    track("sanctuary", 60.0, D, DORIAN, sanctuary, 0.55, drone_level=0.45, seed=5, space=0.45)
    boss = [(0, 0.5), (1, 0.5), (0, 0.5), (3, 0.5), (1, 1), (0, 0.5), (-1, 0.5), (0, 1), (4, 0.5), (3, 0.5), (1, 0.5), (0, 0.5), (1, 2)]
    track("boss", 56.0, E, PHRYGIAN, boss, 0.27, voice="reed", drums=[(1.0, 1), (0.4, 0.5), (0.4, 0.5), (0.8, 0.5), (0.4, 0.5), (0.9, 1)], drone_level=0.35, seed=6)
    title = [(0, 2), (2, 1), (4, 1), (7, 2), (6, 1), (4, 1), (5, 2), (4, 1), (2, 1), (1, 2), (0, 2), (None, 2)]
    track("title", 60.0, D, DORIAN, title, 0.6, drone_level=0.4, seed=7, space=0.5)
    kit.log("audio", "6 music loops -> assets/audio/*.ogg")


def main():
    effects()
    ambience()
    music()


kit.run(main)
