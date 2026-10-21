"""RHYTHM-PROJECT 패턴 툴 런처.

exe 를 실행하면:
  1) 게임 프로젝트(project.godot 이 있는 폴더)를 찾고
  2) 127.0.0.1 에 로컬 서버를 띄워 웹 에디터(web/)와 charts/ 읽기·쓰기 API 를 제공하고
  3) Edge/Chrome 을 앱 창 모드로 열고, 창이 닫히면 함께 종료한다.

개발용: python launcher.py [--no-browser] [--root <게임 폴더>] [--port N]
"""
import argparse
import json
import mimetypes
import os
import re
import secrets
import shutil
import subprocess
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

APP_NAME = "RhythmPatternTool"
PREFERRED_PORT = 47653  # 포트가 고정이어야 브라우저 localStorage(설정)가 유지된다
LANE_COUNT = 4
AUDIO_EXT = {".wav", ".ogg", ".mp3"}
MAX_UPLOAD = 200 * 1024 * 1024
FOLDER_RE = re.compile(r"^[A-Za-z0-9가-힣._\- ]{1,64}$")

# 오디오 포맷 (Windows 레지스트리가 비어 있는 PC 대비)
mimetypes.add_type("audio/wav", ".wav")
mimetypes.add_type("audio/ogg", ".ogg")
mimetypes.add_type("audio/mpeg", ".mp3")
mimetypes.add_type("text/javascript", ".js")


def resource_dir() -> Path:
    """PyInstaller onefile 에서는 압축 해제된 임시 폴더, 개발 시에는 이 파일 옆."""
    return Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))


def app_dir() -> Path:
    """exe(또는 스크립트)가 놓인 폴더."""
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


def data_dir() -> Path:
    base = Path(os.environ.get("LOCALAPPDATA") or Path.home() / ".config")
    d = base / APP_NAME
    d.mkdir(parents=True, exist_ok=True)
    return d


# ---------------------------------------------------------------- 게임 프로젝트
def is_game_root(p: Path) -> bool:
    return (p / "project.godot").is_file()


def find_game_root(cli_root: str = "") -> Path | None:
    """우선순위: 인자 > 저장된 설정 > exe 주변(자신/상위/형제 RHYTHM-PROJECT)."""
    if cli_root and is_game_root(Path(cli_root)):
        return Path(cli_root).resolve()
    cfg = data_dir() / "config.json"
    if cfg.is_file():
        try:
            saved = Path(json.loads(cfg.read_text(encoding="utf-8")).get("project_root", ""))
            if saved and is_game_root(saved):
                return saved.resolve()
        except (OSError, ValueError):
            pass
    start = app_dir()
    cands = [start, *list(start.parents)[:4]]
    for base in list(cands):
        cands.append(base / "RHYTHM-PROJECT")
        cands.append(base / "rhythm-project")
    for c in cands:
        if is_game_root(c):
            return c.resolve()
    return None


def save_game_root(p: Path) -> None:
    (data_dir() / "config.json").write_text(json.dumps({"project_root": str(p)}, ensure_ascii=False), encoding="utf-8")


# ---------------------------------------------------------------- ChartLoader 모사
def simulate_loader(root: dict) -> dict:
    """core/chart_loader.gd 의 파싱 규칙을 그대로 따라, 로더가 살려 두는 노트 수를 센다."""

    def num(v):
        try:
            return float(v)
        except (TypeError, ValueError):
            return None

    def lane_ok(d):
        try:
            return "lane" in d and 0 <= int(d["lane"]) < LANE_COUNT
        except (TypeError, ValueError):
            return False

    kept = {"tap": 0, "hold": 0, "flick": 0, "field": 0}
    notes = root.get("notes", [])
    for d in notes if isinstance(notes, list) else []:
        if not isinstance(d, dict):
            continue
        kind = str(d.get("type", ""))
        if kind == "tap" and "time" in d and lane_ok(d):
            kept["tap"] += 1
        elif kind == "hold" and "time" in d and "end" in d and lane_ok(d) and num(d["end"]) > num(d["time"]):
            kept["hold"] += 1
        elif kind == "flick" and "time" in d:
            kept["flick"] += 1
        elif kind == "field" and isinstance(d.get("keys"), list) and len(d["keys"]) >= 2:
            kept["field"] += 1
    return kept


# ---------------------------------------------------------------- HTTP 서버
class State:
    root: Path | None = None
    token = secrets.token_urlsafe(16)
    last_ping = 0.0
    seen_ping = False
    port = 0
    dev = False


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "PatternTool/1.0"

    def log_message(self, fmt, *args):  # 콘솔 없는 exe 에서 stderr 가 없을 수 있다
        pass

    def handle(self):
        try:
            super().handle()
        except (ConnectionError, TimeoutError):
            pass  # 브라우저가 연결을 먼저 끊은 경우(시킹, 창 닫기)

    # ---- 공통
    def _send(self, code, body=b"", ctype="application/json; charset=utf-8", extra=None):
        if isinstance(body, (dict, list)):
            body = json.dumps(body, ensure_ascii=False).encode("utf-8")
        elif isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _err(self, code, msg):
        self._send(code, {"ok": False, "error": msg})

    def _authorized(self, q) -> bool:
        host = (self.headers.get("Host") or "").split(":")[0]
        if host not in ("127.0.0.1", "localhost"):
            return False
        return secrets.compare_digest(q.get("t", [""])[0], State.token)

    def _body(self) -> bytes | None:
        n = int(self.headers.get("Content-Length") or 0)
        if n > MAX_UPLOAD:
            return None
        return self.rfile.read(n) if n else b""

    def _charts_dir(self) -> Path | None:
        return State.root / "charts" if State.root else None

    def _song_dir(self, folder: str) -> Path | None:
        d = self._charts_dir()
        if d is None or not FOLDER_RE.match(folder or "") or folder in (".", ".."):
            return None
        return d / folder

    # ---- 라우팅
    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        path = urllib.parse.unquote(u.path)

        if path in ("/", "/index.html"):
            if not self._authorized(q):
                return self._err(403, "forbidden")
            html = (resource_dir() / "web" / "index.html").read_text(encoding="utf-8")
            html = html.replace("__TOKEN__", State.token)
            return self._send(200, html, "text/html; charset=utf-8")

        if State.dev and path.startswith("/dev/"):  # --dev: tests/ 폴더의 UI 셀프테스트 제공
            f = (app_dir() / "tests" / Path(path[len("/dev/"):]).name)
            if not f.is_file():
                return self._err(404, "not found")
            return self._send(200, f.read_bytes(), "text/javascript; charset=utf-8")

        if path.startswith("/static/"):
            f = (resource_dir() / "web" / path[len("/static/"):]).resolve()
            web = (resource_dir() / "web").resolve()
            if web not in f.parents or not f.is_file():
                return self._err(404, "not found")
            return self._send(200, f.read_bytes(), mimetypes.guess_type(f.name)[0] or "application/octet-stream")

        if not self._authorized(q):
            return self._err(403, "forbidden")

        if path == "/api/state":
            return self._send(200, {
                "ok": True,
                "root": str(State.root) if State.root else None,
                "has_charts_dir": bool(State.root and (State.root / "charts").is_dir()),
            })
        if path == "/api/songs":
            return self._send(200, {"ok": True, "songs": self._list_songs()})
        if path == "/api/chart":
            return self._get_chart(q.get("song", [""])[0])
        if path.startswith("/audio/"):
            return self._get_audio(path[len("/audio/"):])
        self._err(404, "not found")

    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        path = urllib.parse.unquote(u.path)
        if not self._authorized(q):
            return self._err(403, "forbidden")
        body = self._body()
        if body is None:
            return self._err(413, "too large")

        if State.dev and path == "/api/devlog":  # --dev: 실시간 시간이 필요한 디버그 로그 수집
            with (data_dir() / "devlog.txt").open("ab") as fh:
                fh.write(body + b"\n")
            return self._send(200, {"ok": True})
        if path == "/api/ping":
            State.last_ping = time.time()
            State.seen_ping = True
            return self._send(200, {"ok": True})
        if path == "/api/chart":
            return self._save_chart(q.get("song", [""])[0], body)
        if path == "/api/audio":
            return self._save_audio(q.get("song", [""])[0], q.get("name", [""])[0], body)
        if path == "/api/browse-root":
            return self._browse_root()
        if path == "/api/set-root":
            try:
                p = Path(json.loads(body.decode("utf-8")).get("path", ""))
            except ValueError:
                return self._err(400, "bad json")
            if not is_game_root(p):
                return self._err(400, "project.godot 이 있는 폴더가 아닙니다")
            State.root = p.resolve()
            save_game_root(State.root)
            return self._send(200, {"ok": True, "root": str(State.root)})
        self._err(404, "not found")

    # ---- API 구현
    def _list_songs(self):
        out = []
        cd = self._charts_dir()
        if not cd or not cd.is_dir():
            return out
        for d in sorted(p for p in cd.iterdir() if p.is_dir()):
            f = d / "chart.json"
            item = {"folder": d.name, "has_chart": f.is_file(), "title": d.name, "artist": "", "level": 0, "difficulty": "", "bpm": 0, "notes": 0}
            if f.is_file():
                try:
                    data = json.loads(f.read_text(encoding="utf-8"))
                    meta = data.get("meta", {}) if isinstance(data, dict) else {}
                    timing = data.get("timing", []) if isinstance(data, dict) else []
                    item.update(
                        title=str(meta.get("title") or d.name),
                        artist=str(meta.get("artist", "")),
                        level=meta.get("level", 0),
                        difficulty=str(meta.get("difficulty", "")),
                        bpm=timing[0].get("bpm", 0) if timing and isinstance(timing[0], dict) else 0,
                        notes=len(data.get("notes", [])),
                    )
                except (OSError, ValueError, AttributeError):
                    item["broken"] = True
            out.append(item)
        return out

    def _get_chart(self, folder):
        d = self._song_dir(folder)
        if d is None:
            return self._err(400, "잘못된 곡 폴더 이름")
        f = d / "chart.json"
        audio = sorted(p.name for p in d.iterdir() if p.suffix.lower() in AUDIO_EXT) if d.is_dir() else []
        if not f.is_file():
            return self._send(200, {"ok": True, "chart": None, "audio_files": audio})
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            return self._err(500, f"chart.json 을 읽을 수 없습니다: {e}")
        if not isinstance(data, dict):
            return self._err(500, "chart.json 최상위가 객체가 아닙니다")
        return self._send(200, {"ok": True, "chart": data, "audio_files": audio})

    def _save_chart(self, folder, body):
        d = self._song_dir(folder)
        if d is None:
            return self._err(400, "잘못된 곡 폴더 이름")
        try:
            data = json.loads(body.decode("utf-8"))
        except ValueError:
            return self._err(400, "JSON 이 아닙니다")
        if not isinstance(data, dict):
            return self._err(400, "최상위는 객체여야 합니다")
        sent = len(data.get("notes", []))
        kept = simulate_loader(data)
        survived = sum(kept.values())
        if survived != sent:
            return self._err(422, f"로더가 노트 {sent - survived}개를 버립니다 (저장 {sent} → 로드 {survived}). 저장하지 않았습니다.")
        d.mkdir(parents=True, exist_ok=True)
        f = d / "chart.json"
        if f.is_file():
            shutil.copyfile(f, d / "chart.json.bak")
        tmp = d / "chart.json.tmp"
        tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
        os.replace(tmp, f)
        return self._send(200, {"ok": True, "saved": sent, "kept": kept})

    def _save_audio(self, folder, name, body):
        d = self._song_dir(folder)
        if d is None:
            return self._err(400, "잘못된 곡 폴더 이름")
        name = Path(name).name
        if Path(name).suffix.lower() not in AUDIO_EXT or not name:
            return self._err(400, "wav / ogg / mp3 만 가능합니다")
        d.mkdir(parents=True, exist_ok=True)
        (d / name).write_bytes(body)
        return self._send(200, {"ok": True, "name": name})

    def _get_audio(self, rel):
        parts = rel.split("/", 1)
        if len(parts) != 2:
            return self._err(404, "not found")
        d = self._song_dir(parts[0])
        if d is None:
            return self._err(400, "bad folder")
        f = (d / Path(parts[1]).name)
        if f.suffix.lower() not in AUDIO_EXT or not f.is_file():
            return self._err(404, "audio not found")
        size = f.stat().st_size
        ctype = mimetypes.guess_type(f.name)[0] or "application/octet-stream"
        rng = self.headers.get("Range")
        start, end, code = 0, size - 1, 200
        if rng:
            m = re.match(r"bytes=(\d*)-(\d*)", rng)
            if m:
                if m.group(1):
                    start = int(m.group(1))
                    end = int(m.group(2)) if m.group(2) else size - 1
                elif m.group(2):
                    start = max(0, size - int(m.group(2)))
                end = min(end, size - 1)
                if start > end:
                    return self._send(416, b"", extra={"Content-Range": f"bytes */{size}"})
                code = 206
        length = end - start + 1
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(length))
        self.send_header("Cache-Control", "no-store")
        if code == 206:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()
        if self.command == "HEAD":
            return
        try:
            with f.open("rb") as fh:
                fh.seek(start)
                left = length
                while left > 0:
                    chunk = fh.read(min(65536, left))
                    if not chunk:
                        break
                    self.wfile.write(chunk)
                    left -= len(chunk)
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass  # 브라우저가 시킹하며 연결을 끊는 정상 상황

    def _browse_root(self):
        try:
            import tkinter
            from tkinter import filedialog

            tk = tkinter.Tk()
            tk.withdraw()
            tk.attributes("-topmost", True)
            path = filedialog.askdirectory(title="게임 프로젝트 폴더 선택 (project.godot 이 있는 곳)")
            tk.destroy()
        except Exception as e:  # tkinter 가 없는 환경
            return self._err(500, f"폴더 선택 창을 열 수 없습니다: {e}")
        if not path:
            return self._send(200, {"ok": False, "cancelled": True})
        p = Path(path)
        if not is_game_root(p):
            return self._err(400, "선택한 폴더에 project.godot 이 없습니다")
        State.root = p.resolve()
        save_game_root(State.root)
        return self._send(200, {"ok": True, "root": str(State.root)})


# ---------------------------------------------------------------- 브라우저
def find_browser() -> str | None:
    pf = [os.environ.get("ProgramFiles", r"C:\Program Files"), os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
          os.environ.get("LOCALAPPDATA", "")]
    rels = [r"Microsoft\Edge\Application\msedge.exe", r"Google\Chrome\Application\chrome.exe"]
    for rel in rels:
        for base in pf:
            if base and (Path(base) / rel).is_file():
                return str(Path(base) / rel)
    return shutil.which("msedge") or shutil.which("chrome")


def open_app_window(url: str):
    """앱 모드(주소창 없는 창)로 연다. 전용 프로필을 쓰므로 프로세스 종료 = 창 닫힘."""
    exe = find_browser()
    if not exe:
        import webbrowser

        webbrowser.open(url)
        return None
    profile = data_dir() / "profile"
    return subprocess.Popen([
        exe, f"--app={url}", f"--user-data-dir={profile}", "--window-size=1500,920",
        "--no-first-run", "--no-default-browser-check", "--autoplay-policy=no-user-gesture-required",
    ])


def make_server(port: int) -> ThreadingHTTPServer:
    for p in (port, 0):
        try:
            srv = ThreadingHTTPServer(("127.0.0.1", p), Handler)
            srv.daemon_threads = True
            return srv
        except OSError:
            continue
    raise RuntimeError("로컬 서버를 열 수 없습니다")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="")
    ap.add_argument("--port", type=int, default=PREFERRED_PORT)
    ap.add_argument("--no-browser", action="store_true")
    ap.add_argument("--dev", action="store_true", help="UI 셀프테스트(tests/)를 제공")
    args = ap.parse_args()
    State.dev = args.dev

    State.root = find_game_root(args.root)
    srv = make_server(args.port)
    State.port = srv.server_address[1]
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{State.port}/?t={State.token}"
    print(url, flush=True)
    print("game root:", State.root, flush=True)
    try:  # 콘솔 없는 exe 에서도 디버그할 수 있게
        (data_dir() / "last_url.txt").write_text(url + "\n" + str(State.root), encoding="utf-8")
    except OSError:
        pass

    proc = None if args.no_browser else open_app_window(url)
    started = time.time()
    State.last_ping = started
    try:
        while True:
            time.sleep(0.5)
            now = time.time()
            if proc is not None and proc.poll() is not None and now - started > 5:
                # 앱 창 프로세스가 끝났어도(이미 열린 Edge 에 위임된 경우 등) 핑이 오면 계속 산다
                if not State.seen_ping or now - State.last_ping > 6:
                    break
            if State.seen_ping and now - State.last_ping > 8:
                break
            if not State.seen_ping and now - started > 60:
                break
    except KeyboardInterrupt:
        pass
    srv.shutdown()


if __name__ == "__main__":
    main()
