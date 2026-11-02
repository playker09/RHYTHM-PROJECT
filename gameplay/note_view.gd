class_name NoteView
extends Node3D
## Tap/Hold/Flick 노트의 그림. 원점 = 노트 머리(판정 기준), Hold 몸통은 -Z(미래) 방향.

enum Kind { TAP, HOLD, FLICK }
enum State { NORMAL, HELD, MISSED }

const TAP_COLOR := Color(0.5, 0.92, 1.0)
const HOLD_COLOR := Color(1.0, 0.62, 0.22)
const HELD_COLOR := Color(1.0, 0.95, 0.72)
const MISSED_COLOR := Color(0.32, 0.32, 0.4)
const FLICK_LEFT_COLOR := Color(1.0, 0.88, 0.2)    # 왼쪽 = 노랑
const FLICK_RIGHT_COLOR := Color(0.3, 1.0, 0.45)   # 오른쪽 = 초록

const PILL_SHADER := preload("res://gameplay/shaders/note_pill.gdshader")
const HOLD_SHADER := preload("res://gameplay/shaders/note_hold.gdshader")
const FLICK_SHADER := preload("res://gameplay/shaders/note_flick.gdshader")

var kind: int = Kind.TAP
var _head_mat: ShaderMaterial
var _body_mat: ShaderMaterial
var _body: MeshInstance3D
var _base_color: Color = TAP_COLOR

static func create(k: int) -> NoteView:
	var v := NoteView.new()
	v.kind = k
	v._build()
	return v

func _build() -> void:
	var w: float = GameConst.LANE_WIDTH
	var head := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	if kind == Kind.FLICK:
		pm.size = Vector2(3.0, 1.6)     # 비스듬히 보이므로 Z를 늘려 쐐기가 읽히게 한다
		_head_mat = Highway.fx_mat(FLICK_SHADER, Highway.ORDER_AIR)
	else:
		pm.size = Vector2(w * 1.05, 0.6)
		_head_mat = Highway.fx_mat(PILL_SHADER, Highway.ORDER_NOTE + 1, {
			"size": pm.size, "body": Vector2(w * 0.88, 0.2)})
	head.mesh = pm
	head.material_override = _head_mat
	add_child(head)
	if kind == Kind.HOLD:
		_base_color = HOLD_COLOR
		_body_mat = Highway.fx_mat(HOLD_SHADER, Highway.ORDER_NOTE)
		_body = MeshInstance3D.new()
		var bm := PlaneMesh.new()
		bm.size = Vector2(w * 0.72, 1.0)
		_body.mesh = bm
		_body.material_override = _body_mat
		_body.position.y = -0.01
		add_child(_body)
	set_state(State.NORMAL)

func set_flick_dir(dir: String) -> void:
	var left: bool = dir == "left"
	_base_color = FLICK_LEFT_COLOR if left else FLICK_RIGHT_COLOR
	rotation_degrees.y = 180.0 if left else 0.0
	set_state(State.NORMAL)

func set_state(state: int) -> void:
	var c: Color = _base_color
	var a: float = 1.0
	match state:
		State.HELD:
			c = HELD_COLOR
		State.MISSED:
			c = MISSED_COLOR
			a = 0.45
	_head_mat.set_shader_parameter("color", c)
	_head_mat.set_shader_parameter("alpha", a)
	if _body_mat != null:
		_body_mat.set_shader_parameter("color", c)
		_body_mat.set_shader_parameter("alpha", a)
		_body_mat.set_shader_parameter("energy", 1.1 if state == State.HELD else 1.0)

## 몸통 길이(m). 머리에서 -Z 방향으로 뻗는다.
func set_hold_extent(length: float) -> void:
	if _body == null:
		return
	var l: float = maxf(length, 0.001)
	_body.scale = Vector3(1.0, 1.0, l)
	_body.position = Vector3(0.0, -0.01, -l * 0.5)
