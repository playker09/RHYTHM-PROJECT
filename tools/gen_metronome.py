"""테스트용 더미 곡 생성 (WAV, 44.1kHz, 16-bit mono) -> charts/sample/song.wav
박마다 클릭(마디 첫 박 강조) + 킥/하이햇/베이스/패드를 얹은 메트로놈. 싱크 검증용이라 박 위치는 정확히 격자에 있다.
사용법: python tools/gen_metronome.py [bpm] [seconds]
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

bpm = float(sys.argv[1]) if len(sys.argv) > 1 else 120.0
seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 60.0
SR = 44100
N = int(SR * seconds)
BEAT = 60.0 / bpm
OUT = Path(__file__).resolve().parent.parent / "charts" / "sample" / "song.wav"
buf = [0.0] * N
rng = random.Random(7)
TAU = 2.0 * math.pi


def add(start_s, length_s, fn):
    s0 = int(start_s * SR)
    for i in range(int(length_s * SR)):
        if s0 + i >= N:
            break
        buf[s0 + i] += fn(i / SR)


def click(t, freq, amp):
    add(t, 0.04, lambda x: amp * math.exp(-x / 0.008) * math.sin(TAU * freq * x))


def kick(t, amp=0.7):
    # 주파수가 빠르게 떨어지는 사인
    add(t, 0.28, lambda x: amp * math.exp(-x / 0.09) * math.sin(TAU * (48.0 * x + 110.0 * 0.03 * (1.0 - math.exp(-x / 0.03)))))


def hat(t, amp=0.12):
    add(t, 0.05, lambda x: amp * math.exp(-x / 0.012) * (rng.random() * 2.0 - 1.0))


def snare(t, amp=0.3):
    add(t, 0.16, lambda x: amp * math.exp(-x / 0.045) * ((rng.random() * 2.0 - 1.0) * 0.8 + 0.4 * math.sin(TAU * 190.0 * x)))


def bass(t, freq, length, amp=0.22):
    def fn(x):
        env = min(x / 0.005, 1.0) * math.exp(-x / (length * 0.9))
        ph = TAU * freq * x
        return amp * env * (math.sin(ph) + 0.35 * math.sin(2.0 * ph) + 0.15 * math.sin(3.0 * ph))
    add(t, length, fn)


def pad(t, freqs, length, amp=0.05):
    def fn(x):
        env = min(x / 0.4, 1.0) * min((length - x) / 0.4, 1.0)
        return amp * env * sum(math.sin(TAU * f * x) + 0.5 * math.sin(TAU * f * 1.004 * x) for f in freqs)
    add(t, length, fn)


def note(semi):
    return 220.0 * 2.0 ** (semi / 12.0)


# Am - F - C - G (마디마다 바뀜)
PROG = [(-12, [0, 3, 7]), (-16, [-4, 0, 3]), (-9, [3, 7, 10]), (-14, [-2, 2, 5])]

beats = int(seconds / BEAT) + 1
for b in range(beats):
    t = b * BEAT
    if t >= seconds:
        break
    accent = b % 4 == 0
    click(t, 1600 if accent else 1000, 0.55 if accent else 0.38)
    kick(t)
    hat(t + BEAT * 0.5)
    if b % 2 == 1:
        snare(t)
    root, chord = PROG[(b // 4) % 4]
    bass(t, note(root), BEAT * 0.48)
    bass(t + BEAT * 0.5, note(root + 12), BEAT * 0.4, 0.14)
    if accent:
        pad(t, [note(s) for s in chord], BEAT * 4.0)

peak = max(abs(v) for v in buf) or 1.0
gain = 0.89 / peak
with wave.open(str(OUT), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * gain)) * 32767)) for v in buf))
print("wrote", OUT, bpm, "bpm", seconds, "s")
