shader_type canvas_item;

// S'lang's house: the same print pass as the restored hub — a little
// contrast and shade so the painted interior sits with the village plate.

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = (c - vec3(0.5)) * 1.16 + vec3(0.5);
	graded *= 0.92;
	float shade = 1.0 - smoothstep(0.10, 0.48, luma);
	graded *= mix(1.0, 0.78, shade * 0.45);
	vec2 from_centre = (UV - vec2(0.50, 0.46)) * vec2(1.12, 1.08);
	float vig = smoothstep(0.42, 1.18, length(from_centre));
	graded *= mix(1.0, 0.82, vig * 0.5);
	COLOR = vec4(clamp(graded, 0.0, 1.0), 1.0);
}
