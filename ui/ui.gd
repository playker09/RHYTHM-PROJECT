class_name Ui
## UI 공통 스타일 (레퍼런스 인게임의 청록/네이비 패널 느낌).

const CYAN := Color(0.35, 0.95, 0.85)
const NAVY := Color(0.03, 0.07, 0.12, 0.86)

static func panel_style(border: Color = Color(0.35, 0.95, 0.85, 0.7)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = NAVY
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.border_width_left = 6
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 22.0
	return sb
