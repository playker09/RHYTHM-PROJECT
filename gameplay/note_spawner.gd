class_name NoteSpawner
extends Node
## 보이는 범위의 Tap/Hold/Flick 노트만 풀에서 꺼내 배치하고, 지나가면 풀로 돌려보낸다.
## 노트 위치는 곡 시간에서 직접 계산한다 (누적 이동 없음). Field는 FieldRenderer가 담당.

var time_fn: Callable

var _notes: Array[NoteData] = []    # Tap/Hold/Flick, time 오름차순
var _next: int = 0
var _active: Array[NoteData] = []
var _pools: Dictionary = {}         # NoteData.Type -> NotePool

func setup(chart: ChartData, parent: Node3D, judge: Judge) -> void:
	for n in chart.notes:
		n.reset_runtime()
		if n.type != NoteData.Type.FIELD:
			_notes.append(n)
	_pools[NoteData.Type.TAP] = NotePool.new(parent, NoteView.Kind.TAP, 32)
	_pools[NoteData.Type.HOLD] = NotePool.new(parent, NoteView.Kind.HOLD, 12)
	_pools[NoteData.Type.FLICK] = NotePool.new(parent, NoteView.Kind.FLICK, 12)
	judge.judged.connect(_on_judged)

func _speed_per_ms() -> float:
	return GameConst.SCROLL_UNITS_PER_SEC * Settings.hispeed / 1000.0

func _process(_delta: float) -> void:
	var now: float = time_fn.call()
	var speed: float = _speed_per_ms()
	var lookahead: float = GameConst.VIEW_DEPTH / speed

	while _next < _notes.size() and _notes[_next].time - now <= lookahead:
		var n: NoteData = _notes[_next]
		_next += 1
		if n.judged and n.type != NoteData.Type.HOLD:
			continue
		var view: NoteView = _pool(n).acquire()
		n.view = view
		if n.type == NoteData.Type.FLICK:
			view.set_flick_dir(n.dir)
		elif n.type == NoteData.Type.HOLD and n.head_hit:
			view.set_state(NoteView.State.HELD)
		_active.append(n)

	for i in range(_active.size() - 1, -1, -1):
		var n: NoteData = _active[i]
		if _is_finished(n, now):
			_release_view(n)
			_active.remove_at(i)
		else:
			_update_view(n, now, speed)

func _pool(n: NoteData) -> NotePool:
	return _pools[n.type]

func _is_finished(n: NoteData, now: float) -> bool:
	if n.type == NoteData.Type.HOLD:
		return now - n.end_time > 150.0
	return now - n.time > 300.0

func _update_view(n: NoteData, now: float, speed: float) -> void:
	var v: NoteView = n.view as NoteView
	match n.type:
		NoteData.Type.TAP:
			var x: float = (n.lane - (GameConst.LANE_COUNT - 1) * 0.5) * GameConst.LANE_WIDTH
			v.position = Vector3(x, 0.08, -(n.time - now) * speed)
		NoteData.Type.FLICK:
			var fx: float = (n.x - 0.5) * GameConst.FIELD_WIDTH
			v.position = Vector3(fx, GameConst.AIR_Y + 0.05, -(n.time - now) * speed + GameConst.AIR_Z)
		NoteData.Type.HOLD:
			var hx: float = (n.lane - (GameConst.LANE_COUNT - 1) * 0.5) * GameConst.LANE_WIDTH
			# 머리를 잡은 뒤에는 머리가 판정선에 붙어 있고 몸통만 줄어든다
			var head_t: float = n.time
			if n.head_hit:
				head_t = maxf(n.time, now)
			var head_z: float = -(head_t - now) * speed
			var tail_z: float = maxf(-(n.end_time - now) * speed, -GameConst.VIEW_DEPTH)
			v.position = Vector3(hx, 0.08, head_z)
			v.set_hold_extent(maxf(head_z - tail_z, 0.0))

func _release_view(n: NoteData) -> void:
	if n.view == null:
		return
	_pool(n).release(n.view as NoteView)
	n.view = null

func _on_judged(note: NoteData, grade: int, _delta: float, _is_tick: bool) -> void:
	var v: NoteView = note.view as NoteView
	if v == null:
		return
	var missed: bool = grade == JudgeLogic.Grade.MISS
	if note.type == NoteData.Type.HOLD:
		# 머리/tick 결과로 색 갱신
		v.set_state(NoteView.State.MISSED if missed else NoteView.State.HELD)
	elif missed:
		v.set_state(NoteView.State.MISSED)
	else:
		_release_view(note)
		_active.erase(note)
