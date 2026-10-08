shader_type canvas_item;
render_mode unshaded;

// Cursed cloth like the other house plates, plus a staff-and-torch veil
// so the Golden Sun hall can start pitch-dark without 2D lights.
// restore 0 = forgotten ash, 1 = gold restored.
// veil 1 = only staff/torch pools are visible, 0 = full cursed/restored plate.

uniform float restore : hint_range(0.0, 1.0) = 0.0;
uniform float veil : hint_range(0.0, 1.0) = 1.0;
uniform vec2 player_uv = vec2(0.50, 0.72);
uniform float player_radius = 0.28;
uniform vec2 torch_uvs[4];
uniform float torch_energy[4];

#include "res://shaders/plate_motion.gdshaderinc"

vec3 hub_curse(vec3 c) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 dead = vec3(luma);
	dead = mix(dead, vec3(0.19, 0.18, 0.16), 0.32);
	dead *= vec3(0.90, 0.86, 0.80);
	dead *= 0.50;
	float shade = 1.0 - smoothstep(0.06, 0.42, luma);
	dead = mix(dead, vec3(0.048, 0.044, 0.040), shade * 0.74);
	return clamp(dead, 0.0, 1.0);
}

void fragment() {
	vec3 still = texture(TEXTURE, UV).rgb;
	vec2 moved = motion_uv(UV, still, TEXTURE_PIXEL_SIZE, TIME);
	vec3 c = texture(TEXTURE, moved).rgb;
	c += vec3(1.0, 0.74, 0.38) * motion_glow(UV, still, TIME);
	vec3 dead = hub_curse(c);
	vec2 from_centre = (UV - vec2(0.50, 0.34)) * vec2(1.10, 1.08);
	float vig = smoothstep(0.34, 1.18, length(from_centre));
	dead *= mix(1.0, 0.70, vig * 0.55);
	vec3 base = clamp(mix(dead, c, restore), 0.0, 1.0);

	float light = 1.0 - smoothstep(player_radius * 0.42, player_radius, distance(UV, player_uv));
	for (int i = 0; i < 4; i++) {
		float energy = torch_energy[i];
		if (energy > 0.01) {
			light += energy * (1.0 - smoothstep(0.035, 0.13, distance(UV, torch_uvs[i])));
		}
	}
	light = clamp(light, 0.0, 1.0);
	vec3 night = base * vec3(0.12, 0.11, 0.14);
	vec3 seen = mix(night, base, light);
	vec3 picture = mix(base, seen, veil);

	vec3 pool = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float energy = torch_energy[i];
		if (energy > 0.01) {
			float halo = energy * (1.0 - smoothstep(0.012, 0.11, distance(UV, torch_uvs[i])));
			pool += vec3(1.0, 0.64, 0.30) * halo;
		}
	}
	COLOR = vec4(clamp(picture + pool * 0.48, 0.0, 1.0), 1.0);
}
