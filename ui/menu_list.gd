class_name MenuList
extends Control
## 세로 메뉴. 선택 항목은 왼쪽 끝에서 뻗어 나온 흰 사선 슬랩 위에 올라간다.
## 키 입력은 소유자가 handle_key 로 넘겨 준다.

signal activated(id: String)
signal highlighted(id: String)

const TEXT_X := 72.0

var _items: Array = []
var _row_h: float = 80.0
var _index: int = 0
var _rows: Array[Dictionary] = []
var _slab_y: float = 0.0
var _slab_w: float = 0.0
var _flash: float = 0.0

func setup(items: Array, font_size: int = 52, row_h: float = 80.0) -> void:
	_items = items
	_row_h = row_h
	custom_minimum_size.y = row_h * items.size()
	for i in items.size():
		var it: Dictionary = items[i]
		var row := Control.new()
		row.position = Vector2(0.0, i * row_h)
		row.size = Vector2(2000.0, row_h)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		var name_l := Ui.d(String(it["name"]), font_size, Ui.TEXT, 600, 1, true)
		name_l.position = Vector2(TEXT_X, (row_h - font_size * 1.3) * 0.5)
		row.add_child(name_l)
		var sub := Ui.t(String(it.get("sub", "")), 14, Ui.TEXT_2, 500)
		row.add_child(sub)
		_rows.append({"name": name_l, "sub": sub})
	_index = 0
	_refresh()
	_slab_y = 0.0
	_slab_w = _target_w()

func _ready() -> void:
	# 라벨 크기가 정해진 뒤 슬랩 폭을 다시 계산한다
	await get_tree().process_frame
	_refresh()
	_slab_w = _target_w()

func current_id() -> String:
	return String(_items[_index]["id"])

func select(i: int, with_sound: bool = true) -> void:
	if i == _index:
		return
	_index = i
	_refresh()
	if with_sound:
		App.sfx("move")
	highlighted.emit(current_id())

func activate() -> void:
	_flash = 1.0
	activated.emit(current_id())

## 처리했으면 true
func handle_key(event: InputEventKey) -> bool:
	match event.physical_keycode:
		KEY_UP:
			select(posmod(_index - 1, _items.size()))
		KEY_DOWN:
			select(posmod(_index + 1, _items.size()))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			activate()
		_:
			return false
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i: int = _row_at((event as InputEventMouseMotion).position.y)
		if i >= 0:
			select(i)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var i: int = _row_at(mb.position.y)
			if i >= 0:
				select(i, false)
				activate()

func _row_at(y: float) -> int:
	var i: int = floori(y / _row_h)
	return i if i >= 0 and i < _items.size() else -1

func _refresh() -> void:
	for i in _rows.size():
		var sel: bool = i == _index
		var n: Label = _rows[i]["name"]
		var s: Label = _rows[i]["sub"]
		Ui.set_color(n, Ui.INK if sel else Ui.TEXT_2)
		s.visible = sel
		Ui.set_color(s, Color(Ui.INK, 0.62))
		s.position = Vector2(TEXT_X + n.size.x + 18.0, (_row_h - s.size.y) * 0.5 + 6.0)

func _target_w() -> float:
	var r: Dictionary = _rows[_index]
	var n: Label = r["name"]
	var s: Label = r["sub"]
	var w: float = TEXT_X + n.size.x + 44.0
	if s.text != "":
		w += s.size.x + 18.0
	return w

func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-delta * 20.0)
	_slab_y = lerpf(_slab_y, _index * _row_h, k)
	_slab_w = lerpf(_slab_w, _target_w(), k)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()

func _draw() -> void:
	var y0: float = _slab_y + 6.0
	var y1: float = _slab_y + _row_h - 6.0
	var skew: float = (y1 - y0) * Ui.SLANT
	var c: Color = Ui.TEXT.lerp(Ui.CYAN, _flash)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, y0), Vector2(_slab_w + skew, y0), Vector2(_slab_w, y1), Vector2(0.0, y1)]), c)
	# 슬랩 꼬리 (보라 -> 자홍)
	var x0: float = _slab_w + skew + 8.0
	draw_polygon(PackedVector2Array([
		Vector2(x0, y0), Vector2(x0 + 14.0, y0), Vector2(x0 + 14.0 - skew, y1), Vector2(x0 - skew, y1)]),
		PackedColorArray([Ui.VIOLET, Ui.VIOLET, Ui.MAGENTA, Ui.MAGENTA]))
	x0 += 22.0
	draw_polygon(PackedVector2Array([
		Vector2(x0, y0), Vector2(x0 + 5.0, y0), Vector2(x0 + 5.0 - skew, y1), Vector2(x0 - skew, y1)]),
		PackedColorArray([Ui.VIOLET, Ui.VIOLET, Ui.MAGENTA, Ui.MAGENTA]))
