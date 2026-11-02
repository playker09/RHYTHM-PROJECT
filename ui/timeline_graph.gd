class_name TimelineGraph
extends Control
## 곡 전체를 가로축으로 하는 그래프. 기본은 막대(노트 밀도), silhouette 이면 이어진 면(파형).
## 선택이 바뀌면 높이가 부드럽게 바뀐다.

const SILHOUETTE_DONE := Color(0.82, 0.84, 0.9)
const SILHOUETTE_REST := Color(0.5, 0.51, 0.57)

var silhouette: bool = false
var color_a: Color = Ui.VIOLET
var color_b: Color = Ui.MAGENTA
var playhead: float = -1.0     # 0~1, 음수면 숨김
var _target := PackedFloat32Array()
var _shown := PackedFloat32Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_data(values: PackedFloat32Array) -> void:
	_target = values
	if _shown.size() != values.size():
		_shown = PackedFloat32Array()
		_shown.resize(values.size())

func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-delta * 12.0)
	for i in _shown.size():
		_shown[i] = lerpf(_shown[i], _target[i], k)
	queue_redraw()

func _draw() -> void:
	var n: int = _shown.size()
	if n == 0:
		return
	if silhouette:
		_draw_silhouette(n)
	else:
		_draw_bars(n)
	if playhead >= 0.0:
		draw_rect(Rect2(playhead * size.x, 0.0, 1.5, size.y), Ui.TEXT)

func _draw_bars(n: int) -> void:
	var w: float = size.x / n
	for i in n:
		var u: float = float(i) / maxf(n - 1, 1)
		var col: Color = color_a.lerp(color_b, u)
		var passed: bool = playhead >= 0.0 and u <= playhead
		col.a = 1.0 if passed or playhead < 0.0 else 0.55
		var h: float = maxf(_shown[i] * size.y, 2.0)
		draw_rect(Rect2(i * w + 0.5, size.y - h, maxf(w - 1.5, 1.0), h), col)

## 바닥에서 올라오는 빈틈없는 면 + 위쪽 밝은 테두리
func _draw_silhouette(n: int) -> void:
	var w: float = size.x / n
	for i in n:
		var u: float = float(i) / maxf(n - 1, 1)
		var passed: bool = playhead < 0.0 or u <= playhead
		var col: Color = SILHOUETTE_DONE if passed else SILHOUETTE_REST
		var h: float = maxf(_shown[i] * size.y, 1.0)
		var r := Rect2(i * w, size.y - h, w + 0.5, h)
		draw_rect(r, Color(col, 0.55))
		draw_rect(Rect2(r.position, Vector2(r.size.x, minf(1.5, h))), col)
