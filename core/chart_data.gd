class_name ChartData
extends RefCounted

var title: String = ""
var artist: String = ""
var audio: String = ""
var level: int = 0
var difficulty: String = ""
var offset_ms: float = 0.0
var base_dir: String = ""
var timing: TimingMap = TimingMap.new()
var notes: Array[NoteData] = []   # time 오름차순

## 마지막 노트가 끝나는 시각
func end_time_ms() -> float:
	var last: float = 0.0
	for n in notes:
		last = maxf(last, n.end_time)
	return last

## 곡 전체의 판정 수 (head + tick + flick). 풀콤보일 때의 콤보 수와 같다.
func total_judgements() -> int:
	var total: int = 0
	for n in notes:
		match n.type:
			NoteData.Type.TAP, NoteData.Type.FLICK:
				total += 1
			NoteData.Type.HOLD:
				total += 1 + timing.tick_times(n.time, n.end_time, GameConst.TICK_BEAT_FRACTION).size()
			NoteData.Type.FIELD:
				total += timing.tick_times(n.time, n.end_time, GameConst.TICK_BEAT_FRACTION).size()
	return total
