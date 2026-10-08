// Shared motion for the painted houses. Same noise and sway language as the
// hub plate: foliage shifts, hanging fibre and cloth breathe, lanterns flicker.

float motion_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float motion_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(motion_hash(i), motion_hash(i + vec2(1.0, 0.0)), u.x),
		mix(motion_hash(i + vec2(0.0, 1.0)), motion_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float motion_foliage(vec3 c) {
	return smoothstep(0.02, 0.08, c.g - c.r) * smoothstep(0.04, 0.10, c.g - c.b);
}

// Pale warp, drying strands, and the sacred fringe. Wood is too orange to match.
float motion_fibre(vec3 c, vec2 uv) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	float chroma = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float pale = smoothstep(0.52, 0.72, luma) * (1.0 - smoothstep(0.07, 0.16, chroma));
	float column = smoothstep(0.40, 0.45, uv.x) * (1.0 - smoothstep(0.55, 0.60, uv.x));
	float band = smoothstep(0.12, 0.18, uv.y) * (1.0 - smoothstep(0.58, 0.66, uv.y));
	return pale * column * band;
}

// Hanging dye bundles and the cloth on the loom. Side pots and wall banners stay still.
float motion_hanging_red(vec3 c, vec2 uv) {
	float red = smoothstep(0.10, 0.22, c.r - max(c.g, c.b));
	float column = smoothstep(0.30, 0.36, uv.x) * (1.0 - smoothstep(0.70, 0.76, uv.x));
	float band = smoothstep(0.06, 0.12, uv.y) * (1.0 - smoothstep(0.40, 0.50, uv.y));
	return red * column * band;
}

// Ceiling lanterns only. The sun shaft on the floor is lower and must not strobe.
float motion_lantern(vec3 c, vec2 uv) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	float warm = smoothstep(0.05, 0.16, c.r - c.b);
	float upper = 1.0 - smoothstep(0.16, 0.34, uv.y);
	return smoothstep(0.70, 0.90, luma) * warm * upper;
}

vec2 motion_uv(vec2 uv, vec3 base, vec2 px, float t) {
	float leaves = motion_foliage(base);
	float gust = motion_noise(uv * vec2(3.0, 2.0) + vec2(t * 0.22, 0.0));
	float sway = sin(t * 1.35 + uv.x * 11.0 + uv.y * 6.0) * 0.6
		+ sin(t * 2.3 + uv.y * 23.0) * 0.25;
	float flutter = motion_noise(uv * 180.0 + vec2(t * 1.6, t * 0.9)) - 0.5;
	vec2 leaf_offset = vec2(sway * (0.8 + gust * 1.6) + flutter * 1.2,
		flutter * 0.8 + sway * 0.3) * px * 1.6 * leaves;

	float hang = max(motion_fibre(base, uv), motion_hanging_red(base, uv));
	float hang_sway = sin(t * 1.15 + uv.x * 16.0) * 0.65
		+ sin(t * 2.1 + uv.y * 9.0) * 0.35;
	vec2 hang_offset = vec2(hang_sway, hang_sway * 0.2) * px * 2.4 * hang;

	return clamp(uv + leaf_offset + hang_offset, vec2(0.0), vec2(1.0));
}

float motion_glow(vec2 uv, vec3 base, float t) {
	float lantern = motion_lantern(base, uv);
	float flick = 0.62 + 0.38 * sin(t * 5.5 + uv.x * 36.0);
	flick *= 0.7 + 0.3 * motion_noise(uv * 24.0 + vec2(t * 1.4, 0.0));
	return lantern * flick * 0.16;
}
