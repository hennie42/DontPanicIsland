class_name Ocean
extends Node3D
## The sea (director, 2026-10-18): one subdivided plane with shaders/ocean.gdshader replaces the flat water tiles.
## Shallows, foam and calm water near the beach come from a baked distance-to-shore field
## (tools/make_shore_field.py -> assets/generated/shore_field.png, ShoreField.RECT).

const WATER_Y := 0.13      # the tiles stand 0.2 tall: only a low lip of their (dark) sides shows above the water
const EXTENT := 160.0      # the plane reaches past the view in every direction


func build(view: BoardView) -> void:
	for n in view.get_children():
		if String(n.name).begins_with("Water_"):
			(n as Node3D).visible = false
	var noise_tex := NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.generate_mipmaps = true
	var fnl := FastNoiseLite.new()
	fnl.frequency = 0.03
	fnl.fractal_octaves = 3
	noise_tex.noise = fnl
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ocean.gdshader")
	mat.set_shader_parameter("shore_field", load("res://assets/generated/shore_field.png"))
	mat.set_shader_parameter("field_rect", ShoreField.RECT)
	mat.set_shader_parameter("noise", noise_tex)
	var plane := PlaneMesh.new()
	plane.size = Vector2(EXTENT, EXTENT)
	# dense where waves show (near the island), the whole plane at one density keeps it simple: ~48k vertices
	plane.subdivide_width = 220
	plane.subdivide_depth = 220
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r: Vector4 = ShoreField.RECT
	sea.position = Vector3(r.x + r.z * 0.5, WATER_Y, r.y + r.z * 0.5)
	add_child(sea)
