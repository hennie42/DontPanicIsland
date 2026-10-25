extends Node3D

class_name Intro

signal finished

const UFO_Y := 4.5   # flight height: at 6 it flew above the top of a 16:9 frame

var rig: CameraRig
var board: Board
var _sfx: Sfx
var _ended: bool = false
var _tween: Tween    # the UFO and camera timeline; its end is the intro's end

# For driving rig.yaw and rig.distance via Intro's _process
var _tween_yaw: float = 0.0
var _tween_zoom: float = 1.5    # rig.distance = rig.home_distance * this: the home distance changes when the window
                                # is resized (it is at startup), and a distance fixed at the start ended in a jump

## Plays the intro and returns when it is over, played to the end or skipped. Every timed step is a tween of this
## node, so a skip (which frees it) also stops the steps still to come.
func play(full: bool, camera_rig: CameraRig, sfx: Sfx) -> void:
	rig = camera_rig
	board = get_parent().board
	_sfx = sfx

	GameEvent.marker("INTRO_START", "full=%s" % str(full))

	if full:
		_do_full_intro()
	else:
		_do_short_intro()
	await finished

func _input(event: InputEvent) -> void:
	if _ended: return
	if event is InputEventMouseButton or event is InputEventKey:
		if event.pressed:
			# the skip press is the intro's: passed on, its release dug the tile under the mouse (landing the camp)
			get_viewport().set_input_as_handled()
			_end(true)

## Ends the intro (once): the camera in the play view, then `finished` and free.
func _end(skipped: bool = false) -> void:
	if _ended:
		return
	_ended = true
	if _tween:
		_tween.kill()
	# hand the camera back: left alive, _process kept forcing rig.yaw and rig.distance every frame, so the
	# player's turns and zooms snapped back
	set_process(false)
	rig.distance = rig.home_distance
	rig.yaw = 0.0
	rig.apply()
	GameEvent.marker("INTRO_END", "t=%d skipped=%s" % [Time.get_ticks_msec() / 1000, skipped])
	finished.emit()
	queue_free()

func _process(_delta: float) -> void:
	if rig:
		rig.yaw = _tween_yaw
		rig.distance = rig.home_distance * _tween_zoom
		rig.apply()

func _do_full_intro() -> void:
	# Setup UFO
	var ufo := Ufo.make()   # glass dome, the alien inside
	ufo.scale *= 2.0
	add_child(ufo)
	ufo.position = Vector3(-25, UFO_Y, 0)

	# Setup Camera
	_tween_zoom = 1.5
	_tween_yaw = 0.0

	# 0-8 s: the camera circles far out while the UFO crosses, bobbing and tilting. One timeline: two tweens on the
	# same property fought (the 12 s circle undid the swoop and left the camera at 1.5x the play distance).
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "_tween_yaw", 240.0, 8.0)
	_tween.tween_property(ufo, "position:x", 8.0, 8.0)
	_tween.tween_method(func(t: float):
		ufo.position.y = UFO_Y + sin(t * 2.0) * 0.5
		ufo.rotation.z = sin(t * 2.0) * 0.2
	, 0.0, 8.0, 8.0)
	# 8-11 s: the UFO zips off and the camera swoops down to the play view, still turning the same way
	_tween.chain().tween_property(ufo, "position", Vector3(40, 10, 0), 3.0)
	_tween.tween_property(ufo, "rotation:z", 0.0, 3.0)
	_tween.tween_property(self, "_tween_yaw", 360.0, 3.0)
	_tween.tween_property(self, "_tween_zoom", 1.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(_end)

	# 3 s: bombs; 4.5 s: the speech bubble, once the UFO is well into the picture (at 3 s it was at the left edge
	# and the text was clipped); 6 s: the whale and the petunias
	var cues := create_tween()
	cues.tween_interval(3.0)
	cues.tween_callback(_drop_bombs.bind(8, 0.6))
	cues.tween_interval(1.5)
	cues.tween_callback(_show_speech_bubble.bind(ufo))
	cues.tween_interval(1.5)
	cues.tween_callback(_drop_gag)

func _do_short_intro() -> void:
	# Setup UFO
	var ufo := Ufo.make()   # glass dome, the alien inside
	ufo.scale *= 2.0
	add_child(ufo)
	ufo.position = Vector3(-25, UFO_Y, 0)

	_tween_zoom = 1.5
	_tween_yaw = 0.0

	# one turn while closing in to the play view (it used to stay out at 1.5x and jump in at the end)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "_tween_yaw", 360.0, 3.0)
	_tween.tween_property(self, "_tween_zoom", 1.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(ufo, "position:x", 25.0, 3.0)
	_tween.finished.connect(_end)

	# 3 bombs
	var cues := create_tween()
	cues.tween_interval(0.5)
	cues.tween_callback(_drop_bombs.bind(3, 0.5))

## `count` bombs at random cells, `gap` seconds apart (decoys: the real mines are placed after the first click).
func _drop_bombs(count: int, gap: float) -> void:
	var tw := create_tween()
	for i in count:
		tw.tween_callback(_drop_bomb)
		tw.tween_interval(gap)

func _drop_bomb() -> void:
	var cell: Vector2i = board.land.keys().pick_random()
	_sfx.play("ufo")
	_sfx.play("drop")
	_drop_item(Hex.to_world(cell) + Vector3(0, 10, 0), Art.prop("bomb"), 2.0, cell)

func _drop_gag() -> void:
	var cell: Vector2i = board.land.keys().pick_random()
	var pos := Hex.to_world(cell) + Vector3(0, 10, 0)
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
	# the intro frees itself (and its puffs) when it ends: the puff may be gone when the timer fires
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(puff): puff.queue_free())

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
