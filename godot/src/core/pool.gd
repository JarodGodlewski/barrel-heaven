class_name ObjectPool
extends RefCounted

var _idle: Array[Node] = []
var _factory: Callable
var max_count: int = 0
var total_spawned: int = 0
var active_count: int = 0


func configure(factory: Callable, warmup := 0, p_max := 0) -> void:
	_factory = factory
	max_count = p_max
	for i in warmup:
		var n: Node = _factory.call()
		if n is CanvasItem or n is Node3D:
			n.visible = false
		_idle.append(n)
		total_spawned += 1


func take() -> Node:
	var n: Node
	if _idle.size() > 0:
		n = _idle.pop_back()
	else:
		if max_count > 0 and total_spawned >= max_count:
			push_warning("ObjectPool exhausted (%d)" % max_count)
		n = _factory.call()
		total_spawned += 1
	if n is CanvasItem or n is Node3D:
		n.visible = true
	active_count += 1
	return n


func give(n: Node) -> void:
	if n is CanvasItem or n is Node3D:
		n.visible = false
	_idle.append(n)
	active_count = maxi(0, active_count - 1)


func idle_count() -> int:
	return _idle.size()
