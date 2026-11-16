class_name ChartLoader
extends RefCounted
## JSON 채보 -> ChartData. 시간 단위는 ms.

const DIFFS: Array[String] = ["EZ", "NM", "HD"]
const DIFF_FILES: Array[String] = ["ez.json", "nm.json", "hd.json"]
const JACKET_FILES: Array[String] = ["jacket.png", "jacket.jpg", "jacket.webp"]
const TUTORIAL_DIR := "tutorial"                          # 선곡 목록에 나오지 않는 연습 채보 폴더
const TUTORIAL_CHART := "res://charts/tutorial/ez.json"

## res://charts/*/ 를 훑어 선곡 화면용 곡 목록을 만든다 (제목순).
## 곡 = {dir, title, artist, audio, bpm, bpm_hi, jacket, duration_ms, waveform, diffs}
## diffs = 난이도 슬롯(EZ/NM/HD)별 요약. 파일이 없는 슬롯은 빈 Dictionary.
static func list_songs() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://charts")
	if dir == null:
		return out
	for d in dir.get_directories():
		if d == TUTORIAL_DIR:
			continue
		var song := _load_song("res://charts/%s" % d, d)
		if not song.is_empty():
			out.append(song)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["title"]).naturalnocasecmp_to(String(b["title"])) < 0)
	return out

static func _load_song(base: String, fallback_title: String) -> Dictionary:
	var diffs: Array = []
	var song: Dictionary = {}
	var longest: float = 0.0
	for file in DIFF_FILES:
		var path: String = base.path_join(file)
		var chart: ChartData = load_chart(path) if FileAccess.file_exists(path) else null
		if chart == null:
			diffs.append({})
			continue
		if song.is_empty():
			# 곡 정보는 처음 찾은 채보의 meta 를 쓴다
			song = {
				"dir": base,
				"title": chart.title if chart.title != "" else fallback_title,
				"artist": chart.artist,
				"audio": base.path_join(chart.audio),
				"bpm": chart.timing.bpm_min(),
				"bpm_hi": chart.timing.bpm_max(),
				"jacket": find_jacket(base),
			}
		longest = maxf(longest, chart.end_time_ms())
		diffs.append({
			"path": path,
			"level": chart.level,
			"notes": chart.notes.size(),
			"total": chart.total_judgements(),
			"duration_ms": chart.end_time_ms(),
			"types": _type_counts(chart),
			"density": density(chart),
		})
	if song.is_empty():
		return {}
	song["diffs"] = diffs
	song["duration_ms"] = longest
	song["waveform"] = load_waveform(base, longest)
	return song

## 곡 폴더의 guide.json(화면 안내 문구, 튜토리얼용)을 읽는다. 없으면 빈 배열.
## 항목 = {time, end, text, pad, focus}  (ms. pad = 컨트롤러용 문구, 없으면 text 와 같다.
##   focus = 그동안 노랗게 강조할 조작 부위: "keys"(키 패드) | "air"(공중 판정선·커서) | "")
static func load_guides(base_dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var path := base_dir.path_join("guide.json")
	if not FileAccess.file_exists(path):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var raw: Variant = (parsed as Dictionary).get("guides", []) if typeof(parsed) == TYPE_DICTIONARY else null
	if typeof(raw) != TYPE_ARRAY:
		push_warning("안내 문구 파일 형식이 올바르지 않습니다: " + path)
		return out
	for item: Variant in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = item
		if not _is_num(d.get("time")) or not _is_num(d.get("end")) or typeof(d.get("text")) != TYPE_STRING:
			push_warning("잘못된 guide 무시: " + str(d))
			continue
		var text: String = d["text"]
		out.append({"time": float(d["time"]), "end": float(d["end"]), "text": text,
			"pad": str(d["pad"]) if typeof(d.get("pad")) == TYPE_STRING else text,
			"focus": str(d["focus"]) if typeof(d.get("focus")) == TYPE_STRING else ""})
	return out

## 곡 시간 t 에 띄울 안내 문구. 없으면 "".
static func guide_at(guides: Array[Dictionary], t: float, controller: bool) -> String:
	for g in guides:
		if t >= g["time"] and t < g["end"]:
			return g["pad"] if controller else g["text"]
	return ""

## 곡 시간 t 에 강조할 조작 부위("keys" | "air"). 없으면 "".
static func focus_at(guides: Array[Dictionary], t: float) -> String:
	for g in guides:
		if t >= g["time"] and t < g["end"]:
			return g["focus"]
	return ""

static func find_jacket(base: String) -> String:
	for f in JACKET_FILES:
		if ResourceLoader.exists(base.path_join(f)):
			return base.path_join(f)
	return ""

## want 슬롯에 채보가 없으면 가장 가까운 슬롯을 돌려준다 (동점이면 쉬운 쪽). 하나도 없으면 -1.
static func nearest_diff(diffs: Array, want: int) -> int:
	var best: int = -1
	var best_dist: int = 99
	for i in diffs.size():
		if (diffs[i] as Dictionary).is_empty():
			continue
		var dist: int = absi(i - want)
		if dist < best_dist:
			best = i
			best_dist = dist
	return best

## 채보 파일 경로 -> 난이도 슬롯 번호 (모르면 -1)
static func diff_of_path(path: String) -> int:
	return DIFF_FILES.find(path.get_file())

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
	var slot: int = diff_of_path(path)
	chart.difficulty = DIFFS[slot] if slot >= 0 else str(meta.get("difficulty", ""))
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
	var fx_raw: Variant = root.get("effects", [])
	if typeof(fx_raw) == TYPE_ARRAY:
		chart.effects = parse_effects(fx_raw)
	return chart

## 연출 종류별 기본값 (패턴 툴 web/core.js 의 FX 와 같다)
const FX_DEFAULTS := {
	"flash": {"duration": 0.0, "side": "left", "strength": 1.0},
	"glitch": {"duration": 500.0, "strength": 0.5},
	"spin": {"duration": 2000.0, "turns": 1.0, "dir": "cw"},
}

## effects 배열 -> 정리된 연출 목록 (time 오름차순). 모르는 종류/잘못된 항목은 버리고, 빠진 값은 기본값으로 채운다.
static func parse_effects(raw: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			push_warning("잘못된 effect 항목 무시: " + str(item))
			continue
		var d: Dictionary = item
		var kind: String = str(d.get("type", ""))
		if not FX_DEFAULTS.has(kind) or not _is_num(d.get("time")):
			push_warning("잘못된 effect 무시: " + str(d))
			continue
		var def: Dictionary = FX_DEFAULTS[kind]
		var e: Dictionary = {"type": kind, "time": float(d["time"])}
		for k: String in def:
			var v: Variant = d.get(k)
			if typeof(def[k]) == TYPE_STRING:
				e[k] = str(v) if typeof(v) == TYPE_STRING else def[k]
			else:
				e[k] = float(v) if _is_num(v) else def[k]
		e["duration"] = maxf(e["duration"], 0.0)
		out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	return out

static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT

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
			f.width = clampf(float(d["width"]), GameConst.FLICK_MIN_WIDTH, 1.0) if _is_num(d.get("width")) else GameConst.FLICK_DEFAULT_WIDTH
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
