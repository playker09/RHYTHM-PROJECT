"""Generate a dummy metronome track (WAV, 44.1kHz, 16-bit mono).
Click on every beat, accented on beat 1 of each 4/4 bar.
Usage: python tools/gen_metronome.py [bpm] [seconds]
"""
import math, struct, sys, wave

bpm = float(sys.argv[1]) if len(sys.argv) > 1 else 120.0
seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 60.0
sr = 44100
n = int(sr * seconds)
buf = [0.0] * n
beat_len = 60.0 / bpm


def click(start_s, freq, amp):
    s0 = int(start_s * sr)
    length = int(0.04 * sr)
    for i in range(length):
        if s0 + i >= n:
            break
        env = math.exp(-i / (sr * 0.008))
        buf[s0 + i] += amp * env * math.sin(2 * math.pi * freq * i / sr)


b = 0
while b * beat_len < seconds:
    accent = (b % 4 == 0)
    click(b * beat_len, 1600 if accent else 1000, 0.9 if accent else 0.6)
    b += 1

with wave.open("charts/sample/song.wav", "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(sr)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in buf))
print("wrote charts/sample/song.wav", bpm, "bpm", seconds, "s")
