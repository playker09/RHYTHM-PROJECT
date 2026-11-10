class_name GlassPanel
extends Control
## 유리 패널: 뒤를 흐린 바탕 + 헤어라인 테두리 + 왼쪽 위 강조 모서리. 내용은 content 에 넣는다.

var accent: Color = Ui.VIOLET:
	set(v):
		accent = v
		queue_redraw()
var content: MarginContainer

func _init(margin: float = 20.0, tint: Color = Ui.GLASS, lod: float = 3.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Ui.backdrop(lod, tint))
	content = MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, int(margin))
	Ui.place(content, 0.0, 0.0, 1.0, 1.0)
	add_child(content)
	resized.connect(queue_redraw)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Ui.LINE, false, 1.0)
	# 위쪽 하이라이트
	draw_line(Vector2(1.0, 1.0), Vector2(size.x - 1.0, 1.0), Color(1, 1, 1, 0.1), 1.0)
	# 강조 모서리
	draw_rect(Rect2(0.0, 0.0, 3.0, 26.0), accent)
	draw_rect(Rect2(0.0, 0.0, 26.0, 3.0), accent)
