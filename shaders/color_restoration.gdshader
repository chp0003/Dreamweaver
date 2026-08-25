shader_type canvas_item;

// The Shadow of Forgetfulness, as a post-process pass.
//
// This is not a uniform gray filter. Forgotten pixels keep a warm cloth tint,
// sacred gold (the Lewet Staff) stays readable, and each restored Essence
// returns one dye family: Black (earth/structure), Red (hulo pigment),
// Gold (sun-thread). Local `zones` still punch circular holes of full colour.

const int MAX_ZONES = 8;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;

uniform float global_gray : hint_range(0.0, 1.0) = 1.0;
uniform int zone_count = 0;
uniform vec4 zones[MAX_ZONES];
uniform float screen_aspect = 1.7777778;
uniform vec3 gray_tint : source_color = vec3(1.02, 0.99, 0.94);
uniform float feather : hint_range(0.02, 1.0) = 0.4;

// Dye families returned as Houses are restored. 0 = still forgotten.
uniform float black_restore : hint_range(0.0, 1.0) = 0.0;
uniform float red_restore : hint_range(0.0, 1.0) = 0.0;
uniform float gold_restore : hint_range(0.0, 1.0) = 0.0;
// How much sacred gold chroma (staff, brass, sun-thread) survives the curse.
uniform float protect_gold : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	float luma = dot(src, vec3(0.299, 0.587, 0.114));
	vec3 drained = vec3(luma) * gray_tint;

	float restored = 0.0;
	for (int i = 0; i < MAX_ZONES; i++) {
		if (i >= zone_count) {
			break;
		}
		vec4 zone = zones[i];
		if (zone.z <= 0.0001) {
			continue;
		}
		vec2 delta = SCREEN_UV - zone.xy;
		delta.y /= screen_aspect;
		float d = length(delta) / zone.z;
		restored = max(restored, zone.w * (1.0 - smoothstep(1.0 - feather, 1.0, d)));
	}

	float veil = clamp(global_gray * (1.0 - clamp(restored, 0.0, 1.0)), 0.0, 1.0);
	vec3 outc = mix(src, drained, veil);

	// --- Essence families: bring dye back even outside a local zone ---
	float max_gb = max(src.g, src.b);
	float red_chroma = max(src.r - max_gb, 0.0);
	float gold_chroma = max(min(src.r, src.g) - src.b, 0.0);
	float earth = clamp(1.0 - abs(luma - 0.22) * 3.2, 0.0, 1.0);
	earth *= 1.0 - smoothstep(0.12, 0.28, abs(src.r - src.g) + abs(src.g - src.b));

	outc = mix(outc, src, red_restore * smoothstep(0.04, 0.22, red_chroma) * veil);
	outc = mix(outc, src, gold_restore * smoothstep(0.04, 0.18, gold_chroma) * veil);
	outc = mix(outc, src, black_restore * earth * 0.55 * veil);

	// Lewet Staff / brass / sun-thread: a lantern that the curse cannot fully take.
	float sacred = smoothstep(0.06, 0.22, gold_chroma);
	outc = mix(outc, src, sacred * protect_gold * veil * 0.85);

	COLOR = vec4(outc, 1.0);
}
