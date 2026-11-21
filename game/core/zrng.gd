class_name ZRng
extends RefCounted




const MASK := 4294967295

var state: int


func _init(seed_value: int = 0) -> void:
	state = seed_value & MASK



static func hash_string(text: String) -> int:
	var h := 2166136261
	for b in text.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & MASK
	return h



static func imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var a_lo := a & 65535
	var a_hi := a >> 16
	var b_lo := b & 65535
	var b_hi := b >> 16
	return (a_lo * b_lo + (((a_hi * b_lo + a_lo * b_hi) << 16) & MASK)) & MASK


func next_u32() -> int:
	state = (state + 1831565813) & MASK
	var t := state
	t = imul(t ^ (t >> 15), t | 1)
	t = ((t + imul(t ^ (t >> 7), t | 61)) & MASK) ^ t
	return (t ^ (t >> 14)) & MASK



func next_float() -> float:
	return next_u32() / 4294967296.0



func below(n: int) -> int:
	return int(next_float() * n)


func chance(probability: float) -> bool:
	return next_float() < probability



func shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := below(i + 1)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp



func pick_weighted(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return -1
	var roll := next_float() * total
	for i in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			return i
	return weights.size() - 1
