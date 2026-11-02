class_name Jacket
extends ColorRect
## 곡 제목에서 만들어지는 생성 재킷. 같은 제목이면 항상 같은 그림이다.

const SHADER := preload("res://ui/shaders/jacket.gdshader")

var _mat: ShaderMaterial

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat

func set_song(title: String) -> void:
	var cols: Array = palette(title)
	_mat.set_shader_parameter("seed", float(title.hash() % 1000) * 0.137)
	_mat.set_shader_parameter("c1", cols[0])
	_mat.set_shader_parameter("c2", cols[1])
	_mat.set_shader_parameter("c3", cols[2])

## [어두운 색, 중간 색, 밝은 강조색]
static func palette(title: String) -> Array:
	var hue: float = float(title.hash() % 360) / 360.0
	return [
		Color.from_hsv(hue, 0.78, 0.2),
		Color.from_hsv(fposmod(hue + 0.09, 1.0), 0.72, 0.62),
		Color.from_hsv(fposmod(hue + 0.46, 1.0), 0.5, 1.0),
	]
