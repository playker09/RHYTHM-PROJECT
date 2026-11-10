class_name Stage
extends Node3D
## 무대(세계): 하늘/일식, 글로우 환경, 카메라, 길 아래 격자, 양옆 기둥과 아치, 떠다니는 결정, 먼지, 화면 마무리.
## 게임과 메뉴가 같은 무대를 쓴다. 판정 로직과 무관한 순수 비주얼이고 sync() 로 박자를 받는다.

const SKY_SHADER := preload("res://gameplay/shaders/sky.gdshader")
const ABYSS_SHADER := preload("res://gameplay/shaders/abyss.gdshader")
const PILLAR_SHADER := preload("res://gameplay/shaders/pillar.gdshader")
const SHARD_SHADER := preload("res://gameplay/shaders/shard.gdshader")
const NEON_SHADER := preload("res://gameplay/shaders/neon.gdshader")
const POST_SHADER := preload("res://gameplay/shaders/post.gdshader")

const LEFT := Color(0.56, 0.48, 1.0)
const RIGHT := Color(1.0, 0.31, 0.62)
const FAR := 150.0                  # 기둥/아치가 보이기 시작하는 거리 (m)
const PILLAR_ROWS := 12
const GATE_COUNT := 6
const INNER_X := 9.6
const OUTER_X := 15.5
const INNER_H := 12.0
const OUTER_H := 20.0
const ABYSS_Y := -10.0

## 카메라 구도. 게임 구도는 판정 가독성 기준이라 바꾸지 않는다.
const VIEWS := {
	"game": {"pos": Vector3(0.0, 3.7, 7.4), "at": Vector3(0.0, 0.4, -6.0), "fov": 46.0},
	"title": {"pos": Vector3(0.0, 1.6, 9.5), "at": Vector3(0.0, -0.8, -30.0), "fov": 44.0},
	"menu": {"pos": Vector3(3.6, 2.5, 9.0), "at": Vector3(-2.2, 2.4, -24.0), "fov": 54.0},
	"select": {"pos": Vector3(-2.6, 5.4, 10.5), "at": Vector3(1.2, 1.8, -26.0), "fov": 50.0},
}

var camera: Camera3D
var sway: float = 0.0               # 메뉴에서 카메라가 천천히 흔들리는 정도 (m)

var _env: Environment
var _sky_mat: ShaderMaterial
var _abyss_mat: ShaderMaterial
var _pillar_mats: Array[ShaderMaterial] = []
var _shard_mat: ShaderMaterial
var _post_mat: ShaderMaterial
var _gate_mat: ShaderMaterial
var _pillars: Array[Array] = []     # [node, x, row_offset(0/0.5)]
var _gates: Array[MeshInstance3D] = []
var _view_pos := Vector3(0.0, 3.7, 7.4)
var _view_at := Vector3(0.0, 0.4, -6.0)
var _view_tween: Tween
var _post_tween: Tween
var _time: float = 0.0

func _init() -> void:
	_build_environment()
	_build_abyss()
	_build_pillars()
	_build_gates()
	_build_shards()
	_build_dust(-11.0)
	_build_dust(11.0)
	_build_post()
	set_view("game")

# --- 외부 인터페이스 ---
## 카메라 구도를 바꾼다. duration > 0 이면 부드럽게 이동.
func set_view(view: String, duration: float = 0.0) -> void:
	var v: Dictionary = VIEWS[view]
	if _view_tween != null:
		_view_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		_view_pos = v["pos"]
		_view_at = v["at"]
		camera.fov = v["fov"]
		_apply_camera()
		return
	_view_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_view_tween.tween_property(self, "_view_pos", v["pos"], duration)
	_view_tween.tween_property(self, "_view_at", v["at"], duration)
	_view_tween.tween_property(camera, "fov", v["fov"], duration)

## 화면 마무리 값. dim = 어둡게(0~1), blur = 흐림(mip 단계).
func set_post(dim: float, blur: float, duration: float = 0.0) -> void:
	if _post_tween != null:
		_post_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		_post_mat.set_shader_parameter("dim", dim)
		_post_mat.set_shader_parameter("blur", blur)
		return
	var d0: float = _post_mat.get_shader_parameter("dim")
	var b0: float = _post_mat.get_shader_parameter("blur")
	_post_tween = create_tween().set_parallel()
	_post_tween.tween_method(func(v: float): _post_mat.set_shader_parameter("dim", v), d0, dim, duration)
	_post_tween.tween_method(func(v: float): _post_mat.set_shader_parameter("blur", v), b0, blur, duration)

## 하늘 전체 밝기 (1 = 기본)
func set_sky_energy(v: float) -> void:
	_sky_mat.set_shader_parameter("energy", v)

## 박자에 맞춰 무대를 움직인다. beats = 지금까지의 박 수, beat_len = 박 하나의 길이(m), pulse = 박 직후 1 -> 0.
func sync(beats: float, beat_len: float, pulse: float) -> void:
	var travelled: float = beats * beat_len
	_sky_mat.set_shader_parameter("pulse", pulse)
	_abyss_mat.set_shader_parameter("scroll", fposmod(travelled, 8.0))
	_abyss_mat.set_shader_parameter("pulse", pulse)
	_shard_mat.set_shader_parameter("scroll", fposmod(travelled * 0.35, 180.0))
	for m in _pillar_mats:
		m.set_shader_parameter("pulse", pulse)
	_gate_mat.set_shader_parameter("energy", 0.7 + pulse * 0.9)
	# 기둥/아치: 마디 간격(너무 촘촘하거나 성기면 2배씩 조정)으로 흘러온다
	var spacing: float = beat_len * 4.0
	while spacing < 11.0:
		spacing *= 2.0
	while spacing > 22.0:
		spacing *= 0.5
	var z0: float = fposmod(travelled, spacing) + spacing
	for p: Array in _pillars:
		var node: Node3D = p[0]
		node.position.z = z0 - (float(p[2]) + float(p[3])) * spacing
	for i in _gates.size():
		_gates[i].position.z = z0 - float(i * 2) * spacing

func _process(delta: float) -> void:
	_time += delta
	_apply_camera()

func _apply_camera() -> void:
	var off := Vector3.ZERO
	if sway > 0.0:
		off = Vector3(sin(_time * 0.21) * sway, sin(_time * 0.33 + 1.0) * sway * 0.45, 0.0)
	var pos: Vector3 = _view_pos + off
	camera.transform = Transform3D(Basis.looking_at(_view_at - off * 0.4 - pos, Vector3.UP), pos)

# --- 구성 ---
func _build_environment() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 5.0
	_env.tonemap_exposure = 1.1
	_env.glow_enabled = true
	_env.glow_intensity = 0.62
	_env.glow_bloom = 0.02
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_hdr_threshold = 1.0
	_env.glow_hdr_scale = 1.4
	_env.set_glow_level(0, 0.0)
	_env.set_glow_level(1, 1.0)
	_env.set_glow_level(2, 0.9)
	_env.set_glow_level(3, 0.6)
	_env.set_glow_level(4, 0.4)
	_env.set_glow_level(5, 0.25)
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	camera = Camera3D.new()
	camera.fov = 46.0
	camera.far = 400.0
	add_child(camera)

func _build_abyss() -> void:
	_abyss_mat = ShaderMaterial.new()
	_abyss_mat.shader = ABYSS_SHADER
	_abyss_mat.render_priority = -8
	_abyss_mat.set_shader_parameter("tone_left", LEFT)
	_abyss_mat.set_shader_parameter("tone_right", RIGHT)
	var pm := PlaneMesh.new()
	pm.size = Vector2(700.0, 700.0)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = _abyss_mat
	mi.position = Vector3(0.0, ABYSS_Y, -200.0)
	add_child(mi)

func _build_pillars() -> void:
	# [x, 높이, 폭, 줄 어긋남(0/0.5), 색]
	var rows: Array = [
		[-INNER_X, INNER_H, 1.3, 0.0, LEFT], [INNER_X, INNER_H, 1.3, 0.0, RIGHT],
		[-OUTER_X, OUTER_H, 1.9, 0.5, LEFT], [OUTER_X, OUTER_H, 1.9, 0.5, RIGHT],
	]
	for r: Array in rows:
		var mat := ShaderMaterial.new()
		mat.shader = PILLAR_SHADER
		mat.render_priority = -6
		mat.set_shader_parameter("rim", r[4])
		mat.set_shader_parameter("depth", FAR)
		_pillar_mats.append(mat)
		var qm := QuadMesh.new()
		qm.size = Vector2(float(r[2]), float(r[1]))
		var x: float = r[0]
		for i in PILLAR_ROWS:
			var mi := MeshInstance3D.new()
			mi.mesh = qm
			mi.material_override = mat
			# 판이 길 쪽을 비스듬히 보게 돌린다. 바닥 아래에서 솟아오른다.
			mi.rotation.y = (PI * 0.5 - 0.62) * (1.0 if x < 0.0 else -1.0)
			mi.position = Vector3(x, float(r[1]) * 0.5 - 4.0, 0.0)
			add_child(mi)
			_pillars.append([mi, x, float(i), float(r[3])])

## 안쪽 기둥 위를 잇는 뾰족한 아치
func _build_gates() -> void:
	var top: float = INNER_H - 4.0
	var pts: Array[Vector2] = [
		Vector2(-INNER_X, top - 2.2), Vector2(-INNER_X * 0.5, top + 1.4), Vector2(0.0, top + 3.2),
		Vector2(INNER_X * 0.5, top + 1.4), Vector2(INNER_X, top - 2.2)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t: float = 0.035
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n: Vector2 = (b - a).normalized().orthogonal() * t
		for p: Vector2 in [a + n, a - n, b + n, b + n, a - n, b - n]:
			st.add_vertex(Vector3(p.x, p.y, 0.0))
	var mesh: ArrayMesh = st.commit()
	_gate_mat = ShaderMaterial.new()
	_gate_mat.shader = NEON_SHADER
	_gate_mat.render_priority = -5
	_gate_mat.set_shader_parameter("depth", FAR)
	_gate_mat.set_shader_parameter("color", Color(0.78, 0.68, 1.0))
	_gate_mat.set_shader_parameter("energy", 0.8)
	_gate_mat.set_shader_parameter("alpha", 0.55)
	_gate_mat.set_shader_parameter("near_z", 4.0)
	for i in GATE_COUNT:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _gate_mat
		add_child(mi)
		_gates.append(mi)

func _build_shards() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.0, 1.0, 0.0)
	var bottom := Vector3(0.0, -1.0, 0.0)
	var ring: Array[Vector3] = [Vector3(0.45, 0.0, 0.0), Vector3(0.0, 0.0, 0.45), Vector3(-0.45, 0.0, 0.0), Vector3(0.0, 0.0, -0.45)]
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		_add_tri(st, top, b, a)
		_add_tri(st, bottom, a, b)
	var mesh: ArrayMesh = st.commit()
	_shard_mat = ShaderMaterial.new()
	_shard_mat.shader = SHARD_SHADER
	_shard_mat.set_shader_parameter("tone_a", LEFT)
	_shard_mat.set_shader_parameter("tone_b", RIGHT)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = 90
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240
	for i in mm.instance_count:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * rng.randf_range(17.0, 60.0)
		var y: float = rng.randf_range(-6.0, 34.0)
		var z: float = rng.randf_range(-180.0, 0.0)
		var s: float = rng.randf_range(0.35, 1.9)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3(s, s * rng.randf_range(1.0, 2.4), s))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		mm.set_instance_custom_data(i, Color(rng.randf(), 0.5 + side * 0.5 * rng.randf_range(0.4, 1.0), rng.randf(), 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _shard_mat
	mmi.custom_aabb = AABB(Vector3(-80.0, -20.0, -200.0), Vector3(160.0, 80.0, 230.0))
	add_child(mmi)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = (c - a).cross(b - a).normalized()
	for p: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(p)

## 길 옆을 스쳐 지나가는 빛 입자
func _build_dust(x: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 70
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.position = Vector3(x, 4.0, -60.0)
	p.visibility_aabb = AABB(Vector3(-12.0, -10.0, -20.0), Vector3(24.0, 26.0, 100.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6.0, 5.0, 6.0)
	pm.direction = Vector3(0.0, 0.0, 1.0)
	pm.spread = 0.0
	pm.initial_velocity_min = 11.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 1.1)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c: Color = LEFT if x < 0.0 else RIGHT
	m.albedo_color = Color(c.r, c.g, c.b, 0.32)
	m.render_priority = -2
	q.material = m
	p.draw_pass_1 = q
	add_child(p)

func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var r := ColorRect.new()
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = POST_SHADER
	_post_mat.set_shader_parameter("dim", 0.0)
	_post_mat.set_shader_parameter("blur", 0.0)
	r.material = _post_mat
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
