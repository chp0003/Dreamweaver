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
	vec3 live = grade_restored(texture(TEXTURE, UV).rgb, UV);
	vec3 dead = texture(cursed_tex, UV).rgb;
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
		restored = max(restored, zone.w * (1.0 - smoothstep(0.70, 1.0, d)));
	}
	float veil = clamp(curse * (1.0 - restored), 0.0, 1.0);
	COLOR = vec4(mix(live, dead, veil), 1.0);
}
