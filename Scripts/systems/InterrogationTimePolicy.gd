extends Resource
class_name InterrogationTimePolicy

@export var tier_size: int = 10
@export var tier_deadlines_s: PackedInt32Array = PackedInt32Array([90, 75, 65, 55])
@export var min_deadline_s: int = 45
@export var deadline_stage_multipliers: PackedFloat32Array = PackedFloat32Array([1.0, 0.7, 0.4])
@export var min_stage_deadline_s: int = 10
@export var ingame_minutes_per_real_second: float = 1.0
@export var clock_start_minutes: int = 540
@export var clock_gap_min_minutes: int = 60
@export var clock_gap_max_minutes: int = 240
@export var noise_breach_kill_delay_s: float = 30.0
@export var noise_breach_game_over_overlay_id: String = "GAME_OVER"
@export var breach_grace_s: int = 30
@export var breach_resolve_drop_to: int = 80

@export var phone_ring_interval_start_s: float = 8.0
@export var phone_ring_interval_min_s: float = 2.5
@export var phone_ring_interval_mul: float = 0.85
@export var phone_spike_base: int = 6
@export var phone_spike_add_per_ring: int = 2
@export var phone_heat_per_ring: int = 2
@export_group("Noise Triggers")
@export var noise_triggers: Array[NoiseTriggerDef] = []
@export_group("Noise Sensitivity")
@export var sensitivity_min: float = 1.0
@export var sensitivity_max: float = 2.0
@export var sensitivity_relax_per_sec: float = 0.0
@export var sensitivity_step_size: int = 10
@export var sensitivity_steps: PackedFloat32Array = PackedFloat32Array([1.0, 1.05, 1.1, 1.15, 1.2, 1.3, 1.4, 1.55, 1.7, 1.85])

func get_deadline_s(suspect_index: int) -> int:
	var size := maxi(tier_size, 1)
	var tier_idx := int(suspect_index / size)
	var v: int = min_deadline_s
	if tier_idx >= 0 and tier_idx < tier_deadlines_s.size():
		v = int(tier_deadlines_s[tier_idx])
	return maxi(min_deadline_s, v)

func get_deadline_stage_s(base_deadline_s: int, stage_index: int) -> int:
	if deadline_stage_multipliers.is_empty():
		return maxi(min_stage_deadline_s, base_deadline_s)
	var idx := clampi(stage_index, 0, deadline_stage_multipliers.size() - 1)
	var mult := float(deadline_stage_multipliers[idx])
	return maxi(min_stage_deadline_s, int(round(float(base_deadline_s) * mult)))

func get_clock_gap_minutes(rng: RandomNumberGenerator) -> int:
	if rng == null:
		return clock_gap_min_minutes
	return int(rng.randi_range(clock_gap_min_minutes, clock_gap_max_minutes))

var _noise_trigger_cache: Dictionary = {}
var _noise_trigger_cache_valid: bool = false

func get_noise_trigger(id: StringName) -> NoiseTriggerDef:
	if not _noise_trigger_cache_valid or _noise_trigger_cache.size() != noise_triggers.size():
		_noise_trigger_cache.clear()
		for t in noise_triggers:
			if t == null:
				continue
			_noise_trigger_cache[t.id] = t
		_noise_trigger_cache_valid = true
	return _noise_trigger_cache.get(id, null)
