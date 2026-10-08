class_name ChartLoader
extends RefCounted
## JSON 채보 -> ChartData. 시간 단위는 ms.

## res://charts/*/chart.json 을 훑어 선곡 화면용 요약 목록을 만든다 (제목순).
static func list_charts() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://charts")
	if dir == null:
		return out
	for d in dir.get_directories():
		var path := "res://charts/%s/chart.json" % d
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var root: Dictionary = parsed
		var meta: Dictionary = root.get("meta", {})
		var timing: Array = root.get("timing", [])
		var bpm: float = 120.0
		if not timing.is_empty() and typeof(timing[0]) == TYPE_DICTIONARY:
			bpm = float((timing[0] as Dictionary).get("bpm", 120))
		out.append({
			"path": path,
			"title": str(meta.get("title", d)),
			"artist": str(meta.get("artist", "")),
			"bpm": bpm,
			"level": int(meta.get("level", 1)),
			"difficulty": str(meta.get("difficulty", "NORMAL")),
			"notes": (root.get("notes", []) as Array).size(),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["title"]).naturalnocasecmp_to(String(b["title"])) < 0)
	return out

static func load_chart(path: String) -> ChartData:
	if not FileAccess.file_exists(path):
		push_error("채보 파일이 없습니다: " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("채보 JSON 형식이 올바르지 않습니다: " + path)
		return null
	var root: Dictionary = parsed

	var chart := ChartData.new()
	chart.base_dir = path.get_base_dir()

	var meta: Dictionary = root.get("meta", {})
	chart.title = str(meta.get("title", ""))
	chart.artist = str(meta.get("artist", ""))
	chart.audio = str(meta.get("audio", ""))
	chart.level = int(meta.get("level", 0))
	chart.difficulty = str(meta.get("difficulty", ""))
	chart.offset_ms = float(meta.get("offset", 0))

	var points: Array = []
	var timing_raw: Array = root.get("timing", [])
	for raw in timing_raw:
		if typeof(raw) == TYPE_DICTIONARY and raw.has("time") and raw.has("bpm") and float(raw["bpm"]) > 0.0:
			points.append(raw)
		else:
			push_warning("잘못된 timing 항목 무시: " + str(raw))
	chart.timing = TimingMap.new(points)

	var notes_raw: Array = root.get("notes", [])
	for raw in notes_raw:
		if typeof(raw) != TYPE_DICTIONARY:
			push_warning("잘못된 note 항목 무시: " + str(raw))
			continue
		var n: NoteData = _parse_note(raw)
		if n != null:
			chart.notes.append(n)
	chart.notes.sort_custom(func(a: NoteData, b: NoteData) -> bool: return a.time < b.time)
	return chart

static func _parse_note(d: Dictionary) -> NoteData:
	var kind: String = str(d.get("type", ""))
	match kind:
		"tap":
			if not d.has("time") or not _valid_lane(d):
				return _bad(d)
			return NoteData.make_tap(float(d["time"]), int(d["lane"]))
		"hold":
			if not d.has("time") or not d.has("end") or not _valid_lane(d) or float(d["end"]) <= float(d["time"]):
				return _bad(d)
			return NoteData.make_hold(float(d["time"]), float(d["end"]), int(d["lane"]))
		"flick":
			if not d.has("time"):
				return _bad(d)
			var f := NoteData.new()
			f.type = NoteData.Type.FLICK
			f.time = float(d["time"])
			f.end_time = f.time
			f.x = float(d.get("x", 0.5))
			f.dir = str(d.get("dir", "right"))
			return f
		"field":
			var keys: Array = d.get("keys", [])
			if keys.size() < 2:
				return _bad(d)
			var fld := NoteData.new()
			fld.type = NoteData.Type.FIELD
			fld.keys = keys
			fld.time = float(keys[0]["time"])
			fld.end_time = float(keys[keys.size() - 1]["time"])
			return fld
	return _bad(d)

static func _valid_lane(d: Dictionary) -> bool:
	if not d.has("lane"):
		return false
	var lane: int = int(d["lane"])
	return lane >= 0 and lane < GameConst.LANE_COUNT

static func _bad(d: Dictionary) -> NoteData:
	push_warning("잘못된 note 무시: " + str(d))
	return null
