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

vec3 hub_curse(vec3 c) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 dusk = mix(c, vec3(luma), 0.42);
	dusk *= vec3(0.78, 0.62, 0.52);
	dusk *= 0.86;
	float shade = 1.0 - smoothstep(0.06, 0.46, luma);
	dusk = mix(dusk, vec3(0.07, 0.045, 0.04), shade * 0.42);
	return clamp(dusk, 0.0, 1.0);
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	vec3 dead = hub_curse(c);
	vec2 from_centre = (UV - vec2(0.50, 0.36)) * vec2(1.08, 1.06);
	float vig = smoothstep(0.42, 1.22, length(from_centre));
	dead *= mix(1.0, 0.82, vig * 0.48);
	vec3 base = clamp(mix(dead, c, restore), 0.0, 1.0);

	float light = 0.46;
	light += 0.62 * (1.0 - smoothstep(player_radius * 0.34, player_radius, distance(UV, player_uv)));
	light += 0.38 * (1.0 - smoothstep(0.05, 0.18, distance(UV, vec2(0.145, 0.22))));
	light += 0.22 * (1.0 - smoothstep(0.03, 0.11, distance(UV, vec2(0.38, 0.18))));
	light += 0.22 * (1.0 - smoothstep(0.03, 0.11, distance(UV, vec2(0.62, 0.18))));
	if (loom_energy > 0.01) {
		light += loom_energy * (1.0 - smoothstep(0.08, 0.34, distance(UV, loom_uv)));
	}
	light = clamp(light + sanctity * 0.38, 0.0, 1.45);

	vec3 night = base * vec3(0.42, 0.36, 0.32);
	vec3 gold = vec3(1.08, 0.94, 0.74);
	vec3 seen = mix(night, base * mix(vec3(1.0), gold, sanctity * 0.22), clamp(light, 0.0, 1.0));
	COLOR = vec4(clamp(seen, 0.0, 1.0), 1.0);
}
