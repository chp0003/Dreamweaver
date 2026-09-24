shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec2 hole_uv = vec2(0.5, 0.45);
uniform float radius_px = 78.0;
uniform float soft_px = 16.0;
uniform float veil_alpha = 0.98;
uniform vec3 veil_rgb = vec3(0.01, 0.004, 0.018);

void fragment() {
	vec2 delta_px = (SCREEN_UV - hole_uv) / SCREEN_PIXEL_SIZE;
	float cover = smoothstep(radius_px, radius_px + soft_px, length(delta_px));
	COLOR = vec4(veil_rgb, veil_alpha * cover);
}
