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
		var bpm_lo: float = INF
		var bpm_hi: float = 0.0
		for p in timing:
			if typeof(p) == TYPE_DICTIONARY:
				var b: float = float((p as Dictionary).get("bpm", 120))
				bpm_lo = minf(bpm_lo, b)
				bpm_hi = maxf(bpm_hi, b)
		if bpm_hi <= 0.0:
			bpm_lo = 120.0
			bpm_hi = 120.0
		var chart: ChartData = load_chart(path)
		out.append({
			"path": path,
			"title": str(meta.get("title", d)),
			"artist": str(meta.get("artist", "")),
			"audio": path.get_base_dir().path_join(str(meta.get("audio", ""))),
			"bpm": bpm_lo,
			"bpm_hi": bpm_hi,
			"level": int(meta.get("level", 1)),
			"difficulty": str(meta.get("difficulty", "NORMAL")),
			"notes": chart.notes.size(),
			"total": chart.total_judgements(),
			"duration_ms": chart.end_time_ms(),
			"types": _type_counts(chart),
			"density": density(chart),
			"waveform": load_waveform(path.get_base_dir(), chart.end_time_ms()),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["title"]).naturalnocasecmp_to(String(b["title"])) < 0)
	return out

static func _type_counts(chart: ChartData) -> Dictionary:
	var c := {"tap": 0, "hold": 0, "field": 0, "flick": 0}
	for n in chart.notes:
		match n.type:
			NoteData.Type.TAP:
				c["tap"] += 1
			NoteData.Type.HOLD:
				c["hold"] += 1
			NoteData.Type.FIELD:
				c["field"] += 1
			NoteData.Type.FLICK:
				c["flick"] += 1
	return c

## 곡 전체를 bins 칸으로 나눈 노트 밀도(0~1). Hold/Field는 걸친 칸마다 센다.
static func density(chart: ChartData, bins: int = 64) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(bins)
	var dur: float = maxf(chart.end_time_ms(), 1.0)
	for n in chart.notes:
		var a: int = mini(floori(n.time / dur * bins), bins - 1)
		var b: int = mini(floori(n.end_time / dur * bins), bins - 1)
		for i in range(a, b + 1):
			out[i] += 1.0
	var top: float = 1.0
	for v in out:
		top = maxf(top, v)
	for i in bins:
		out[i] /= top
	return out

## 곡 폴더의 waveform.json(tools/gen_waveform.py)을 읽는다. 없거나 잘못되면 빈 배열.
static func load_waveform(base_dir: String, chart_ms: float, bins: int = 256) -> PackedFloat32Array:
	var path := base_dir.path_join("waveform.json")
	if not FileAccess.file_exists(path):
		return PackedFloat32Array()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("파형 파일 형식이 올바르지 않습니다: " + path)
		return PackedFloat32Array()
	var root: Dictionary = parsed
	var raw: Variant = root.get("peaks", [])
	if typeof(raw) != TYPE_ARRAY:
		push_warning("파형 파일 형식이 올바르지 않습니다: " + path)
		return PackedFloat32Array()
	return envelope(resample_peaks(PackedFloat32Array(raw), float(root.get("duration_ms", 0.0)), chart_ms, bins))

## 봉우리 뒤를 천천히 떨어뜨려 이어진 실루엣으로 만든다. 소리가 드문 곡도 끊겨 보이지 않는다.
static func envelope(values: PackedFloat32Array, release: float = 0.88) -> PackedFloat32Array:
	var out := values.duplicate()
	for i in range(1, out.size()):
		out[i] = maxf(out[i], out[i - 1] * release)
	return out

## 오디오 전체 파형을 채보 길이(0~chart_ms)에 맞춰 bins 칸으로 줄인다. 노트 밀도와 시간축이 같아진다.
static func resample_peaks(peaks: PackedFloat32Array, audio_ms: float, chart_ms: float, bins: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if peaks.is_empty() or audio_ms <= 0.0 or chart_ms <= 0.0:
		return out
	out.resize(bins)
	var n: int = peaks.size()
	var top: float = 0.0
	for b in bins:
		var a: int = floori(chart_ms * b / bins / audio_ms * n)
		var e: int = ceili(chart_ms * (b + 1) / bins / audio_ms * n)
		for i in range(a, mini(e, n)):
			out[b] = maxf(out[b], peaks[i])
		top = maxf(top, out[b])
	if top > 0.0:
		for b in bins:
			out[b] /= top
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
