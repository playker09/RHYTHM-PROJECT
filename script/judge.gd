class_name RhythmJudge
extends Node

signal judgement_made(result: String, offset_ms: float)
var _music: RhythmMusicPlayer
var _display: RhythmDisplay

func configure(music: RhythmMusicPlayer, display: RhythmDisplay, player_input: PlayerInput) -> void:
	_music = music
	_display = display
	player_input.normal_note_pressed.connect(_on_normal_input)
	player_input.slide_performed.connect(_on_slide_input)

func _process(_delta: float) -> void:
	if _music == null or not _music.is_song_playing(): return
	for note in _display.get_expired_notes(_music.get_current_time(), Global.BAD_WINDOW): _apply_result(note, "MISS", 0.0)

func _on_normal_input(lane: Global.Lane) -> void:
	if _music.is_song_playing() and Global.current_lane == lane: _try_judge(RhythmChart.NoteType.NORMAL, lane)

func _on_slide_input(direction: Global.Lane) -> void:
	if _music.is_song_playing(): _try_judge(RhythmChart.NoteType.SLIDE, direction)

func _try_judge(type: RhythmChart.NoteType, value: Global.Lane) -> void:
	var note := _display.get_matching_note(type, value)
	if note == null: return
	var offset_ms := (_music.get_current_time() - note.target_time) * 1000.0
	var absolute_offset := absf(offset_ms) / 1000.0
	if absolute_offset <= Global.PERFECT_WINDOW: _apply_result(note, "PERFECT", offset_ms)
	elif absolute_offset <= Global.GOOD_WINDOW: _apply_result(note, "GOOD", offset_ms)
	elif absolute_offset <= Global.BAD_WINDOW: _apply_result(note, "BAD", offset_ms)

func _apply_result(note: NoteVisual, result: String, offset_ms: float) -> void:
	if result == "PERFECT":
		Global.score += 300; Global.combo += 1
	elif result == "GOOD":
		Global.score += 200; Global.combo += 1
	elif result == "BAD":
		Global.score += 100; Global.combo += 1
	else: Global.combo = 0
	_display.remove_note(note)
	_display.show_judgement(result)
	judgement_made.emit(result, offset_ms)
