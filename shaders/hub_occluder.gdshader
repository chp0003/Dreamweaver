shader_type canvas_item;

// Y-sorted house card: alpha from the isolated silhouette, colour from the
// painted plate (same curse / restoration mix as hub_plate.gdshader).

const int MAX_ZONES = 8;

uniform sampler2D live_tex : source_color, filter_linear;
uniform sampler2D cursed_tex : source_color, filter_linear;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0); // xy min, zw size in plate UV
uniform float curse : hint_range(0.0, 1.0) = 1.0;
uniform int zone_count = 0;
uniform vec4 zones[MAX_ZONES];

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
	float alpha = texture(TEXTURE, UV).a;
	if (alpha < 0.08) {
		discard;
	}
	vec2 puv = uv_rect.xy + UV * uv_rect.zw;
	vec3 live = grade_restored(texture(live_tex, puv).rgb, puv);
	vec3 dead = texture(cursed_tex, puv).rgb;
	float restored = 0.0;
	for (int i = 0; i < MAX_ZONES; i++) {
		if (i >= zone_count) {
			break;
		}
		vec4 zone = zones[i];
		if (zone.z <= 0.0001) {
			continue;
		}
		float d = length(puv - zone.xy) / zone.z;
		restored = max(restored, zone.w * (1.0 - smoothstep(0.75, 1.0, d)));
	}
	float veil = clamp(curse * (1.0 - restored), 0.0, 1.0);
	COLOR = vec4(mix(live, dead, veil), alpha);
}
