class_name ResultScreen
extends Control
## 결과 화면. 왼쪽 = 등급/점수, 오른쪽 = 판정 분포. 순서대로 등장한다.

signal action(id: String)    # "retry" | "quit"

var _score_label: Label
var _bars: Array[_Bar] = []

func build(score: ScoreManager, song: Dictionary, new_record: bool) -> void:
	Ui.place(self, 0.0, 0.0, 1.0, 1.0)
	add_child(Ui.backdrop(4.0, Color(0.03, 0.025, 0.06, 0.8)))

	var rank: String = score.rank()
	var rank_color: Color = Ui.RANK_COLORS[rank]
	var total: int = score.counts[0] + score.counts[1] + score.counts[2]

	# 왼쪽
	var left := Ui.vbox(0)
	Ui.place(left, 0.0, 0.0, 0.48, 1.0, 72.0, 52.0, 0.0, -90.0)
	add_child(left)
	left.add_child(Ui.d("RESULT", 15, Ui.TEXT_2, 600, 5))
	left.add_child(Ui.gap(6.0))
	var song_row := Ui.hbox(12)
	left.add_child(song_row)
	var jacket := Jacket.new()
	jacket.custom_minimum_size = Vector2(52.0, 52.0)
	jacket.set_song(String(song["title"]))
	song_row.add_child(jacket)
	var names := Ui.vbox(0)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	song_row.add_child(names)
	names.add_child(Ui.d(String(song["title"]), 22, Ui.TEXT, 600))
	names.add_child(Ui.t(String(song["artist"]), 13, Ui.TEXT_2))
	left.add_child(Ui.expander())

	var rank_size: int = 210 if rank != "AP" else 170
	var rank_l := Ui.d(rank, rank_size, Ui.TEXT, 700, 0, true)
	Ui.gradient(rank_l, Ui.TEXT, rank_color, rank_size * 1.15)
	rank_l.custom_minimum_size = Vector2(0.0, rank_size * 1.1)
	rank_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_child(rank_l)

	_score_label = Ui.d("0", 68, Ui.TEXT, 700)
	left.add_child(_score_label)
	var badges := Ui.hbox(8)
	left.add_child(badges)
	badges.add_child(Ui.t("정확도 %.2f%%" % score.accuracy(), 16, Ui.TEXT_2, 500))
	if new_record:
		badges.add_child(Ui.chip("NEW RECORD", Ui.MAGENTA))
	if rank == "AP":
		badges.add_child(Ui.chip("ALL PERFECT", Ui.GOLD))
	elif score.is_full_combo():
		badges.add_child(Ui.chip("FULL COMBO", Ui.CYAN))

	# 오른쪽
	var right := Ui.vbox(14)
	Ui.place(right, 0.52, 0.0, 1.0, 1.0, 0.0, 52.0, -72.0, -90.0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(right)
	_add_bar(right, "PERFECT", score.counts[0], total, Ui.GOLD)
	_add_bar(right, "GREAT", score.counts[1], total, Ui.CYAN)
	_add_bar(right, "MISS", score.counts[2], total, Ui.RED)
	right.add_child(Ui.gap(10.0))
	var stats := Ui.hbox(44)
	right.add_child(stats)
	stats.add_child(Ui.stat("최대 콤보", "%s / %s" % [Ui.fmt_int(score.max_combo), Ui.fmt_int(score.total())], 28)["root"])
	stats.add_child(Ui.stat("FAST", str(score.fast), 28)["root"])
	stats.add_child(Ui.stat("SLOW", str(score.slow), 28)["root"])

	# 하단
	var foot := Ui.hbox(14)
	Ui.place(foot, 0.0, 1.0, 1.0, 1.0, 72.0, -72.0, -72.0, -24.0)
	add_child(foot)
	foot.add_child(Ui.hints([["R", "다시 하기"], ["Esc", "곡 선택"]]))
	foot.add_child(Ui.expander())
	var retry := Ui.button("다시 하기")
	retry.pressed.connect(func(): action.emit("retry"))
	foot.add_child(retry)
	var quit := Ui.button("곡 선택", true)
	quit.pressed.connect(func(): action.emit("quit"))
	foot.add_child(quit)

	_animate(score.score, rank_l, left, right, foot)

func _add_bar(parent: Control, caption: String, count: int, total: int, color: Color) -> void:
	var v := Ui.vbox(3)
	parent.add_child(v)
	var top := Ui.hbox(0)
	v.add_child(top)
	top.add_child(Ui.d(caption, 19, color, 600, 2))
	top.add_child(Ui.expander())
	top.add_child(Ui.d(Ui.fmt_int(count), 25, Ui.TEXT, 600))
	var bar := _Bar.new()
	bar.custom_minimum_size = Vector2(0.0, 6.0)
	bar.color = color
	bar.target = float(count) / maxf(total, 1)
	v.add_child(bar)
	_bars.append(bar)

func _animate(score_value: int, rank_l: Label, left: Control, right: Control, foot: Control) -> void:
	modulate.a = 0.0
	left.modulate.a = 0.0
	right.modulate.a = 0.0
	foot.modulate.a = 0.0
	rank_l.modulate.a = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_property(left, "modulate:a", 1.0, 0.2)
	tw.tween_method(func(v: float): _score_label.text = Ui.fmt_int(roundi(v)), 0.0, float(score_value), 0.9)
	tw.tween_property(rank_l, "modulate:a", 1.0, 0.12)
	tw.tween_callback(App.sfx.bind("confirm"))
	tw.tween_property(right, "modulate:a", 1.0, 0.2)
	for b in _bars:
		tw.tween_property(b, "shown", b.target, 0.28)
	tw.tween_property(foot, "modulate:a", 1.0, 0.2)

class _Bar extends Control:
	var color: Color = Color.WHITE
	var target: float = 0.0
	var shown: float = 0.0:
		set(v):
			shown = v
			queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(0.0, 0.0, size.x * shown, size.y), color)
