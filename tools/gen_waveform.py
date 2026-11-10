"""곡 오디오에서 선곡 화면용 파형 파일(waveform.json)을 만든다.

사용법:
    python tools/gen_waveform.py                  # charts 폴더의 모든 곡
    python tools/gen_waveform.py charts/sample    # 특정 곡 폴더만

곡 폴더 채보(ez/nm/hd.json 중 처음 것)의 meta.audio 파일을 읽어 같은 폴더에 waveform.json을 저장한다.
PCM WAV는 표준 라이브러리만으로 처리하고, MP3/OGG 등은 PATH에 ffmpeg가 있어야 한다.
"""

import json
import shutil
import struct
import subprocess
import sys
import wave
from pathlib import Path

CHART_FILES = ("ez.json", "nm.json", "hd.json")
BINS = 1000                 # 저장할 칸 수. 게임은 이걸 화면 칸 수로 다시 줄여 쓴다.
FFMPEG_RATE = 44100
PROJECT_ROOT = Path(__file__).resolve().parent.parent


def _pcm_to_mono(raw, width, channels):
    """정수 PCM 바이트를 -1~1 모노 샘플 목록으로 바꾼다. 채널은 절댓값이 큰 쪽을 쓴다."""
    frames = len(raw) // (width * channels)
    out = [0.0] * frames
    if width == 1:      # 8비트는 부호 없는 형식
        decode = lambda o: (raw[o] - 128) / 128.0
    elif width == 2:
        decode = lambda o: struct.unpack_from("<h", raw, o)[0] / 32768.0
    elif width == 3:
        decode = lambda o: int.from_bytes(raw[o:o + 3], "little", signed=True) / 8388608.0
    elif width == 4:
        decode = lambda o: struct.unpack_from("<i", raw, o)[0] / 2147483648.0
    else:
        raise ValueError(f"지원하지 않는 샘플 크기: {width}바이트")
    for f in range(frames):
        base = f * width * channels
        out[f] = max((abs(decode(base + c * width)) for c in range(channels)))
    return out


def _read_wav(path):
    with wave.open(str(path), "rb") as w:
        raw = w.readframes(w.getnframes())
        return _pcm_to_mono(raw, w.getsampwidth(), w.getnchannels()), w.getframerate()


def _read_ffmpeg(path):
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise RuntimeError("ffmpeg가 필요합니다 (WAV가 아닌 파일이거나 PCM WAV가 아님)")
    result = subprocess.run(
        [ffmpeg, "-v", "error", "-i", str(path), "-f", "s16le", "-ac", "1", "-ar", str(FFMPEG_RATE), "-"],
        capture_output=True, check=True)
    return _pcm_to_mono(result.stdout, 2, 1), FFMPEG_RATE


def read_samples(path):
    if path.suffix.lower() == ".wav":
        try:
            return _read_wav(path)
        except wave.Error:
            pass    # float WAV 등 wave 모듈이 못 읽는 형식은 ffmpeg로 넘긴다
    return _read_ffmpeg(path)


def compute_peaks(samples, bins=BINS):
    """칸마다 최대 진폭을 구하고 곡 전체 최댓값을 1로 맞춘다."""
    if not samples:
        return []
    peaks = [0.0] * bins
    n = len(samples)
    for i, s in enumerate(samples):
        b = i * bins // n
        if s > peaks[b]:
            peaks[b] = s
    top = max(peaks)
    if top <= 0.0:
        return peaks
    return [round(p / top, 3) for p in peaks]


def process(chart_dir):
    chart_path = next((chart_dir / n for n in CHART_FILES if (chart_dir / n).is_file()), None)
    if chart_path is None:
        raise FileNotFoundError(f"채보 파일(ez/nm/hd.json)이 없습니다: {chart_dir}")
    meta = json.loads(chart_path.read_text(encoding="utf-8")).get("meta", {})
    audio = chart_dir / str(meta.get("audio", ""))
    if not audio.is_file():
        raise FileNotFoundError(f"오디오 파일이 없습니다: {audio}")
    samples, rate = read_samples(audio)
    data = {
        "duration_ms": round(len(samples) * 1000.0 / rate, 1),
        "peaks": compute_peaks(samples),
    }
    out = chart_dir / "waveform.json"
    out.write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
    print(f"{out}: {data['duration_ms'] / 1000.0:.1f}초, {len(data['peaks'])}칸")


def main():
    if len(sys.argv) > 1:
        targets = [Path(a) for a in sys.argv[1:]]
    else:
        targets = sorted({p.parent for n in CHART_FILES for p in (PROJECT_ROOT / "charts").glob("*/" + n)})
    if not targets:
        print("채보(ez/nm/hd.json)가 있는 곡 폴더를 찾지 못했습니다.")
        return 1
    failed = 0
    for d in targets:
        try:
            process(d)
        except Exception as e:
            failed += 1
            print(f"실패 {d}: {e}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
