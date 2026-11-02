class_name NotePool
extends RefCounted
## NoteView 재사용 풀. 플레이 중 노드 생성/해제가 없도록 미리 만들어 둔다.

var _free: Array[NoteView] = []
var _parent: Node3D
var _kind: int

func _init(parent: Node3D, kind: int, prewarm: int = 24) -> void:
	_parent = parent
	_kind = kind
	for i in prewarm:
		_free.append(_make())

func acquire() -> NoteView:
	var v: NoteView = _free.pop_back() if not _free.is_empty() else _make()
	v.visible = true
	v.set_state(NoteView.State.NORMAL)
	return v

func release(v: NoteView) -> void:
	v.visible = false
	_free.append(v)

func _make() -> NoteView:
	var v := NoteView.create(_kind)
	v.visible = false
	_parent.add_child(v)
	return v
