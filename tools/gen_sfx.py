"""UI/타격 효과음 생성 (WAV, 44.1kHz, 16-bit mono) -> assets/sfx/*.wav
전부 수식으로 합성한다(외부 샘플 없음). 사용법: python tools/gen_sfx.py
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
TAU = 2.0 * math.pi
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"
rng = random.Random(11)


def render(length, fn, gain=0.8):
    n = int(length * SR)
    buf = [fn(i / SR) for i in range(n)]
    # 끝을 5ms 페이드해 클릭 방지
    fade = int(0.005 * SR)
    for i in range(min(fade, n)):
        buf[n - 1 - i] *= i / fade
    peak = max(abs(v) for v in buf) or 1.0
    return [v / peak * gain for v in buf]


def save(name, buf):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in buf))
    print("wrote", name, f"{len(buf) / SR * 1000:.0f}ms")


def noise():
    return rng.random() * 2.0 - 1.0


def bell(x, freq, decay):
    """유리 종: 기음 + 비정수 배음"""
    e = math.exp(-x / decay)
    return e * (math.sin(TAU * freq * x) + 0.45 * math.exp(-x / (decay * 0.5)) * math.sin(TAU * freq * 2.76 * x)
                + 0.2 * math.exp(-x / (decay * 0.3)) * math.sin(TAU * freq * 5.4 * x))


def hp_noise(state):
    """1차 하이패스 흉내 (연속 호출)"""
    v = noise()
    out = v - state[0]
    state[0] = v * 0.85 + state[0] * 0.15
    return out


def sweep(x, f0, f1, length):
    """f0 -> f1 로 지수 스윕하는 사인의 위상"""
    k = math.log(f1 / f0) / length
    return TAU * f0 * (math.exp(k * x) - 1.0) / k


def main():
    st = [0.0]
    # --- UI ---
    save("ui_move.wav", render(0.05, lambda x: math.exp(-x / 0.009) * (math.sin(TAU * 2100 * x) + 0.5 * math.sin(TAU * 3150 * x)), 0.45))
    save("ui_confirm.wav", render(0.42, lambda x: bell(x, 1318.5, 0.11) + (bell(x - 0.07, 1975.5, 0.13) if x > 0.07 else 0.0), 0.6))
    save("ui_back.wav", render(0.22, lambda x: math.exp(-x / 0.05) * math.sin(sweep(x, 900.0, 420.0, 0.22)) * 0.9
                               + 0.15 * math.exp(-x / 0.01) * noise(), 0.5))
    save("ui_tab.wav", render(0.09, lambda x: math.exp(-x / 0.02) * math.sin(TAU * 1568 * x), 0.4))

    def start(x):
        v = 0.0
        for i, f in enumerate([659.3, 987.8, 1318.5, 1975.5]):
            d = x - i * 0.045
            if d > 0.0:
                v += bell(d, f, 0.28) * (0.9 - i * 0.12)
        v += 0.25 * min(x / 0.25, 1.0) * math.exp(-max(x - 0.25, 0.0) / 0.1) * hp_noise(st)
        return v
    save("ui_start.wav", render(1.0, start, 0.7))

    # --- 카운트다운 ---
    save("count.wav", render(0.11, lambda x: math.exp(-x / 0.03) * (math.sin(TAU * 880 * x) + 0.3 * math.sin(TAU * 1760 * x)), 0.5))
    save("count_go.wav", render(0.4, lambda x: bell(x, 1760.0, 0.12) + 0.6 * bell(x, 1320.0, 0.14), 0.6))

    # --- 타격음 ---
    def tap(x):
        return (math.exp(-x / 0.004) * hp_noise(st) * 0.9
                + math.exp(-x / 0.012) * math.sin(TAU * 1250 * x) * 0.6
                + math.exp(-x / 0.02) * math.sin(TAU * 420 * x) * 0.35)
    save("hit_tap.wav", render(0.07, tap, 0.8))

    def flick(x):
        env = min(x / 0.012, 1.0) * math.exp(-max(x - 0.012, 0.0) / 0.035)
        return env * (hp_noise(st) * 0.7 + math.sin(sweep(x, 1400.0, 4200.0, 0.14)) * 0.5)
    save("hit_flick.wav", render(0.14, flick, 0.7))

    # --- 결과 ---
    def result(x):
        v = 0.0
        for i, f in enumerate([523.3, 659.3, 784.0, 1046.5, 1318.5, 1568.0]):
            d = x - i * 0.06
            if d > 0.0:
                v += bell(d, f, 0.4) * 0.6
        return v
    save("result.wav", render(1.6, result, 0.6))

    def clear(x):
        v = 0.3 * min(x / 0.5, 1.0) * math.exp(-max(x - 0.5, 0.0) / 0.25) * hp_noise(st)
        for f in [392.0, 587.3, 784.0, 1174.7]:
            v += bell(max(x - 0.5, 0.0), f, 0.6) * (0.5 if x > 0.5 else 0.0)
        return v
    save("clear.wav", render(2.0, clear, 0.6))


if __name__ == "__main__":
    main()
