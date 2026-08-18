extends Node

# =========================
# 레인
# =========================

enum Lane {
	LEFT,
	RIGHT
}


# =========================
# 판정
# =========================

const PERFECT_WINDOW := 0.050 # ±50ms
const GOOD_WINDOW := 0.100    # ±100ms
const OKAY_WINDOW := 0.150    # ±150ms


# =========================
# 노트 표시
# =========================

# 판정선까지 도착하기 전에 화면에 보여주는 시간
const APPROACH_TIME := 2.0

# 노트의 기본 표시 속도 배율
# 나중에 Note Speed 설정으로 사용할 수 있음
var note_speed := 1.0

# =========================
# 화면
# =========================

const JUDGEMENT_Y := 600.0
const SPAWN_Y := -20.0

func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
