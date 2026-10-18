extends Node3D

class_name Intro

signal finished

var rig: CameraRig
var board: Board
var _sfx: Sfx
var _is_skipping: bool = false
var _tween: Tween

# For driving rig.yaw and rig.distance via Intro's _process
var _tween_yaw: float = 0.0
var _tween_dist: float = 14.0

func _ready() -> void:
	pass

func play(full: bool, camera_rig: CameraRig, sfx: Sfx) -> void:
	rig = camera_rig
	board = get_parent().board
	_sfx = sfx
	_is_skipping = false

	GameEvent.marker("INTRO_START", "full=%s" % str(full))

	if full:
		await _do_full_intro()
	else:
		await _do_short_intro()

	GameEvent.marker("INTRO_END", "t=%d" % (Time.get_ticks_msec() / 1000))
	finished.emit()

func _input(event: InputEvent) -> void:
	if _is_skipping: return
	if event is InputEventMouseButton or event is InputEventKey:
		if event.pressed:
			_skip()

func _skip() -> void:
	_is_skipping = true
	if _tween:
		_tween.kill()

	# Skip to the end: camera at play view, nodes freed
	rig.distance = 14.0
	rig.yaw = 0.0
	rig.apply()

	finished.emit()
	queue_free()

func _process(_delta: float) -> void:
	if rig:
		rig.yaw = _tween_yaw
		rig.distance = _tween_dist
		rig.apply()

func _do_full_intro() -> void:
	_tween = create_tween()

	# Setup UFO
	var ufo := Art.prop("ufo")
	ufo.scale *= 2.0
	add_child(ufo)
	var alien := Art.prop("alien")
	ufo.add_child(alien)
	# the alien model's mesh sits off its origin (measured): this centres it on the dome; the dome is opaque, so it
	# stands in a hatch at the top with head and shoulders out (dome top: 0.68 in UFO space, alien: 0.35 tall)
	alien.position = Vector3(-0.83, 0.55, -0.64)
	ufo.global_position = Vector3(-25, 6, 0)

	# Setup Camera
	_tween_dist = 22.0
	_tween_yaw = 0.0

	# 0-3s: Camera starts far and rotating
	_tween.set_parallel(true)
	_tween.tween_property(self, "_tween_yaw", 360.0, 12.0)
	_tween.tween_property(self, "_tween_dist", 22.0, 12.0)
	_tween.tween_property(ufo, "global_position", Vector3(25, 6, 0), 12.0)

	# Bobbing and tilting
	var bob_tween := create_tween()
	bob_tween.tween_method(func(t: float):
		ufo.position.y = 6.0 + sin(t * 2.0) * 0.5
		ufo.rotation.z = sin(t * 2.0) * 0.2
	, 0.0, 12.0, 12.0)

	# 3-8s: Bombs
	get_tree().create_timer(3.0).timeout.connect(func(): _drop_bombs(ufo))

	# 3-8s: Speech bubble
	get_tree().create_timer(3.0).timeout.connect(func(): _show_speech_bubble(ufo))

	# 3-8s: Whale and Petunias
	get_tree().create_timer(6.0).timeout.connect(func(): _drop_gag(ufo))

	# 8-11s: UFO zips off and Camera swoops
	get_tree().create_timer(8.0).timeout.connect(func():
		var zip_tween := create_tween()
		zip_tween.tween_property(ufo, "global_position", Vector3(40, 10, 0), 3.0)

		var cam_swoop := create_tween()
		cam_swoop.tween_property(self, "_tween_dist", 14.0, 3.0)
		cam_swoop.parallel().tween_property(self, "_tween_yaw", 0.0, 3.0)
	)

	await _tween.finished

func _do_short_intro() -> void:
	_tween = create_tween()

	# Setup UFO
	var ufo := Art.prop("ufo")
	ufo.scale *= 2.0
	add_child(ufo)
	var alien := Art.prop("alien")
	ufo.add_child(alien)
	# the alien model's mesh sits off its origin (measured): this centres it on the dome; the dome is opaque, so it
	# stands in a hatch at the top with head and shoulders out (dome top: 0.68 in UFO space, alien: 0.35 tall)
	alien.position = Vector3(-0.83, 0.55, -0.64)
	ufo.global_position = Vector3(-25, 6, 0)

	_tween_dist = 22.0
	_tween_yaw = 0.0

	_tween.set_parallel(true)
	_tween.tween_property(self, "_tween_yaw", 360.0, 3.0)
	_tween.tween_property(self, "_tween_dist", 22.0, 3.0)
	_tween.tween_property(ufo, "global_position", Vector3(25, 6, 0), 3.0)

	# 3 bombs
	get_tree().create_timer(0.5).timeout.connect(func(): _drop_bombs_short(ufo))

	await _tween.finished

func _drop_bombs_short(ufo: Node3D) -> void:
	var land_cells = board.land.keys()
	for i in range(3):
		var cell = land_cells.pick_random()
		var pos = Hex.to_world(cell) + Vector3(0, 10, 0)
		_sfx.play("ufo")
		_sfx.play("drop")
		_drop_item(pos, Art.prop("bomb"), 2.0, cell)
		await get_tree().create_timer(0.5).timeout

func _drop_bombs(ufo: Node3D) -> void:
	var land_cells = board.land.keys()
	for i in range(8):
		var cell = land_cells.pick_random()
		var pos = Hex.to_world(cell) + Vector3(0, 10, 0)
		_sfx.play("ufo")
		_sfx.play("drop")
		_drop_item(pos, Art.prop("bomb"), 2.0, cell)
		await get_tree().create_timer(0.6).timeout

func _drop_gag(ufo: Node3D) -> void:
	var land_cells = board.land.keys()
	var cell = land_cells.pick_random()
	var pos = Hex.to_world(cell) + Vector3(0, 10, 0)
	_sfx.play("ufo")
	_sfx.play("drop")

	# Whale
	var whale := load("res://assets/generated/whale.glb").instantiate() as Node3D
	_drop_item(pos, whale, 1.0, cell)

	# Petunias
	var petunias := load("res://assets/generated/petunias.glb").instantiate() as Node3D
	_drop_item(pos + Vector3(2, 0, 0), petunias, 1.0, cell)

func _drop_item(start_pos: Vector3, item: Node3D, scale_factor: float, target_cell: Vector2i) -> void:
	item.scale *= scale_factor
	add_child(item)
	item.global_position = start_pos
	var target_pos = Hex.to_world(target_cell) + Vector3(0, Art.TILE_TOP, 0)

	var tween := create_tween()
	tween.tween_property(item, "global_position", target_pos, 0.6)
	tween.finished.connect(func():
		_spawn_puff(target_pos)
		item.queue_free()
	)

func _spawn_puff(pos: Vector3) -> void:
	var puff := CPUParticles3D.new()
	puff.amount = 20
	puff.spread = 180.0
	puff.gravity = Vector3.ZERO
	puff.direction = Vector3.UP
	puff.initial_velocity_min = 1.0
	puff.initial_velocity_max = 2.0
	puff.scale_amount_min = 0.1
	puff.scale_amount_max = 0.3
	puff.color = Color("#d2b48c") # Sand color
	puff.one_shot = true
	puff.explosiveness = 1.0
	add_child(puff)
	puff.global_position = pos
	puff.emitting = true
	get_tree().create_timer(1.0).timeout.connect(func(): puff.queue_free())

func _show_speech_bubble(ufo: Node3D) -> void:
	# White text with a thick black outline, facing the camera: readable without a panel (a flat white quad
	# behind it read as a big white square)
	var label := Label3D.new()
	label.text = "Galactic Planning Office notice: this island is scheduled for demolition. Have a nice day."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP   # hangs below the UFO: above it is off-screen
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = 800
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = load("res://assets/kenney/kenney-fonts/Kenney Future.ttf")
	label.font_size = 36
	label.pixel_size = 0.004   # the UFO is scaled 3.2x: ~10 units wide, fits a tall window too
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.outline_size = 10
	label.no_depth_test = true
	ufo.add_child(label)
	label.position = Vector3(0, -0.3, 0)
