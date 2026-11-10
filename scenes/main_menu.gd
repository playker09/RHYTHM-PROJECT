extends Control
## 메인 메뉴. 왼쪽 = 메뉴(사선 슬랩), 오른쪽 아래 = 최근 고른 곡 카드. 뒤는 3D 무대.
## 화면의 숫자(곡 수, 클리어 수, 최고 점수)는 채보/기록에서 읽은 실제 값이다.

var _world: MenuWorld
var _list: MenuList
var _settings: SettingsPanel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	App.bgm_play("menu")
	_world = MenuWorld.new("menu")
	add_child(_world)
	# 왼쪽 글자가 묻히지 않게 옅은 그늘
	var shade := _SideShade.new()
	Ui.place(shade, 0.0, 0.0, 0.62, 1.0)
	add_child(shade)

	var songs: Array = ChartLoader.list_songs()
	_build_header()
	_build_menu()
	_build_card(songs)
	_build_footer(songs)

	_settings = SettingsPanel.new()
	add_child(_settings)

func _build_header() -> void:
	var head := Ui.hbox(14)
	Ui.place(head, 0.0, 0.0, 1.0, 0.0, 72.0, 40.0, -72.0, 70.0)
	add_child(head)
	head.add_child(Ui.d(String(ProjectSettings.get_setting("application/config/name", "")).to_upper(), 15, Ui.TEXT, 600, 7))
	var line := Ui.rule(Ui.LINE)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(line)
	head.add_child(Ui.caption("MAIN MENU", Ui.TEXT_2, 12))
	Ui.reveal(head, 0.1)

func _build_menu() -> void:
	_list = MenuList.new()
	_list.setup([
		{"id": "play", "name": "PLAY", "sub": "곡 선택"},
		{"id": "settings", "name": "SETTINGS", "sub": "설정"},
		{"id": "quit", "name": "QUIT", "sub": "게임 종료"},
	], 62, 92.0)
	Ui.place(_list, 0.0, 0.5, 0.6, 0.5, 0.0, -150.0, 0.0, 126.0)
	add_child(_list)
	_list.activated.connect(_on_activated)
	Ui.slide_in(_list, -80.0, 0.12)

## 최근 고른 곡 카드
func _build_card(songs: Array) -> void:
	var song: Dictionary = {}
	for s: Dictionary in songs:
		if App.selected_chart.begins_with(String(s["dir"]) + "/"):
			song = s
	if song.is_empty() and not songs.is_empty():
		song = songs[0]
	if song.is_empty():
		return
	var slot: int = ChartLoader.nearest_diff(song["diffs"], App.selected_diff)
	var diff: Dictionary = song["diffs"][slot]
	var rec: Dictionary = App.get_record(String(diff["path"]))

	var panel := GlassPanel.new(18.0)
	panel.accent = Ui.DIFF_COLORS[slot]
	Ui.place(panel, 1.0, 1.0, 1.0, 1.0, -492.0, -246.0, -72.0, -92.0)
	add_child(panel)
	var row := Ui.hbox(18)
	panel.content.add_child(row)
	var jacket := Jacket.new()
	jacket.custom_minimum_size = Vector2(118.0, 118.0)
	jacket.set_song(String(song["title"]), String(song["jacket"]))
	row.add_child(jacket)
	var v := Ui.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(Ui.caption("LAST SELECTED", Ui.VIOLET, 11))
	var title := Ui.d(String(song["title"]), 24, Ui.TEXT, 600)
	title.clip_text = true
	v.add_child(title)
	var artist := Ui.t(String(song["artist"]), 13, Ui.TEXT_2)
	artist.clip_text = true
	v.add_child(artist)
	v.add_child(Ui.expander())
	var bottom := Ui.hbox(12)
	v.add_child(bottom)
	bottom.add_child(Ui.diff_chip(slot, int(diff["level"]), true, 12))
	bottom.add_child(Ui.expander())
	if rec.is_empty():
		bottom.add_child(Ui.t("기록 없음", 14, Ui.TEXT_3))
	else:
		var rank := Ui.d(String(rec["rank"]), 26, Ui.RANK_COLORS.get(String(rec["rank"]), Ui.TEXT), 700, 0, true)
		bottom.add_child(rank)
		bottom.add_child(Ui.d(Ui.fmt_int(int(rec["score"])), 22, Ui.TEXT, 600, 1, true))
	Ui.slide_in(panel, 60.0, 0.3)

func _build_footer(songs: Array) -> void:
	var foot := Ui.hbox(0)
	Ui.place(foot, 0.0, 1.0, 1.0, 1.0, 72.0, -62.0, -72.0, -30.0)
	add_child(foot)
	foot.add_child(Ui.hints([["↑↓", "선택"], ["Enter", "확인"], ["Esc", "타이틀"], ["F11", "전체 화면"]]))
	foot.add_child(Ui.expander())
	# 곡/채보/클리어 수 (실제 값)
	var charts: int = 0
	var cleared: int = 0
	for s: Dictionary in songs:
		for d: Dictionary in s["diffs"]:
			if d.is_empty():
				continue
			charts += 1
			if not App.get_record(String(d["path"])).is_empty():
				cleared += 1
	var info := Ui.caption("SONGS %d    CHARTS %d    PLAYED %d" % [songs.size(), charts, cleared], Ui.TEXT_3, 11)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(info)
	Ui.reveal(foot, 0.4)

func _input(event: InputEvent) -> void:
	if _settings.is_open() or App.is_busy():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			App.sfx("back")
			App.goto(App.TITLE_SCENE)
		elif k.physical_keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			_settings.open()
		elif _list.handle_key(k):
			get_viewport().set_input_as_handled()

func _on_activated(id: String) -> void:
	match id:
		"play":
			App.sfx("confirm")
			App.goto(App.SELECT_SCENE)
		"settings":
			_settings.open()
		"quit":
			App.sfx("back")
			get_tree().quit()

## 왼쪽에서 오른쪽으로 사라지는 그늘
class _SideShade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var strong := Color(0.02, 0.015, 0.05, 0.72)
		var clear := Color(0.02, 0.015, 0.05, 0.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
			PackedColorArray([strong, clear, clear, strong]))
