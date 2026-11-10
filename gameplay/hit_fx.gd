class_name HitFx
extends Node3D
## 판정 성공 이펙트. 풀로 재사용하고 판정 로직에는 관여하지 않는다.
## 머리/플릭 판정 = 고리 + 불꽃 입자 + 빛기둥, tick = 작은 고리만.

const BURST_POOL := 32
const SPARK_POOL := 10
const COLUMN_POOL := 8
const LIFE := 0.38
const TICK_LIFE := 0.2
const COLUMN_LIFE := 0.26
const TICK_COLOR := Color(0.55, 0.9, 1.0)
const BURST_SHADER := preload("res://gameplay/shaders/hit_burst.gdshader")
const BEAM_SHADER := preload("res://gameplay/shaders/beam.gdshader")

var _field: FieldController
var _bursts: Array[Dictionary] = []
var _next_burst: int = 0
var _sparks: Array[GPUParticles3D] = []
var _next_spark: int = 0
var _columns: Array[Dictionary] = []
var _next_column: int = 0

func setup(judge: Judge, field: FieldController) -> void:
	_field = field
	judge.judged.connect(_on_judged)
	for i in BURST_POOL:
		var mi := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(1.0, 1.0)
		mi.mesh = q
		var m := Highway.fx_mat(BURST_SHADER, Highway.ORDER_FX)
		m.set_shader_parameter("seed", randf())
		mi.material_override = m
		mi.visible = false
		add_child(mi)
		_bursts.append({"node": mi, "mat": m, "t": 0.0, "life": 1.0})
	for i in SPARK_POOL:
		_sparks.append(_make_sparks())
	for i in COLUMN_POOL:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(GameConst.LANE_WIDTH * 0.9, 3.4)
		mi.mesh = qm
		var m := Highway.fx_mat(BEAM_SHADER, Highway.ORDER_FX, {"intensity": 0.9, "power": 2.6})
		mi.material_override = m
		mi.visible = false
		add_child(mi)
		_columns.append({"node": mi, "mat": m, "t": 0.0})

func _make_sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.42
	p.one_shot = true
	p.explosiveness = 1.0
	p.interpolate = false
	p.fract_delta = false
	p.local_coords = true
	p.emitting = false
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.visibility_aabb = AABB(Vector3(-4.0, -2.0, -4.0), Vector3(8.0, 6.0, 8.0))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.25)
	pm.spread = 62.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 8.5
	pm.gravity = Vector3(0.0, -13.0, 0.0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.25
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(2.2, 2.2, 2.2)
	m.no_depth_test = true
	m.render_priority = Highway.ORDER_FX
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p

func _on_judged(note: NoteData, grade: int, _delta: float, is_tick: bool) -> void:
	if grade == JudgeLogic.Grade.MISS:
		return
	var pos: Vector3
	var on_lane: bool = false
	match note.type:
		NoteData.Type.TAP, NoteData.Type.HOLD:
			pos = Vector3(Highway.lane_x(note.lane), 0.08, 0.0)
			on_lane = true
		NoteData.Type.FLICK:
			pos = Vector3((note.x - 0.5) * GameConst.FIELD_WIDTH, GameConst.AIR_Y, GameConst.AIR_Z)
		_:
			pos = Vector3((_field.cursor_x - 0.5) * GameConst.FIELD_WIDTH, GameConst.AIR_Y, GameConst.AIR_Z)
	if is_tick:
		_burst(pos, 1.2, TICK_COLOR, TICK_LIFE, 0.3)
		return
	var color: Color = Ui.GRADE_COLORS[grade]
	var perfect: bool = grade == JudgeLogic.Grade.PERFECT
	_burst(pos, 4.6 if note.type == NoteData.Type.FLICK else 3.6, color, LIFE, 1.25 if perfect else 0.9)
	_spark(pos, color, 14 if perfect else 8)
	if on_lane:
		_column(pos, color)

func _burst(pos: Vector3, scale_m: float, color: Color, life: float, power: float) -> void:
	var it: Dictionary = _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % _bursts.size()
	var mi: MeshInstance3D = it["node"]
	mi.position = pos
	mi.scale = Vector3(scale_m, 1.0, scale_m)
	mi.visible = true
	var m: ShaderMaterial = it["mat"]
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("power", power)
	m.set_shader_parameter("progress", 0.0)
	it["t"] = 0.0
	it["life"] = life

func _spark(pos: Vector3, color: Color, amount: int) -> void:
	var p: GPUParticles3D = _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % _sparks.size()
	p.position = pos
	p.amount_ratio = float(amount) / float(p.amount)
	(p.process_material as ParticleProcessMaterial).color = color.lerp(Color.WHITE, 0.25)
	p.restart()
	p.emitting = true

func _column(pos: Vector3, color: Color) -> void:
	var it: Dictionary = _columns[_next_column]
	_next_column = (_next_column + 1) % _columns.size()
	var mi: MeshInstance3D = it["node"]
	mi.position = Vector3(pos.x, 1.7, 0.0)
	mi.visible = true
	(it["mat"] as ShaderMaterial).set_shader_parameter("color", color)
	it["t"] = 0.0

func _process(delta: float) -> void:
	for it in _bursts:
		var mi: MeshInstance3D = it["node"]
		if not mi.visible:
			continue
		it["t"] = float(it["t"]) + delta
		var p: float = float(it["t"]) / float(it["life"])
		if p >= 1.0:
			mi.visible = false
		else:
			(it["mat"] as ShaderMaterial).set_shader_parameter("progress", p)
	for it in _columns:
		var mi: MeshInstance3D = it["node"]
		if not mi.visible:
			continue
		it["t"] = float(it["t"]) + delta
		var p: float = float(it["t"]) / COLUMN_LIFE
		if p >= 1.0:
			mi.visible = false
		else:
			(it["mat"] as ShaderMaterial).set_shader_parameter("gain", (1.0 - p) * (1.0 - p))
