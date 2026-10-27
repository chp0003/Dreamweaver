class_name RhythmJudge
extends RefCounted

enum Rating { PERFECT, GOOD, MISS }

static func judge(elapsed: float, beat_interval: float) -> Rating:
	var distance := absf(fposmod(elapsed, beat_interval))
	distance = minf(distance, beat_interval - distance)
	if distance <= beat_interval * 0.12:
		return Rating.PERFECT
	if distance <= beat_interval * 0.28:
		return Rating.GOOD
	return Rating.MISS
