class_name RevolverSim
extends RefCounted

func run(seed_u64: int, shots: int = 50, _tier: int = 6) -> Dictionary:
	var errors: Array[String] = []
	var sys: RevolverSystem = RevolverSystem.new()
	var tier_results: Dictionary = {}
	var tiers: Array[int] = [0, 3, 6]

	# A) Fresh-load correctness (tiers 0, 3, 6)
	for t in [0, 3, 6]:
		sys.setup(seed_u64)
		sys.set_danger(t)
		sys.load_fresh_cylinder()
		var live_count := _popcount(sys.live_mask)
		if live_count != t:
			errors.append("fresh_load tier=%d live_count=%d" % [t, live_count])
		if sys.consumed_mask != 0:
			errors.append("fresh_load tier=%d consumed_mask=%d" % [t, sys.consumed_mask])
		if (sys.live_mask & sys.consumed_mask) != 0:
			errors.append("fresh_load tier=%d overlap live=%d consumed=%d" % [t, sys.live_mask, sys.consumed_mask])

	# B) 50 firings (tiers 0, 3, 6)
	for t2 in tiers:
		sys.setup(seed_u64)
		sys.set_danger(t2)
		sys.load_fresh_cylinder()
		var resets: int = 0
		var clicks: int = 0
		var booms: int = 0
		var tier_ok: bool = true
		var prev_consumed_count: int = _popcount(sys.consumed_mask)
		for _i in range(shots):
			var roll: Dictionary = sys.roll_random_chamber("SIM")
			if not bool(roll.get("ok", false)):
				errors.append("roll ok=false tier=%d" % t2)
				tier_ok = false
				break
			var chamber_id: int = int(roll.get("chamber_id", -1))
			if chamber_id < 1 or chamber_id > 6:
				errors.append("roll chamber_id out of range: %d tier=%d" % [chamber_id, t2])
				tier_ok = false
			var idx: int = int(roll.get("index", -1))
			var was_live: bool = bool(roll.get("was_live", false))
			if was_live:
				booms += 1
			else:
				clicks += 1
			sys.consume_chamber(idx, was_live)
			var consumed_count: int = _popcount(sys.consumed_mask)
			if consumed_count < prev_consumed_count:
				resets += 1
			if consumed_count == prev_consumed_count:
				errors.append("consume did not change count idx=%d tier=%d" % [idx, t2])
				tier_ok = false
			elif consumed_count > prev_consumed_count + 1:
				errors.append("consume delta != 1 idx=%d tier=%d" % [idx, t2])
				tier_ok = false
			if (sys.live_mask & sys.consumed_mask) != 0:
				errors.append("consume overlap live=%d consumed=%d tier=%d" % [sys.live_mask, sys.consumed_mask, t2])
				tier_ok = false
			prev_consumed_count = consumed_count
		tier_results[t2] = {
			"shots": shots,
			"cycles_reset": resets,
			"clicks": clicks,
			"booms": booms,
			"ok": tier_ok
		}

	# C) Overflow behavior
	var sys2: RevolverSystem = RevolverSystem.new()
	sys2.setup(seed_u64)
	sys2.set_danger(6)
	sys2.load_fresh_cylinder()
	sys2.live_mask = 63
	sys2.consumed_mask = 0
	sys2.danger = 6
	var ov: Dictionary = sys2.fire_overflow_full("SIM_OVERFLOW")
	if not bool(ov.get("fired", false)):
		errors.append("overflow fired=false")
	var oidx: int = int(ov.get("idx", -1))
	if oidx < 0 or oidx > 5:
		errors.append("overflow idx out of range: %d" % oidx)
	if ((sys2.consumed_mask >> oidx) & 1) == 0:
		errors.append("overflow did not consume idx=%d" % oidx)
	if ((sys2.live_mask >> oidx) & 1) == 1:
		errors.append("overflow did not clear live idx=%d" % oidx)

	var ok: bool = errors.is_empty()
	var summary: String = "PASS tiers=[0,3,6] overflow_ok=%d" % [0 if errors.size() > 0 else 1]
	if not ok:
		summary = "FAIL errors=%d tiers=[0,3,6]" % errors.size()
	var lines: Array[String] = []
	lines.append(summary)
	for t3 in tiers:
		var tier_result: Dictionary = tier_results.get(t3, {})
		lines.append("REVOLVER_SIM_TIER: t=%d shots=%d cycles_reset=%d clicks=%d booms=%d ok=%s" % [
			t3,
			int(tier_result.get("shots", 0)),
			int(tier_result.get("cycles_reset", 0)),
			int(tier_result.get("clicks", 0)),
			int(tier_result.get("booms", 0)),
			str(tier_result.get("ok", false))
		])
	return { "ok": ok, "errors": errors, "summary": "\n".join(lines) }

func _popcount(v: int) -> int:
	var n := v
	var count := 0
	while n != 0:
		if (n & 1) == 1:
			count += 1
		n >>= 1
	return count
