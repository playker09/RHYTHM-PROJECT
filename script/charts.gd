extends Node

# ==========================================
# 테스트용 채보
#
# time : 노트가 판정되어야 하는 음악 시간
# lane : LEFT / RIGHT
# ==========================================

static func get_chart() -> Array:
	return [
		{"time": 2.000, "lane": Global.Lane.LEFT},
		{"time": 2.500, "lane": Global.Lane.RIGHT},
		{"time": 3.000, "lane": Global.Lane.LEFT},
		{"time": 3.500, "lane": Global.Lane.RIGHT},

		{"time": 4.000, "lane": Global.Lane.LEFT},
		{"time": 4.250, "lane": Global.Lane.RIGHT},
		{"time": 4.500, "lane": Global.Lane.LEFT},
		{"time": 4.750, "lane": Global.Lane.RIGHT},

		{"time": 5.500, "lane": Global.Lane.LEFT},
		{"time": 6.000, "lane": Global.Lane.RIGHT},
		{"time": 6.500, "lane": Global.Lane.LEFT},
		{"time": 7.000, "lane": Global.Lane.RIGHT},

		{"time": 8.000, "lane": Global.Lane.LEFT},
		{"time": 8.500, "lane": Global.Lane.LEFT},
		{"time": 9.000, "lane": Global.Lane.RIGHT},
		{"time": 9.500, "lane": Global.Lane.RIGHT},
	]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
