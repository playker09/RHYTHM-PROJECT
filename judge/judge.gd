class_name Judge
extends Node
## 입력 이벤트 -> JudgeLogic -> 시그널.
## 키 입력은 _input 이벤트 시점의 곡 시간으로 판정한다 (프레임 폴링 아님).

## delta_ms: 입력 - 노트 시각 (tick은 0)
signal judged(note: NoteData, grade: int, delta_ms: float, is_tick: bool)
signal lane_changed(lane: int, pressed: bool)

class TickEvent:
	var time: float
	var lane: int
	var note: NoteData
	func _init(t: float, l: int, n: NoteData) -> void:
		time = t
		lane = l
		note = n

var time_fn: Callable                 # 곡 시간(ms)을 돌려주는 함수
var field: FieldController            # 없으면 Field/마우스 입력은 무시
var total_judgements: int = 0         # 점수 정규화용 (head + tick 총합)

var _queues: Array = []               # lane별 미판정 Tap/Hold head 큐
var _ptrs: Array[int] = []
var _pressed: Array[bool] = []
var _ticks: Array[TickEvent] = []
var _tick_ptr: int = 0
var _flicks: Array[NoteData] = []     # time 오름차순
var _flick_ptr: int = 0

func setup(chart: ChartData) -> void:
	_queues.clear()
	_ptrs.clear()
	_pressed.clear()
	_ticks.clear()
	_flicks.clear()
	_flick_ptr = 0
	_tick_ptr = 0
	total_judgements = 0
	for i in GameConst.LANE_COUNT:
		_queues.append([])
		_ptrs.append(0)
		_pressed.append(false)
	for n in chart.notes:
		if n.type == NoteData.Type.FLICK:
			_flicks.append(n)
			total_judgements += 1
			continue
		if n.type == NoteData.Type.FIELD:
			for t in chart.timing.tick_times(n.time, n.end_time, GameConst.TICK_BEAT_FRACTION):
				_ticks.append(TickEvent.new(t, -1, n))
				total_judgements += 1
			continue
		if n.type != NoteData.Type.TAP and n.type != NoteData.Type.HOLD:
			continue
		var q: Array = _queues[n.lane]
		q.append(n)
		total_judgements += 1
		if n.type == NoteData.Type.HOLD:
			for t in chart.timing.tick_times(n.time, n.end_time, GameConst.TICK_BEAT_FRACTION):
				_ticks.append(TickEvent.new(t, n.lane, n))
				total_judgements += 1
	_ticks.sort_custom(func(a: TickEvent, b: TickEvent) -> bool: return a.time < b.time)

func is_pressed(lane: int) -> bool:
	return _pressed[lane]

func _process(_delta: float) -> void:
	advance(time_fn.call())

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		move_cursor((event as InputEventMouseMotion).relative.x, time_fn.call())
		return
	for i in GameConst.LANE_COUNT:
		var action: String = "lane_%d" % i
		if event.is_action_pressed(action):
			press(i, time_fn.call())
		elif event.is_action_released(action):
			release(i, time_fn.call())

## 시간 경과 처리: 놓친 노트 MISS, 지나간 tick 판정
func advance(now_ms: float) -> void:
	if field != null:
		field.update(now_ms)
	_advance_ticks(now_ms)
	_expire_flicks(now_ms)
	for i in GameConst.LANE_COUNT:
		_expire(i, now_ms)

func press(lane: int, now_ms: float) -> void:
	_advance_ticks(now_ms)       # 누르기 직전까지의 tick은 '안 눌린 상태'로 판정
	_pressed[lane] = true
	lane_changed.emit(lane, true)
	_expire(lane, now_ms)
	var q: Array = _queues[lane]
	var p: int = _ptrs[lane]
	if p >= q.size():
		return
	var note: NoteData = q[p]
	var delta: float = now_ms - note.time
	var grade: int = JudgeLogic.grade_from_delta(delta)
	if grade == JudgeLogic.Grade.MISS:
		return                   # 너무 이른 입력은 무시
	note.judged = true
	note.head_hit = true
	_ptrs[lane] = p + 1
	judged.emit(note, grade, delta, false)

## 마우스 이동(픽셀) 처리: Field tick 정산 -> 커서 이동 -> Flick 통과 검사
func move_cursor(dx_pixels: float, now_ms: float) -> void:
	if field == null:
		return
	_advance_ticks(now_ms)       # 커서가 움직이기 직전까지의 tick은 이전 위치로 판정
	var prev_x: float = field.cursor_x
	field.apply_motion(dx_pixels, now_ms)
	_check_flicks(prev_x, field.cursor_x, field.velocity(), now_ms)

func _check_flicks(prev_x: float, new_x: float, velocity: float, now_ms: float) -> void:
	if prev_x == new_x:
		return
	for i in range(_flick_ptr, _flicks.size()):
		var n: NoteData = _flicks[i]
		if n.time - now_ms > GameConst.FLICK_WINDOW_MS:
			break                # 정렬되어 있으므로 이후 노트는 아직 멀다
		if n.judged:
			continue
		if not JudgeLogic.flick_crossed(prev_x, new_x, n.x, n.dir):
			continue
		if not JudgeLogic.flick_speed_ok(velocity, n.dir, GameConst.FLICK_MIN_SPEED):
			continue
		var delta: float = now_ms - n.time
		var grade: int = JudgeLogic.flick_grade(delta)
		if grade == JudgeLogic.Grade.MISS:
			continue             # 윈도우 밖 (너무 이른 통과)
		n.judged = true
		n.head_hit = true
		judged.emit(n, grade, delta, false)

func _expire_flicks(now_ms: float) -> void:
	while _flick_ptr < _flicks.size():
		var n: NoteData = _flicks[_flick_ptr]
		if n.judged:
			_flick_ptr += 1
		elif JudgeLogic.flick_missed(now_ms, n.time):
			n.judged = true
			_flick_ptr += 1
			judged.emit(n, JudgeLogic.Grade.MISS, 0.0, false)
		else:
			break

func release(lane: int, now_ms: float) -> void:
	_advance_ticks(now_ms)       # 놓기 직전까지의 tick은 '눌린 상태'로 판정
	_pressed[lane] = false
	lane_changed.emit(lane, false)

func _expire(lane: int, now_ms: float) -> void:
	var q: Array = _queues[lane]
	var p: int = _ptrs[lane]
	while p < q.size():
		var note: NoteData = q[p]
		if not JudgeLogic.is_missed(now_ms, note.time):
			break
		note.judged = true
		p += 1
		judged.emit(note, JudgeLogic.Grade.MISS, 0.0, false)
	_ptrs[lane] = p

func _advance_ticks(now_ms: float) -> void:
	while _tick_ptr < _ticks.size() and _ticks[_tick_ptr].time <= now_ms:
		var e: TickEvent = _ticks[_tick_ptr]
		_tick_ptr += 1
		var grade: int
		if e.note.type == NoteData.Type.FIELD:
			grade = field.evaluate_tick(e.note, e.time) if field != null else JudgeLogic.Grade.MISS
			if grade == JudgeLogic.GRADE_SKIP:
				continue         # 이탈 유예 중: 판정 없음 (콤보/점수 모두 변화 없음)
		else:
			grade = JudgeLogic.Grade.PERFECT if _pressed[e.lane] else JudgeLogic.Grade.MISS
		judged.emit(e.note, grade, 0.0, true)
