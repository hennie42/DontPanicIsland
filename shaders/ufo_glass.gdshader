shader_type spatial;
// The UFO with a glass dome (director, 2026-10-18): the Kenney UFO is one mesh with one atlas-textured material,
// so the dome is picked out by shape: everything above DOME_Y in the model's own space (the disc's top is at
// 0.34-0.35, the dome wall runs from 0.34 to 0.44; a cut at 0.35 ran through near-flat triangles and speckled, at
// 0.40 it crosses the wall and leaves a small solid collar). glass_pass false: the solid UFO without the dome; true (next_pass): only the
// dome, as tinted glass with a bright rim.
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform bool glass_pass = false;
uniform vec3 glass_tint : source_color = vec3(0.70, 0.88, 1.0);
const float DOME_Y = 0.40;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	bool dome = local_pos.y > DOME_Y;
	if (dome != glass_pass) {
		discard;
	}
	if (glass_pass) {
		float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
		ALBEDO = glass_tint;
		ALPHA = 0.22 + fresnel * 0.6;
		ROUGHNESS = 0.05;
		SPECULAR = 0.9;
	} else {
		ALBEDO = texture(albedo_tex, UV).rgb;
		ROUGHNESS = 0.6;
	}
}
