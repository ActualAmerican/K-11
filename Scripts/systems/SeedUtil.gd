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
