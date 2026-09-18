shader_type canvas_item;
render_mode unshaded;

// Final hall. restore 0 = forgotten ash, 1 = the Sacred Loom remembers.
// loom_energy blooms the half-woven cloth during Weave Mode and the Color Burst.

uniform float restore : hint_range(0.0, 1.0) = 0.0;
uniform float sanctity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 player_uv = vec2(0.50, 0.78);
uniform float player_radius = 0.26;
uniform vec2 loom_uv = vec2(0.50, 0.34);
uniform float loom_energy = 0.0;

vec3 hub_curse(vec3 c) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 dead = vec3(luma);
	dead = mix(dead, vec3(0.16, 0.14, 0.13), 0.38);
	dead *= vec3(0.88, 0.84, 0.78);
	dead *= 0.48;
	float shade = 1.0 - smoothstep(0.06, 0.42, luma);
	dead = mix(dead, vec3(0.040, 0.036, 0.034), shade * 0.78);
	return clamp(dead, 0.0, 1.0);
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	vec3 dead = hub_curse(c);
	vec2 from_centre = (UV - vec2(0.50, 0.34)) * vec2(1.10, 1.08);
	float vig = smoothstep(0.34, 1.18, length(from_centre));
	dead *= mix(1.0, 0.68, vig * 0.58);
	vec3 base = clamp(mix(dead, c, restore), 0.0, 1.0);

	float light = 1.0 - smoothstep(player_radius * 0.42, player_radius, distance(UV, player_uv));
	if (loom_energy > 0.01) {
		light += loom_energy * (1.0 - smoothstep(0.07, 0.28, distance(UV, loom_uv)));
	}
	light = clamp(light + sanctity * 0.40, 0.0, 1.40);

	vec3 night = base * vec3(0.14, 0.13, 0.12);
	vec3 gold = vec3(1.06, 0.96, 0.82);
	vec3 seen = mix(night, base * mix(vec3(1.0), gold, sanctity * 0.22), clamp(light, 0.0, 1.0));
	COLOR = vec4(clamp(seen, 0.0, 1.0), 1.0);
}
