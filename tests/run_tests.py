"""코어(JS) + 서버(Python) 테스트 실행기.
사용: python tests/run_tests.py [게임폴더]
- JS: 헤드리스 Chrome/Edge 로 core_tests.js 실행
- 서버: 임시 게임 폴더를 만들어 API (목록/저장/로더 검증/경로 차단/Range) 확인
"""
import html
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent
sys.path.insert(0, str(TOOL))
import launcher  # noqa: E402

GAME = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"C:\Users\ADMIN\Downloads\RHYTHM-PROJECT")
fails = 0


def check(name, ok, detail=""):
    global fails
    print(("PASS " if ok else "FAIL ") + name + (f"  -> {detail}" if detail and not ok else ""))
    if not ok:
        fails += 1


# ---------------------------------------------------------------- JS 코어
def run_js():
    sample = json.loads((GAME / "charts" / "sample" / "chart.json").read_text(encoding="utf-8"))
    tmp = Path(tempfile.mkdtemp(prefix="pt_core_"))
    page = tmp / "t.html"
    page.write_text(
        "<!doctype html><meta charset=utf-8><body>"
        f"<script>window.__SAMPLE={json.dumps(sample)}</script>"
        f"<script src='{(TOOL / 'web' / 'core.js').as_uri()}'></script>"
        f"<script src='{(HERE / 'core_tests.js').as_uri()}'></script>",
        encoding="utf-8",
    )
    browser = launcher.find_browser()
    out = subprocess.run(
        [browser, "--headless=new", "--disable-gpu", "--allow-file-access-from-files", f"--user-data-dir={tmp / 'prof'}",
         "--virtual-time-budget=3000", "--dump-dom", page.as_uri()],
        capture_output=True, text=True, timeout=90, encoding="utf-8",
    ).stdout
    shutil.rmtree(tmp, ignore_errors=True)
    i = out.find('<pre id="results">')
    if i < 0:
        return check("JS 코어 테스트 실행", False, out[-400:])
    body = out[i + len('<pre id="results">'): out.find("</pre>", i)]
    for r in json.loads(html.unescape(body)):
        check("[js] " + r["name"], r["ok"], r["detail"])


# ---------------------------------------------------------------- 서버
def run_server():
    root = Path(tempfile.mkdtemp(prefix="pt_game_"))
    (root / "project.godot").write_text("; fake")
    (root / "charts" / "demo").mkdir(parents=True)
    audio = bytes(range(256)) * 40
    (root / "charts" / "demo" / "song.wav").write_bytes(audio)
    launcher.State.root = root
    srv = launcher.make_server(0)
    port = srv.server_address[1]
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{port}"
    tok = launcher.State.token

    def req(path, data=None, headers=None, token=True):
        url = base + path + (("&" if "?" in path else "?") + "t=" + tok if token else "")
        r = urllib.request.Request(url, data=data, headers=headers or {}, method="POST" if data is not None else "GET")
        try:
            with urllib.request.urlopen(r) as resp:
                return resp.status, resp.read(), dict(resp.headers)
        except urllib.error.HTTPError as e:
            return e.code, e.read(), dict(e.headers)

    c, b, _ = req("/api/songs", token=False)
    check("[srv] 토큰 없으면 403", c == 403)
    c, b, _ = req("/")
    check("[srv] 인덱스에 토큰 주입", c == 200 and tok.encode() in b and b"__TOKEN__" not in b)
    c, b, _ = req("/api/songs")
    songs = json.loads(b)["songs"]
    check("[srv] 곡 목록", songs and songs[0]["folder"] == "demo" and songs[0]["has_chart"] is False)
    c, b, _ = req("/api/chart?song=..%2F..")
    check("[srv] 경로 탈출 차단", c == 400)
    c, b, _ = req("/api/chart?song=demo")
    check("[srv] 채보 없는 곡 -> chart null + 오디오 목록", json.loads(b)["chart"] is None and json.loads(b)["audio_files"] == ["song.wav"])

    good = {"meta": {"title": "한글 제목"}, "timing": [{"time": 0, "bpm": 120}], "notes": [
        {"type": "tap", "time": 0, "lane": 0}, {"type": "hold", "time": 10, "end": 20, "lane": 1},
        {"type": "flick", "time": 5, "x": 0.5, "dir": "left"},
        {"type": "field", "keys": [{"time": 0, "center": 0.5, "width": 0.3}, {"time": 9, "center": 0.5, "width": 0.3}]}]}
    c, b, _ = req("/api/chart?song=demo", json.dumps(good).encode("utf-8"))
    check("[srv] 정상 저장", c == 200 and json.loads(b)["saved"] == 4, b)
    saved = json.loads((root / "charts" / "demo" / "chart.json").read_text(encoding="utf-8"))
    check("[srv] UTF-8 저장/왕복", saved["meta"]["title"] == "한글 제목")
    bad = json.loads(json.dumps(good))
    bad["notes"].append({"type": "tap", "time": 1, "lane": 9})
    c, b, _ = req("/api/chart?song=demo", json.dumps(bad).encode("utf-8"))
    check("[srv] 로더가 버릴 노트가 있으면 저장 거부(422)", c == 422, b)
    check("[srv] 거부 시 기존 파일 유지", json.loads((root / "charts" / "demo" / "chart.json").read_text(encoding="utf-8")) == saved)
    c, b, h = req("/api/chart?song=demo", json.dumps(good).encode("utf-8"))
    check("[srv] 덮어쓸 때 .bak 생성", (root / "charts" / "demo" / "chart.json.bak").is_file())
    c, b, h = req("/audio/demo/song.wav", headers={"Range": "bytes=10-19"})
    check("[srv] 오디오 Range 206", c == 206 and b == audio[10:20] and h["Content-Range"].startswith("bytes 10-19/"))
    c, b, h = req("/audio/demo/song.wav")
    check("[srv] 오디오 전체 200", c == 200 and b == audio)
    c, b, _ = req("/api/audio?song=demo&name=x.exe", b"abc")
    check("[srv] 오디오 확장자 제한", c == 400)
    c, b, _ = req("/api/audio?song=new_song&name=a.ogg", b"OggS")
    check("[srv] 새 곡 폴더 + 오디오 생성", c == 200 and (root / "charts" / "new_song" / "a.ogg").is_file())
    srv.shutdown()
    shutil.rmtree(root, ignore_errors=True)


run_js()
run_server()
print("\n실패:", fails)
sys.exit(1 if fails else 0)
