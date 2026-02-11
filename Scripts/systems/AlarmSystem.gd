extends RefCounted
class_name AlarmSystem

signal alarm_started(meta: Dictionary)
signal alarm_tick(seconds_left: int)
signal alarm_timed_out(meta: Dictionary)
signal alarm_stopped(meta: Dictionary)

var grace_s: int = 30
var seconds_left: int = 0
var active: bool = false

var _meta: Dictionary = {}
var _stub: CanvasItem = null
var _blink: bool = false
var _time_left_f: float = 0.0
var _blink_accum: float = 0.0

func configure(p_grace_s: int) -> void:
	grace_s = maxi(p_grace_s, 1)

func bind_stub(p_stub: CanvasItem) -> void:
	_stub = p_stub
	_apply_stub(false)

func is_active() -> bool:
	return active

func get_seconds_left() -> int:
	return seconds_left

func start(meta: Dictionary = {}) -> void:
	if active:
		return
	active = true
	_meta = meta
	seconds_left = grace_s
	_time_left_f = float(grace_s)
	_blink_accum = 0.0
	_blink = false
	_apply_stub(true)
	alarm_started.emit(meta)
	alarm_tick.emit(seconds_left)

func stop(meta: Dictionary = {}) -> void:
	if not active:
		return
	active = false
	seconds_left = 0
	_time_left_f = 0.0
	_apply_stub(false)
	alarm_stopped.emit(meta)

func tick(delta: float) -> void:
	if not active:
		return
	if delta <= 0.0:
		return
	var d := minf(delta, 0.25)
	_time_left_f = maxf(_time_left_f - d, 0.0)
	var new_seconds := int(ceil(_time_left_f))
	if new_seconds != seconds_left:
		seconds_left = new_seconds
		alarm_tick.emit(seconds_left)
	_blink_accum += delta
	if _blink_accum >= 0.5:
		_blink_accum = 0.0
		_blink = not _blink
		_apply_blink()
	if _time_left_f <= 0.0:
		active = false
		_apply_stub(false)
		alarm_timed_out.emit(_meta)

func _apply_stub(on: bool) -> void:
	if _stub == null:
		return
	_stub.visible = on
	_apply_blink()

func _apply_blink() -> void:
	if _stub == null:
		return
	_stub.modulate.a = 0.18 if _blink else 0.08
