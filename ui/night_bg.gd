class_name NightBg
extends Control
## 타이틀 화면용 밤 도시 배경 (코드로 그림). 별, 달, 건물 실루엣, 떠다니는 네온 조각.

const SKY_TOP := Color(0.035, 0.04, 0.1)
const SKY_BOTTOM := Color(0.13, 0.09, 0.2)

var _t: float = 0.0
var _stars: Array[Vector3] = []     # x, y (0~1), 반짝 위상
var _shapes: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240606
	for i in 70:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.7, rng.randf() * TAU))
	var palette := [Color(1.0, 0.45, 0.2), Color(0.3, 0.9, 0.5), Color(1.0, 0.3, 0.4), Color(1.0, 0.7, 0.3)]
	for i in 9:
		_shapes.append({
			"pos": Vector2(rng.randf_range(0.04, 0.26) if i % 2 == 0 else rng.randf_range(0.74, 0.96), rng.randf_range(0.1, 0.8)),
			"size": rng.randf_range(14.0, 46.0),
			"color": palette[rng.randi() % palette.size()],
			"phase": rng.randf() * TAU,
			"rot": rng.randf_range(-0.5, 0.5),
		})

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var s: Vector2 = size
	# 하늘 그라데이션
	var bands := 24
	for i in bands:
		var k0: float = float(i) / bands
		draw_rect(Rect2(0.0, s.y * k0, s.x, s.y / bands + 1.0), SKY_TOP.lerp(SKY_BOTTOM, k0 * k0))
	# 지평선 주황 빛
	for i in 10:
		var a: float = 0.05 * (1.0 - float(i) / 10.0)
		draw_rect(Rect2(0.0, s.y * (0.95 - i * 0.03), s.x, s.y * 0.03), Color(1.0, 0.45, 0.2, a))
	# 별
	for st in _stars:
		var tw: float = 0.5 + 0.5 * sin(_t * 1.6 + st.z)
		draw_circle(Vector2(st.x * s.x, st.y * s.y), 1.3, Color(1, 1, 1, 0.25 + 0.5 * tw))
	# 달 (초승달)
	var moon := Vector2(s.x * 0.86, s.y * 0.17)
	draw_circle(moon, 14.0, Color(0.95, 0.96, 1.0))
	draw_circle(moon + Vector2(7.0, -3.0), 12.5, SKY_TOP.lerp(SKY_BOTTOM, 0.12))
	# 건물 실루엣 (좌우)
	_draw_towers(s)
	# 네온 조각
	for sh in _shapes:
		var p: Vector2 = (sh["pos"] as Vector2) * s + Vector2(0.0, sin(_t * 0.8 + float(sh["phase"])) * 8.0)
		var z: float = float(sh["size"])
		var c: Color = sh["color"]
		var r: float = float(sh["rot"])
		var pts := PackedVector2Array([
			p + Vector2(-z, -z * 0.5).rotated(r), p + Vector2(z, -z * 0.7).rotated(r),
			p + Vector2(z * 0.8, z * 0.4).rotated(r), p + Vector2(-z * 0.9, z * 0.5).rotated(r)])
		draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.85))
		draw_polyline(pts + PackedVector2Array([pts[0]]), c.lightened(0.5), 2.0)

func _draw_towers(s: Vector2) -> void:
	var base := Color(0.05, 0.06, 0.13)
	var specs := [
		[0.00, 0.10, 0.52], [0.09, 0.07, 0.40], [0.15, 0.05, 0.62],
		[0.84, 0.06, 0.58], [0.89, 0.05, 0.36], [0.93, 0.07, 0.66]]
	for sp in specs:
		var x: float = s.x * float(sp[0])
		var w: float = s.x * float(sp[1])
		var h: float = s.y * float(sp[2])
		draw_rect(Rect2(x, s.y - h, w, h), base)
		draw_rect(Rect2(x + w - 3.0, s.y - h, 3.0, h), Color(0.9, 0.4, 0.25, 0.55))
		# 창문
		for wy in range(int(h / 26.0)):
			for wx in range(int(w / 20.0)):
				var hash_v: int = (wx * 73 + wy * 151 + int(x)) % 11
				if hash_v < 2:
					draw_rect(Rect2(x + 6.0 + wx * 20.0, s.y - h + 8.0 + wy * 26.0, 7.0, 10.0),
						Color(1.0, 0.75, 0.4, 0.75))
	# 가로등
	for lx in [0.03, 0.97]:
		var p := Vector2(s.x * lx, s.y * 0.43)
		draw_line(p, p + Vector2(32.0 if lx < 0.5 else -32.0, -6.0), Color(0.35, 0.38, 0.5), 3.0)
		draw_circle(p + Vector2(34.0 if lx < 0.5 else -34.0, -4.0), 5.0, Color(1.0, 0.7, 0.35))
