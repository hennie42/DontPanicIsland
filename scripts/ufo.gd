class_name Ufo
## The UFO with a glass dome and the alien inside (director, 2026-10-18). The Kenney UFO is one mesh with one
## atlas material, so the dome is picked out by shape in shaders/ufo_glass.gdshader (solid pass + glass pass); the
## model is solid, so a floor disc closes the dome from below; the alien sits on it, scaled to fit under the glass.
## Use Ufo.make() everywhere instead of Art.prop("ufo").

const DOME_FLOOR_Y := 0.37         # just above the disc's own top (0.34-0.35): at the same height they z-fought
const ALIEN_SCALE := 0.75          # 0.35 tall would poke through the dome top (0.68); 0.26 fits
const ALIEN_OFFSET := Vector3(-0.83, 0.0, -0.64)   # the alien mesh sits off its origin (measured at scale 1)


static func make(with_alien: bool = true) -> Node3D:
	var ufo := Art.prop("ufo")
	var mi := ufo.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var src := mi.mesh.surface_get_material(0) as StandardMaterial3D
	var solid := ShaderMaterial.new()
	solid.shader = load("res://shaders/ufo_glass.gdshader")
	solid.set_shader_parameter("albedo_tex", src.albedo_texture)
	var glass := ShaderMaterial.new()
	glass.shader = solid.shader
	glass.set_shader_parameter("glass_pass", true)
	glass.render_priority = 1
	solid.next_pass = glass
	mi.material_override = solid
	# the floor inside the dome
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 0.255     # inside the dome's solid collar (the glass starts at 0.40)
	floor_mesh.bottom_radius = 0.255
	floor_mesh.height = 0.01
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#a7aecb")   # the UFO body's own grey-blue: where it overlaps the disc, no seam
	floor_mat.roughness = 0.6
	var dome_floor := MeshInstance3D.new()
	dome_floor.name = "DomeFloor"
	dome_floor.mesh = floor_mesh
	dome_floor.material_override = floor_mat
	dome_floor.position.y = DOME_FLOOR_Y
	mi.add_child(dome_floor)
	if with_alien:
		var alien := Art.prop("alien")
		alien.name = "Alien"
		alien.scale *= ALIEN_SCALE
		alien.rotation_degrees.y = 180.0   # face out of the dome (towards the default camera, +z)
		# turned 180 degrees about its origin, its off-centre mesh swaps sides: mirror the offset in x and z
		alien.position = Vector3(-ALIEN_OFFSET.x, 0.0, -ALIEN_OFFSET.z) * ALIEN_SCALE + Vector3(0, DOME_FLOOR_Y + 0.005, 0)
		mi.add_child(alien)
	return ufo
