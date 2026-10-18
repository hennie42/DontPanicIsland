shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
// The sea (director, 2026-10-18): turquoise shallows fading into deep blue, a foam line along the beach with a
// second line rolling in, waves that calm near the shore, sun glints. shore_field holds the distance to the
// beach (tools/make_shore_field.py: 0 at the land's edge, 1 = max_d units or more).

uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec4 field_rect;               // min_x, min_z, size, max_d
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec3 shallow : source_color = vec3(0.30, 0.86, 0.82);
uniform vec3 mid : source_color = vec3(0.10, 0.62, 0.82);
uniform vec3 deep : source_color = vec3(0.02, 0.33, 0.66);
uniform vec3 foam_color : source_color = vec3(0.97, 0.99, 1.0);
uniform float wave_height = 0.045;
uniform float ripple = 0.18;        // fine normal ripples (glints); lower on the web renderer
uniform float min_roughness = 0.06; // very shiny water glitters; the web renderer uses more (sub-pixel glints flickered)

varying highp vec3 world;   // highp: phone GPUs default to medium precision (the water flickered)
varying float shore_d;

float dist_to_shore(vec2 xz) {
	vec2 uv = (xz - field_rect.xy) / field_rect.z;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return field_rect.w;
	}
	return texture(shore_field, uv).r * field_rect.w;
}

float waves(vec2 p, float t) {
	return sin(p.x * 0.9 + t * 1.1) * 0.5
		+ sin(p.y * 1.3 - t * 0.8 + p.x * 0.4) * 0.35
		+ sin((p.x + p.y) * 2.1 + t * 1.7) * 0.15;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	highp float t = mod(TIME, 628.3185);   // keeps the wave maths in small numbers (precision), 100 full cycles
	shore_d = dist_to_shore(world.xz);
	float calm = smoothstep(0.0, 2.5, shore_d);           // flat at the beach, full waves further out
	float h = waves(world.xz, t) * wave_height * calm;
	VERTEX.y += h;
	// normal from the wave slope (finite differences)
	float e = 0.15;
	float hx = waves(world.xz + vec2(e, 0.0), t) * wave_height * calm;
	float hz = waves(world.xz + vec2(0.0, e), t) * wave_height * calm;
	NORMAL = normalize(vec3(h - hx, e, h - hz));
}

void fragment() {
	// the clock wrapped at 100 s: every scroll speed below times 100 is a whole number, so the wrap is seamless
	highp float ft = mod(TIME, 100.0);
	float d = dist_to_shore(world.xz);
	// colour by depth: shallow near the beach, deep further out
	vec3 col = mix(shallow, mid, smoothstep(0.0, 1.6, d));
	col = mix(col, deep, smoothstep(1.4, 5.5, d));
	// foam: a broken line at the beach, and a second line rolling in towards it
	float n = texture(noise, world.xz * 0.35 + vec2(ft * 0.03, ft * 0.02)).r;
	float n2 = texture(noise, world.xz * 0.9 - vec2(ft * 0.05, 0.0)).r;
	float edge = 1.0 - smoothstep(0.05, 0.22 + n * 0.12, d);
	float roll = fract(ft * 0.18);                       // 0..1: a wave travels in from 1.1 units to the beach
	float ring_d = mix(1.1, 0.15, roll);
	float ring = (1.0 - smoothstep(0.0, 0.07, abs(d - ring_d))) * smoothstep(0.0, 0.25, roll) * (1.0 - roll);
	float foam = clamp(edge + ring * 0.8, 0.0, 1.0) * smoothstep(0.35, 0.6, n2 + edge * 0.5);
	col = mix(col, foam_color, foam);
	// fine ripples in the normal for the glints
	vec3 rip = texture(noise, world.xz * 1.6 + vec2(ft * 0.06, -ft * 0.04)).rgb * 2.0 - 1.0;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(rip.x * ripple, 0.0, rip.z * ripple, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = mix(min_roughness, 0.6, foam);
	SPECULAR = 0.55;
	METALLIC = 0.0;
}
