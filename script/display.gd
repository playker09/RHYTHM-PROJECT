class_name RhythmDisplay
extends Node2D

const APPROACH_TIME := 2.0
var _notes: Array[NoteVisual] = []
var _next_note_index := 0
var _chart: RhythmChart
var _music: RhythmMusicPlayer
var _judgement_text := "READY"
var _judgement_color := Color.WHITE

func configure(chart: RhythmChart, music: RhythmMusicPlayer) -> void:
	_chart = chart
	_music = music

func reset_notes() -> void:
	for note in _notes: note.queue_free()
	_notes.clear()
	_next_note_index = 0

func _process(_delta: float) -> void:
	queue_redraw()
	if _chart == null or _music == null: return
	var current_time := _music.get_current_time()
	while _next_note_index < _chart.notes.size() and current_time >= float(_chart.notes[_next_note_index].target_time) - APPROACH_TIME:
		var note := NoteVisual.new()
		add_child(note)
		note.setup(_chart.notes[_next_note_index], get_viewport_rect().size, APPROACH_TIME / Global.note_speed)
		_notes.append(note)
		_next_note_index += 1
	for note in _notes: note.update_for_time(current_time)

func get_matching_note(type: RhythmChart.NoteType, value: Global.Lane) -> NoteVisual:
	for note in _notes:
		if int(note.data.type) != type: continue
		var expected := int(note.data.lane) if type == RhythmChart.NoteType.NORMAL else int(note.data.direction)
		if expected == value: return note
	return null

func get_expired_notes(current_time: float, miss_window: float) -> Array[NoteVisual]:
	var expired: Array[NoteVisual] = []
	for note in _notes:
		if current_time - note.target_time > miss_window: expired.append(note)
	return expired

func remove_note(note: NoteVisual) -> void:
	_notes.erase(note)
	note.queue_free()

func show_judgement(result: String) -> void:
	_judgement_text = result
	_judgement_color = {"PERFECT": Color("7fffd4"), "GOOD": Color("87cefa"), "BAD": Color("ffd166"), "MISS": Color("ff6b6b")}.get(result, Color.WHITE)

func _draw() -> void:
	var size := get_viewport_rect().size
	var half := size.x * 0.5
	draw_rect(Rect2(0, 0, half, size.y), Color("18365c") if Global.current_lane == Global.Lane.LEFT else Color("111b2b"))
	draw_rect(Rect2(half, 0, half, size.y), Color("5c2330") if Global.current_lane == Global.Lane.RIGHT else Color("2b111b"))
	var y := size.y - 110.0
	draw_line(Vector2(0, y), Vector2(size.x, y), Color.WHITE, 5.0)
	draw_string(ThemeDB.fallback_font, Vector2(28, 42), "D  LEFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(ThemeDB.fallback_font, Vector2(half + 28, 42), "F  RIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(ThemeDB.fallback_font, Vector2(half - 70, y - 38), _judgement_text, HORIZONTAL_ALIGNMENT_CENTER, 140, 26, _judgement_color)
	draw_string(ThemeDB.fallback_font, Vector2(24, size.y - 28), "Score: %d   Combo: %d" % [Global.score, Global.combo], HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
