class_name Ui
extends RefCounted
## 디자인 시스템: 색, 폰트, 공통 위젯. 화면 스크립트는 여기 값만 쓴다.
## 제목/숫자 = Bahnschrift(윈도우 기본 폰트, 없으면 Noto), 본문/한글 = Noto Sans KR(동봉, OFL).

const INK := Color("08070f")
const INK_SOFT := Color("120f1f")
const PANEL := Color(0.075, 0.065, 0.13, 0.72)
const LINE := Color(1.0, 1.0, 1.0, 0.13)
const TEXT := Color(0.97, 0.97, 1.0)
const TEXT_2 := Color(0.97, 0.97, 1.0, 0.64)
const TEXT_3 := Color(0.97, 0.97, 1.0, 0.38)
const VIOLET := Color("8f7bff")
const MAGENTA := Color("ff4f9e")
const CYAN := Color("62f2e6")
const GOLD := Color("ffe08a")
const RED := Color("ff5a66")
const SLANT := 0.28

const GRADE_COLORS := [GOLD, CYAN, RED]
const RANK_COLORS := {
	"AP": GOLD, "S": GOLD, "A": CYAN, "B": VIOLET, "C": Color("c89bff"), "D": Color("9a97ad")}

const NOTO_PATH := "res://assets/fonts/NotoSansKR-VF.ttf"
const DIN_PATH := "C:/Windows/Fonts/bahnschrift.ttf"

const BACKDROP_SHADER := preload("res://ui/shaders/backdrop.gdshader")
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

# --- 위젯 ---
static func panel_style(fill: Color = PANEL, border: Color = LINE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(18.0)
	sb.anti_aliasing = true
	return sb

## 뒤 화면을 흐리고 어둡게 하는 전체 화면 막
static func backdrop(lod: float = 3.0, tint: Color = Color(0.03, 0.025, 0.06, 0.72)) -> ColorRect:
	var r := ColorRect.new()
	var m := ShaderMaterial.new()
	m.shader = BACKDROP_SHADER
	m.set_shader_parameter("lod", lod)
	m.set_shader_parameter("tint", tint)
	r.material = m
	place(r, 0.0, 0.0, 1.0, 1.0)
	return r

## 기울어진 작은 칩 (난이도, NEW RECORD 등)
static func chip(text: String, color: Color, filled: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color if filled else Color(color.r, color.g, color.b, 0.0)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.skew = Vector2(SLANT, 0.0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 3.0
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(d(text, 14, INK if filled else color, 700, 1))
	return p

## 값 + 설명 묶음 (BPM 120 같은 수치)
static func stat(caption: String, value: String, value_size: int = 26) -> Dictionary:
	var v := vbox(0)
	var val := d(value, value_size, TEXT, 600)
	v.add_child(val)
	v.add_child(t(caption, 12, TEXT_3, 500, 1))
	return {"root": v, "value": val}

## 키캡 + 설명 묶음. pairs = [["Enter", "시작"], ...]
static func hints(pairs: Array) -> HBoxContainer:
	var row := hbox(24)
	for p in pairs:
		var one := hbox(8)
		var cap := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.06)
		sb.border_color = Color(1, 1, 1, 0.26)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		sb.content_margin_top = 0.0
		sb.content_margin_bottom = 1.0
		cap.add_theme_stylebox_override("panel", sb)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cap.add_child(t(String(p[0]), 13, TEXT, 500))
		one.add_child(cap)
		var cap_text := t(String(p[1]), 14, TEXT_2)
		one.add_child(cap_text)
		row.add_child(one)
	return row

## 기울어진 버튼
static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(190.0, 50.0)
	b.add_theme_font_override("font", font(true, 600, 1))
	b.add_theme_font_size_override("font_size", 19)
	var fg: Color = INK if primary else TEXT
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_stylebox_override("normal", _btn_style(TEXT if primary else Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.3)))
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

static func fmt_time(ms: float) -> String:
	var sec: int = roundi(ms / 1000.0)
	return "%d:%02d" % [sec / 60, sec % 60]

## 1234567 -> 1,234,567
static func fmt_int(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
