extends RefCounted
class_name SeedUtil

static func normalize_seed(v: int) -> int:
	# Keep non-negative and stable in Godot int.
	return int(v & 0x7fffffffffffffff)

static func make_rng(seed_u64: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = normalize_seed(seed_u64)
	return rng

static func derive_seed(base_seed_u64: int, label: String, index: int = 0) -> int:
	var h := _fnv1a64(label)
	var x := (base_seed_u64 ^ h ^ int(index)) & 0x7fffffffffffffff
	return normalize_seed(_splitmix64(x))

static func hex16(v: int) -> String:
	var hex_chars := "0123456789abcdef"
	var out := ""
	var x := v & 0xffffffffffffffff
	for i in range(16):
		var shift := (15 - i) * 4
		var nib := (x >> shift) & 0xF
		out += hex_chars[nib]
	return out

static func _splitmix64(x: int) -> int:
	var z := (x + 0x9e3779b97f4a7c15) & 0xffffffffffffffff
	z = ((z ^ (z >> 30)) * 0xbf58476d1ce4e5b9) & 0xffffffffffffffff
	z = ((z ^ (z >> 27)) * 0x94d049bb133111eb) & 0xffffffffffffffff
	return (z ^ (z >> 31)) & 0xffffffffffffffff

static func _fnv1a64(s: String) -> int:
	var hash := 0xcbf29ce484222325
	var prime := 0x100000001b3
	var bytes := s.to_utf8_buffer()
	for b in bytes:
		hash = hash ^ int(b)
		hash = (hash * prime) & 0xffffffffffffffff
	return hash
