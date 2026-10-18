shader_type canvas_item;
render_mode blend_mul;
// Soft darkening towards the screen corners (director, 2026-10-18): frames the island like a photo.
// Multiplies the picture instead of laying a tinted layer over it: an overlay hazed it (contrast 53 -> 48).
uniform float strength = 0.28;
uniform float inner = 0.62;   // distance from the centre (0 centre .. 1 corner) where the darkening starts
uniform float outer = 1.0;

void fragment() {
	vec2 p = (SCREEN_UV - 0.5) * 2.0;
	float v = smoothstep(inner, outer, length(p) / sqrt(2.0));
	COLOR = vec4(vec3(1.0 - v * strength), 1.0);
}
