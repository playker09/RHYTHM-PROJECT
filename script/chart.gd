extends Node

enum NoteType { NORMAL, SLIDE }
var notes: Array[Dictionary] = []

func load_chart(metronome) -> void:
	notes = [
		{"beat": 4.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 4.5, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 5.0, "type": NoteType.SLIDE, "direction": Global.Lane.RIGHT},
		{"beat": 6.0, "type": NoteType.NORMAL, "lane": Global.Lane.RIGHT},
		{"beat": 6.5, "type": NoteType.NORMAL, "lane": Global.Lane.RIGHT},
		{"beat": 7.0, "type": NoteType.SLIDE, "direction": Global.Lane.LEFT},
		{"beat": 8.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 9.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 10.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 11.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 12.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 13.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 14.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 15.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 16.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 17.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 18.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 19.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 20.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 21.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 22.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 23.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 24.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
	]
	for note in notes:
		# The calibrated offset shifts every target consistently, in milliseconds.
		note["target_time"] = metronome.beat_to_time(float(note.beat)) + Global.timing_offset_ms / 1000.0
	notes.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.target_time) < float(b.target_time))
