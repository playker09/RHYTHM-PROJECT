# RHYTHM 패턴 툴

`RHYTHM-PROJECT`(Godot 4) 전용 채보 에디터. **`PatternTool.exe` 를 실행하면 끝.**
기준 문서: `PATTERN_TOOL_GUIDE.md` (게임 코드는 수정하지 않음).

## 실행
- `PatternTool.exe` 더블클릭 → 앱 창(Edge/Chrome)이 열립니다. 창을 닫으면 프로그램도 종료됩니다.
- 게임 폴더(`project.godot` 이 있는 곳)는 자동으로 찾습니다 (exe 주변 / 상위 폴더 / 형제 `RHYTHM-PROJECT`).
  못 찾으면 폴더 선택창이 뜨고, 하단의 `게임: …` 을 클릭하면 언제든 바꿀 수 있습니다. 설정은 `%LOCALAPPDATA%\RhythmPatternTool\` 에 저장됩니다.
- 저장하면 `<게임>/charts/<곡폴더>/chart.json` 에 바로 써집니다 (이전 파일은 `chart.json.bak`).

## 조작
| 키 | 동작 |
|---|---|
| 1 / 2 / 3 / 4 / 5 | 선택 / 탭 / 홀드(드래그) / 플릭(Tab: 방향) / 필드 |
| 필드 | 클릭으로 키프레임 추가 → **Enter** 확정, 우클릭·Backspace 마지막 취소, Esc 취소, Alt+휠 폭 |
| 휠 / Shift+휠 / Ctrl+휠 | 스크롤 / 스냅 단위 이동 / 줌 |
| Space | 재생·정지 (효과음 on/off, 0.5×~1× 속도) |
| `[` `]` | 스냅 1/4 ~ 1/64 |
| Ctrl+Z / Y, Ctrl+C / V, Ctrl+A | 되돌리기·다시, 복사·붙여넣기, 전체 선택 |
| M, Shift+↑↓, Del, 우클릭 | 좌우 반전, 선택 노트 시간 이동, 삭제 |
| Ctrl+S | 저장 |

화면: 왼쪽 = 공중(flick/field, x 0~1), 오른쪽 = 바닥 4레인(A S D F). 시간은 ms, 위로 흐릅니다.
x/center 는 5% 단위로 스냅(Alt 누르면 1%). 파형은 `meta.offset` 이 반영된 위치에 그려집니다.

## 저장 전 검사 (PATTERN_TOOL_GUIDE.md 4·6절)
- **오류(저장 불가)**: lane 0~3, hold `end > time`, flick `x` 0~1·`dir` left/right, field 키 2개 이상·시간 오름차순·`center/width` 0~1·필드끼리 겹침 금지, bpm > 0.
- **경고(저장 가능)**: 같은 레인 tap/hold 겹침, flick 간격/방향 급변, 필드 첫 center 도달 난이도, 오디오 길이 초과.
- 서버가 저장 직전에 `ChartLoader` 규칙을 그대로 모사해서 **로더가 버릴 노트가 하나라도 있으면 저장을 거부**합니다.
- 검사 탭에 tap/hold/flick/field 개수와 **총 판정 수**(hold/field tick = 1/8박 규칙, 마지막 tick = 끝 시각)가 표시됩니다.
- 경고 기준 중 `FLICK_MIN_GAP_MS`, `FLICK_REVERSE_GAP_MS`, `MAX_CURSOR_SPEED` 는 게임 코드에 없는 휴리스틱입니다 (`web/core.js` 상단).

## 새 곡
`＋ 새 곡` → 폴더 이름/제목/BPM/오디오 입력. 새 오디오는 **Godot 에디터에서 프로젝트를 한 번 열어 import** 해야 게임에서 로드됩니다.

## 개발
```
python launcher.py --no-browser      # 서버만 (URL 이 콘솔에 출력됨)
python tests/run_tests.py            # 코어(JS) + 서버 테스트
python tests/run_ui_tests.py         # 실제 마우스 조작 UI 테스트 (임시 폴더에서 실행)
build_exe.bat                        # PatternTool.exe 재빌드 (pip 로 pyinstaller 설치)
```
구성: `launcher.py`(로컬 서버 + 창 실행 + charts API) · `web/core.js`(포맷/타이밍/검증/통계) · `web/app.js`(UI).
서버는 127.0.0.1 에만 열리고, 실행마다 바뀌는 토큰이 없으면 모든 요청을 거부합니다.

## 라이선스
OpenChart(GPLv3)의 구조를 바탕으로 한 파생물이므로 상위 폴더의 `LICENSE`(GPLv3)를 따릅니다.
