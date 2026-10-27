class_name WeaveSfx
extends RefCounted

# Tiny procedural sound effects so the game has audio without any asset files.

const RATE := 22050

static func tone(freqs: Array, note_len: float, volume: float, noise_mix := 0.0, slide := 0.0) -> AudioStreamWAV:
	var per_note := int(RATE * note_len)
	var data := PackedByteArray()
	data.resize(per_note * freqs.size() * 2)
	var offset := 0
	for freq in freqs:
		var phase := 0.0
		for i in range(per_note):
			var t := float(i) / float(per_note)
			var envelope := pow(1.0 - t, 2.0) * minf(1.0, float(i) / 24.0)
			phase += TAU * (float(freq) + slide * t) / float(RATE)
			var sample := sin(phase) * (1.0 - noise_mix) + (randf() * 2.0 - 1.0) * noise_mix
			data.encode_s16(offset, int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0))
			offset += 2
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream

static func stitch() -> AudioStreamWAV:
	return tone([820.0], 0.04, 0.35, 0.6)

static func wrong() -> AudioStreamWAV:
	return tone([170.0], 0.12, 0.5, 0.2, -40.0)

static func tight() -> AudioStreamWAV:
	return tone([110.0], 0.15, 0.9, 0.35, -45.0)

static func done() -> AudioStreamWAV:
	return tone([523.25, 659.25, 783.99, 1046.5], 0.16, 0.5)
