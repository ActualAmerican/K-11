@tool
extends RefCounted
class_name SeedUtil

static func normalize_seed(v: int) -> int:
	# Keep non-negative and stable in Godot int.
	return int(v & 0x7fffffffffffffff)

static func hex_to_int64_signed(hex_str: String) -> int:
	var t: String = hex_str.strip_edges().to_lower()
	if t.begins_with("0x"):
		t = t.substr(2)
	if t.length() == 0:
		return -1
	if t.length() > 16:
		t = t.substr(t.length() - 16, 16)

	var chars: String = "0123456789abcdef"
	var v: int = 0
	for i in range(t.length()):
		var ch: String = t[i]
		var idx: int = chars.find(ch)
		if idx < 0:
			return -1
		v = (v << 4) | idx
	return v

static func hex_to_seed_u63(hex_str: String) -> int:
	var v: int = hex_to_int64_signed(hex_str)
	if v < 0:
		return -1

	var mask: int = 0
	for i in range(63):
		mask = (mask << 1) | 1
	return v & mask

static func make_rng(seed_u64: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = normalize_seed(seed_u64)
	return rng

static func derive_seed(base_seed_u64: int, label: String, index: int = 0) -> int:
	var h := _fnv1a64(label)
	var x := (base_seed_u64 ^ h ^ int(index)) & 0x7fffffffffffffff
	return normalize_seed(_splitmix64(x))

static func derive_camera_schedule_seed(encounter_seed_u64: int, suspect_index: int = 0) -> int:
	return derive_seed(encounter_seed_u64, "camera_schedule", suspect_index)

static func derive_exit_protocol_seed(run_seed_u64: int) -> int:
	return derive_seed(run_seed_u64, "exit_protocol", 0)

static func build_exit_protocol_params(run_seed_u64: int) -> Dictionary:
	var exit_seed_u64: int = derive_exit_protocol_seed(run_seed_u64)
	var rng: RandomNumberGenerator = make_rng(exit_seed_u64)
	var drawer_combo: Array[int] = []
	var combo_length: int = rng.randi_range(4, 6)
	for i in range(combo_length):
		drawer_combo.append(rng.randi_range(0, 9))

	var color_pool: Array[String] = [
		"RED",
		"BLUE",
		"GREEN",
		"YELLOW",
		"WHITE",
		"BLACK",
		"ORANGE",
	]
	var wire_colors: Array[String] = []
	var wire_count: int = rng.randi_range(3, 5)
	for i in range(wire_count):
		var pick_idx: int = rng.randi_range(0, color_pool.size() - 1)
		wire_colors.append(color_pool[pick_idx])
		color_pool.remove_at(pick_idx)

	var remaining_colors: Array[String] = wire_colors.duplicate()
	var wire_cut_order: Array[String] = []
	while not remaining_colors.is_empty():
		var order_idx: int = rng.randi_range(0, remaining_colors.size() - 1)
		wire_cut_order.append(remaining_colors[order_idx])
		remaining_colors.remove_at(order_idx)

	return {
		"seed_u64_hex": hex16(exit_seed_u64),
		"drawer_combo": drawer_combo,
		"wire_colors": wire_colors,
		"wire_cut_order": wire_cut_order,
		"vent_screw_count": rng.randi_range(4, 8),
	}

static func format_run_seed_u63(seed_u64: int) -> String:
	return "K11-%s" % _to_base36(normalize_seed(seed_u64))

static func format_suspect_seed_u64(seed_u64: int) -> String:
	return "K11S-%s" % hex16(normalize_seed(seed_u64))

static func hex16(v: int) -> String:
	var hex_chars: String = "0123456789abcdef"
	var out: String = ""
	var x: int = v
	for i in range(16):
		var shift := (15 - i) * 4
		var nib := (x >> shift) & 0xF
		out += hex_chars[nib]
	return out

static func _splitmix64(x: int) -> int:
	var z: int = x + -7046029254386353131
	z = (z ^ (z >> 30)) * -4658895280553007687
	z = (z ^ (z >> 27)) * -7723592293110705685
	return z ^ (z >> 31)

static func _fnv1a64(s: String) -> int:
	var hash64: int = -3750763034362895579
	var prime: int = 1099511628211
	var bytes: PackedByteArray = s.to_utf8_buffer()
	for b in bytes:
		hash64 = hash64 ^ int(b)
		hash64 = hash64 * prime
	return hash64

static func parse_run_seed_to_u63(seed_text: String) -> int:
	var text: String = seed_text.strip_edges()
	if text == "":
		return -1

	var upper: String = text.to_upper()

	# Primary: K11-<base36> (matches GameController behavior)
	if upper.begins_with("K11-"):
		var suffix: String = text.substr(4).strip_edges()
		if suffix == "":
			return -1
		var v36: int = _from_base36(suffix)
		return normalize_seed(v36) if v36 >= 0 else -1

	# Hex (0x... or 16-hex)
	var hx: int = hex_to_seed_u63(text)
	if hx >= 0:
		return normalize_seed(hx)

	# Digits-only integer
	var digits_only := true
	for i in range(text.length()):
		var ch: String = text[i]
		if ch < "0" or ch > "9":
			digits_only = false
			break
	if digits_only:
		return normalize_seed(int(text.to_int()))

	# Convenience: raw base36 without prefix
	if _is_base36(text):
		var v: int = _from_base36(text)
		return normalize_seed(v) if v >= 0 else -1

	return -1

static func parse_k11_seed_to_u63(seed_text: String) -> int:
	return parse_run_seed_to_u63(seed_text)

static func _is_base36(s: String) -> bool:
	if s == "":
		return false
	var t := s.strip_edges().to_upper()
	for i in range(t.length()):
		var ch: String = t[i]
		var ok := (ch >= "0" and ch <= "9") or (ch >= "A" and ch <= "Z")
		if not ok:
			return false
	return true

static func _from_base36(s: String) -> int:
	var t := s.strip_edges().to_upper()
	if t == "":
		return -1
	var chars := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var v: int = 0
	for i in range(t.length()):
		var ch: String = t[i]
		var idx: int = chars.find(ch)
		if idx < 0:
			return -1
		v = (v * 36) + idx
	return v

static func _to_base36(v: int) -> String:
	var value: int = normalize_seed(v)
	if value == 0:
		return "0"
	var chars: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var result: String = ""
	while value > 0:
		var idx: int = value % 36
		result = chars[idx] + result
		value = int(value / 36)
	return result
