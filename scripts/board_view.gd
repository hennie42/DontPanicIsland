class_name BoardView
extends Node3D

const HIDDEN_Y := 0.12          # hidden cells stand a bit higher than revealed ones (dug out)
var cells: Dictionary = {}       # Vector2i -> Node3D, one per land cell
var _hover: MeshInstance3D       # the ring under the mouse (set_hover)
var _shown: Dictionary = {}      # Vector2i -> bool: the cells revealed at the previous refresh
var _cell_tween: Dictionary = {}  # Vector2i -> Tween: each cell's running reveal tween (killed before a new one)

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


## Grass and forest in green instead of the kit's teal: the same tile material with a recoloured copy of the
## colour atlas (assets/generated/colormap_green.png, tools/make_green_colormap.py). Sand, rock and water keep
## the original.
static var _green_mat: StandardMaterial3D

func _greenify(tile: Node) -> void:
	for m in tile.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if _green_mat == null:
			_green_mat = (mi.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
			_green_mat.albedo_texture = load("res://assets/generated/colormap_green.png")
		mi.material_override = _green_mat


static var _towel_mat: StandardMaterial3D

static func _towel_material() -> StandardMaterial3D:
	if _towel_mat == null:
		_towel_mat = StandardMaterial3D.new()
		_towel_mat.albedo_texture = load("res://assets/generated/towel.png")
		_towel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR   # the rounded corners
		_towel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED                    # seen from both sides
		_towel_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _towel_mat


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
		if b.land[c] in ["grass", "jungle"]:
			_greenify(tile)
		cell_node.add_child(tile)

		# Outline (all hexes) and flag ring (flagged hexes only)
		cell_node.add_child(_ring("Outline", Hex.SIZE * 0.99, 0.035, OUTLINE_COLOR, 0.01))
		cell_node.add_child(_ring("FlagRing", Hex.SIZE * 0.96, 0.08, FLAG_RING_COLOR, 0.02))

		# Props
		var props := Node3D.new()
		props.name = "Props"
		props.position.y = Art.TILE_TOP
		cell_node.add_child(props)

		# the terrain's own prop (palm, wreck, rocks) goes when the hex is dug: palms are chopped for wood and would
		# cover the number; the camp and crew (decor) stay under Props
		var terrain_prop := Node3D.new()
		terrain_prop.name = "TerrainProp"
		props.add_child(terrain_prop)
		var terrain: String = b.land[c]
		if terrain == "palm":
			var palm_keys := ["palm_a", "palm_b", "palm_c", "palm_d"]
			var idx: int = abs(c.x * 7 + c.y * 13) % 4
			var p := Art.prop(palm_keys[idx])
			terrain_prop.add_child(p)
			p.rotation_degrees.y = float((c.x * 37 + c.y * 91) % 360)
		elif terrain == "wreck":
			terrain_prop.add_child(Art.prop("wreck"))
		elif terrain == "desert":
			if abs(c.x + 2 * c.y) % 3 == 0:
				terrain_prop.add_child(Art.prop("rocks_a"))

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
		flag.scale = Vector3.ONE   # rest scale ONE: the bounce_in (bounce_flag) lands here, and the settle check asserts Vector3.ONE
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
		# one towel with a smiley (assets/generated/towel.png, tools/make_towel.py): three red/white/blue
		# stripes read as the Dutch flag. Hangs from the pole top, off to one side; flaps about the pole.
		var cloth := MeshInstance3D.new()
		cloth.name = "Cloth"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.24, 0.15)
		cloth.mesh = quad
		cloth.material_override = _towel_material()
		cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		towel.add_child(cloth)
		cloth.position = Vector3(0.12, -0.075, 0)
		towel.position.y = 0.45

		# Skeleton
		var skel := Art.prop("skeleton_a")
		skel.name = "Skeleton"
		skel.scale *= 1.8                 # a gravestone you can spot at the default camera distance
		skel.position.y = Art.TILE_TOP    # standing on the tile, not in it
		cell_node.add_child(skel)

		# Chest
		var chest := Art.prop("chest")
		chest.name = "Chest"
		cell_node.add_child(chest)
	_cache_nodes()


## Per-frame work touches cached nodes only (F43: the game spent ~47 ms of script time per frame on node lookups by
## name and on re-setting every label's billboard mode every frame).
var _flags: Array = []            # [flag Node3D, towel Node3D, phase] per land cell
var _labels: Array = []           # every Number / Peek Label3D
var _billboard_on := false
var _last_cam_rot := Vector3.INF


func _cache_nodes() -> void:
	_flags.clear()
	_labels.clear()
	for c in cells:
		var node := cells[c] as Node3D
		var flag := node.get_node("Flag") as Node3D
		_flags.append([flag, flag.get_node("Towel"), float(c.x)])
		for part in ["Number", "Peek"]:
			var lbl := node.get_node_or_null(part) as Label3D
			if lbl:
				_labels.append(lbl)
	_billboard_on = false
	_last_cam_rot = Vector3.INF


func refresh(b: Board, origin: Variant = null) -> void:
	# --- instant final state, set at once (visibility, height, labels) ---
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
		node.get_node("Props/TerrainProp").visible = not revealed

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

	# --- motion on top, only when a click origin is given ---
	if origin != null and origin is Vector2i:
		# newly revealed cells = revealed now but not at the previous refresh, nearest first
		var new_cells: Array[Vector2i] = []
		for c in b.revealed:
			if not _shown.has(c):
				new_cells.append(c as Vector2i)
		new_cells.sort_custom(func(a: Vector2i, bb: Vector2i) -> bool:
			return Hex.distance(origin, a) < Hex.distance(origin, bb))
		for i in new_cells.size():
			var c: Vector2i = new_cells[i]
			var d: float = Hex.distance(origin, c) * 0.045
			_animate_cell(c, d)
			if i < 14:   # at most 14 sand bursts, on the nearest cells
				_add_burst(cells[c] as Node3D, d)

	# update _shown at the end of every refresh
	var shown_now: Dictionary = {}
	for c in b.revealed:
		shown_now[c] = true
	_shown = shown_now


## T18: the flag (towel) on cell `c` pops in: scale 0.2 -> 1.2 (0.12 s) -> ONE
## (0.12 s), while position.y drops 0.4 -> 0 over 0.2 s. Ends exactly at scale ONE, y 0.
func bounce_flag(c: Vector2i) -> void:
	if not cells.has(c):
		return
	var flag: Node3D = cells[c].get_node("Flag")
	if flag == null:
		return
	flag.scale = Vector3(0.2, 0.2, 0.2)
	flag.position.y = 0.4
	var tw := create_tween()
	tw.tween_property(flag, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel()
	tw.tween_property(flag, "scale", Vector3(1.2, 1.2, 1.2), 0.12)
	tw.tween_property(flag, "scale", Vector3(1, 1, 1), 0.12)


## Pull a freshly revealed cell back to its "hidden" start state, then one tween (bound to the
## view) pops it down in a ripple: the delay grows with the distance from the click.
func _animate_cell(c: Vector2i, d: float) -> void:
	# kill the cell's running tween before starting a new one
	var prev_tween := (_cell_tween.get(c, null)) as Tween
	if prev_tween:
		prev_tween.kill()

	var node := cells[c] as Node3D
	var num := node.get_node("Number") as Label3D
	var show_num := num.visible

	# the instant refresh just set the final state: restore the start state, so the tween (and
	# the look during the delay) reads as a pop out of the sand
	node.position.y = HIDDEN_Y
	node.scale = Vector3(1.12, 0.75, 1.12)
	if show_num:
		num.scale = Vector3.ZERO

	# one create_tween() per cell, bound to the view; the cell motion runs in parallel, the
	# number pops in a touch after the cell starts
	var tween := create_tween()
	tween.tween_interval(d)   # ripple: the delay grows with distance from the click
	tween.tween_property(node, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel()
	tween.tween_property(node, "scale", Vector3.ONE, 0.3)
	if show_num:
		tween.parallel()
		tween.tween_property(num, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
	_cell_tween[c] = tween


## A one-shot burst of sand grains on the (up to) 14 nearest revealed cells: fired when the
## cell's delay has passed, freed 1.0 s after it started.
func _add_burst(cell_node: Node3D, d: float) -> void:
	# replace any previous Burst for this cell
	var old_burst := cell_node.get_node_or_null("Burst")
	if old_burst != null:
		old_burst.queue_free()

	var burst := CPUParticles3D.new()
	burst.name = "Burst"
	burst.position.y = Art.TILE_TOP
	burst.amount = 10
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = false
	burst.direction = Vector3.UP
	burst.spread = 60.0
	burst.initial_velocity_min = 0.8
	burst.initial_velocity_max = 1.6
	burst.gravity = Vector3(0.0, -6.0, 0.0)
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.0
	burst.color = Color("#e8c79a")

	# a small cube per grain of sand, tinted by the vertex colour (like the smoke in ambience.gd)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	burst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	burst.material_override = mat

	cell_node.add_child(burst)

	# start the burst when the cell's delay has passed; free it 1.0 s after it started
	var start_t := get_tree().create_timer(d)
	start_t.timeout.connect(func():
		if is_instance_valid(burst):
			burst.emitting = true
			var free_t := get_tree().create_timer(1.0)
			free_t.timeout.connect(func():
				if is_instance_valid(burst):
					burst.queue_free())
	)


func _process(_delta: float) -> void:
	# Flapping flags
	var time := Time.get_ticks_msec() / 1000.0
	for f in _flags:
		if (f[0] as Node3D).visible:
			(f[1] as Node3D).rotation_degrees.y = sin(time * 3.0 + float(f[2])) * 12.0

	# Numbers face the camera's yaw and pitch (flat labels are foreshortened into unreadable shapes at the low camera
	# angle); zoomed out they billboard by themselves. Only when the camera has turned.
	var cam := get_viewport().get_camera_3d()
	if cam and not _billboard_on:
		var cam_rot := Vector3(cam.global_rotation_degrees.x, cam.global_rotation_degrees.y, 0.0)
		if not cam_rot.is_equal_approx(_last_cam_rot):
			_last_cam_rot = cam_rot
			for lbl in _labels:          # hidden ones too: a number revealed later must already face the camera
				(lbl as Label3D).rotation_degrees = cam_rot

func set_numbers_billboard(on: bool) -> void:
	if on == _billboard_on:
		return                    # called every frame by main: only a change costs anything
	_billboard_on = on
	_last_cam_rot = Vector3.INF   # back to manual facing: turn the labels on the next frame
	for lbl in _labels:
		(lbl as Label3D).billboard = BaseMaterial3D.BILLBOARD_ENABLED if on else BaseMaterial3D.BILLBOARD_DISABLED

func _get_number_color(n: int) -> Color:
	# six distinct hues on the warm sand of the "tropical punch" scheme (the old navy 4 read like the blue 1, the
	# teal 6 like the grass)
	match n:
		1: return Color("#1560f0")
		2: return Color("#1f9a2e")
		3: return Color("#e0301e")
		4: return Color("#7b2fd6")
		5: return Color("#8a3a12")
		6: return Color("#00707a")
		_: return Color.WHITE
