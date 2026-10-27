"""Synthesised UI/game sound effects (16-bit mono WAV, 44.1 kHz). No external assets needed.
Run from the project root: python3 tools/generate_sfx.py
"""
import math, random, struct, wave
SR = 44100
OUT = "game/assets/audio/sfx/"

def write(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    with wave.open(OUT + name, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.85 * 32767)) for s in samples))

def env(t, a, d):
    return min(1.0, t / a) * math.exp(-t / d) if a > 0 else math.exp(-t / d)

def tone(freqs, dur, a=0.005, d=0.2, shape=math.sin):
    n = int(SR * dur)
    return [sum(shape(2 * math.pi * f * i / SR) for f in freqs) * env(i / SR, a, d) for i in range(n)]

def mix(*parts):
    n = max(len(p) for _, p in parts)
    out = [0.0] * n
    for off, p in parts:
        o = int(off * SR)
        for i, s in enumerate(p):
            if o + i < n + int(1 * SR) and o + i < len(out):
                out[o + i] += s
    return out

random.seed(3)
# Move: soft filtered-noise whoosh with a rising pitch tick
n = int(SR * 0.45)
lp = 0.0
whoosh = []
for i in range(n):
    t = i / SR
    lp += (random.uniform(-1, 1) - lp) * (0.02 + 0.25 * math.sin(math.pi * t / 0.45))
    whoosh.append(lp * math.sin(math.pi * t / 0.45) ** 2)
write("move.wav", mix((0, whoosh), (0.33, tone([880], 0.12, d=0.04))))
# Reveal: two-note sting
write("reveal.wav", mix((0, tone([392, 587], 0.6, d=0.25)), (0.16, tone([466, 698, 932], 0.9, d=0.35))))
# Win: rising arpeggio
win = [(0.11 * k, tone([f, f * 2], 0.5, d=0.22)) for k, f in enumerate([523, 659, 784, 1047])]
write("win.wav", mix(*win, (0.0, [0.0] * int(SR * 1.0))))
# Lose: falling minor
lose = [(0.16 * k, tone([f], 0.6, d=0.3)) for k, f in enumerate([440, 370, 311])]
write("lose.wav", mix(*lose, (0.0, [0.0] * int(SR * 1.1))))
# Tap: short click for station selection
write("tap.wav", tone([1500, 2200], 0.06, a=0.001, d=0.012))
print("sfx written")
