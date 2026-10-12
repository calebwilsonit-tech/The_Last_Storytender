class_name Blip
extends RefCounted
## Procedural typewriter clack so dialogue has voice before real audio exists.

static func clack(seed_v: int = 11) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.045)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var prev := 0.0
	for i in n:
		var t := float(i) / n
		var env := exp(-t * 7.0)
		prev = lerpf(prev, rng.randf_range(-1.0, 1.0), 0.55)
		var tone := sin(TAU * 820.0 * i / rate) * 0.3
		data.encode_s16(i * 2, clampi(int((prev * 0.9 + tone) * env * 18000.0), -32768, 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s
