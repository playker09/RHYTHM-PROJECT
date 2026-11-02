class_name AmbientBg
extends ColorRect
## 메뉴 공통 배경. tint 를 바꾸면 부드럽게 곡 색으로 물든다.

const SHADER := preload("res://ui/shaders/ambient.gdshader")

var pulse: float = 0.0
var _mat: ShaderMaterial
var _a: Color = Ui.VIOLET
var _b: Color = Ui.MAGENTA
var _ta: Color = Ui.VIOLET
var _tb: Color = Ui.MAGENTA

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.place(self, 0.0, 0.0, 1.0, 1.0)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_apply()

func set_tint(a: Color, b: Color) -> void:
	_ta = a
	_tb = b

func set_strength(v: float) -> void:
	_mat.set_shader_parameter("strength", v)

func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-delta * 3.0)
	_a = _a.lerp(_ta, k)
	_b = _b.lerp(_tb, k)
	_apply()

func _apply() -> void:
	_mat.set_shader_parameter("tint_a", _a)
	_mat.set_shader_parameter("tint_b", _b)
	_mat.set_shader_parameter("pulse", pulse)
