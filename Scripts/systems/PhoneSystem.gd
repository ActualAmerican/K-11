extends RefCounted
class_name PhoneSystem

var ringing: bool = false
var ring_count: int = 0
var _timer: float = 0.0
var _interval: float = 0.0
var _reason: String = ""

var _noise: NoiseSystem = null
var _policy: InterrogationTimePolicy = null

func setup(noise: NoiseSystem, policy: InterrogationTimePolicy) -> void:
	_noise = noise
	_policy = policy
	_reset_timers()

func start(reason: String = "") -> void:
	ringing = true
	_reason = reason
	_reset_timers()

func stop() -> void:
	ringing = false
	_reason = ""
	_reset_timers()

func toggle_dev() -> void:
	if ringing:
		stop()
	else:
		start("dev")

func tick(delta: float) -> void:
	if not ringing:
		return
	if _noise == null or _policy == null:
		return
	if delta <= 0.0:
		return
	_timer += delta
	if _timer < _interval:
		return
	_timer = 0.0
	ring_count += 1
	var spike := _policy.phone_spike_base + (ring_count * _policy.phone_spike_add_per_ring)
	_noise.emit_noise(spike, "phone:ring", {"count": ring_count, "interval": _interval, "reason": _reason})
	_noise.add_heat(_policy.phone_heat_per_ring, "phone:ring", {"count": ring_count, "interval": _interval, "reason": _reason})
	_interval = max(_policy.phone_ring_interval_min_s, _interval * _policy.phone_ring_interval_mul)

func _reset_timers() -> void:
	ring_count = 0
	_timer = 0.0
	if _policy != null:
		_interval = _policy.phone_ring_interval_start_s
