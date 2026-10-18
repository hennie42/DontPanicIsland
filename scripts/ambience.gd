class_name Ambience
extends Node3D

var _palms: Array[Dictionary] = [] # {node: Node3D, ph: float}
var _fogs: Array[Dictionary] = []  # {node: Node3D, ph: float}
var _gulls: Array[Dictionary] = [] # {node: Node3D, r: float, h: float, w: float, i: float}
var _island_centre: Vector3 = Vector3.ZERO

func build(b: Board, view: BoardView) -> void:
	# Collect palms
	for c in b.land:
		if b.land[c] == "palm":
			var p := view.cells[c].get_node("Props/TerrainProp") as Node3D
			if p:
				var ph := float(abs(c.x * 13 + c.y * 7) % 100) * 0.37
				_palms.append({"node": p, "ph": ph})

	# Collect fog
	for c in b.land:
		var f := view.cells[c].get_node("Fog") as Node3D
		if f:
			var ph := float(abs(c.x * 13 + c.y * 7) % 100) * 0.37
			_fogs.append({"node": f, "ph": ph})

	# Build gulls
	_island_centre = Vector3.ZERO
	for c in b.land:
		_island_centre += Hex.to_world(c)
	_island_centre /= float(b.land.size())

	for i in 3:
		var gull_node := _create_gull(i)
		add_child(gull_node)

		var w := 0.25 + i * 0.07
		if i == 1: w = -w

		_gulls.append({
			"node": gull_node,
			"r": 5.0 + i * 1.3,
			"h": 3.0 + i * 0.4,
			"w": w,
			"i": float(i)
		})

	# Marker
	GameEvent.marker("LIFE", "gulls=3 palms=%d" % _palms.size())

func _create_gull(i: int) -> Node3D:
	var gull := Node3D.new()
	gull.name = "Gull_%d" % i

	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.04
	bm.height = 0.18
	body.mesh = bm

	# CapsuleMesh's height is along Y. So we rotate it around X.
	body.rotation_degrees.x = 90.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#f4f6f8")
	body.set_surface_override_material(0, mat)
	gull.add_child(body)

	# Wings
	for side in [-1, 1]:
		var hinge := Node3D.new()
		hinge.name = "Hinge_%s" % ("L" if side == -1 else "R")
		# offset by half its width. BoxMesh width is 0.22. Half is 0.11.
		hinge.position.x = 0.11 * side
		gull.add_child(hinge)

		var wing_mesh := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.22, 0.01, 0.07)
		wing_mesh.mesh = wm
		wing_mesh.set_surface_override_material(0, mat)

		# pivoting at the body side.
		# hinge is at x=0.11. Mesh center at 0.0.
		# We want mesh's edge to be at hinge.
		# If we put mesh as child of hinge, and mesh's center is 0.0,
		# then hinge at 0.11 means mesh is at 0.11 to 0.33.
		# We want mesh to be from 0.0 to 0.22 relative to hinge.
		# So offset mesh by -0.11 in x.
		wing_mesh.position.x = -0.11
		hinge.add_child(wing_mesh)
		hinge.set_name("Wing_%s" % ("L" if side == -1 else "R"))

	return gull

func add_smoke(pos: Vector3) -> void:
	if pos == Vector3.INF:
		return

	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	add_child(smoke)
	smoke.position = pos + Vector3(0, 0.15, 0)
	smoke.amount = 24
	smoke.lifetime = 2.5
	smoke.emitting = true
	smoke.direction = Vector3.UP
	smoke.spread = 12
	smoke.gravity = Vector3(0, 0.15, 0)
	smoke.initial_velocity_min = 0.2
	smoke.initial_velocity_max = 0.35
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.0

	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.0))
	smoke.scale_amount_curve = curve

	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.85, 0.85, 0.55))
	grad.set_color(1, Color(0.9, 0.9, 0.9, 0.0))
	smoke.color_ramp = grad

	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	smoke.mesh = sm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	smoke.material_override = mat

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0

	# Palms sway
	for item in _palms:
		var p := item.node as Node3D
		var ph: float = item.ph
		if is_instance_valid(p):
			p.rotation_degrees.x = sin(t * 1.1 + ph) * 2.5
			p.rotation_degrees.z = cos(t * 0.9 + ph) * 2.0

	# Fog drifts
	for item in _fogs:
		var f := item.node as Node3D
		var ph: float = item.ph
		if is_instance_valid(f):
			f.position.y = 0.5 + sin(t * 0.7 + ph) * 0.05
			f.rotation_degrees.y = sin(t * 0.25 + ph) * 12.0

	# Gulls
	for g in _gulls:
		var gull := g.node as Node3D
		if is_instance_valid(gull):
			var angle: float = t * g.w
			var next_angle: float = (t + 0.1) * g.w
			var pos := _island_centre + Vector3(g.r * cos(angle), g.h, g.r * sin(angle))
			gull.position = pos

			# Facing direction of travel (tangent)
			# Tangent of (cos(a), sin(a)) is (-sin(a), cos(a))
			# In 3D: (-sin(a), 0, cos(a)) if y is up
			# But look_at needs a target. Next point on circle:
			var next_pos := _island_centre + Vector3(g.r * cos(next_angle), g.h, g.r * sin(next_angle))
			if gull.position.distance_to(next_pos) > 0.001:
				gull.look_at(next_pos, Vector3.UP)

			# Flap wings
			for hinge in gull.get_children():
				if hinge.name.begins_with("Hinge_"):
					var side := 1 if "R" in hinge.name else -1
					hinge.rotation_degrees.z = side * sin(t * 6.0 + g.i) * 25.0
