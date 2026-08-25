"""Barrel Heaven — procedural audio generator (stdlib only).

Generates music loops + SFX as 16-bit mono WAV into godot/assets/audio/.
Run from repo root:  python tools/generate_audio.py
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "godot" / "assets" / "audio"
random.seed(20260825)

# ---------------------------------------------------------------- helpers

def silence(dur):
    return [0.0] * int(SR * dur)


def mix(buf, add, at=0.0, gain=1.0):
    i0 = int(at * SR)
    end = i0 + len(add)
    if end > len(buf):
        buf.extend([0.0] * (end - len(buf)))
    for i, v in enumerate(add):
        buf[i0 + i] += v * gain


def env_ad(n, a=0.005, d=0.15, curve=3.0):
    out = []
    na = max(1, int(a * SR))
    nd = max(1, int(d * SR))
    for i in range(n):
        if i < na:
            out.append(i / na)
        else:
            t = (i - na) / nd
            out.append(max(0.0, (1.0 - t)) ** curve)
    return out


def osc(kind, freq, dur, vol=1.0, detune=0.0):
    n = int(SR * dur)
    out = []
    ph = 0.0
    for _ in range(n):
        ph += freq * (1.0 + detune) / SR
        t = ph % 1.0
        if kind == "sine":
            v = math.sin(t * math.tau)
        elif kind == "square":
            v = 1.0 if t < 0.5 else -1.0
        elif kind == "saw":
            v = 2.0 * t - 1.0
        else:  # tri
            v = 4.0 * abs(t - 0.5) - 1.0
        out.append(v * vol)
    return out


def noise(dur, vol=1.0):
    return [random.uniform(-1, 1) * vol for _ in range(int(SR * dur))]


def lowpass(buf, alpha=0.2):
    out = []
    acc = 0.0
    for v in buf:
        acc += alpha * (v - acc)
        out.append(acc)
    return out


def highpass(buf, alpha=0.9):
    lp = lowpass(buf, 1.0 - alpha)
    return [b - l for b, l in zip(buf, lp)]


def normalize(buf, peak=0.8):
    m = max(1e-6, max(abs(v) for v in buf))
    k = peak / m
    return [v * k for v in buf]


def write_wav(name, buf):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in buf)
        w.writeframes(frames)
    print(f"  {name}  {len(buf)/SR:.1f}s")


# ---------------------------------------------------------------- notes

A1, C2, D2, E2, F2, G2 = 55.0, 65.41, 73.42, 82.41, 87.31, 98.0
A2, B2, C3, D3, E3, F3, G3 = 110.0, 123.47, 130.81, 146.83, 164.81, 174.61, 196.0
A3, BB3, B3, C4, D4, E4, F4, G4 = 220.0, 233.08, 246.94, 261.63, 293.66, 329.63, 349.23, 392.0
A4, C5, E5, A5 = 440.0, 523.25, 659.26, 880.0


# ---------------------------------------------------------------- music

def kick(dur=0.14):
    n = int(SR * dur)
    out = []
    ph = 0.0
    e = env_ad(n, 0.001, dur, 2.2)
    for i in range(n):
        f = 120.0 * math.exp(-6.0 * i / n) + 38.0
        ph += f / SR
        out.append(math.sin(ph * math.tau) * e[i])
    return out


def hat(dur=0.035, vol=1.0):
    return highpass(noise(dur, vol), 0.85)[: int(SR * dur)]


def snare(dur=0.16):
    n = int(SR * dur)
    nz = lowpass(highpass(noise(dur), 0.5), 0.7)
    tone = osc("tri", 190, dur, 0.4)
    e = env_ad(n, 0.001, dur, 2.0)
    return [(nz[i] * 0.9 + tone[i]) * e[i] for i in range(n)]


def bass_note(freq, dur):
    n = int(SR * dur)
    o = osc("saw", freq, dur, 0.8)
    o2 = osc("square", freq / 2, dur, 0.35)
    lp = lowpass([a + b for a, b in zip(o, o2)], 0.28)
    e = env_ad(n, 0.004, dur * 0.9, 1.4)
    return [lp[i] * e[i] for i in range(n)]


def arp_note(freq, dur, kind="tri"):
    n = int(SR * dur)
    o = osc(kind, freq, dur, 0.75)
    e = env_ad(n, 0.002, dur * 0.8, 2.0)
    return [o[i] * e[i] for i in range(n)]


def pad_chord(freqs, dur):
    n = int(SR * dur)
    acc = [0.0] * n
    for f in freqs:
        mix(acc, osc("sine", f, dur, 0.30, detune=0.003))
        mix(acc, osc("sine", f, dur, 0.22, detune=-0.004))
    e = []
    na = int(n * 0.45)
    for i in range(n):
        t = min(1.0, i / na) if i < na else max(0.0, 1.0 - (i - na) / (n - na))
        e.append(t * t)
    return [acc[i] * e[i] for i in range(n)]


def build_track(bpm, bars, chords, bass_pat, arp_pat, drums, lead=None):
    """chords: per-bar list of pad freq lists; bass_pat/arp_pat: 16th-step patterns."""
    step = 60.0 / bpm / 4.0          # 16th
    bar_dur = step * 16
    total = bar_dur * bars
    buf = [0.0] * (int(total * SR) + SR)   # tail room
    echo = []

    for b in range(bars):
        chord = chords[b % len(chords)]
        t0 = b * bar_dur
        # pad
        mix(buf, pad_chord(chord["pad"], bar_dur), t0, gain=0.55)
        # bass + arp + drums on 16ths
        for s in range(16):
            ts = t0 + s * step
            bn = bass_pat[s % len(bass_pat)]
            if bn:
                mix(buf, bass_note(bn, step * 1.6), ts, gain=0.9)
            an = arp_pat[s % len(arp_pat)]
            if an:
                g = arp_note(an, step * 1.2)
                mix(buf, g, ts, gain=0.5)
                echo.append((ts + step * 3, g, 0.18))
            d = drums[s % len(drums)]
            if d == "k":
                mix(buf, kick(), ts, gain=0.95)
            elif d == "h":
                mix(buf, hat(), ts, gain=0.30)
            elif d == "s":
                mix(buf, snare(), ts, gain=0.5)
            elif d == "H":
                mix(buf, hat(0.05), ts, gain=0.42)
    for ts, g, gn in echo:
        mix(buf, g, ts, gain=gn)
    if lead:
        lead(buf, bar_dur, step)
    return normalize(buf[: int(total * SR)], 0.72)


def boss_lead(buf, bar_dur, step):
    """Alarm-like siren phrase every other bar."""
    phrase = [A4, C5, BB3, A4]
    for b in range(2, len(phrase) * 40, 4):   # every 4 bars
        if b * bar_dur > (len(buf) - SR) / SR:
            break
        for i, f in enumerate(phrase):
            mix(buf, arp_note(f, step * 6, "square"), b * bar_dur + i * step * 4, gain=0.16)


def gen_music():
    print("music:")
    bpm = 92
    step = 60.0 / bpm / 4.0
    bar = step * 16
    Am = {"pad": [A2, C3, E3]}
    Fm = {"pad": [F2, A2, C3]}
    G_ = {"pad": [G2, B2, D3]}
    Em = {"pad": [E2, G2, B2]}
    chords_c = [Am, Am, Fm, G_, Am, Am, Em, G_]
    bass_c = [A1, 0, A1, 0, A1, 0, C2, 0] * 2
    arp_notes_c = [A3, C4, E4, A4, E4, C4]
    arp_c = [arp_notes_c[i % 6] if i % 8 != 7 else 0 for i in range(16)]
    drums_c = ["k", "", "h", "", "k", "", "h", "s"] * 2
    write_wav("music_combat.wav", build_track(bpm, 32, chords_c, bass_c, arp_c, drums_c))

    bpm_b = 138
    chords_b = [Am, Am, {"pad": [A2, BB3, E3]}, Am] * 4
    bass_b = [A1, A1, 0, A1, A1, 0, A1, A1, C2, C2, 0, C2, G2 // 2, 0, A1, 0]
    arp_b = [A3 if i % 2 == 0 else (E4 if i % 8 == 5 else 0) for i in range(16)]
    drums_b = ["k", "H", "h", "k", "H", "s", "h", "k"] * 2
    write_wav("music_boss.wav", build_track(bpm_b, 16, chords_b, bass_b, arp_b, drums_b, lead=boss_lead))


# ---------------------------------------------------------------- sfx

def gen_sfx():
    print("sfx:")

    # laser — descending square blip
    n = int(SR * 0.09)
    buf = []
    ph = 0.0
    for i in range(n):
        f = 1400.0 * math.exp(-9.0 * i / n) + 320.0
        ph += f / SR
        t = ph % 1.0
        v = (1.0 if t < 0.35 else -1.0)
        buf.append(v * env_ad(n, 0.001, 0.09, 2.5)[i])
    write_wav("sfx_laser.wav", normalize(buf, 0.5))

    # enemy explode — filtered noise burst with body
    n = int(SR * 0.45)
    nz = lowpass(noise(0.45), 0.16)
    boom = osc("sine", 70, 0.45, 0.8)
    e = env_ad(n, 0.002, 0.45, 2.6)
    write_wav("sfx_explode.wav", normalize([(nz[i] * 0.8 + boom[i]) * e[i] for i in range(n)], 0.75))

    # big explosion (arm break / boss death)
    n = int(SR * 0.9)
    nz = lowpass(noise(0.9), 0.11)
    boom = osc("sine", 52, 0.9, 1.0)
    sub = osc("sine", 36, 0.9, 0.7)
    e = env_ad(n, 0.002, 0.9, 2.2)
    write_wav("sfx_bigexplode.wav",
              normalize([(nz[i] * 0.75 + boom[i] + sub[i]) * e[i] for i in range(n)], 0.85))

    # player hurt — harsh buzz down
    n = int(SR * 0.28)
    buf = []
    ph = 0.0
    for i in range(n):
        f = 260.0 * math.exp(-4.0 * i / n) + 90.0
        ph += f / SR
        t = ph % 1.0
        v = 1.0 if t < 0.5 else -1.0
        jitter = random.uniform(-0.25, 0.25)
        buf.append((v + jitter) * env_ad(n, 0.001, 0.28, 1.8)[i])
    write_wav("sfx_hurt.wav", normalize(lowpass(buf, 0.5), 0.7))

    # gem pickup — quick two-tone rise
    n1 = arp_note(E5, 0.05, "square")
    n2 = arp_note(A5, 0.07, "square")
    write_wav("sfx_gem.wav", normalize(n1 + n2, 0.35))

    # level-up chime — ascending arpeggio
    seq = [A4, C5, E5, A5]
    buf = []
    for i, f in enumerate(seq):
        mix(buf, arp_note(f, 0.22, "tri"), i * 0.07, gain=0.8)
        mix(buf, arp_note(f, 0.22, "tri"), i * 0.07 + 0.03, gain=0.3)
    write_wav("sfx_levelup.wav", normalize(buf, 0.55))

    # ui pick — soft click blip
    write_wav("sfx_pick.wav", normalize(arp_note(G4, 0.06, "tri"), 0.4))

    # roll whoosh — band-swept noise
    n = int(SR * 0.35)
    nz = noise(0.35)
    lp_a = lowpass(nz, 0.10)
    hp = highpass(lp_a, 0.35)
    e = env_ad(n, 0.06, 0.30, 1.6)
    write_wav("sfx_roll.wav", normalize([hp[i] * e[i] for i in range(n)], 0.45))

    # boost — rising rumble
    n = int(SR * 0.5)
    buf = []
    ph = 0.0
    for i in range(n):
        f = 48.0 + 90.0 * (i / n) ** 2
        ph += f / SR
        v = math.sin(ph * math.tau) * 0.6 + random.uniform(-0.3, 0.3)
        buf.append(v * env_ad(n, 0.02, 0.5, 1.2)[i])
    write_wav("sfx_boost.wav", normalize(lowpass(buf, 0.4), 0.55))

    # slam ring boom
    n = int(SR * 0.7)
    deep = osc("sine", 44, 0.7, 1.0)
    nz = lowpass(noise(0.7), 0.09)
    e = env_ad(n, 0.001, 0.7, 2.0)
    write_wav("sfx_slam.wav", normalize([(deep[i] * 0.9 + nz[i] * 0.4) * e[i] for i in range(n)], 0.85))

    # core-exposed alarm — two-tone klaxon
    buf = []
    for rep in range(2):
        mix(buf, arp_note(C5, 0.16, "square"), rep * 0.34, gain=0.5)
        mix(buf, arp_note(A4, 0.16, "square"), rep * 0.34 + 0.17, gain=0.5)
    write_wav("sfx_alarm.wav", normalize(buf, 0.5))

    # win sting — major fanfare
    seq = [(C4, 0.0), (E4, 0.12), (G4, 0.24), (C5, 0.36)]
    buf = []
    for f, t in seq:
        mix(buf, arp_note(f, 0.5, "tri"), t, gain=0.7)
        mix(buf, osc("sine", f * 2, 0.4, 0.2), t)
    mix(buf, pad_chord([C4, E4, G4], 1.1), 0.36, gain=0.5)
    write_wav("sfx_win.wav", normalize(buf, 0.65))

    # lose sting — descending minor
    seq = [(A4, 0.0), (E4, 0.18), (C4, 0.36), (A3, 0.54)]
    buf = []
    for f, t in seq:
        mix(buf, arp_note(f, 0.45, "tri"), t, gain=0.7)
    mix(buf, pad_chord([A2, C3, E3], 1.4), 0.5, gain=0.55)
    write_wav("sfx_lose.wav", normalize(buf, 0.6))


if __name__ == "__main__":
    gen_music()
    gen_sfx()
    print("audio generation complete")
