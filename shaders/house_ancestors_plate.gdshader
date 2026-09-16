shader_type canvas_item;
render_mode unshaded;

// Cream ancestral hall. restore 0 = forgotten ash, 1 = memory returned.
// sanctity blooms statue and loom light as the House is questioned.

uniform float restore : hint_range(0.0, 1.0) = 0.0;
uniform float sanctity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 player_uv = vec2(0.50, 0.72);
uniform float player_radius = 0.24;
uniform vec2 statue_uvs[4];
uniform float statue_energy[4];
uniform vec2 loom_uv = vec2(0.50, 0.38);
uniform float loom_energy = 0.0;

vec3 hub_curse(vec3 c) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 dead = vec3(luma);
	dead = mix(dead, vec3(0.20, 0.19, 0.17), 0.34);
	dead *= vec3(0.90, 0.86, 0.78);
	dead *= 0.52;
	float shade = 1.0 - smoothstep(0.06, 0.42, luma);
	dead = mix(dead, vec3(0.050, 0.046, 0.040), shade * 0.72);
	return clamp(dead, 0.0, 1.0);
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	vec3 dead = hub_curse(c);
	vec2 from_centre = (UV - vec2(0.50, 0.36)) * vec2(1.10, 1.08);
	float vig = smoothstep(0.34, 1.18, length(from_centre));
	dead *= mix(1.0, 0.70, vig * 0.55);
	vec3 base = clamp(mix(dead, c, restore), 0.0, 1.0);

	float light = 1.0 - smoothstep(player_radius * 0.42, player_radius, distance(UV, player_uv));
	for (int i = 0; i < 4; i++) {
		float energy = statue_energy[i];
		if (energy > 0.01) {
			light += energy * (1.0 - smoothstep(0.05, 0.18, distance(UV, statue_uvs[i])));
		}
	}
	if (loom_energy > 0.01) {
		light += loom_energy * (1.0 - smoothstep(0.06, 0.24, distance(UV, loom_uv)));
	}
	light = clamp(light + sanctity * 0.35, 0.0, 1.35);

	vec3 night = base * vec3(0.16, 0.15, 0.14);
	vec3 cream = vec3(1.04, 0.98, 0.88);
	vec3 seen = mix(night, base * mix(vec3(1.0), cream, sanctity * 0.18), clamp(light, 0.0, 1.0));
	COLOR = vec4(clamp(seen, 0.0, 1.0), 1.0);
}
