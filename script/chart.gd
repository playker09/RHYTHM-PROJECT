class_name RhythmChart
extends Node

enum NoteType { NORMAL, SLIDE }
var notes: Array[Dictionary] = []

func load_chart(metronome: Metronome) -> void:
	notes = [
		{"beat": 4.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 5.0, "type": NoteType.NORMAL, "lane": Global.Lane.RIGHT},
		{"beat": 6.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 7.0, "type": NoteType.NORMAL, "lane": Global.Lane.RIGHT},
		{"beat": 8.0, "type": NoteType.SLIDE, "direction": Global.Lane.RIGHT},
		{"beat": 10.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 10.5, "type": NoteType.NORMAL, "lane": Global.Lane.RIGHT},
		{"beat": 11.0, "type": NoteType.NORMAL, "lane": Global.Lane.LEFT},
		{"beat": 12.0, "type": NoteType.SLIDE, "direction": Global.Lane.LEFT},
		{"beat": 14.0, "type": NoteType.NORMAL, "lane": Global.Lane.RIGHT},
	]
	for note in notes:
		note["target_time"] = metronome.beat_to_time(float(note.beat))
	notes.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.target_time) < float(b.target_time))
