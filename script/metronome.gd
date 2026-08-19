class_name Metronome
extends Node

var tempo_map: Array[Dictionary] = []

func configure_fixed_bpm(bpm: float) -> void:
	configure_tempo_map([{"time": 0.0, "bpm": bpm}])

func configure_tempo_map(entries: Array[Dictionary]) -> void:
	tempo_map = entries.duplicate(true)
	tempo_map.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.time) < float(b.time))
	if tempo_map.is_empty() or float(tempo_map[0].time) != 0.0:
		tempo_map.push_front({"time": 0.0, "bpm": 120.0})
	for index in tempo_map.size():
		var entry := tempo_map[index]
		entry["start_beat"] = 0.0 if index == 0 else time_to_beat(float(entry.time))
		tempo_map[index] = entry

func beat_to_time(beat: float) -> float:
	var segment := _segment_for_beat(beat)
	return float(segment.time) + (beat - float(segment.start_beat)) * 60.0 / float(segment.bpm)

func time_to_beat(time_seconds: float) -> float:
	var segment := _segment_for_time(time_seconds)
	return float(segment.start_beat) + (time_seconds - float(segment.time)) * float(segment.bpm) / 60.0

func _segment_for_time(time_seconds: float) -> Dictionary:
	var result := tempo_map[0]
	for entry in tempo_map:
		if float(entry.time) > time_seconds: break
		result = entry
	return result

func _segment_for_beat(beat: float) -> Dictionary:
	var result := tempo_map[0]
	for entry in tempo_map:
		if float(entry.start_beat) > beat: break
		result = entry
	return result
