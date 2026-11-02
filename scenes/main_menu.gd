extends Control
## 메인 메뉴. 왼쪽에 큰 목록, 오른쪽에 선택 항목의 실제 정보(최근 곡/현재 설정).

const ITEMS := [
	{"id": "play", "name": "PLAY", "sub": "곡 선택"},
	{"id": "option", "name": "SETTINGS", "sub": "설정"},
	{"id": "quit", "name": "QUIT", "sub": "종료"},
]

var _list: MenuList
var _preview: Control
var _settings: SettingsPanel
var _charts: Array = []
var _busy: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_charts = ChartLoader.list_charts()
	add_child(AmbientBg.new())

	var brand := Ui.d("RHYTHM PROJECT", 15, Ui.TEXT_2, 600, 5)
	Ui.place(brand, 0.0, 0.0, 0.0, 0.0, 72.0, 44.0, 500.0, 70.0)
	add_child(brand)

	_list = MenuList.new()
	_list.setup(ITEMS, 64, 96.0)
	Ui.place(_list, 0.0, 0.5, 0.56, 0.5, 0.0, -144.0, 0.0, 144.0)
	add_child(_list)
	_list.highlighted.connect(_show_preview)
	_list.activated.connect(_activate)

	_preview = Control.new()
	Ui.place(_preview, 0.56, 0.5, 1.0, 0.5, 0.0, -190.0, -72.0, 190.0)
	add_child(_preview)

	var foot := Ui.hints([["↑↓", "선택"], ["Enter", "확인"], ["Esc", "타이틀"], ["F11", "전체 화면"]])
	Ui.place(foot, 0.0, 1.0, 1.0, 1.0, 72.0, -56.0, 0.0, -24.0)
	add_child(foot)

	_settings = SettingsPanel.new()
	add_child(_settings)
	_settings.changed.connect(_refresh_settings_preview)
	_show_preview("play")

func _input(event: InputEvent) -> void:
	if _busy or _settings.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE:
			_busy = true
			App.sfx("back")
			App.goto(App.TITLE_SCENE)
		elif not k.alt_pressed:
			_list.handle_key(k)

func _activate(id: String) -> void:
	match id:
		"play":
			_busy = true
			App.sfx("confirm")
			App.goto(App.SELECT_SCENE)
		"option":
			_settings.open()
		"quit":
			get_tree().quit()

func _refresh_settings_preview() -> void:
	if _list.current_id() == "option":
		_show_preview("option")

# --- 오른쪽 정보 ---
func _show_preview(id: String) -> void:
	for c in _preview.get_children():
		_preview.remove_child(c)
		c.queue_free()
	var content: Control
	match id:
		"play":
			content = _play_preview()
		"option":
			content = _settings_preview()
		_:
			content = _quit_preview()
	_preview.add_child(content)
	content.modulate.a = 0.0
	var dx := 24.0
	content.offset_left += dx
	content.offset_right += dx
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(content, "modulate:a", 1.0, 0.2)
	tw.tween_property(content, "offset_left", content.offset_left - dx, 0.26)
	tw.tween_property(content, "offset_right", content.offset_right - dx, 0.26)

func _play_preview() -> Control:
	var v := Ui.vbox(0)
	Ui.place(v, 0.0, 0.0, 1.0, 1.0)
	v.alignment = BoxContainer.ALIGNMENT_END
	if _charts.is_empty():
		v.add_child(Ui.t("charts 폴더에 곡이 없습니다", 18, Ui.TEXT_2))
		return v
	var c: Dictionary = _charts[0]
	for ch in _charts:
		if String(ch["path"]) == App.selected_chart:
			c = ch
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var row := Ui.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var info := Ui.vbox(4)
	info.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(info)
	var head := Ui.t("최근 선택한 곡" if App.selected_chart == String(c["path"]) else "곡", 13, Ui.VIOLET, 700, 1)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(head)
	var title := Ui.d(String(c["title"]), 30, Ui.TEXT, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(title)
	var artist := Ui.t(String(c["artist"]), 15, Ui.TEXT_2)
	artist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(artist)
	info.add_child(Ui.gap(10.0))
	var rec: Dictionary = App.get_record(String(c["path"]))
	var best := Ui.d(Ui.fmt_int(int(rec["score"])) if not rec.is_empty() else "기록 없음", 22, Ui.TEXT if not rec.is_empty() else Ui.TEXT_3, 600)
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(best)
	var cap := Ui.t("최고 점수", 12, Ui.TEXT_3, 500, 1)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(cap)
	var jacket := Jacket.new()
	jacket.custom_minimum_size = Vector2(240.0, 240.0)
	jacket.set_song(String(c["title"]))
	row.add_child(jacket)
	var count := Ui.t("곡 %d개" % _charts.size(), 13, Ui.TEXT_3, 500)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(Ui.gap(12.0))
	v.add_child(count)
	return v

func _settings_preview() -> Control:
	var v := Ui.vbox(10)
	Ui.place(v, 0.0, 0.0, 1.0, 1.0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := Ui.t("현재 설정", 13, Ui.VIOLET, 700, 1)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(head)
	var pairs := [
		["배속", "%.1f" % Settings.hispeed],
		["싱크 오프셋", "%+.0f ms" % Settings.offset_ms],
		["마우스 감도", "%.2f" % Settings.sensitivity],
		["음량", "%d%%" % roundi(Settings.volume * 100.0)],
		["전체 화면", "켜짐" if Settings.fullscreen else "꺼짐"],
	]
	for p in pairs:
		var r := Ui.hbox(0)
		r.alignment = BoxContainer.ALIGNMENT_END
		var name_l := Ui.t(String(p[0]), 16, Ui.TEXT_2)
		r.add_child(name_l)
		var val := Ui.d(String(p[1]), 24, Ui.TEXT, 600)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.custom_minimum_size = Vector2(130.0, 0.0)
		r.add_child(val)
		v.add_child(r)
	return v

func _quit_preview() -> Control:
	var v := Ui.vbox(6)
	Ui.place(v, 0.0, 0.0, 1.0, 1.0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Ui.t("게임을 종료합니다", 18, Ui.TEXT_2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(l)
	return v
