class_name Hud
extends CanvasLayer
## 플레이 HUD: 진행 선, 점수/정확도, 곡 정보, 판정 수, 콤보, 판정 글자, 타이밍 오차 막대, 카운트다운.
## 패널 없이 3D 위에 글자만 올린다. 보이는 숫자는 전부 ScoreManager/채보의 실제 값이다.

signal result_action(action: String)    # "retry" | "quit"

const COMBO_SIZE := Vector2(360.0, 150.0)
const JUDGE_SIZE := Vector2(520.0, 96.0)
const JUDGE_FONT_SIZE := 40
const JUDGE_WEIGHT := 600
const JUDGE_SPACING := 4
const JUDGE_GLOW_LAYERS := 7         # 번지는 빛을 만드는 겹 수 (테두리 30px -> 6px)
const JUDGE_GLOW_ALPHA := 0.055      # 한 겹의 세기. 글자 가까이일수록 여러 겹이 겹쳐 진해진다
## 판정 글자 색 [글자, 테두리] (In Falsus 식: 채도 낮은 옅은 글자 + 같은 계열의 진한 테두리).
## PERFECT 분홍/자주 · GREAT 회청/파랑 · MISS 살구/빨강
const JUDGE_NEON: Array = [
	[Color("e6b4ea"), Color("a544c4")],
	[Color("a9bfe2"), Color("5474c6")],
	[Color("f2a394"), Color("d8382c")],
]
const COUNT_SIZE := Vector2(400.0, 240.0)
const BANNER_FONT_SIZE := 40
const GUIDE_HILITE := Color("ffd64a")    # 안내 문구에서 [대괄호]로 감싼 부분의 색
const SKY_ALERT_Y := 0.56             # 스카이 알림 패널의 세로 위치 (화면 높이 비율)
const GUIDE_Y := 0.695               # 안내 문구(튜토리얼)의 세로 위치 (화면 높이 비율). 공중 판정선과 바닥 판정선 사이

var _root: Control
var _score_lead: Label
var _score: Label
var _rate: Label
var _counts: Array[Label] = []
var _combo_box: Control
var _combo: Label
var _judge_box: Control
var _judge: Label
var _judge_sub: Label
var _speed: Label
var _progress: _ProgressLine
var _time: Label
var _jacket: Jacket
var _title: Label
var _artist: Label
var _chip_slot: HBoxContainer
var _intro: Control
var _count_box: Control
var _count: Label
var _count_ring: _CountRing
var _meter: _ErrorMeter
var _banner: Control
var _result: ResultScreen
var _song: Dictionary = {}
var _judge_time: float = 0.0
var _speed_flash: float = 0.0
var _combo_punch: float = 0.0
var _judge_punch: float = 0.0
var _shown_score: float = 0.0
var _count_shown: int = -1
var _score_mgr: ScoreManager
var _sky: Array[_SkyAlert] = []     # 스카이 알림 패널 [왼쪽, 오른쪽]
var _guide_box: Control
var _guide: HBoxContainer
var _guide_text: String = ""
var _guide_tween: Tween

var _judge_edge: Label              # 글자 둘레의 가는 색 선
var _judge_glow: Array[Label] = []  # 뒤에서 번지는 빛 (겹쳐서 부드럽게)
var _judge_fill: ShaderMaterial     # 글자 안쪽 세로 그라데이션

func _ready() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.place(_root, 0.0, 0.0, 1.0, 1.0)
	add_child(_root)
	_progress = _ProgressLine.new()
	Ui.place(_progress, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 4.0)
	_root.add_child(_progress)
	_build_score()
	_build_song()
	_build_counts()
	_build_center()
	_build_intro()
	_build_countdown()
	_build_guide()
	_build_sky_alert()
	_speed = Ui.caption("", Ui.TEXT_3, 13)
	Ui.place(_speed, 0.0, 1.0, 0.0, 1.0, 32.0, -42.0, 300.0, -18.0)
	_root.add_child(_speed)
	set_speed(Settings.hispeed)
	_speed_flash = 0.0

func bind(score_mgr: ScoreManager, judge: Judge) -> void:
	_score_mgr = score_mgr
	score_mgr.changed.connect(_refresh)
	judge.judged.connect(_on_judged)

## song = {title, artist, level, diff(슬롯 번호), jacket(경로)}
func set_song(song: Dictionary) -> void:
	_song = song
	_title.text = String(song["title"])
	_artist.text = String(song["artist"])
	_jacket.set_song(String(song["title"]), String(song.get("jacket", "")))
	var slot: int = int(song.get("diff", -1))
	if slot >= 0:
		_chip_slot.add_child(Ui.diff_chip(slot, int(song.get("level", 0)), false, 13))
	_fill_intro()

## 콤보 숫자를 이 화면 지점(일식 원반 중심)에 놓는다.
func set_combo_anchor(center: Vector2) -> void:
	_combo_box.position = center - COMBO_SIZE * 0.5 + Vector2(0.0, 6.0)

## 판정 글자를 화면의 이 지점(픽셀)을 중심으로 표시한다.
func set_judge_anchor(center: Vector2) -> void:
	_judge_box.position = center - JUDGE_SIZE * 0.5

## 곡 진행도 0~1 과 현재/전체 시각
func set_progress(now_ms: float, end_ms: float) -> void:
	_progress.value = clampf(now_ms / maxf(end_ms, 1.0), 0.0, 1.0)
	_time.text = "%s / %s" % [Ui.fmt_time(clampf(now_ms, 0.0, end_ms)), Ui.fmt_time(end_ms)]

func set_speed(v: float) -> void:
	_speed.text = "SPEED  %.1f" % v
	_speed_flash = 1.0

## 곡 시작 전 카운트다운. now_ms < 0 인 동안 3·2·1, 0 을 지나면 GO 를 잠깐 보여 준다.
func set_countdown(now_ms: float) -> void:
	var n: int = ceili(-now_ms / 1000.0) if now_ms < 0.0 else 0
	if now_ms > 700.0:
		if _count_box.visible:
			_count_box.visible = false
		return
	if n != _count_shown:
		_count_shown = n
		_count_box.visible = true
		_count.text = str(n) if n > 0 else "GO"
		Ui.set_color(_count, Ui.TEXT if n > 0 else Ui.CYAN)
		_count_box.scale = Vector2.ONE * 1.35
		_count_box.modulate.a = 1.0
		App.sfx("count" if n > 0 else "go", 0.45)
		if n == 0:
			var tw := create_tween()
			tw.tween_property(_intro, "modulate:a", 0.0, 0.35)
	_count_ring.value = fposmod(-now_ms, 1000.0) / 1000.0 if n > 0 else 0.0
	if n == 0:
		_count_box.modulate.a = clampf(1.0 - now_ms / 600.0, 0.0, 1.0)

## 스카이 알림: 곧 공중 노트가 나온다. v = AirAlert.sample() = (왼쪽 깜빡임, 왼쪽 떠 있는 정도, 오른쪽 깜빡임, 오른쪽 떠 있는 정도).
## 왼쪽 플릭 = LEFT 패널(파랑), 오른쪽 플릭 = RIGHT 패널(자홍). 한 번 떴다가 노트 시각에 사라진다. 매 프레임 호출.
func set_air_alert(v: Vector4) -> void:
	for i in 2:
		var blink: float = v.x if i == 0 else v.z
		var level: float = v.y if i == 0 else v.w
		_sky[i].visible = level > 0.01
		_sky[i].modulate.a = level
		_sky[i].shine = blink

## 화면 가운데 아래의 안내 문구(튜토리얼). "" 이면 사라진다. 같은 문구를 매 프레임 넘겨도 된다.
func set_guide(text: String) -> void:
	if text == _guide_text:
		return
	_guide_text = text
	if _guide_tween != null and _guide_tween.is_valid():
		_guide_tween.kill()
	_guide_tween = create_tween()
	_guide_tween.tween_property(_guide_box, "modulate:a", 0.0, 0.18)
	if text != "":
		_guide_tween.tween_callback(_fill_guide.bind(text))
		_guide_tween.tween_property(_guide_box, "modulate:a", 1.0, 0.25)

## 문구를 조각 라벨로 나눠 넣는다. [대괄호] 안은 노란색 굵은 글씨(해야 할 동작).
func _fill_guide(text: String) -> void:
	for c in _guide.get_children():
		c.queue_free()
	var parts: PackedStringArray = text.replace("]", "[").split("[")
	for i in parts.size():
		if parts[i] == "":
			continue
		var hot: bool = i % 2 == 1
		_guide.add_child(Ui.t(parts[i], 23, GUIDE_HILITE if hot else Ui.TEXT, 700 if hot else 500))

## 곡이 끝났을 때 잠깐 띄우는 문구 (FULL COMBO 등)
func show_banner(text: String, color: Color) -> void:
	# 어두운 유리 사선 슬랩이 가운데에서 좌우로 천천히 열리고, 그 위에 흰 글자가 떠오른다 (플레이 화면이라 흰 바탕은 쓰지 않는다)
	var slab := _BannerSlab.new()
	_banner = slab
	Ui.place(slab, 0.0, 0.5, 1.0, 0.5, 0.0, -64.0, 0.0, 24.0)
	_root.add_child(slab)
	var font: Font = Ui.face("supreme", 700, 2)
	slab.text_w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, BANNER_FONT_SIZE).x
	slab.accent = color
	var l := Ui.f(text, BANNER_FONT_SIZE, Ui.TEXT, "supreme", 700, 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.place(l, 0.0, 0.0, 1.0, 1.0)
	l.modulate.a = 0.0
	slab.add_child(l)
	slab.modulate.a = 0.0
	l.position.y += 10.0
	var tw := create_tween().set_parallel()
	tw.tween_property(slab, "modulate:a", 1.0, 0.45)
	tw.tween_property(slab, "open", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(slab, "flash", 0.0, 1.1).set_delay(0.5)
	tw.tween_property(l, "modulate:a", 1.0, 0.5).set_delay(0.35)
	tw.tween_property(l, "position:y", l.position.y - 10.0, 0.6).set_delay(0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	App.sfx("clear", 0.5)

func _process(delta: float) -> void:
	if _score_mgr != null:
		_shown_score = lerpf(_shown_score, float(_score_mgr.score), 1.0 - exp(-delta * 18.0))
		var parts: PackedStringArray = Ui.fmt_score7(roundi(_shown_score))
		_score_lead.text = parts[0]
		_score.text = parts[1]
	if _judge_time > 0.0:
		_judge_time -= delta
		_judge_box.modulate.a = clampf(_judge_time / 0.14, 0.0, 1.0)
		_judge_punch = lerpf(_judge_punch, 0.0, 1.0 - exp(-delta * 22.0))
		_judge_box.scale = Vector2.ONE * (1.0 + _judge_punch)
	_combo_punch = lerpf(_combo_punch, 0.0, 1.0 - exp(-delta * 18.0))
	_combo_box.scale = Vector2.ONE * (1.0 + _combo_punch)
	_count_box.scale = _count_box.scale.lerp(Vector2.ONE, 1.0 - exp(-delta * 14.0))
	_speed_flash = maxf(_speed_flash - delta * 0.8, 0.0)
	Ui.set_color(_speed, Ui.TEXT_3.lerp(Ui.CYAN, _speed_flash))

func _refresh() -> void:
	var c: int = _score_mgr.combo
	_rate.text = "%.2f%%" % _score_mgr.accuracy()
	for i in 3:
		_counts[i].text = str(_score_mgr.counts[i])
	if c > 1:
		if _combo.text != str(c):
			_combo_punch = 0.12
		_combo.text = str(c)
		_combo_box.visible = true
	else:
		_combo.text = ""
		_combo_box.visible = false

func _on_judged(_note: NoteData, grade: int, delta_ms: float, is_tick: bool) -> void:
	if not is_tick and grade != JudgeLogic.Grade.MISS:
		_meter.push(delta_ms, Ui.GRADE_COLORS[grade])
	if is_tick and grade != JudgeLogic.Grade.MISS:
		return
	_judge.text = JudgeLogic.grade_name(grade)
	_judge_edge.text = _judge.text
	# 네온 관: 위가 조금 더 밝은 옅은 색 글자 + 가는 색 선 + 뒤에서 부드럽게 번지는 같은 색 빛
	var fill: Color = JUDGE_NEON[grade][0]
	var edge: Color = JUDGE_NEON[grade][1]
	_judge_fill.set_shader_parameter("top", fill.lerp(Color.WHITE, 0.4))
	_judge_fill.set_shader_parameter("bottom", fill)
	_judge_edge.add_theme_color_override("font_outline_color", Color(edge.r, edge.g, edge.b, 0.9))
	for g in _judge_glow:
		g.text = _judge.text
		g.add_theme_color_override("font_outline_color", Color(edge.r, edge.g, edge.b, JUDGE_GLOW_ALPHA))
	_judge_sub.text = ""
	if grade == JudgeLogic.Grade.GREAT:
		_judge_sub.text = "FAST  %d" % roundi(delta_ms) if delta_ms < 0.0 else "SLOW  +%d" % roundi(delta_ms)
		Ui.set_color(_judge_sub, Ui.VIOLET.lerp(Color.WHITE, 0.4) if delta_ms < 0.0 else Ui.MAGENTA.lerp(Color.WHITE, 0.4))
	_judge_time = 0.45
	_judge_punch = 0.2 if not is_tick else 0.0
	_judge_box.modulate.a = 1.0

# --- 결과 화면 ---
func show_result(score_mgr: ScoreManager, new_record: bool = false, best: Dictionary = {}) -> void:
	hide_result()
	create_tween().tween_property(_root, "modulate:a", 0.0, 0.3)
	_result = ResultScreen.new()
	add_child(_result)
	_result.build(score_mgr, _song, new_record, best)
	_result.action.connect(func(id: String): result_action.emit(id))

func hide_result() -> void:
	if _result != null:
		_result.queue_free()
		_result = null

func is_result_open() -> bool:
	return _result != null

# --- 빌더 ---
func _build_score() -> void:
	var shade := _CornerShade.new()
	Ui.place(shade, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 520.0, 150.0)
	_root.add_child(shade)
	var v := Ui.vbox(-6)
	Ui.place(v, 0.0, 0.0, 0.0, 0.0, 32.0, 20.0, 460.0, 130.0)
	_root.add_child(v)
	v.add_child(Ui.caption("SCORE"))
	var row := Ui.hbox(0)
	v.add_child(row)
	_score_lead = Ui.d("000000", 50, Color(1, 1, 1, 0.22), 600, 1, true)
	row.add_child(_score_lead)
	_score = Ui.d("0", 50, Ui.TEXT, 600, 1, true)
	Ui.shadow(_score, 0.5, 6)
	row.add_child(_score)
	var sub := Ui.hbox(10)
	v.add_child(sub)
	_rate = Ui.d("0.00%", 18, Ui.CYAN, 600, 1)
	sub.add_child(_rate)

func _build_song() -> void:
	var shade := _CornerShade.new()
	shade.flip = true
	Ui.place(shade, 1.0, 0.0, 1.0, 0.0, -520.0, 0.0, 0.0, 150.0)
	_root.add_child(shade)
	var h := Ui.hbox(14)
	Ui.place(h, 1.0, 0.0, 1.0, 0.0, -560.0, 24.0, -32.0, 96.0)
	h.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(h)
	var v := Ui.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_title = Ui.d("", 22, Ui.TEXT, 600)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.clip_text = true
	v.add_child(_title)
	_artist = Ui.t("", 13, Ui.TEXT_2)
	_artist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_artist.clip_text = true
	v.add_child(_artist)
	v.add_child(Ui.gap(3.0))
	_chip_slot = Ui.hbox(10)
	_chip_slot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_chip_slot)
	_time = Ui.d("", 13, Ui.TEXT_3, 500, 1)
	_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip_slot.add_child(_time)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3.0)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(frame)
	_jacket = Jacket.new()
	_jacket.custom_minimum_size = Vector2(66.0, 66.0)
	frame.add_child(_jacket)

## 오른쪽 아래: 지금까지의 판정 수
func _build_counts() -> void:
	var v := Ui.vbox(0)
	Ui.place(v, 1.0, 1.0, 1.0, 1.0, -210.0, -98.0, -32.0, -16.0)
	v.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(v)
	for i in 3:
		var row := Ui.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_END
		v.add_child(row)
		row.add_child(Ui.caption(JudgeLogic.grade_name(i), Color(Ui.GRADE_COLORS[i], 0.85), 12))
		var n := Ui.d("0", 17, Ui.TEXT, 600, 1)
		n.custom_minimum_size = Vector2(46.0, 0.0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(n)
		_counts.append(n)
	_meter = _ErrorMeter.new()
	Ui.place(_meter, 0.5, 1.0, 0.5, 1.0, -170.0, -30.0, 170.0, -10.0)
	_root.add_child(_meter)

func _build_center() -> void:
	_combo_box = Control.new()
	_combo_box.size = COMBO_SIZE
	_combo_box.pivot_offset = COMBO_SIZE * 0.5
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.visible = false
	_root.add_child(_combo_box)
	_combo = Ui.f("", 70, Color(1, 1, 1, 0.96), "oxanium", 600)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(_combo, 0.0, 0.0, 1.0, 0.0, 0.0, 8.0, 0.0, 100.0)
	_combo_box.add_child(_combo)
	var cap := Ui.f("COMBO", 12, Color(1, 1, 1, 0.7), "oxanium", 600, 4)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(cap, 0.0, 0.0, 1.0, 0.0, 0.0, 96.0, 0.0, 116.0)
	_combo_box.add_child(cap)

	_judge_box = Control.new()
	_judge_box.size = JUDGE_SIZE
	_judge_box.pivot_offset = JUDGE_SIZE * 0.5
	_judge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_judge_box.modulate.a = 0.0
	_root.add_child(_judge_box)
	# 뒤쪽 빛(글자는 투명, 넓은 옅은 테두리만) -> 그 위에 글자
	# 아래부터: 번지는 빛(테두리 크기를 조금씩 키워 겹친 것, 더하기 합성) -> 가는 색 선 -> 글자
	var layers: Array[Label] = []
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in JUDGE_GLOW_LAYERS:
		var g := Ui.f("", JUDGE_FONT_SIZE, Color(1, 1, 1, 0), "oxanium", JUDGE_WEIGHT, JUDGE_SPACING)
		g.add_theme_constant_override("outline_size", 30 - i * 4)
		g.material = add
		_judge_glow.append(g)
		layers.append(g)
	_judge_edge = Ui.f("", JUDGE_FONT_SIZE, Color(1, 1, 1, 0), "oxanium", JUDGE_WEIGHT, JUDGE_SPACING)
	_judge_edge.add_theme_constant_override("outline_size", 3)
	layers.append(_judge_edge)
	_judge = Ui.f("", JUDGE_FONT_SIZE, Ui.TEXT, "oxanium", JUDGE_WEIGHT, JUDGE_SPACING)
	_judge_fill = ShaderMaterial.new()
	_judge_fill.shader = Ui.GRADIENT_SHADER
	_judge_fill.set_shader_parameter("span", float(JUDGE_FONT_SIZE) * 1.15)
	_judge.material = _judge_fill
	layers.append(_judge)
	for l: Label in layers:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Ui.place(l, 0.0, 0.0, 1.0, 0.0, 0.0, 10.0, 0.0, 64.0)
		_judge_box.add_child(l)
	_judge_sub = Ui.f("", 14, Ui.TEXT_2, "exo", 600, 2)
	_judge_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(_judge_sub, 0.0, 0.0, 1.0, 0.0, 0.0, 62.0, 0.0, 86.0)
	_judge_box.add_child(_judge_sub)

## 곡 시작 전 화면 가운데 위에 보이는 곡 카드
func _build_intro() -> void:
	_intro = Ui.vbox(0)
	Ui.place(_intro, 0.0, 0.5, 1.0, 0.5, 0.0, -262.0, 0.0, -122.0)
	_root.add_child(_intro)

func _fill_intro() -> void:
	# 머리글(양옆 가는 선) / 제목 / 보라→자홍 짧은 선 / 아티스트 / 난이도 칩. 테두리·번짐 없음
	var head := Ui.hbox(12)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	_intro.add_child(head)
	head.add_child(_intro_line(26.0, true))
	head.add_child(Ui.f("NOW PLAYING", 10, Color(1, 1, 1, 0.6), "exo", 600, 5))
	head.add_child(_intro_line(26.0, false))
	_intro.add_child(Ui.gap(2.0))
	var t := Ui.f(String(_song["title"]), 48, Ui.TEXT, "supreme", 700, 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 제목이 일식의 밝은 테두리 위로 나가도 읽히도록, 글자 뒤에 양 끝이 사라지는 어두운 띠를 깐다 (글자 자체는 순백, 효과 없음)
	var band := _GuideBand.new()
	band.strength = 0.6
	band.show_behind_parent = true
	Ui.place(band, 0.5, 0.0, 0.5, 1.0, -380.0, 6.0, 380.0, -4.0)
	t.add_child(band)
	# 위는 흰색, 아래로 갈수록 무대 빛과 같은 연보라 (글자 아랫부분에서만 색이 돈다)
	Ui.gradient(t, Color(1, 1, 1), Color(0.66, 0.56, 1.0), 26.0)
	(t.material as ShaderMaterial).set_shader_parameter("start", 28.0)
	_intro.add_child(t)
	_intro.add_child(Ui.gap(4.0))
	var rule := _intro_line(0.0, false)
	(rule as _IntroLine).accent = true
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_intro.add_child(rule)
	_intro.add_child(Ui.gap(7.0))
	var a := Ui.f(String(_song["artist"]), 14, Color(1, 1, 1, 0.72), "exo", 500, 2)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.add_child(a)
	var slot: int = int(_song.get("diff", -1))
	if slot >= 0:
		_intro.add_child(Ui.gap(9.0))
		var chips := Ui.hbox(0)
		chips.alignment = BoxContainer.ALIGNMENT_CENTER
		_intro.add_child(chips)
		chips.add_child(Ui.diff_chip(slot, int(_song.get("level", 0)), false, 12))
	# 차례로 나타난다: 머리글 -> 제목 -> 선이 가운데에서 자라남 -> 아티스트/난이도
	var order: Array = _intro.get_children()
	for i in order.size():
		if order[i] is CanvasItem and order[i] != rule:
			Ui.reveal(order[i], 0.15 + 0.12 * minf(float(i), 4.0), 0.5)
	var tw := create_tween()
	tw.tween_property(rule, "custom_minimum_size:x", 64.0, 0.7).set_delay(0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _intro_line(w: float, fade_left: bool) -> Control:
	var l := _IntroLine.new()
	l.fade_left = fade_left
	l.custom_minimum_size = Vector2(w, 2.0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

## 곡 소개의 가는 선: 한쪽 끝이 사라지는 흰 선, accent 면 보라→자홍
class _IntroLine extends Control:
	var fade_left: bool = true
	var accent: bool = false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var l: Color = Ui.VIOLET if accent else Color(1, 1, 1, 0.0 if fade_left else 0.6)
		var r: Color = Ui.MAGENTA if accent else Color(1, 1, 1, 0.6 if fade_left else 0.0)
		var h: float = 2.0 if accent else 1.0
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, h), Vector2(0.0, h)]),
			PackedColorArray([l, r, r, l]))

func _build_countdown() -> void:
	_count_box = Control.new()
	_count_box.size = COUNT_SIZE
	_count_box.pivot_offset = COUNT_SIZE * 0.5
	_count_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_box.visible = false
	Ui.place(_count_box, 0.5, 0.5, 0.5, 0.5, -COUNT_SIZE.x * 0.5, -COUNT_SIZE.y * 0.5 + 10.0, COUNT_SIZE.x * 0.5, COUNT_SIZE.y * 0.5 + 10.0)
	_root.add_child(_count_box)
	_count_ring = _CountRing.new()
	Ui.place(_count_ring, 0.0, 0.0, 1.0, 1.0)
	_count_box.add_child(_count_ring)
	_count = Ui.d("", 110, Ui.TEXT, 600, 0, true)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.place(_count, 0.0, 0.0, 1.0, 1.0)
	_count_box.add_child(_count)

## 스카이 알림 패널: 화면 양옆 가장자리에 붙는 사선 패널 (왼쪽 LEFT 파랑, 오른쪽 RIGHT 자홍)
func _build_sky_alert() -> void:
	for i in 2:
		var p := _SkyAlert.new()
		p.right = i == 1
		p.visible = false
		if i == 0:
			Ui.place(p, 0.0, SKY_ALERT_Y, 0.0, SKY_ALERT_Y, 0.0, -_SkyAlert.H * 0.5, _SkyAlert.W, _SkyAlert.H * 0.5)
		else:
			Ui.place(p, 1.0, SKY_ALERT_Y, 1.0, SKY_ALERT_Y, -_SkyAlert.W, -_SkyAlert.H * 0.5, 0.0, _SkyAlert.H * 0.5)
		_root.add_child(p)
		_sky.append(p)

## 게임의 다른 HUD 와 같은 결: 어두운 유리 바탕 + 화면 가장자리에서 번져 들어오는 색 + 가는 네온 선 + 사선 줄.
## 색 덩어리 패널이 아니라 색은 선과 번짐으로만 쓴다. 깜빡임(shine)에 따라 선과 번짐이 밝아진다.
class _SkyAlert extends Control:
	const W := 214.0
	const H := 84.0
	const LEFT_COLOR := Color("4a8dff")
	const RIGHT_COLOR := Color("ff4f9e")
	var right: bool = false
	var shine: float = 0.0:
		set(v):
			shine = v
			queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color = RIGHT_COLOR if right else LEFT_COLOR
		# 글자는 화면 가장자리 쪽에 붙인다 (안쪽 사선 끝은 비워 둔다)
		var l: float = 62.0 if right else 52.0
		var r: float = -52.0 if right else -62.0
		var cap := Ui.f("SKY", 10, col.lerp(Color.WHITE, 0.55), "exo", 600, 6)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		Ui.place(cap, 0.0, 0.0, 1.0, 0.0, l, 13.0, r, 29.0)
		add_child(cap)
		var big := Ui.f("RIGHT" if right else "LEFT", 34, Ui.TEXT, "supreme", 700, 2)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		Ui.place(big, 0.0, 0.0, 1.0, 0.0, l, 26.0, r, 74.0)
		add_child(big)
	func _draw() -> void:
		var col: Color = RIGHT_COLOR if right else LEFT_COLOR
		var hot: Color = col.lerp(Color.WHITE, 0.25 + 0.45 * shine)
		var skew: float = size.y * Ui.SLANT
		var w: float = size.x
		var h: float = size.y
		# x 를 "화면 가장자리에서 안쪽으로 잰 거리"로 다룬다. 오른쪽 패널은 좌우를 뒤집어 그린다
		var fx := func(d: float, y: float) -> Vector2:
			var slant: float = skew * (1.0 - y / h) if right else skew * (y / h)
			return Vector2(w - d + slant - skew, y) if right else Vector2(d - slant, y)
		# 어두운 유리 바탕
		draw_colored_polygon(PackedVector2Array([fx.call(-skew, 0.0), fx.call(w, 0.0), fx.call(w, h), fx.call(-skew, h)]),
			Color(0.03, 0.025, 0.07, 0.8))
		# 가장자리에서 번져 들어오는 색
		var wash := Color(col, 0.34 + 0.22 * shine)
		var none := Color(col, 0.0)
		draw_polygon(PackedVector2Array([fx.call(-skew, 0.0), fx.call(w * 0.8, 0.0), fx.call(w * 0.8, h), fx.call(-skew, h)]),
			PackedColorArray([wash, none, none, wash]))
		# 위아래 가는 선
		for y: float in [0.0, h - 1.5]:
			draw_polygon(PackedVector2Array([fx.call(-skew, y), fx.call(w, y), fx.call(w, y + 1.5), fx.call(-skew, y + 1.5)]),
				PackedColorArray([Color(hot, 0.95), Color(hot, 0.5), Color(hot, 0.5), Color(hot, 0.95)]))
		# 안쪽 끝의 사선 줄 (굵은 줄 + 가는 줄)
		for bar: Vector2 in [Vector2(8.0, 12.0), Vector2(28.0, 4.0)]:
			draw_colored_polygon(PackedVector2Array([
				fx.call(w + bar.x, 0.0), fx.call(w + bar.x + bar.y, 0.0), fx.call(w + bar.x + bar.y, h), fx.call(w + bar.x, h)]), Color(hot, 0.95))
		# 방향 쐐기 두 겹 (바깥쪽을 가리킨다)
		var cy: float = h * 0.5 + 6.0
		for k: float in [0.0, 9.0]:
			var tip: float = 14.0 + k
			draw_polyline(PackedVector2Array([fx.call(tip + 9.0, cy - 11.0), fx.call(tip, cy), fx.call(tip + 9.0, cy + 11.0)]),
				Color(hot, 0.95 - k * 0.05), 2.5, true)

## 안내 문구 띠: 양 끝이 사라지는 어두운 바탕 + 문구
func _build_guide() -> void:
	_guide_box = Control.new()
	_guide_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_box.modulate.a = 0.0
	Ui.place(_guide_box, 0.0, GUIDE_Y, 1.0, GUIDE_Y, 0.0, -27.0, 0.0, 27.0)
	_root.add_child(_guide_box)
	var band := _GuideBand.new()
	Ui.place(band, 0.5, 0.0, 0.5, 1.0, -520.0, 0.0, 520.0, 0.0)
	_guide_box.add_child(band)
	_guide = Ui.hbox(0)
	_guide.alignment = BoxContainer.ALIGNMENT_CENTER
	Ui.place(_guide, 0.0, 0.0, 1.0, 1.0)
	_guide_box.add_child(_guide)

class _GuideBand extends Control:
	var strength: float = 0.82
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var strong := Color(0.02, 0.015, 0.05, strength)
		var clear := Color(0.02, 0.015, 0.05, 0.0)
		var m: float = size.x * 0.5
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(m, 0.0), Vector2(m, size.y), Vector2(0.0, size.y)]),
			PackedColorArray([clear, strong, strong, clear]))
		draw_polygon(PackedVector2Array([Vector2(m, 0.0), Vector2(size.x, 0.0), size, Vector2(m, size.y)]),
			PackedColorArray([strong, clear, clear, strong]))

## 끝났을 때의 문구 뒤 슬랩: 가운데에서 좌우로 열리는 어두운 평행사변형 + 위아래 가는 선 + 양옆 보라→자홍 줄
class _BannerSlab extends Control:
	const H := 68.0
	const PAD := 46.0
	var text_w: float = 0.0
	var accent: Color = Color.WHITE
	var open: float = 0.0:
		set(v):
			open = v
			queue_redraw()
	var flash: float = 1.0:       # 위아래 선 색: 1 = 강조색, 0 = 흰색
		set(v):
			flash = v
			queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var half: float = (text_w * 0.5 + PAD) * open
		if half < 1.0:
			return
		var y0: float = c.y - H * 0.5
		var y1: float = c.y + H * 0.5
		var skew: float = H * Ui.SLANT
		var x0: float = c.x - half - skew * 0.5
		var x1: float = c.x + half - skew * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(x0 + skew, y0), Vector2(x1 + skew, y0), Vector2(x1, y1), Vector2(x0, y1)]), Color(0.03, 0.025, 0.07, 0.8))
		var edge_col := Color(Ui.TEXT.lerp(accent, flash), 0.75)
		draw_rect(Rect2(x0 + skew, y0, x1 - x0, 1.5), edge_col)
		draw_rect(Rect2(x0, y1 - 1.5, x1 - x0, 1.5), edge_col)
		var cols := PackedColorArray([Ui.VIOLET, Ui.VIOLET, Ui.MAGENTA, Ui.MAGENTA])
		# 오른쪽: 굵은 줄 + 가는 줄, 왼쪽: 거울상
		for side: float in [1.0, -1.0]:
			var edge: float = x1 if side > 0.0 else x0
			for bar: Vector2 in [Vector2(8.0, 14.0), Vector2(30.0, 5.0)]:
				var a: float = edge + side * bar.x if side > 0.0 else edge - bar.x - bar.y
				draw_polygon(PackedVector2Array([
					Vector2(a + skew, y0), Vector2(a + bar.y + skew, y0), Vector2(a + bar.y, y1), Vector2(a, y1)]), cols)

## 화면 맨 위 진행 선
class _ProgressLine extends Control:
	var value: float = 0.0:
		set(v):
			value = v
			queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(0.0, 0.0, size.x, 2.0), Color(1, 1, 1, 0.1))
		var w: float = size.x * value
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, 2.0), Vector2(0.0, 2.0)]),
			PackedColorArray([Ui.VIOLET, Ui.MAGENTA, Ui.MAGENTA, Ui.VIOLET]))
		# 머리 표시
		draw_rect(Rect2(w - 1.5, 0.0, 3.0, size.y), Ui.TEXT)

## 글자 뒤 구석을 살짝 어둡게 (패널 대신)
class _CornerShade extends Control:
	var flip: bool = false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var strong := Color(0.02, 0.015, 0.05, 0.66)
		var clear := Color(0.02, 0.015, 0.05, 0.0)
		var a: Color = clear if flip else strong
		var b: Color = strong if flip else clear
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
			PackedColorArray([a, b, clear, clear]))

## 카운트다운 숫자를 둘러싼 고리. value 1 -> 0 으로 줄어든다.
class _CountRing extends Control:
	var value: float = 0.0:
		set(v):
			value = v
			queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 14.0
		draw_arc(c, r, 0.0, TAU, 96, Color(1, 1, 1, 0.1), 1.5, true)
		if value > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * value, 96, Ui.VIOLET.lerp(Ui.MAGENTA, 1.0 - value), 3.0, true)

## 타이밍 오차 막대: 가운데 = 정확, 왼쪽 = 빠름, 오른쪽 = 느림. 최근 타격이 눈금으로 남았다 사라진다.
class _ErrorMeter extends Control:
	const KEEP := 24
	const LIFE := 2.4
	var _hits: Array[Vector3] = []       # (delta_ms, 남은 시간, 등급 색 인덱스)
	var _colors: Array[Color] = []
	var _avg: float = 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func push(delta_ms: float, color: Color) -> void:
		_hits.append(Vector3(delta_ms, LIFE, 0.0))
		_colors.append(color)
		if _hits.size() > KEEP:
			_hits.pop_front()
			_colors.pop_front()
		_avg = lerpf(_avg, delta_ms, 0.25)
	func _process(delta: float) -> void:
		for i in _hits.size():
			_hits[i].y = maxf(_hits[i].y - delta, 0.0)
		queue_redraw()
	func _draw() -> void:
		var mid: float = size.x * 0.5
		var cy: float = size.y * 0.5
		var span: float = GameConst.GREAT_MS
		var px: float = (size.x * 0.5) / span
		# 구간 바탕: GREAT 폭 전체, PERFECT 폭은 조금 더 밝게
		draw_rect(Rect2(0.0, cy - 1.0, size.x, 2.0), Color(1, 1, 1, 0.12))
		var pw: float = GameConst.PERFECT_MS * px
		draw_rect(Rect2(mid - pw, cy - 1.0, pw * 2.0, 2.0), Color(Ui.GOLD, 0.4))
		draw_rect(Rect2(mid - 0.75, cy - 8.0, 1.5, 16.0), Color(1, 1, 1, 0.7))
		for i in _hits.size():
			var h: Vector3 = _hits[i]
			if h.y <= 0.0:
				continue
			var x: float = mid + clampf(h.x, -span, span) * px
			draw_rect(Rect2(x - 1.0, cy - 6.0, 2.0, 12.0), Color(_colors[i], clampf(h.y / LIFE, 0.0, 1.0) * 0.9))
		# 최근 평균 위치
		var ax: float = mid + clampf(_avg, -span, span) * px
		draw_colored_polygon(PackedVector2Array([Vector2(ax - 4.0, cy - 10.0), Vector2(ax + 4.0, cy - 10.0), Vector2(ax, cy - 5.0)]), Ui.TEXT)
