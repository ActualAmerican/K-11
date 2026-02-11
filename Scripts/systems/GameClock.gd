extends RefCounted
class_name GameClock

var real_elapsed_s: float = 0.0
var ingame_minutes_f: float = 0.0
var minutes_per_real_second: float = 1.0
var start_minutes: int = 0

func setup(minutes_per_sec: float, start_minutes_in: int) -> void:
	minutes_per_real_second = minutes_per_sec
	start_minutes = start_minutes_in
	reset()

func reset() -> void:
	real_elapsed_s = 0.0
	ingame_minutes_f = float(start_minutes)

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	real_elapsed_s += delta
	ingame_minutes_f += minutes_per_real_second * delta

func set_minutes(minutes: int) -> void:
	ingame_minutes_f = float(minutes)

func add_minutes(minutes: int) -> void:
	ingame_minutes_f += float(minutes)

func get_clock_minutes_int() -> int:
	return int(floor(ingame_minutes_f))

func format_hhmm(minutes: int) -> String:
	var m := minutes % 60
	var h := int(minutes / 60)
	h = h % 24
	return "%02d:%02d" % [h, m]
