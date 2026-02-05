extends RefCounted
class_name RevolverSystem


const CHAMBER_COUNT := 6
const DANGER_STEP_POINTS := 100

var run_seed_u64: int = 0
var danger_fill: int = 0 # 0..99
var danger: int = 0 # optional tier 0..6

var live_mask: int = 0
var consumed_mask: int = 0
var current_index: int = 0

var _op_id: int = 0
var _cycle_id: int = 0
var _fire_id: int = 0

func setup(seed_u64: int) -> void:
	run_seed_u64 = SeedUtil.normalize_seed(seed_u64)
	danger = 0
	danger_fill = 0
	live_mask = 0
	consumed_mask = 0
	current_index = 0
	_op_id = 0
	_cycle_id = 0

func set_danger(v: int) -> void:
	danger = clampi(v, 0, CHAMBER_COUNT)

func set_danger_fill(v: int) -> void:
	danger_fill = clampi(v, 0, DANGER_STEP_POINTS - 1)

func add_danger_fill(delta: int) -> int:
	if delta == 0:
		return 0
	var total := maxi(danger_fill + delta, 0)
	var crosses := int(total / float(DANGER_STEP_POINTS))
	var rem := total % DANGER_STEP_POINTS
	danger_fill = rem

	var injected := 0
	for _i in range(crosses):
		danger = clampi(danger + 1, 0, CHAMBER_COUNT)
		var idx := add_live_round_random()
		if idx >= 0:
			injected += 1
	return injected

func load_fresh_cylinder() -> void:
	_cycle_id += 1
	consumed_mask = 0
	current_index = 0
	live_mask = 0
	var to_add := clampi(danger, 0, CHAMBER_COUNT)
	if to_add > 0:
		var rng := _rng("fresh_load", _cycle_id)
		var pool: Array[int] = []
		for i in range(CHAMBER_COUNT):
			pool.append(i)

		# Fisher-Yates shuffle with deterministic RNG
		for n in range(pool.size()):
			var j := n + rng.randi_range(0, pool.size() - n - 1)
			var tmp := pool[n]
			pool[n] = pool[j]
			pool[j] = tmp

		for i in range(to_add):
			live_mask |= (1 << pool[i])
	print("[K11] REVOLVER: cycle reset (6 pulls used) tier=%d live=%d live_mask=%d consumed_mask=%d" % [
		to_add,
		to_add,
		live_mask,
		consumed_mask
	])

func debug_chambers() -> Dictionary:
	var full: Array[int] = []
	var empty: Array[int] = []
	var consumed: Array[int] = []
	var available: Array[int] = []
	for i in range(CHAMBER_COUNT):
		var id := i + 1
		if ((live_mask >> i) & 1) == 1:
			full.append(id)
		else:
			empty.append(id)
		if ((consumed_mask >> i) & 1) == 1:
			consumed.append(id)
		else:
			available.append(id)
	return {
		"full": full,
		"empty": empty,
		"consumed": consumed,
		"available": available
	}

func ensure_cycle_ready(label: String = "") -> void:
	if (live_mask & consumed_mask) != 0:
		print("[K11] REVOLVER WARN: live+consumed overlap (illegal) live_mask=%d consumed_mask=%d" % [
			live_mask,
			consumed_mask
		])
		live_mask &= ~consumed_mask
	if consumed_mask == 63:
		load_fresh_cylinder()
		_fire_id = 0
		print("[K11] REVOLVER: cycle reset (6 pulls used) tier=%d live=%d live_mask=%d consumed_mask=%d label=%s" % [
			clampi(danger, 0, CHAMBER_COUNT),
			_popcount(live_mask),
			live_mask,
			consumed_mask,
			label
		])

func fire_random_unconsumed(label: String = "fire") -> Dictionary:
	ensure_cycle_ready("fire_random_unconsumed:" + label)

	var candidates: Array[int] = []
	for i in range(CHAMBER_COUNT):
		if ((consumed_mask >> i) & 1) == 0:
			candidates.append(i)

	var rng := _rng("rev_fire:" + label, _fire_id)
	_fire_id += 1
	var pick := rng.randi_range(0, candidates.size() - 1)
	var idx := candidates[pick]
	current_index = idx
	var was_live := ((live_mask >> idx) & 1) == 1
	consumed_mask |= (1 << idx)
	if was_live:
		live_mask &= ~(1 << idx)
		danger = clampi(danger - 1, 0, CHAMBER_COUNT)

	return {
		"idx": idx,
		"was_live": was_live
	}

func fire_overflow_full(label: String = "overflow") -> Dictionary:
	ensure_cycle_ready("fire_overflow_full:" + label)
	if live_mask != 63:
		return {
			"fired": false,
			"idx": -1
		}
	var rng := _rng("rev_overflow:" + label, _fire_id)
	_fire_id += 1
	var idx := rng.randi_range(0, CHAMBER_COUNT - 1)
	current_index = idx
	consumed_mask |= (1 << idx)
	live_mask &= ~(1 << idx)
	danger = clampi(danger - 1, 0, CHAMBER_COUNT)
	return {
		"fired": true,
		"idx": idx
	}

func add_live_round_random() -> int:
	# Prefer empty + unconsumed.
	var candidates: Array[int] = []
	for i in range(CHAMBER_COUNT):
		var is_live := ((live_mask >> i) & 1) == 1
		var is_consumed := ((consumed_mask >> i) & 1) == 1
		if (not is_live) and (not is_consumed):
			candidates.append(i)

	if candidates.is_empty():
		# Fall back: any empty slot (including consumed).
		for i in range(CHAMBER_COUNT):
			var is_live2 := ((live_mask >> i) & 1) == 1
			if not is_live2:
				candidates.append(i)

	if candidates.is_empty():
		return -1

	var rng := _rng("rev_inject", candidates.size())
	var pick := rng.randi_range(0, candidates.size() - 1)
	var idx2 := candidates[pick]
	live_mask |= (1 << idx2)
	# Reloading a spent chamber clears its consumed state.
	consumed_mask &= ~(1 << idx2)
	return idx2

func fire_random_chamber(label: String = "fire") -> Dictionary:
	ensure_cycle_ready("fire_random_chamber:" + label)
	var candidates: Array[int] = []
	for i in range(CHAMBER_COUNT):
		if ((consumed_mask >> i) & 1) == 0:
			candidates.append(i)

	if candidates.is_empty():
		load_fresh_cylinder()
		_fire_id = 0
		candidates.clear()
		for i in range(CHAMBER_COUNT):
			if ((consumed_mask >> i) & 1) == 0:
				candidates.append(i)
		if candidates.is_empty():
			return { "ok": false }

	var rng := _rng("rev_fire:" + label, _fire_id)
	_fire_id += 1
	var pick := rng.randi_range(0, candidates.size() - 1)
	var idx := candidates[pick]
	current_index = idx
	var was_live := ((live_mask >> idx) & 1) == 1
	consumed_mask |= (1 << idx)
	live_mask &= ~(1 << idx)
	if was_live:
		danger = clampi(danger - 1, 0, CHAMBER_COUNT)

	return {
		"ok": true,
		"index": idx,
		"was_live": was_live
	}

func roll_random_chamber(label: String = "roll") -> Dictionary:
	ensure_cycle_ready("roll_random_chamber:" + label)
	var candidates: Array[int] = []
	for i in range(CHAMBER_COUNT):
		if ((consumed_mask >> i) & 1) == 0:
			candidates.append(i)
	if candidates.is_empty():
		return { "ok": false }
	var rng := _rng("rev_roll:" + label, _fire_id)
	_fire_id += 1
	var pick := rng.randi_range(0, candidates.size() - 1)
	var idx := candidates[pick]
	var was_live := ((live_mask >> idx) & 1) == 1
	return {
		"ok": true,
		"index": idx,
		"chamber_id": idx + 1,
		"was_live": was_live
	}

func consume_chamber(idx: int, was_live: bool) -> void:
	if idx < 0 or idx >= CHAMBER_COUNT:
		return
	current_index = idx
	consumed_mask |= (1 << idx)
	if was_live:
		live_mask &= ~(1 << idx)
		danger = clampi(danger - 1, 0, CHAMBER_COUNT)

func snapshot() -> Dictionary:
	return {
		"danger": danger,
		"danger_fill": danger_fill,
		"live_mask": live_mask,
		"consumed_mask": consumed_mask,
		"current_index": current_index,
		"cycle_id": _cycle_id
	}

func _rng(label: String, index: int) -> RandomNumberGenerator:
	var s := SeedUtil.derive_seed(run_seed_u64, label, int(index) + _op_id)
	_op_id += 1
	return SeedUtil.make_rng(s)

func _popcount(v: int) -> int:
	var n := v
	var count := 0
	while n != 0:
		if (n & 1) == 1:
			count += 1
		n >>= 1
	return count
