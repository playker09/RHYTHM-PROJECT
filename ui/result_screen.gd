class_name ResultScreen
extends Control
## 결과 화면. 왼쪽 = 곡/등급/점수, 오른쪽 = 판정 분포, 콤보, 타이밍 분포. 순서대로 등장한다.
## 숫자는 전부 ScoreManager 와 기록(user://records.cfg)의 실제 값이다.

signal action(id: String)    # "retry" | "quit"

var _score_lead: Label
var _score_label: Label
var _bars: Array[_Bar] = []

## song = {title, artist, level, diff, jacket}, best = 이번 플레이 전의 최고 기록 (없으면 빈 Dictionary)
func build(score: ScoreManager, song: Dictionary, new_record: bool, best: Dictionary = {}) -> void:
	Ui.place(self, 0.0, 0.0, 1.0, 1.0)
	var veil := Ui.backdrop(4.0, Color(0.03, 0.025, 0.06, 0.8))
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)

	var rank: String = score.rank()
	var rank_color: Color = Ui.RANK_COLORS[rank]
	var total: int = score.counts[0] + score.counts[1] + score.counts[2]

	# --- 왼쪽 ---
	var left := Ui.vbox(0)
	Ui.place(left, 0.0, 0.0, 0.47, 1.0, 72.0, 48.0, 0.0, -96.0)
	add_child(left)
	left.add_child(Ui.caption("RESULT", Ui.TEXT_2, 14))
	left.add_child(Ui.gap(12.0))
	var song_row := Ui.hbox(16)
	left.add_child(song_row)
	var jacket := Jacket.new()
	jacket.custom_minimum_size = Vector2(84.0, 84.0)
	jacket.set_song(String(song["title"]), String(song.get("jacket", "")))
	song_row.add_child(jacket)
	var names := Ui.vbox(2)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	song_row.add_child(names)
	var title := Ui.d(String(song["title"]), 30, Ui.TEXT, 600)
	names.add_child(title)
	names.add_child(Ui.t(String(song["artist"]), 14, Ui.TEXT_2))
	var slot: int = int(song.get("diff", -1))
	if slot >= 0:
		names.add_child(Ui.gap(2.0))
		names.add_child(Ui.diff_chip(slot, int(song.get("level", 0)), true, 13))
	left.add_child(Ui.expander())

	# 등급 글자 + 뒤의 빛살
	var rank_size: int = 230 if rank != "AP" else 190
	var rank_box := Control.new()
	rank_box.custom_minimum_size = Vector2(0.0, 250.0)
	rank_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(rank_box)
	var burst := _RankBurst.new()
	burst.color = rank_color
	Ui.place(burst, 0.0, 0.5, 0.0, 0.5, -90.0, -210.0, 330.0, 210.0)
	rank_box.add_child(burst)
	var rank_l := Ui.d(rank, rank_size, Ui.TEXT, 700, 0, true)
	Ui.gradient(rank_l, Ui.TEXT, rank_color, rank_size * 1.15)
	rank_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 가로는 빛살(burst)과 같은 폭(-90~330)에 가운데 정렬 -> 고리 한가운데. 높이는 그라데이션 span 기준이라 266 유지
	Ui.place(rank_l, 0.0, 0.0, 0.0, 1.0, -90.0, -4.0, 330.0, 12.0)
	rank_box.add_child(rank_l)

	left.add_child(Ui.caption("SCORE"))
	var score_row := Ui.hbox(0)
	left.add_child(score_row)
	_score_lead = Ui.d("", 66, Color(1, 1, 1, 0.2), 600, 1, true)
	score_row.add_child(_score_lead)
	_score_label = Ui.d("0", 66, Ui.TEXT, 600, 1, true)
	score_row.add_child(_score_label)
	var badges := Ui.hbox(10)
	left.add_child(badges)
	badges.add_child(Ui.d("%.2f%%" % score.accuracy(), 22, Ui.CYAN, 600, 1))
	if new_record:
		badges.add_child(Ui.chip("NEW RECORD", Ui.MAGENTA))
	if rank == "AP":
		badges.add_child(Ui.chip("ALL PERFECT", Ui.GOLD))
	elif score.is_full_combo():
		badges.add_child(Ui.chip("FULL COMBO", Ui.CYAN))
	left.add_child(Ui.gap(4.0))
	var best_text: String = "첫 플레이"
	if not best.is_empty():
		var diff: int = score.score - int(best["score"])
		best_text = "이전 최고  %s   (%s%s)" % [Ui.fmt_int(int(best["score"])), "+" if diff >= 0 else "-", Ui.fmt_int(absi(diff))]
	left.add_child(Ui.t(best_text, 14, Ui.TEXT_3))

	# --- 오른쪽 ---
	var panel := GlassPanel.new(30.0, Color(0.04, 0.034, 0.085, 0.55), 2.0)
	panel.accent = rank_color
	Ui.place(panel, 0.52, 0.0, 1.0, 1.0, 0.0, 60.0, -72.0, -108.0)
	add_child(panel)
	var right := Ui.vbox(14)
	panel.content.add_child(right)
	right.add_child(Ui.caption("JUDGEMENT", Ui.TEXT_2))
	_add_bar(right, "PERFECT", score.counts[0], total, Ui.GOLD)
	_add_bar(right, "GREAT", score.counts[1], total, Ui.CYAN)
	_add_bar(right, "MISS", score.counts[2], total, Ui.RED)
	right.add_child(Ui.gap(2.0))
	right.add_child(Ui.rule(Ui.LINE_SOFT))
	var stats := Ui.hbox(40)
	right.add_child(stats)
	stats.add_child(Ui.stat("MAX COMBO", "%s / %s" % [Ui.fmt_int(score.max_combo), Ui.fmt_int(score.total())], 26)["root"])
	stats.add_child(Ui.stat("FAST", str(score.fast), 26, Ui.VIOLET.lerp(Color.WHITE, 0.35))["root"])
	stats.add_child(Ui.stat("SLOW", str(score.slow), 26, Ui.MAGENTA.lerp(Color.WHITE, 0.35))["root"])
	right.add_child(Ui.rule(Ui.LINE_SOFT))
	var head := Ui.hbox(0)
	right.add_child(head)
	head.add_child(Ui.caption("TIMING", Ui.TEXT_2))
	head.add_child(Ui.expander())
	head.add_child(Ui.t(_timing_summary(score.deltas), 13, Ui.TEXT_3))
	var hist := _Histogram.new()
	hist.set_deltas(score.deltas)
	hist.custom_minimum_size = Vector2(0.0, 90.0)
	hist.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(hist)

	# --- 하단 ---
	var foot := Ui.hbox(14)
	Ui.place(foot, 0.0, 1.0, 1.0, 1.0, 72.0, -76.0, -72.0, -28.0)
	add_child(foot)
	foot.add_child(Ui.hints([["R", "다시 하기"], ["Esc", "곡 선택"]]))
	foot.add_child(Ui.expander())
	var retry := Ui.button("다시 하기")
	retry.pressed.connect(func(): action.emit("retry"))
	foot.add_child(retry)
	var quit := Ui.button("곡 선택", true)
	quit.pressed.connect(func(): action.emit("quit"))
	foot.add_child(quit)

	_animate(score.score, rank_l, burst, left, panel, foot)

## 타이밍 분포 요약: 평균 오차(부호 있음). 타격이 없으면 "-"
func _timing_summary(deltas: Array[float]) -> String:
	if deltas.is_empty():
		return "타격 없음"
	var sum: float = 0.0
	for v in deltas:
		sum += v
	var mean: float = sum / deltas.size()
	return "평균 %+.1f ms  (%s)" % [mean, "빠름" if mean < -0.05 else ("느림" if mean > 0.05 else "정확")]

func _add_bar(parent: Control, caption: String, count: int, total: int, color: Color) -> void:
	var v := Ui.vbox(4)
	parent.add_child(v)
	var top := Ui.hbox(0)
	v.add_child(top)
	top.add_child(Ui.d(caption, 18, color, 600, 3))
	top.add_child(Ui.expander())
	top.add_child(Ui.d(Ui.fmt_int(count), 26, Ui.TEXT, 600))
	var bar := _Bar.new()
	bar.custom_minimum_size = Vector2(0.0, 5.0)
	bar.color = color
	bar.target = float(count) / maxf(total, 1)
	v.add_child(bar)
	_bars.append(bar)

func _set_score(v: float) -> void:
	var parts: PackedStringArray = Ui.fmt_score7(roundi(v))
	_score_lead.text = parts[0]
	_score_label.text = parts[1]

func _animate(score_value: int, rank_l: Label, burst: Control, left: Control, right: Control, foot: Control) -> void:
	modulate.a = 0.0
	left.modulate.a = 0.0
	right.modulate.a = 0.0
	foot.modulate.a = 0.0
	rank_l.modulate.a = 0.0
	burst.modulate.a = 0.0
	_set_score(0.0)
	rank_l.pivot_offset = Vector2(210.0, 133.0)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_property(left, "modulate:a", 1.0, 0.25)
	tw.tween_method(_set_score, 0.0, float(score_value), 1.0)
	tw.tween_callback(func():
		rank_l.scale = Vector2(1.6, 1.6)
		App.sfx("result", 0.5)
		# 등급 효과음이 지나간 뒤 결과 배경 음악 (연출 순서를 밀지 않게 따로 센다. 화면이 닫히면 같이 취소된다)
		create_tween().tween_callback(func(): App.bgm_play("result")).set_delay(0.9))
	tw.tween_property(rank_l, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(rank_l, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_QUINT)
	tw.parallel().tween_property(burst, "modulate:a", 1.0, 0.5)
	tw.tween_property(right, "modulate:a", 1.0, 0.25)
	for b in _bars:
		tw.tween_property(b, "shown", b.target, 0.26)
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
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.09))
		draw_rect(Rect2(0.0, 0.0, size.x * shown, size.y), color)

## 등급 글자 뒤에서 천천히 도는 빛살과 고리
class _RankBurst extends Control:
	var color: Color = Color.WHITE
	var _t: float = 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		for i in 36:
			var a: float = TAU * i / 36.0 + _t * 0.08
			var long: bool = i % 3 == 0
			var r0: float = r * (0.56 if long else 0.62)
			var r1: float = r * (0.98 if long else 0.74)
			var dir := Vector2(cos(a), sin(a))
			draw_line(c + dir * r0, c + dir * r1, Color(color, 0.3 if long else 0.16), 1.5, true)
		draw_arc(c, r * 0.52, 0.0, TAU, 96, Color(color, 0.35), 1.5, true)
		draw_arc(c, r * 0.47, -_t * 0.3, -_t * 0.3 + PI * 1.2, 64, Color(color, 0.7), 2.5, true)

## 타이밍 오차 분포 (빠름 <- 0 -> 느림). 타격(머리/플릭)의 실제 오차를 10ms 칸으로 센다.
class _Histogram extends Control:
	const BIN_MS := 10.0
	var _bins := PackedInt32Array()
	var _top: int = 1
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_deltas(deltas: Array[float]) -> void:
		var half: int = ceili(GameConst.GREAT_MS / BIN_MS)
		_bins.resize(half * 2)
		_bins.fill(0)
		for d in deltas:
			var i: int = clampi(floori(d / BIN_MS) + half, 0, half * 2 - 1)
			_bins[i] += 1
		_top = 1
		for v in _bins:
			_top = maxi(_top, v)
		queue_redraw()
	func _draw() -> void:
		var n: int = _bins.size()
		if n == 0:
			return
		var base: float = size.y - 18.0
		var w: float = size.x / n
		var f: Font = Ui.font(true, 500, 1)
		draw_rect(Rect2(0.0, base, size.x, 1.0), Ui.LINE)
		for i in n:
			var ms: float = (i - n * 0.5 + 0.5) * BIN_MS
			var col: Color = Ui.GOLD if absf(ms) <= GameConst.PERFECT_MS else Ui.CYAN
			var h: float = base * float(_bins[i]) / float(_top)
			draw_rect(Rect2(i * w + 1.5, base - h, w - 3.0, h), Color(col, 0.9))
			draw_rect(Rect2(i * w + 1.5, base - 2.0, w - 3.0, 2.0), Color(col, 0.3))
		draw_rect(Rect2(size.x * 0.5 - 0.5, 0.0, 1.0, base), Color(1, 1, 1, 0.3))
		draw_string(f, Vector2(0.0, size.y - 2.0), "FAST", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Ui.TEXT_3)
		draw_string(f, Vector2(0.0, size.y - 2.0), "0", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Ui.TEXT_3)
		draw_string(f, Vector2(0.0, size.y - 2.0), "SLOW", HORIZONTAL_ALIGNMENT_RIGHT, size.x, 11, Ui.TEXT_3)
