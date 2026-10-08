shader_type canvas_item;
render_mode unshaded;

// Final hall. restore 0 = dusk siege, 1 = the Sacred Loom remembers.
// Keep the painted room readable during the fight; the Color Burst still
// blooms restore to 1.0 as the world comes back.

uniform float restore : hint_range(0.0, 1.0) = 0.0;
uniform float sanctity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 player_uv = vec2(0.50, 0.78);
uniform float player_radius = 0.36;
uniform vec2 loom_uv = vec2(0.50, 0.34);
uniform float loom_energy = 0.0;

#include "res://shaders/plate_motion.gdshaderinc"

vec3 hub_curse(vec3 c) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 dead = vec3(luma);
	dead = mix(dead, vec3(0.17, 0.17, 0.18), 0.30);
	dead *= vec3(0.84, 0.85, 0.88);
	dead *= 0.52;
	float shade = 1.0 - smoothstep(0.06, 0.42, luma);
	dead = mix(dead, vec3(0.045, 0.046, 0.050), shade * 0.72);
	return clamp(dead, 0.0, 1.0);
}

void fragment() {
	vec3 still = texture(TEXTURE, UV).rgb;
	vec2 moved = motion_uv(UV, still, TEXTURE_PIXEL_SIZE, TIME);
	vec3 c = texture(TEXTURE, moved).rgb;
	c += vec3(1.0, 0.74, 0.38) * motion_glow(UV, still, TIME);
	vec3 dead = hub_curse(c);
	vec2 from_centre = (UV - vec2(0.50, 0.36)) * vec2(1.08, 1.06);
	float vig = smoothstep(0.42, 1.22, length(from_centre));
	dead *= mix(1.0, 0.78, vig * 0.50);
	vec3 base = clamp(mix(dead, c, restore), 0.0, 1.0);

	float light = 0.38;
	light += 0.34 * (1.0 - smoothstep(player_radius * 0.34, player_radius, distance(UV, player_uv)));
	light += 0.16 * (1.0 - smoothstep(0.05, 0.18, distance(UV, vec2(0.145, 0.22))));
	if (loom_energy > 0.01) {
		light += loom_energy * 0.35 * (1.0 - smoothstep(0.08, 0.34, distance(UV, loom_uv)));
	}
	light = clamp(light + sanctity * 0.28, 0.0, 1.2);

	vec3 seen = base * mix(0.58, 1.04, clamp(light, 0.0, 1.0));
	COLOR = vec4(clamp(seen, 0.0, 1.0), 1.0);
}
