class_name Fx
extends Node3D
## T18: one-shot explosion FX at a mine. Spawns a flash light, a one-shot smoke
## burst and a one-shot sparks burst (all children of this node), kicks the camera
## shake, and logs the FX marker. Every child frees itself when its effect runs out.

var _rig: CameraRig
var _hud: Hud


## Stores the rig (used for the shake) and the hud. Called once in main._ready().
func setup(rig: CameraRig, hud: Hud) -> void:
	_rig = rig
	_hud = hud


## A mine went off at this world position (the tile top).
func explosion(pos: Vector3) -> void:
	# --- Flash: a warm point light that fades to 0 over 0.35 s, then frees ---
	var flash := OmniLight3D.new()
	flash.name = "Flash"
	flash.position = pos + Vector3(0, 0.6, 0)
	flash.light_color = Color("#ffb347")
	flash.omni_range = 4.0
	flash.light_energy = 6.0
	add_child(flash)
	var flash_tw := create_tween()
	flash_tw.tween_property(flash, "light_energy", 0.0, 0.35)
	flash_tw.finished.connect(func():
		if is_instance_valid(flash):
			flash.queue_free())

	# --- Smoke: a one-shot burst of translucent grey spheres drifting upward ---
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.position = pos
	smoke.amount = 30
	smoke.lifetime = 1.2
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.direction = Vector3.UP
	smoke.spread = 45.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3(0, 0.3, 0)
	smoke.color = Color(0.25, 0.25, 0.27, 0.8)
	smoke.emitting = false

	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.07
	smoke_mesh.height = 0.14
	smoke.mesh = smoke_mesh

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.vertex_color_use_as_albedo = true
	smoke.material_override = smoke_mat

	add_child(smoke)
	smoke.emitting = true
	get_tree().create_timer(1.6).timeout.connect(func():
		if is_instance_valid(smoke):
			smoke.queue_free())

	# --- Sparks: a one-shot burst of tiny glowing cubes thrown up then falling ---
	var sparks := CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.position = pos
	sparks.amount = 20
	sparks.lifetime = 0.5
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 3.5
	sparks.gravity = Vector3(0, -9, 0)
	sparks.color = Color("#ffcf4a")
	sparks.emitting = false

	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.03, 0.03, 0.03)
	sparks.mesh = spark_mesh

	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.vertex_color_use_as_albedo = true
	sparks.material_override = spark_mat

	add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(sparks):
			sparks.queue_free())

	# --- Camera shake + FX marker ---
	if _rig != null:
		_rig.shake(0.18, 0.4)
	GameEvent.marker("FX", "boom")


func treasure(pos: Vector3, gold: int) -> void:
	# --- Chest sparkle: a one-shot burst of tiny gold sparks that fly up and
	# fall, thrown from a chest tile top.
	var sparkle := CPUParticles3D.new()
	sparkle.name = "Sparkle"
	sparkle.position = pos + Vector3(0, 0.25, 0)
	sparkle.amount = 24
	sparkle.lifetime = 0.8
	sparkle.one_shot = true
	sparkle.explosiveness = 0.8
	sparkle.direction = Vector3.UP
	sparkle.spread = 70.0
	sparkle.initial_velocity_min = 0.6
	sparkle.initial_velocity_max = 1.4
	sparkle.gravity = Vector3(0, -1.5, 0)
	sparkle.color = Color("#ffd23f")
	sparkle.emitting = false

	var sparkle_mesh := SphereMesh.new()
	sparkle_mesh.radius = 0.025
	sparkle.mesh = sparkle_mesh

	var sparkle_mat := StandardMaterial3D.new()
	sparkle_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	sparkle_mat.vertex_color_use_as_albedo = true
	sparkle.material_override = sparkle_mat

	add_child(sparkle)
	sparkle.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(sparkle):
			sparkle.queue_free())

	# --- Coins fly to the counter, and the FX marker ---
	_hud.fly_coins(_rig.camera.unproject_position(pos), clampi(gold / 10, 3, 8))
	GameEvent.marker("TREASURE", str(gold))
