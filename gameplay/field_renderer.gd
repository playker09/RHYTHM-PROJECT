class_name FieldRenderer
extends Node
## 보이는 Field 노트에 FieldView를 배정한다. 뷰는 재사용한다.

var time_fn: Callable

var _fields: Array[NoteData] = []
var _first: int = 0
var _controller: FieldController
var _parent: Node3D
var _views: Dictionary = {}          # NoteData -> FieldView
var _free: Array[FieldView] = []

func setup(chart: ChartData, parent: Node3D, controller: FieldController) -> void:
	_parent = parent
	_controller = controller
	for n in chart.notes:
		if n.type == NoteData.Type.FIELD:
			_fields.append(n)

func _process(_delta: float) -> void:
	var now: float = time_fn.call()
	var speed: float = GameConst.SCROLL_UNITS_PER_SEC * Settings.hispeed / 1000.0
	var lookahead: float = GameConst.VIEW_DEPTH / speed
	while _first < _fields.size() and _fields[_first].end_time < now:
		_release(_fields[_first])
		_first += 1
	for i in range(_first, _fields.size()):
		var n: NoteData = _fields[i]
		if n.time - now > lookahead:
			break                     # 시간순 정렬이므로 이후는 모두 아직 먼 노트
		var view: FieldView = _views.get(n)
		if view == null:
			view = _acquire()
			_views[n] = view
		var active: bool = n.time <= now
		view.draw(n, now, speed, lookahead, active and _controller.is_outside)

func _acquire() -> FieldView:
	var v: FieldView = _free.pop_back() if not _free.is_empty() else _make()
	v.visible = true
	return v

func _make() -> FieldView:
	var v := FieldView.new()
	_parent.add_child(v)
	return v

func _release(n: NoteData) -> void:
	var v: FieldView = _views.get(n)
	if v == null:
		return
	v.visible = false
	_views.erase(n)
	_free.append(v)
