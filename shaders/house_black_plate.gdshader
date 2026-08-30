shader_type canvas_item;

// Pass the painted hall through as-is so play matches the editor plate.
// Restore still cools toward charcoal after the vat.

uniform float restore : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float shade = 1.0 - smoothstep(0.12, 0.55, luma);
	vec3 charcoal = c * vec3(0.82, 0.78, 0.72);
	charcoal = mix(charcoal, vec3(0.18, 0.15, 0.12), shade * 0.18 * restore);
	COLOR = vec4(clamp(mix(c, charcoal, restore), 0.0, 1.0), 1.0);
}
