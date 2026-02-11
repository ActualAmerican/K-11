extends RefCounted
class_name NoiseSystem

signal noise_changed(before: int, after: int, reason: String, meta: Dictionary)
signal heat_changed(before: int, after: int, reason: String, meta: Dictionary)
signal band_changed(before_band: int, after_band: int)
signal breach_started(meta: Dictionary)
signal breach_resolved(success: bool, meta: Dictionary)
signal alarm_triggered(v: int)

enum Band { QUIET, ALERT, DANGER, BREACH }

const NOISE_MAX := 100
const HEAT_MAX := 100

const DECAY_DELAY_S := 3.0
const DECAY_PER_SEC := 6.0

const BAND_ALERT_AT := 40
const BAND_DANGER_AT := 70
const BAND_BREACH_AT := 90

const PHONE_RING_INTERVAL_START_S := 10.0
const PHONE_RING_INTERVAL_MIN_S := 2.5
const PHONE_RING_INTERVAL_MUL := 0.85
const PHONE_RING_SPIKE_BASE := 6
const PHONE_HISS_PER_SEC := 0.0
const PHONE_HEAT_PER_RING := 2

var run_seed_u64: int = 0

var noise_i: int = 0
var heat_i: int = 0

var breach_active: bool = false

var phone_ringing: bool = false
var _phone_ring_timer_s: float = 0.0
var _phone_ring_interval_s: float = PHONE_RING_INTERVAL_START_S
var _phone_hiss_accum: float = 0.0

var last_reason: String = ""
var last_meta: Dictionary = {}

var _since_last_emit_s: float = 0.0
var _decay_accum: float = 0.0
var _band: int = Band.QUIET
var _policy: InterrogationTimePolicy = null
var _dev_log_enabled: bool = false
var _dev_log_cb: Callable = Callable()
var _dev_events: Array[Dictionary] = []
const DEV_LOG_MAX: int = 50
var _context_meta: Dictionary = {}
var _sensitivity: float = 1.0

func setup_run(seed_u64: int) -> void:
	# Keep seed available for later (breach checks, etc.), but 8.1 doesn't need RNG yet.
	run_seed_u64 = seed_u64
	reset_run()

func set_policy(policy: InterrogationTimePolicy) -> void:
	_policy = policy

func set_dev_logging(enabled: bool, cb: Callable = Callable()) -> void:
	_dev_log_enabled = enabled
	_dev_log_cb = cb

func set_context(meta: Dictionary) -> void:
	_context_meta = meta

func reset_run() -> void:
	noise_i = 0
	heat_i = 0
	breach_active = false
	last_reason = ""
	last_meta = {}
	_since_last_emit_s = 0.0
	_decay_accum = 0.0
	phone_ringing = false
	_phone_ring_timer_s = 0.0
	_phone_ring_interval_s = PHONE_RING_INTERVAL_START_S
	_phone_hiss_accum = 0.0
	_set_band(_band_for_noise(noise_i))
	_reset_sensitivity()

func start_suspect(start_noise: int = 0) -> void:
	noise_i = clampi(start_noise, 0, NOISE_MAX)
	breach_active = (noise_i >= NOISE_MAX)
	_since_last_emit_s = 0.0
	_decay_accum = 0.0
	last_reason = "suspect_start"
	last_meta = { "start_noise": noise_i }
	_set_band(_band_for_noise(noise_i))
	_reset_sensitivity()

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	if breach_active:
		return
	_since_last_emit_s += delta
	_relax_sensitivity(delta)
	# Phone ringing is a run-wide noise source (kettle). It must work even from 0 noise.
	if phone_ringing:
		_tick_phone(delta)
	if noise_i <= 0:
		return

	if _since_last_emit_s < DECAY_DELAY_S:
		return

	_decay_accum += DECAY_PER_SEC * delta
	var decay_pts := int(_decay_accum)
	if decay_pts <= 0:
		return

	_decay_accum -= float(decay_pts)

	var before := noise_i
	noise_i = max(0, noise_i - decay_pts)

	if noise_i != before:
		last_reason = "decay"
		last_meta = {}
		_set_band(_band_for_noise(noise_i))
		noise_changed.emit(before, noise_i, last_reason, last_meta)

func emit_noise(amount: int, reason: String, meta: Dictionary = {}, log_event: bool = true) -> void:
	# Noise should only go up from triggers; down only via decay.
	if amount <= 0:
		return

	var before := noise_i
	noise_i = clampi(noise_i + amount, 0, NOISE_MAX)

	_since_last_emit_s = 0.0
	_decay_accum = 0.0
	last_reason = reason
	last_meta = meta

	_set_band(_band_for_noise(noise_i))
	noise_changed.emit(before, noise_i, reason, meta)
	_raise_sensitivity_for_level(noise_i)
	if log_event:
		_dev_log_event(reason, amount, before, noise_i, meta)

	if (not breach_active) and noise_i >= NOISE_MAX:
		_trigger_breach(meta)

func apply_trigger(id: StringName, meta: Dictionary = {}) -> void:
	if _policy == null:
		return
	var def: NoiseTriggerDef = _policy.get_noise_trigger(id)
	if def == null:
		_dev_log_event("unknown", 0, noise_i, noise_i, {"id": String(id)})
		return
	var before := noise_i
	var combined_meta := _context_meta.duplicate()
	for k in meta.keys():
		combined_meta[k] = meta[k]
	combined_meta["trigger"] = String(id)
	combined_meta["sensitivity"] = _sensitivity
	combined_meta["base_delta"] = def.noise_delta
	if def.noise_delta > 0:
		var scaled := int(round(float(def.noise_delta) * _sensitivity))
		emit_noise(scaled, String(id), combined_meta, false)
	if def.heat_delta != 0:
		add_heat(def.heat_delta, String(id), combined_meta)
	var after := noise_i
	var applied := int(after - before)
	_dev_log_event(String(id), applied, before, after, combined_meta)

func _dev_log_event(trigger_id: String, delta: int, before: int, after: int, meta: Dictionary) -> void:
	if not _dev_log_enabled:
		return
	var line := "NOISE +%d (%d->%d) trigger=%s meta=%s" % [delta, before, after, trigger_id, str(meta)]
	_dev_events.append({
		"trigger": trigger_id,
		"delta": delta,
		"before": before,
		"after": after,
		"meta": meta,
		"time_msec": Time.get_ticks_msec()
	})
	while _dev_events.size() > DEV_LOG_MAX:
		_dev_events.pop_front()
	if not _dev_log_cb.is_null():
		_dev_log_cb.call(line)

func get_dev_events() -> Array[Dictionary]:
	return _dev_events

func _reset_sensitivity() -> void:
	_sensitivity = 1.0
	if _policy != null:
		_sensitivity = clampf(_policy.sensitivity_min, 0.1, _policy.sensitivity_max)

func _relax_sensitivity(delta: float) -> void:
	if _policy == null:
		_sensitivity = maxf(1.0, _sensitivity)
		return
	if _policy.sensitivity_relax_per_sec <= 0.0:
		return
	var min_v := _policy.sensitivity_min
	var relax := _policy.sensitivity_relax_per_sec
	_sensitivity = maxf(min_v, _sensitivity - (relax * delta))

func _raise_sensitivity_for_level(noise_value: int) -> void:
	if _policy == null:
		return
	var next := _sensitivity
	var step := maxi(_policy.sensitivity_step_size, 1)
	var idx := clampi(int(floor(float(noise_value) / float(step))), 0, _policy.sensitivity_steps.size() - 1)
	if _policy.sensitivity_steps.size() > 0:
		next = maxf(next, _policy.sensitivity_steps[idx])
	_sensitivity = clampf(next, _policy.sensitivity_min, _policy.sensitivity_max)

func _tick_phone(delta: float) -> void:
	# no per-second drip; escalation is driven by ring spikes only
	_phone_hiss_accum += PHONE_HISS_PER_SEC * delta
	var hiss_pts := int(_phone_hiss_accum)
	if hiss_pts > 0:
		_phone_hiss_accum -= float(hiss_pts)
		emit_noise(hiss_pts, "phone:hiss", {})

	# ring spikes (interval shrinks)
	_phone_ring_timer_s += delta
	if _phone_ring_timer_s >= _phone_ring_interval_s:
		_phone_ring_timer_s = 0.0
		emit_noise(PHONE_RING_SPIKE_BASE, "phone:ring", { "interval": _phone_ring_interval_s })
		add_heat(PHONE_HEAT_PER_RING, "phone:ring", {})
		_phone_ring_interval_s = max(PHONE_RING_INTERVAL_MIN_S, _phone_ring_interval_s * PHONE_RING_INTERVAL_MUL)

func add_heat(amount: int, reason: String, meta: Dictionary = {}) -> void:
	if amount == 0:
		return
	var before := heat_i
	heat_i = clampi(heat_i + amount, 0, HEAT_MAX)
	if heat_i != before:
		heat_changed.emit(before, heat_i, reason, meta)

func resolve_breach(success: bool, meta: Dictionary = {}, drop_to: int = 80) -> void:
	if not breach_active:
		return

	breach_active = false

	if success:
		var before := noise_i
		noise_i = clampi(drop_to, 0, NOISE_MAX)
		_since_last_emit_s = 0.0
		_decay_accum = 0.0
		last_reason = "breach_resolve_success"
		last_meta = meta
		_set_band(_band_for_noise(noise_i))
		noise_changed.emit(before, noise_i, last_reason, last_meta)

	breach_resolved.emit(success, meta)

func get_noise() -> int:
	return noise_i

func get_heat() -> int:
	return heat_i

func get_band() -> int:
	return _band

func start_phone_ringing() -> void:
	if phone_ringing:
		return
	phone_ringing = true
	_phone_ring_timer_s = 0.0
	_phone_ring_interval_s = PHONE_RING_INTERVAL_START_S
	_phone_hiss_accum = 0.0

func stop_phone_ringing() -> void:
	if not phone_ringing:
		return
	phone_ringing = false
	_phone_ring_timer_s = 0.0
	_phone_ring_interval_s = PHONE_RING_INTERVAL_START_S
	_phone_hiss_accum = 0.0

func is_phone_ringing() -> bool:
	return phone_ringing

func band_name(b: int = -1) -> String:
	var v := b if b >= 0 else _band
	match v:
		Band.QUIET: return "QUIET"
		Band.ALERT: return "ALERT"
		Band.DANGER: return "DANGER"
		Band.BREACH: return "BREACH"
		_: return "UNKNOWN"

func heat_mult(mult_at_100: float = 0.30) -> float:
	return 1.0 + (clampf(float(heat_i) / float(HEAT_MAX), 0.0, 1.0) * mult_at_100)

func _trigger_breach(meta: Dictionary) -> void:
	breach_active = true
	last_reason = "breach_started"
	last_meta = meta
	breach_started.emit(meta)
	alarm_triggered.emit(noise_i)

func _band_for_noise(v: int) -> int:
	if v >= BAND_BREACH_AT:
		return Band.BREACH
	if v >= BAND_DANGER_AT:
		return Band.DANGER
	if v >= BAND_ALERT_AT:
		return Band.ALERT
	return Band.QUIET

func _set_band(next_band: int) -> void:
	if next_band == _band:
		return
	var before := _band
	_band = next_band
	band_changed.emit(before, next_band)

func is_breach_active() -> bool:
	return breach_active
