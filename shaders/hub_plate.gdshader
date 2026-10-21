shader_type canvas_item;

// Hub plate: cursed dusk vs restored daylight, mixed by the same veil
// the rest of the game uses. Zones punch restored colour around finished houses.
// Restored grade is a mild print pass — contrast, shade, sun from the north-west —
// so the bright plate reads as jungle afternoon instead of a washed midday still.

const int MAX_ZONES = 8;

uniform sampler2D cursed_tex : source_color, filter_linear;
uniform float curse : hint_range(0.0, 1.0) = 1.0;
uniform int zone_count = 0;
uniform vec4 zones[MAX_ZONES]; // xy = UV centre, z = UV radius, w = strength
uniform float motion : hint_range(0.0, 2.0) = 1.0;
// The two painted falls on the north-west cliff: xy = top-left UV, zw = bottom-right UV.
uniform vec4 fall_a = vec4(0.095, 0.13, 0.145, 0.30);
uniform vec4 fall_b = vec4(0.175, 0.07, 0.225, 0.30);
// Plaza braziers, left then right of the totem. Tight on the flame, not the bowl.
uniform vec4 fire_a = vec4(0.440, 0.456, 0.468, 0.522);
uniform vec4 fire_b = vec4(0.528, 0.444, 0.564, 0.522);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Mask colours come from the live plate; the cursed plate shares its layout.
float water_mask(vec3 c) {
	return smoothstep(0.10, 0.22, c.b - c.r) * smoothstep(0.06, 0.16, c.g - c.r);
}

float foliage_mask(vec3 c) {
	return smoothstep(0.02, 0.08, c.g - c.r) * smoothstep(0.04, 0.10, c.g - c.b);
}

// Falls are painted cyan-to-white; the cliff rock around them is olive and gold.
float spray_mask(vec3 c) {
	float cyan = smoothstep(0.04, 0.12, c.b - c.r);
	float white = smoothstep(0.84, 0.94, min(c.r, min(c.g, c.b))) * (1.0 - smoothstep(0.0, 0.06, c.r - c.b));
	return max(cyan, white);
}

float fall_mask(vec2 uv, vec4 rect) {
	vec2 lo = smoothstep(rect.xy - vec2(0.008), rect.xy + vec2(0.006), uv);
	vec2 hi = 1.0 - smoothstep(rect.zw - vec2(0.006), rect.zw + vec2(0.008), uv);
	return lo.x * lo.y * hi.x * hi.y;
}

// 0 at the lip, 1 at the plunge pool.
float fall_depth(vec2 uv, vec4 rect) {
	return clamp((uv.y - rect.y) / max(rect.w - rect.y, 0.001), 0.0, 1.0);
}

// 1 across the painted flame, 0 on the bowl and the totem.
float fire_mask(vec2 uv, vec4 rect) {
	vec2 pad = vec2(0.002, 0.003);
	vec2 lo = smoothstep(rect.xy - pad, rect.xy + pad * 0.25, uv);
	vec2 hi = 1.0 - smoothstep(rect.zw - pad * 0.25, rect.zw + pad, uv);
	return lo.x * lo.y * hi.x * hi.y;
}

// 0 at the bowl, 1 at the tongue tip.
float fire_tip(vec2 uv, vec4 rect) {
	return clamp((rect.w - uv.y) / max(rect.w - rect.y, 0.001), 0.0, 1.0);
}

// Tongues travel from the bowl toward the tip. The bowl itself does not rock.
float fire_wave(float tip, float phase, float ft) {
	float main = sin(tip * 10.0 - ft * 6.0 + phase);
	float small = sin(tip * 17.0 - ft * 9.0 + phase * 1.4);
	return main * 0.72 + small * 0.28;
}

vec2 fire_sample(vec2 uv, vec4 rect, float tip, float phase, float ft, vec2 px) {
	float body = smoothstep(0.16, 0.95, tip);
	float wave = fire_wave(tip, phase, ft);
	float lean = sin(ft * 1.25 + phase);
	vec2 sample = uv;
	sample.x += (lean * 1.5 + wave * 2.4) * body * px.x;
	sample.y += body * (2.4 + wave * 3.2) * px.y;
	return clamp(sample, rect.xy, rect.zw);
}

vec3 grade_restored(vec3 c, vec2 uv) {
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = (c - vec3(0.5)) * 1.24 + vec3(0.5);
	graded *= 0.80;

	float shade = 1.0 - smoothstep(0.12, 0.52, luma);
	graded *= mix(1.0, 0.68, shade * 0.62);
	graded = mix(graded, graded * vec3(0.76, 0.80, 0.90), shade * 0.32);

	float sun = clamp((uv.x - 0.18) * 0.38 + (uv.y - 0.10) * 0.52, 0.0, 1.0);
	graded *= mix(1.02, 0.76, sun * 0.68);

	vec2 from_centre = (uv - vec2(0.50, 0.48)) * vec2(1.18, 1.04);
	float vig = smoothstep(0.28, 1.12, length(from_centre));
	graded *= mix(1.0, 0.72, vig * 0.62);

	return clamp(graded, 0.0, 1.0);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float t = TIME * motion;
	vec3 base = texture(TEXTURE, UV).rgb;
	float falls = max(fall_mask(UV, fall_a), fall_mask(UV, fall_b)) * spray_mask(base);
	float water = max(water_mask(base), falls);
	float leaves = foliage_mask(base) * (1.0 - water);

	// Foliage: slow sway plus rolling gusts, stronger toward the canopy tops.
	float gust = value_noise(UV * vec2(3.0, 2.0) + vec2(t * 0.22, 0.0));
	float sway = sin(t * 1.35 + UV.x * 11.0 + UV.y * 6.0) * 0.6
		+ sin(t * 2.3 + UV.y * 23.0) * 0.25;
	float flutter = value_noise(UV * 180.0 + vec2(t * 1.6, t * 0.9)) - 0.5;
	vec2 leaf_offset = vec2(sway * (0.8 + gust * 1.6) + flutter * 1.2,
		flutter * 0.8 + sway * 0.3) * px * 1.8 * leaves;

	// Water: rim rivers drift south, pools churn; ripples bend the painted bed.
	vec2 flow = vec2(0.0, t * 0.035);
	float ripple_a = value_noise(UV * vec2(70.0, 38.0) - flow * 38.0);
	float ripple_b = value_noise(UV * vec2(46.0, 90.0) + vec2(t * 0.05, -t * 0.02) * 46.0);
	vec2 water_offset = vec2(ripple_a - 0.5, ripple_b - 0.5) * px * 3.2 * water * (1.0 - falls);

	// Falls: sheet pulled downward in streaks.
	float fall_scroll = value_noise(vec2(UV.x * 260.0, UV.y * 18.0 - t * 5.5));
	vec2 fall_offset = vec2((fall_scroll - 0.5) * 1.5, (fall_scroll - 0.5) * 5.0) * px * falls;

	float fa = fire_mask(UV, fire_a);
	float fb = fire_mask(UV, fire_b);
	float fire = max(fa, fb);
	vec2 fire_uv = UV;
	fire_uv = mix(fire_uv, fire_sample(UV, fire_a, fire_tip(UV, fire_a), 0.0, t, px), fa);
	fire_uv = mix(fire_uv, fire_sample(UV, fire_b, fire_tip(UV, fire_b), 1.8, t, px), fb);
	vec2 drifted = UV + leaf_offset + water_offset + fall_offset;
	vec2 uv = clamp(mix(drifted, fire_uv, fire), vec2(0.0), vec2(1.0));
	vec3 live_src = texture(TEXTURE, uv).rgb;
	vec3 dead = texture(cursed_tex, uv).rgb;

	float glint = pow(value_noise(UV * vec2(210.0, 120.0) - flow * 120.0 + vec2(t * 0.3, 0.0)), 7.0);
	float current = smoothstep(0.55, 0.9, value_noise(UV * vec2(28.0, 9.0) - flow * 16.0));
	float water_light = (glint * 0.55 + current * 0.08) * water * (1.0 - falls);

	float streak = smoothstep(0.52, 0.95, value_noise(vec2(UV.x * 340.0, UV.y * 22.0 - t * 7.0)));
	float depth_a = fall_depth(UV, fall_a) * fall_mask(UV, fall_a) * falls;
	float depth_b = fall_depth(UV, fall_b) * fall_mask(UV, fall_b) * falls;
	float foam_band = smoothstep(0.72, 1.0, max(depth_a, depth_b));
	float foam = foam_band * (0.35 + 0.65 * value_noise(UV * 160.0 + vec2(0.0, -t * 3.0)));
	float fall_light = (streak * 0.22 + foam * 0.30) * falls;

	live_src += vec3(0.80, 0.92, 1.0) * (water_light + fall_light);
	dead += vec3(0.46, 0.52, 0.70) * (water_light * 0.55 + fall_light * 0.7);

	float warmth = smoothstep(0.22, 0.55, live_src.r - live_src.b);
	float tip = fa >= fb ? fire_tip(UV, fire_a) : fire_tip(UV, fire_b);
	float wave = fa * fire_wave(fire_tip(UV, fire_a), 0.0, t) + fb * fire_wave(fire_tip(UV, fire_b), 1.8, t);
	float core = smoothstep(0.08, 0.40, tip) * (1.0 - smoothstep(0.70, 1.0, tip));
	live_src += vec3(0.18, 0.07, 0.0) * fire * warmth * core * (0.45 + 0.55 * wave);
	float spent = smoothstep(0.62, 1.0, tip) * clamp(0.55 - wave, 0.0, 1.0);
	live_src = mix(live_src, live_src * 0.78, fire * warmth * spent);

	vec3 live = grade_restored(live_src, UV);
	float restored = 0.0;
	for (int i = 0; i < MAX_ZONES; i++) {
		if (i >= zone_count) {
			break;
		}
		vec4 zone = zones[i];
		if (zone.z <= 0.0001) {
			continue;
		}
		float d = length(UV - zone.xy) / zone.z;
		restored = max(restored, zone.w * (1.0 - smoothstep(0.75, 1.0, d)));
	}
	float veil = clamp(curse * (1.0 - restored), 0.0, 1.0);
	COLOR = vec4(mix(live, dead, veil), 1.0);
}
