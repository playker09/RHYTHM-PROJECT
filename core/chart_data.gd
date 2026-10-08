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
