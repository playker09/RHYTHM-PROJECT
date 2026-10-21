"""UI 셀프테스트: 임시 게임 폴더(샘플 복사본)에 대해 launcher --dev 를 띄우고 헤드리스 Chrome 으로 ui_selftest.js 실행.
사용: python tests/run_ui_tests.py [게임폴더]
"""
import html
import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent
sys.path.insert(0, str(TOOL))
import launcher  # noqa: E402

GAME = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"C:\Users\ADMIN\Downloads\RHYTHM-PROJECT")

tmp = Path(tempfile.mkdtemp(prefix="pt_ui_"))
root = tmp / "game"
(root / "charts").mkdir(parents=True)
(root / "project.godot").write_text("; fake")
shutil.copytree(GAME / "charts" / "sample", root / "charts" / "sample")

srv = subprocess.Popen([sys.executable, str(TOOL / "launcher.py"), "--dev", "--no-browser", "--port", "0", "--root", str(root)],
                       stdout=subprocess.PIPE, text=True)
fails = 0
try:
    url = srv.stdout.readline().strip()
    out = subprocess.run(
        [launcher.find_browser(), "--headless=new", "--disable-gpu", f"--user-data-dir={tmp / 'prof'}", "--window-size=1500,900",
         "--virtual-time-budget=20000", "--dump-dom", url + "&selftest=1"],
        capture_output=True, text=True, timeout=120, encoding="utf-8",
    ).stdout
    i = out.find('<pre id="uiresults">')
    if i < 0:
        print("FAIL 셀프테스트 결과 없음\n", out[-600:])
        fails = 1
    else:
        body = out[i + len('<pre id="uiresults">'): out.find("</pre>", i)]
        for r in json.loads(html.unescape(body)):
            print(("PASS " if r["ok"] else "FAIL ") + "[ui] " + r["name"] + ("" if r["ok"] else "  -> " + r["detail"]))
            fails += 0 if r["ok"] else 1
    # 저장된 파일을 로더 규칙으로 다시 검증
    saved = json.loads((root / "charts" / "sample" / "chart.json").read_text(encoding="utf-8"))
    kept = launcher.simulate_loader(saved)
    good = sum(kept.values()) == len(saved["notes"])
    print(("PASS " if good else "FAIL ") + f"[ui] 저장 파일을 로더 규칙으로 읽어도 노트 수 동일 ({sum(kept.values())}/{len(saved['notes'])})")
    fails += 0 if good else 1
finally:
    srv.kill()
    time.sleep(0.3)
    shutil.rmtree(tmp, ignore_errors=True)
print("\n실패:", fails)
sys.exit(1 if fails else 0)
