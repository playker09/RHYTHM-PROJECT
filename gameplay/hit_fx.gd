class_name HitFx
extends Node3D
## 판정 성공 이펙트. 풀로 재사용하고 판정 로직에는 관여하지 않는다.
## 머리/플릭 판정 = 크게, tick = 작게.

const POOL_SIZE := 32
const LIFE := 0.34
const TICK_LIFE := 0.2
const SHADER := preload("res://gameplay/shaders/hit_burst.gdshader")

var _field: FieldController
var _items: Array[Dictionary] = []
var _next: int = 0

func setup(judge: Judge, field: FieldController) -> void:
	_field = field
	judge.judged.connect(_on_judged)
	for i in POOL_SIZE:
		var mi := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(1.0, 1.0)
		mi.mesh = q
		var m := Highway.fx_mat(SHADER, Highway.ORDER_FX)
		m.set_shader_parameter("seed", randf())
		mi.material_override = m
		mi.visible = false
		add_child(mi)
		_items.append({"node": mi, "mat": m, "t": 0.0, "life": 1.0})

func _on_judged(note: NoteData, grade: int, _delta: float, is_tick: bool) -> void:
	if grade == JudgeLogic.Grade.MISS:
		return
	var pos: Vector3
	match note.type:
		NoteData.Type.TAP, NoteData.Type.HOLD:
			var x: float = (note.lane - (GameConst.LANE_COUNT - 1) * 0.5) * GameConst.LANE_WIDTH
			pos = Vector3(x, 0.08, 0.0)
		NoteData.Type.FLICK:
			pos = Vector3((note.x - 0.5) * GameConst.FIELD_WIDTH, GameConst.AIR_Y, GameConst.AIR_Z)
		_:
			pos = Vector3((_field.cursor_x - 0.5) * GameConst.FIELD_WIDTH, GameConst.AIR_Y, GameConst.AIR_Z)
	if is_tick:
		_spawn(pos, 1.5, Color(0.55, 0.9, 1.0), TICK_LIFE)
	else:
		_spawn(pos, 4.2 if note.type == NoteData.Type.FLICK else 3.4, Ui.GRADE_COLORS[grade], LIFE)

func _spawn(pos: Vector3, scale_m: float, color: Color, life: float) -> void:
	var it: Dictionary = _items[_next]
	_next = (_next + 1) % _items.size()
	var mi: MeshInstance3D = it["node"]
	mi.position = pos
	mi.scale = Vector3(scale_m, 1.0, scale_m)
	mi.visible = true
	(it["mat"] as ShaderMaterial).set_shader_parameter("color", color)
	it["t"] = 0.0
	it["life"] = life

func _process(delta: float) -> void:
	for it in _items:
		var mi: MeshInstance3D = it["node"]
		if not mi.visible:
			continue
		it["t"] = float(it["t"]) + delta
		var p: float = float(it["t"]) / float(it["life"])
		if p >= 1.0:
			mi.visible = false
		else:
			(it["mat"] as ShaderMaterial).set_shader_parameter("progress", p)
