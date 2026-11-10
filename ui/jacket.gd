class_name Jacket
extends ColorRect
## 곡 재킷. 곡 폴더에 jacket.png 등이 있으면 그 그림을, 없으면 제목에서 만든 생성 재킷을 보여 준다.
## 같은 제목이면 항상 같은 그림이다.

const SHADER := preload("res://ui/shaders/jacket.gdshader")

var _mat: ShaderMaterial
var _image: TextureRect

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.visible = false
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_image)

func set_song(title: String, image_path: String = "") -> void:
	var cols: Array = palette(title)
	_mat.set_shader_parameter("seed", float(title.hash() % 1000) * 0.137)
	_mat.set_shader_parameter("c1", cols[0])
	_mat.set_shader_parameter("c2", cols[1])
	_mat.set_shader_parameter("c3", cols[2])
	var tex: Texture2D = load(image_path) if image_path != "" else null
	_image.texture = tex
	_image.visible = tex != null

## [어두운 색, 중간 색, 밝은 강조색]
static func palette(title: String) -> Array:
	var hue: float = float(title.hash() % 360) / 360.0
	return [
		Color.from_hsv(hue, 0.78, 0.2),
		Color.from_hsv(fposmod(hue + 0.09, 1.0), 0.72, 0.62),
		Color.from_hsv(fposmod(hue + 0.46, 1.0), 0.5, 1.0),
	]
