class_name Ui
extends RefCounted
## 디자인 시스템: 색, 폰트, 공통 위젯, 등장 애니메이션. 화면 스크립트는 여기 값만 쓴다.
## 제목/숫자 = Bahnschrift(윈도우 기본 폰트, 없으면 Noto), 본문/한글 = Noto Sans KR(동봉, OFL).

const INK := Color("07060d")
const INK_SOFT := Color("110e1e")
const GLASS := Color(0.035, 0.03, 0.075, 0.62)
const LINE := Color(1.0, 1.0, 1.0, 0.14)
const LINE_SOFT := Color(1.0, 1.0, 1.0, 0.07)
const TEXT := Color(0.97, 0.97, 1.0)
const TEXT_2 := Color(0.97, 0.97, 1.0, 0.66)
const TEXT_3 := Color(0.97, 0.97, 1.0, 0.4)
const VIOLET := Color("8f7bff")
const MAGENTA := Color("ff4f9e")
const CYAN := Color("62f2e6")
const GOLD := Color("ffdd8a")
const RED := Color("ff5a66")
const SLANT := 0.28

const GRADE_COLORS: Array[Color] = [GOLD, CYAN, RED]
const RANK_COLORS := {
	"AP": GOLD, "S": GOLD, "A": CYAN, "B": VIOLET, "C": Color("c89bff"), "D": Color("9a97ad")}
## 난이도 슬롯(ChartLoader.DIFFS) 순서: EZ 청록 / NM 보라 / HD 자홍
const DIFF_COLORS: Array[Color] = [CYAN, VIOLET, MAGENTA]
const DIFF_LONG: Array[String] = ["EASY", "NORMAL", "HARD"]

const NOTO_PATH := "res://assets/fonts/NotoSansKR-VF.ttf"
const DIN_PATH := "C:/Windows/Fonts/bahnschrift.ttf"

const GLASS_SHADER := preload("res://ui/shaders/glass.gdshader")
const GRADIENT_SHADER := preload("res://ui/shaders/text_gradient.gdshader")

static var _noto: Font
static var _din: Font
static var _din_checked: bool = false
static var _cache: Dictionary = {}

# --- 폰트 ---
static func font(display: bool, weight: int = 500, spacing: int = 0, condensed: bool = false) -> Font:
	var key := "%s/%d/%d/%s" % [display, weight, spacing, condensed]
	if _cache.has(key):
		return _cache[key]
	var ts := TextServerManager.get_primary_interface()
	var wght: int = ts.name_to_tag("wght")
	var noto := FontVariation.new()
	noto.base_font = _noto_file()
	noto.variation_opentype = {wght: float(weight)}
	var fv := FontVariation.new()
	var din: Font = _din_file() if display else null
	if din != null:
		fv.base_font = din
		fv.variation_opentype = {
			wght: float(clampi(weight, 300, 700)),
			ts.name_to_tag("wdth"): 75.0 if condensed else 100.0,
		}
		fv.fallbacks = [noto]
	else:
		fv.base_font = _noto_file()
		fv.variation_opentype = {wght: float(weight)}
	fv.spacing_glyph = spacing
	_cache[key] = fv
	return fv

static func _noto_file() -> Font:
	if _noto == null:
		_noto = load(NOTO_PATH)
	return _noto

static func _din_file() -> Font:
	if not _din_checked:
		_din_checked = true
		if FileAccess.file_exists(DIN_PATH):
			var f := FontFile.new()
			if f.load_dynamic_font(DIN_PATH) == OK:
				_din = f
	return _din

# --- 텍스트 ---
## 본문 라벨 (한글)
static func t(text: String, size: int, color: Color = TEXT, weight: int = 400, spacing: int = 0) -> Label:
	return _label(text, size, color, font(false, weight, spacing))

## 제목/숫자 라벨
static func d(text: String, size: int, color: Color = TEXT, weight: int = 600, spacing: int = 0, condensed: bool = false) -> Label:
	return _label(text, size, color, font(true, weight, spacing, condensed))

## 자간 넓은 작은 대문자 캡션 (SCORE, BPM 등)
static func caption(text: String, color: Color = TEXT_3, size: int = 12) -> Label:
	return _label(text, size, color, font(true, 600, 3))

static func _label(text: String, size: int, color: Color, f: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## 라벨에 세로 그라데이션을 입힌다. span = 글자 높이(px).
static func gradient(l: CanvasItem, top: Color, bottom: Color, span: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = GRADIENT_SHADER
	m.set_shader_parameter("top", top)
	m.set_shader_parameter("bottom", bottom)
	m.set_shader_parameter("span", span)
	l.material = m

static func set_color(l: Label, c: Color) -> void:
	l.add_theme_color_override("font_color", c)

## 글자 뒤에 번지는 빛 (윤곽선을 반투명 색으로)
static func glow(l: Label, color: Color, size: int = 14, strength: float = 0.22) -> void:
	l.add_theme_color_override("font_outline_color", Color(color.r, color.g, color.b, strength))
	l.add_theme_constant_override("outline_size", size)

## 어두운 그림자 (3D 위에서 글자가 묻히지 않게)
static func shadow(l: Label, alpha: float = 0.6, size: int = 8) -> void:
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.06, alpha))
	l.add_theme_constant_override("outline_size", size)

# --- 레이아웃 ---
## 앵커(0~1)와 오프셋(px)을 한 번에 지정한다.
static func place(c: Control, al: float, at: float, ar: float, ab: float, ol: float = 0.0, ot: float = 0.0, orr: float = 0.0, ob: float = 0.0) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob

static func hbox(sep: int = 0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func vbox(sep: int = 0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func expander() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(h, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## 가로 헤어라인
static func rule(color: Color = LINE) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0.0, 1.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# --- 등장 애니메이션 ---
## 투명 -> 불투명. 컨테이너 안의 자식에도 안전하다.
static func reveal(c: CanvasItem, delay: float = 0.0, duration: float = 0.35) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 옆에서 미끄러져 들어오며 나타난다. 앵커/오프셋으로 직접 배치한 컨트롤에만 쓴다.
static func slide_in(c: Control, dx: float, delay: float = 0.0, duration: float = 0.5) -> void:
	var l: float = c.offset_left
	var r: float = c.offset_right
	c.offset_left = l + dx
	c.offset_right = r + dx
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "offset_left", l, duration).set_delay(delay)
	tw.tween_property(c, "offset_right", r, duration).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, duration * 0.7).set_delay(delay)

# --- 위젯 ---
## 뒤 화면을 흐리고 어둡게 하는 막 (전체 화면 또는 패널 바탕)
static func backdrop(lod: float = 3.0, tint: Color = Color(0.03, 0.025, 0.06, 0.72)) -> ColorRect:
	var r := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = GLASS_SHADER
	m.set_shader_parameter("lod", lod)
	m.set_shader_parameter("tint", tint)
	r.material = m
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(r, 0.0, 0.0, 1.0, 1.0)
	return r

## 기울어진 작은 칩 (난이도, NEW RECORD 등)
static func chip(text: String, color: Color, filled: bool = true, size: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color if filled else Color(color.r, color.g, color.b, 0.12)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.skew = Vector2(SLANT, 0.0)
	sb.content_margin_left = size
	sb.content_margin_right = size
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 3.0
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(d(text, size, INK if filled else color, 700, 1))
	return p

## 난이도 칩: "HD 12"
static func diff_chip(slot: int, level: int, filled: bool = true, size: int = 14) -> PanelContainer:
	var name: String = ChartLoader.DIFFS[slot] if slot >= 0 else "?"
	var col: Color = DIFF_COLORS[slot] if slot >= 0 else TEXT
	return chip("%s  %d" % [name, level] if level > 0 else name, col, filled, size)

## 값 + 설명 묶음 (BPM 120 같은 수치). 캡션이 위.
static func stat(cap: String, value: String, value_size: int = 26, color: Color = TEXT) -> Dictionary:
	var v := vbox(-2)
	v.add_child(caption(cap))
	var val := d(value, value_size, color, 600)
	v.add_child(val)
	return {"root": v, "value": val}

## 키캡 + 설명 묶음. pairs = [["Enter", "시작"], ...]
static func hints(pairs: Array) -> HBoxContainer:
	var row := hbox(22)
	for p in pairs:
		var one := hbox(8)
		# "1 2"처럼 띄어 쓴 키는 키캡을 따로 그린다
		var caps := hbox(4)
		for key in String(p[0]).split(" ", false):
			var cap := PanelContainer.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 1, 1, 0.07)
			sb.border_color = Color(1, 1, 1, 0.3)
			sb.set_border_width_all(1)
			sb.border_width_bottom = 2
			sb.set_corner_radius_all(4)
			sb.content_margin_left = 8.0
			sb.content_margin_right = 8.0
			sb.content_margin_top = 0.0
			sb.content_margin_bottom = 1.0
			cap.add_theme_stylebox_override("panel", sb)
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cap.add_child(d(key, 13, TEXT, 600))
			caps.add_child(cap)
		one.add_child(caps)
		var cap_text := t(String(p[1]), 13, TEXT_2)
		one.add_child(cap_text)
		row.add_child(one)
	return row

## 기울어진 버튼
static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(190.0, 48.0)
	b.add_theme_font_override("font", font(false, 600, 1))
	b.add_theme_font_size_override("font_size", 17)
	var fg: Color = INK if primary else TEXT
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_stylebox_override("normal", _btn_style(TEXT if primary else Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.34)))
	b.add_theme_stylebox_override("hover", _btn_style(CYAN if primary else TEXT, TEXT))
	b.add_theme_stylebox_override("pressed", _btn_style(MAGENTA, MAGENTA))
	b.mouse_entered.connect(func(): App.sfx("move"))
	return b

static func _btn_style(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.skew = Vector2(SLANT, 0.0)
	sb.anti_aliasing = true
	return sb

## 사선 슬랩(평행사변형)을 그린다. 선택 표시의 공통 모양: 흰 면 + 보라→자홍 꼬리 두 줄.
static func draw_slab(ci: CanvasItem, x0: float, x1: float, y0: float, y1: float, color: Color, tail: bool = true) -> void:
	var skew: float = (y1 - y0) * SLANT
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x0, y0), Vector2(x1 + skew, y0), Vector2(x1, y1), Vector2(x0, y1)]), color)
	if not tail:
		return
	var cols := PackedColorArray([VIOLET, VIOLET, MAGENTA, MAGENTA])
	var tx: float = x1 + skew + 8.0
	ci.draw_polygon(PackedVector2Array([
		Vector2(tx, y0), Vector2(tx + 14.0, y0), Vector2(tx + 14.0 - skew, y1), Vector2(tx - skew, y1)]), cols)
	tx += 22.0
	ci.draw_polygon(PackedVector2Array([
		Vector2(tx, y0), Vector2(tx + 5.0, y0), Vector2(tx + 5.0 - skew, y1), Vector2(tx - skew, y1)]), cols)

static func fmt_time(ms: float) -> String:
	var sec: int = roundi(ms / 1000.0)
	@warning_ignore("integer_division")
	return "%d:%02d" % [sec / 60, sec % 60]

## 1234567 -> 1,234,567
static func fmt_int(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

## 점수를 7자리로 (0012345 의 앞 0 은 흐리게 쓰려고 나눠서 돌려준다): [앞쪽 0, 나머지]
static func fmt_score7(n: int) -> PackedStringArray:
	var s := "%07d" % clampi(n, 0, 9999999)
	var lead: int = 0
	while lead < 6 and s[lead] == "0":
		lead += 1
	return PackedStringArray([s.substr(0, lead), s.substr(lead)])
