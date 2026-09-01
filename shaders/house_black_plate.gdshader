shader_type canvas_item;

// Same language as hub_plate: cursed charcoal dusk vs the live painting.
// restore 0 = forgotten (matches hub_background_cursed), 1 = vat restored.

uniform float restore : hint_range(0.0, 1.0) = 0.0;

vec3 hub_curse(vec3 c) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 dead = vec3(luma);
	dead = mix(dead, vec3(0.16, 0.15, 0.13), 0.22);
	dead *= vec3(0.78, 0.80, 0.72);
	dead *= 0.48;
	float shade = 1.0 - smoothstep(0.06, 0.42, luma);
	dead = mix(dead, vec3(0.045, 0.048, 0.042), shade * 0.72);
	float gold = max(min(c.r, c.g) - c.b, 0.0);
	float fire = max(c.r - c.g, 0.0);
	float lantern = max(
		smoothstep(0.10, 0.28, gold) * smoothstep(0.28, 0.65, luma),
		smoothstep(0.08, 0.22, fire) * smoothstep(0.25, 0.55, luma)
	);
	dead = mix(dead, clamp(c * vec3(1.15, 0.70, 0.32), 0.0, 1.0), lantern * 0.62);
	return clamp(dead, 0.0, 1.0);
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	vec3 dead = hub_curse(c);
	vec2 from_centre = (UV - vec2(0.50, 0.46)) * vec2(1.10, 1.08);
	float vig = smoothstep(0.34, 1.18, length(from_centre));
	dead *= mix(1.0, 0.70, vig * 0.55);
	COLOR = vec4(clamp(mix(dead, c, restore), 0.0, 1.0), 1.0);
}
