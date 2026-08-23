extends Node

# 판정 윈도우 (초 단위)
const PERFECT_WINDOW := 0.045
const GREAT_WINDOW := 0.085
const GOOD_WINDOW := 0.135
const APPROACH_TIME := 1.65

# 3D 광각 원근 투시 (Perspective Field) 기준 좌표
const TRACK_TOP_Y := 75.0             # 상단 소실점 Y
const TRACK_TOP_WIDTH := 110.0        # 소실점 트랙 폭 (멀리서 극도로 좁아짐)
const TRACK_BOTTOM_Y := 615.0         # 하단 4키 판정선 Y
const TRACK_BOTTOM_WIDTH := 860.0     # 하단 트랙 폭 (화면을 꽉 채우는 광각)
const LEVER_JUDGEMENT_Y := 465.0      # 상단 레버 판정선 Y (중간 상공)
const SIDE_WALL_WIDTH_RATIO := 0.32   # 3D 사이드 월 패널 너비 비율

# 모드 및 난이도 Enum
enum PlayMode {
	CASUAL_LEVER_2KEY,  # 2키 + 레버 모드 (일반인 모드)
	PRO_4KEY_LEVER      # 4키 + 레버 롱노트/플릭 모드 (진짜 리듬게임 모드)
}

enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

enum NoteType {
	TAP,               # 4키 바닥 탭 노트
	HOLD,              # 4키 바닥 롱노트
	LEVER_FLICK_LEFT,  # 상단 레버 좌측 갈고리 플릭
	LEVER_FLICK_RIGHT, # 상단 레버 우측 갈고리 플릭
	LEVER_CURVE_HOLD   # 상단 좌우 곡선 레버 리본 롱노트
}

# 4개 레인 컬러 팔레트 (Chunithm / ONGEKI / In Falsus 테마)
const LANE_COLORS := [
	Color("00e5ff"), # 1레인: Cyan
	Color("80d8ff"), # 2레인: Light Cyan
	Color("00e5ff"), # 3레인: Cyan
	Color("80d8ff")  # 4레인: Light Cyan
]

# 판정 텍스트 색상
const JUDGE_COLORS := {
	"EXACT": Color("d500f9"),
	"MAX 100%": Color("ffea00"),
	"PERFECT": Color("00e5ff"),
	"GREAT": Color("76ff03"),
	"GOOD": Color("ff9100"),
	"MISS": Color("ff1744"),
	"READY": Color("ffffff")
}
