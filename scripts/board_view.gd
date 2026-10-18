class_name BoardView
extends Node3D

const HIDDEN_Y := 0.12          # hidden cells stand a bit higher than revealed ones (dug out)
var cells: Dictionary = {}       # Vector2i -> Node3D, one per land cell
var _hover: MeshInstance3D       # the ring under the mouse (set_hover)

const OUTLINE_COLOR := Color(0.06, 0.12, 0.2, 0.55)   # every hex: the grid reads even under trees
const FLAG_RING_COLOR := Color("#ff5a1f")              # flagged hex
const HOVER_COLOR := Color("#ffe14d")                  # the hex a click would hit


## A flat hexagonal ring (pointy-top, like Hex) lying in the xz plane: outer corner radius r, band width w.
static func hex_ring(r: float, w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in 6:
		var a0 := deg_to_rad(60.0 * i - 30.0)
		var a1 := deg_to_rad(60.0 * (i + 1) - 30.0)
		var o0 := Vector3(cos(a0), 0, sin(a0)) * r
		var o1 := Vector3(cos(a1), 0, sin(a1)) * r
		var i0 := Vector3(cos(a0), 0, sin(a0)) * (r - w)
		var i1 := Vector3(cos(a1), 0, sin(a1)) * (r - w)
		for v in [o0, i1, o1, o0, i0, i1]:
			st.add_vertex(v)
	return st.commit()


static func _ring_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _ring(name: String, r: float, w: float, color: Color, lift: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = hex_ring(r, w)
	mi.material_override = _ring_material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = Art.TILE_TOP + lift
	return mi


## Highlight the hex under the mouse, or none (null).
func set_hover(c: Variant) -> void:
	if c == null or not cells.has(c):
		_hover.visible = false
		return
	var node := cells[c] as Node3D
	_hover.visible = true
	_hover.global_position = node.global_position + Vector3(0, Art.TILE_TOP + 0.03, 0)

func build(b: Board) -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()
	cells.clear()
	_hover = _ring("Hover", Hex.SIZE * 1.0, 0.09, HOVER_COLOR, 0.0)
	_hover.visible = false
	add_child(_hover)

	# Water
	for c in b.water:
		var node := Node3D.new()
		node.name = "Water_%d_%d" % [c.x, c.y]
		add_child(node)

		var tile_key := "water"
		if (c.x * 7 + c.y * 13) % 11 == 0:
			tile_key = "water_rocks"

		var tile := Art.tile(tile_key).instantiate() as Node3D
		node.add_child(tile)
		node.position = Hex.to_world(c)

	# Land
	for c in b.land:
		var cell_node := Node3D.new()
		cell_node.name = "Cell_%d_%d" % [c.x, c.y]
		add_child(cell_node)
		cells[c] = cell_node
		cell_node.position = Hex.to_world(c)

		# Tile
		var tile := Art.tile(b.land[c]).instantiate() as Node3D
		tile.name = "Tile"
		cell_node.add_child(tile)

		# Outline (all hexes) and flag ring (flagged hexes only)
		cell_node.add_child(_ring("Outline", Hex.SIZE * 0.99, 0.035, OUTLINE_COLOR, 0.01))
		cell_node.add_child(_ring("FlagRing", Hex.SIZE * 0.96, 0.08, FLAG_RING_COLOR, 0.02))

		# Props
		var props := Node3D.new()
		props.name = "Props"
		props.position.y = Art.TILE_TOP
		cell_node.add_child(props)

		var terrain: String = b.land[c]
		if terrain == "palm":
			var palm_keys := ["palm_a", "palm_b", "palm_c", "palm_d"]
			var idx: int = abs(c.x * 7 + c.y * 13) % 4
			var p := Art.prop(palm_keys[idx])
			props.add_child(p)
			p.rotation_degrees.y = float((c.x * 37 + c.y * 91) % 360)
		elif terrain == "wreck":
			props.add_child(Art.prop("wreck"))
		elif terrain == "desert":
			if abs(c.x + 2 * c.y) % 3 == 0:
				props.add_child(Art.prop("rocks_a"))

		# Fog
		var fog := Node3D.new()
		fog.name = "Fog"
		fog.position.y = 0.5
		cell_node.add_child(fog)
		fog.add_child(Art.prop("cloud_small"))
		if (c.x + c.y) % 2 == 0:
			fog.add_child(Art.prop("cloud_big"))

		# Dug
		var dug := Art.tile("beach").instantiate() as Node3D
		dug.name = "Dug"
		dug.scale = Vector3(0.94, 1, 0.94)
		cell_node.add_child(dug)

		# Number
		var num := Label3D.new()
		num.name = "Number"
		num.font = load("res://assets/kenney/kenney-fonts/Kenney Future.ttf")
		num.font_size = 128
		num.pixel_size = 0.005
		num.outline_size = 18
		num.outline_modulate = Color.WHITE
		num.position.y = Art.TILE_TOP + 0.03
		num.rotation_degrees.x = -90
		num.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM   # stands on the tile when tilted up
		num.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		cell_node.add_child(num)

		# Peek
		var peek := Label3D.new()
		peek.name = "Peek"
		peek.font = num.font
		peek.font_size = num.font_size
		peek.pixel_size = num.pixel_size
		peek.outline_size = num.outline_size
		peek.outline_modulate = num.outline_modulate
		peek.position.y = num.position.y
		peek.rotation_degrees.x = -90
		peek.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		peek.modulate.a = 0.55
		peek.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		cell_node.add_child(peek)

		# Flag
		var flag := Node3D.new()
		flag.name = "Flag"
		flag.scale = Vector3.ONE * 1.8   # readable at the default camera distance
		cell_node.add_child(flag)

		var pole := MeshInstance3D.new()
		pole.name = "Pole"
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.015
		pole_mesh.bottom_radius = 0.015
		pole_mesh.height = 0.45
		pole.mesh = pole_mesh
		var pole_mat := StandardMaterial3D.new()
		pole_mat.albedo_color = Color("#5d4037") # Brown
		pole.set_surface_override_material(0, pole_mat)
		flag.add_child(pole)
		pole.position.y = 0.225

		var towel := Node3D.new()
		towel.name = "Towel"
		flag.add_child(towel)
		var colors := [Color("#e94f37"), Color("#f6f7eb"), Color("#3f88c5")]
		for i in 3:
			var stripe := MeshInstance3D.new()
			stripe.name = "Stripe_%d" % i
			var box := BoxMesh.new()
			box.size = Vector3(0.24, 0.045, 0.01)
			stripe.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = colors[i]
			stripe.set_surface_override_material(0, mat)
			towel.add_child(stripe)
			# relative to the towel, which already sits at the pole top: hang down from it, off to one side of the pole
			# (it rotates about the pole when it flaps)
			stripe.position = Vector3(0.12, -(i * 0.045) - 0.0225, 0)
		towel.position.y = 0.45

		# Skeleton
		var skel := Art.prop("skeleton_a")
		skel.name = "Skeleton"
		cell_node.add_child(skel)

		# Chest
		var chest := Art.prop("chest")
		chest.name = "Chest"
		cell_node.add_child(chest)

func refresh(b: Board) -> void:
	for c in b.land:
		var node := cells[c] as Node3D
		var revealed := b.revealed.has(c)

		# Fog
		var fog := node.get_node("Fog") as Node3D
		fog.visible = not b.is_visible(c)

		# Height
		node.position.y = 0.0 if revealed else HIDDEN_Y

		# Tile / Dug
		node.get_node("Tile").visible = not revealed
		node.get_node("Dug").visible = revealed

		# Number
		var num := node.get_node("Number") as Label3D
		if revealed and not b.exploded.has(c) and b.number(c) > 0:
			num.visible = true
			num.text = str(b.number(c))
			num.modulate = _get_number_color(b.number(c))
		else:
			num.visible = false

		# Peek
		var peek := node.get_node("Peek") as Label3D
		if b.peeked.has(c) and not revealed:
			peek.visible = true
			peek.text = str(b.peeked[c])
			peek.modulate = _get_number_color(b.peeked[c])
			peek.modulate.a = 0.55
		else:
			peek.visible = false

		# Flag
		node.get_node("Flag").visible = b.flagged.has(c)
		node.get_node("FlagRing").visible = b.flagged.has(c)
		node.get_node("Outline").visible = b.is_visible(c)   # not under the fog clouds

		# Skeleton
		node.get_node("Skeleton").visible = b.exploded.has(c)

		# Chest
		node.get_node("Chest").visible = revealed and b.chests.has(c)

func _process(_delta: float) -> void:
	# Flapping flag
	var time := Time.get_ticks_msec() / 1000.0
	for c in cells:
		var node := cells[c] as Node3D
		var flag := node.get_node("Flag") as Node3D
		if flag.visible:
			var towel := flag.get_node("Towel") as Node3D
			towel.rotation_degrees.y = sin(time * 3.0 + float(c.x)) * 12.0

	# Billboard numbers
	var cam := get_viewport().get_camera_3d()
	if cam:
		# face the camera's yaw and pitch: flat labels are foreshortened into unreadable shapes at the low camera angle
		var cam_rot := Vector3(cam.global_rotation_degrees.x, cam.global_rotation_degrees.y, 0.0)
		for c in cells:
			var node := cells[c] as Node3D
			for part in ["Number", "Peek"]:
				var lbl := node.get_node(part) as Label3D
				if lbl.visible:
					lbl.rotation_degrees = cam_rot

func set_numbers_billboard(on: bool) -> void:
	for c in cells:
		var node := cells[c] as Node3D
		for part in ["Number", "Peek"]:
			var lbl := node.get_node(part) as Label3D
			if lbl:
				lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED if on else BaseMaterial3D.BILLBOARD_DISABLED

func _get_number_color(n: int) -> Color:
	match n:
		1: return Color("#1e5bd8")
		2: return Color("#2e8b3a")
		3: return Color("#d63a2f")
		4: return Color("#1a2a6c")
		5: return Color("#7a1f1f")
		6: return Color("#138a8a")
		_: return Color.WHITE
