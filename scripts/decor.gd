class_name Decor
extends Node3D
## T14. Static beach dressing (build), the camp on the landing cell
## (place_camp), and the crew figures that become skeletons as crewmates are
## lost (update_crew).
##
## Every prop sits on Art.TILE_TOP under a cell's "Props" node, so it moves
## with that cell (a revealed cell drops from the hidden height to y=0).
## The camp flag is scaled down by a third for each lost crewmate.

const CREW_KEYS := ["crew_a", "crew_b", "crew_c"]
const SKELETON_KEY := "skeleton_a"
const FLAG_BASE_SCALE := 0.3577   # uniform scale of Art.PROPS["camp_flag"]

var _campfire: Node3D
var _camp_flag: Node3D
var _crew_holders: Array[Node3D] = []
var _crew_figs: Array[Node3D] = []
var _view: BoardView
var _last_crew: int = -1
var _crabs: Array = []           # each: {node, base, dir, phase}
var _boat: Node3D

const FIRE_POS := Vector3(0.14, 0.0, 0.06)  # campfire, offset from the cell
                                            # centre (clears a palm trunk)


func build(b: Board, view: BoardView) -> void:
	_view = view
	# beach cells in a deterministic order (the ticket's cell hash)
	var beach: Array = []
	for c in b.land:
		if b.land[c] == "beach":
			beach.append(c)
	beach.sort_custom(_hash_less)

	# ~6 beach balls, red/yellow alternating
	for i in 6:
		if i < beach.size():
			_place_ball(view, beach[i], i % 2 == 0)
	# ~4 buckets, each with a shovel next to it
	for i in range(6, 10):
		if i < beach.size():
			_place_bucket(view, beach[i])
	# ~5 crabs (wander in _process)
	for i in range(10, 15):
		if i < beach.size():
			_place_crab(view, beach[i])
	# 3 umbrellas
	for i in range(15, 18):
		if i < beach.size():
			_place_umbrella(view, beach[i])

	# a parrot perched on one palm top
	var palms: Array = []
	for c in b.land:
		if b.land[c] == "palm":
			palms.append(c)
	palms.sort_custom(_hash_less)
	if not palms.is_empty():
		_place_parrot(view, palms[0])

	# a rowboat in the water next to one beach cell
	_place_rowboat(b, view)


func place_camp(b: Board, first: Vector2i) -> void:
	if _camp_flag != null:
		return
	if not _view.cells.has(first):
		return
	var props := _view.cells[first].get_node("Props") as Node3D

	# campfire
	var fire := Art.prop("campfire")
	fire.name = "CampFire"
	fire.position = FIRE_POS
	props.add_child(fire)
	_campfire = fire

	# camp flag (scales down a third per lost crewmate)
	var flag := Art.prop("camp_flag")
	flag.name = "CampFlag"
	flag.position = Vector3(-0.08, 0.0, -0.14)
	flag.rotation_degrees.y = 45.0
	props.add_child(flag)
	_camp_flag = flag

	# barrel + crate
	var barrel := Art.prop("barrel")
	barrel.name = "CampBarrel"
	barrel.position = Vector3(0.28, 0.0, -0.12)
	props.add_child(barrel)
	var crate := Art.prop("crate")
	crate.name = "CampCrate"
	crate.position = Vector3(0.0, 0.0, 0.24)
	props.add_child(crate)

	# three crew holders standing around the fire
	_crew_holders.clear()
	_crew_figs.clear()
	for i in 3:
		var holder := Node3D.new()
		holder.name = "Crew_%d" % i
		holder.position = FIRE_POS + _crew_spot(i)
		props.add_child(holder)
		_crew_holders.append(holder)
		_crew_figs.append(null)

	_last_crew = -1
	GameEvent.marker("CAMP", "%d %d" % [first.x, first.y])


func update_crew(b: Board) -> void:
	if b.crew != _last_crew:
		_rebuild_crew(b.crew)
	_last_crew = b.crew

	# lower the camp flag by a third for each lost crewmate
	if _camp_flag != null:
		var frac := clampf(b.crew / 3.0, 0.0, 1.0)
		if frac > 0.0:
			_camp_flag.visible = true
			_camp_flag.scale = Vector3(FLAG_BASE_SCALE, FLAG_BASE_SCALE * frac, FLAG_BASE_SCALE)
		else:
			# fully lowered (all crew lost): hide it (avoids a zero-scale
			# degenerate transform)
			_camp_flag.visible = false

	GameEvent.marker("CREW", str(b.crew))


func _rebuild_crew(crew: int) -> void:
	for i in 3:
		var holder := _crew_holders[i]
		# swap the current occupant for a fresh figure or a fallen skeleton
		for ch in holder.get_children():
			ch.queue_free()
		if i < crew:
			# alive: crew figure, idle bob driven in _process
			var fig := Art.prop(CREW_KEYS[i])
			fig.name = "Crew_%d" % i
			var to_fire := -_crew_spot(i)
			fig.rotation_degrees.y = rad_to_deg(atan2(to_fire.z, to_fire.x))
			holder.add_child(fig)
			_crew_figs[i] = fig
		else:
			# lost: skeleton lying down (rotation x 90)
			var skel := Art.prop(SKELETON_KEY)
			skel.name = "Skel_%d" % i
			skel.rotation_degrees.x = 90.0
			holder.add_child(skel)
			_crew_figs[i] = null


func _crew_spot(i: int) -> Vector3:
	const ANGLES := [210.0, 90.0, 330.0]
	var a := rad_to_deg(deg_to_rad(ANGLES[i]))
	return Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2)


func _cell_offset(c: Vector2i) -> Vector3:
	var h: int = abs(c.x * 31 + c.y * 17)
	var ox: float = (h % 17) / 16.0 * 0.5 - 0.25
	var oz: float = (h * 7 % 19) / 18.0 * 0.5 - 0.25
	return Vector3(ox, 0.0, oz)


func _hash_less(a: Vector2i, b: Vector2i) -> bool:
	var ha: int = abs(a.x * 31 + a.y * 17)
	var hb: int = abs(b.x * 31 + b.y * 17)
	if ha != hb:
		return ha < hb
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y


func _place_ball(view: BoardView, c: Vector2i, red: bool) -> void:
	var props := view.cells[c].get_node("Props") as Node3D
	var ball := Art.prop("ball_red" if red else "ball_yellow")
	ball.name = "Ball"
	# sphere origin is at the centre -> sit it on the tile top
	ball.position = _cell_offset(c) + Vector3(0.0, 0.09, 0.0)
	props.add_child(ball)


func _place_bucket(view: BoardView, c: Vector2i) -> void:
	var props := view.cells[c].get_node("Props") as Node3D
	var off := _cell_offset(c)
	var bucket := Art.prop("bucket")
	bucket.name = "Bucket"
	bucket.position = off
	props.add_child(bucket)
	var shovel := Art.prop("shovel")
	shovel.name = "Shovel"
	shovel.position = off + Vector3(0.12, 0.0, 0.0)
	shovel.rotation_degrees.x = 90.0   # lying in the sand
	props.add_child(shovel)


func _place_crab(view: BoardView, c: Vector2i) -> void:
	var props := view.cells[c].get_node("Props") as Node3D
	var crab := Art.prop("crab")
	crab.name = "Crab"
	var base := _cell_offset(c)
	crab.position = base
	props.add_child(crab)
	var h: int = abs(c.x * 31 + c.y * 17)
	var ang := deg_to_rad(h * 6.0)
	var dir := Vector3(cos(ang), 0.0, sin(ang))
	_crabs.append({"node": crab, "base": base, "dir": dir, "phase": h})


func _place_umbrella(view: BoardView, c: Vector2i) -> void:
	var props := view.cells[c].get_node("Props") as Node3D
	var u := _make_umbrella()
	u.position = _cell_offset(c)
	props.add_child(u)


func _make_umbrella() -> Node3D:
	var u := Node3D.new()
	u.name = "Umbrella"

	# pole: CylinderMesh, 0.5 tall
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.02
	pm.bottom_radius = 0.02
	pm.height = 0.5
	pole.mesh = pm
	var pm_mat := StandardMaterial3D.new()
	pm_mat.albedo_color = Color("#c8a273")
	pole.set_surface_override_material(0, pm_mat)
	u.add_child(pole)
	pole.position = Vector3(0.0, 0.25, 0.0)   # pole stands from the tile top up

	# canopy: 8 flat slats (Cone-like), two colours alternating
	var colors: Array = [Color("#e63946"), Color("#f1f1f1")]
	for i in 8:
		var slat := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.135, 0.03, 0.34)
		slat.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % 2]
		slat.set_surface_override_material(0, mat)
		var a := i * 45.0
		var rad := deg_to_rad(a)
		slat.rotation_degrees.y = a
		slat.position = Vector3(sin(rad), 0.0, cos(rad)) * 0.17 + Vector3(0.0, 0.5, 0.0)
		u.add_child(slat)
	return u


func _place_parrot(view: BoardView, c: Vector2i) -> Node3D:
	var props := view.cells[c].get_node("Props") as Node3D
	var p := Art.prop("parrot")
	p.name = "Parrot"
	# perched on top of the palm (palm tops are ~0.9-0.95 tall)
	p.position = Vector3(0.0, 0.92, 0.0)
	p.rotation_degrees.y = ((c.x * 37 + c.y * 91) % 360)
	props.add_child(p)
	return p


func _place_rowboat(b: Board, view: BoardView) -> void:
	# find a beach cell bordering water and park the boat in that water cell
	for c in b.land:
		if b.land[c] != "beach":
			continue
		for nb in Hex.neighbors(c):
			if b.water.has(nb):
				var boat := Art.prop("rowboat")
				boat.name = "Rowboat"
				var wc := Hex.to_world(c)
				var wn := Hex.to_world(nb)
				boat.position = wn + Vector3(0.0, 0.03, 0.0)
				var dx := wc.x - wn.x
				var dz := wc.z - wn.z
				boat.rotation_degrees.y = rad_to_deg(atan2(dz, dx)) + 90.0
				add_child(boat)   # Decor is at the scene origin -> world position
				_boat = boat
				return


func fire_position() -> Vector3:
	if _campfire:
		return _campfire.global_position
	return Vector3.INF


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# crew figures idle bob (skeletons are skipped)
	for i in _crew_figs.size():
		var fig := _crew_figs[i]
		if fig != null and is_instance_valid(fig):
			fig.position = Vector3(0.0, sin(t * 2.5 + float(i) * 1.7) * 0.02, 0.0)
	# crabs wander back and forth over 0.2 units
	for ci in _crabs.size():
		var info: Dictionary = _crabs[ci]
		var crab := info.node as Node3D
		if crab != null and is_instance_valid(crab):
			crab.position = info.base + info.dir * (sin(t * 1.3 + float(info.phase)) * 0.2)
