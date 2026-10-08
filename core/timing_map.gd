class_name TimingMap
extends RefCounted
## BPM 변화(타이밍 포인트) 관리. 시간 단위는 ms.

var _times: Array[float] = []
var _bpms: Array[float] = []

## points: [{"time": ms, "bpm": float}, ...]
func _init(points: Array = []) -> void:
	var sorted: Array = points.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["time"]) < float(b["time"]))
	for p in sorted:
		var d: Dictionary = p
		_times.append(float(d["time"]))
		_bpms.append(float(d["bpm"]))
	if _times.is_empty():
		_times.append(0.0)
		_bpms.append(120.0)

func bpm_at(t: float) -> float:
	var bpm: float = _bpms[0]
	for i in _times.size():
		if _times[i] <= t:
			bpm = _bpms[i]
		else:
			break
	return bpm

func beat_ms_at(t: float) -> float:
	return 60000.0 / bpm_at(t)

## (start, end] 구간의 tick 시각. 마지막 tick은 항상 end.
func tick_times(start: float, end: float, beat_fraction: float) -> Array[float]:
	var result: Array[float] = []
	var t: float = start
	while true:
		t += beat_ms_at(t) * beat_fraction
		if t >= end - 0.5:
			break
		result.append(t)
	result.append(end)
	return result
