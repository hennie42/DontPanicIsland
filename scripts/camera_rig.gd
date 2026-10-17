class_name CameraRig
extends Node3D

const TILT := 50.0               # degrees above the horizon, fixed
const MIN_DIST := 4.0
const MAX_DIST := 22.0
const PAN_LIMIT := 9.0           # the target stays within this distance of the island centre (0, 0, 0)

var camera: Camera3D             # created in _ready() as a child (current = true, fov 50)
var yaw: float = 0.0             # degrees, around the y axis
var distance: float = 14.0
var target: Vector3 = Vector3.ZERO

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 50.0
	camera.current = true
	add_child(camera)

	_setup_input_actions()
	apply()

func _setup_input_actions() -> void:
	var actions := {
		"camera_rotate_left": [KEY_Q],
		"camera_rotate_right": [KEY_E],
		"camera_zoom_in": [MOUSE_BUTTON_WHEEL_UP],
		"camera_zoom_out": [MOUSE_BUTTON_WHEEL_DOWN],
		"camera_pan": [MOUSE_BUTTON_MIDDLE],
		"camera_orbit": [MOUSE_BUTTON_RIGHT],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	for action in actions:
		for event_type in actions[action]:
			var ev: InputEvent
			if event_type is Key:
				ev = InputEventKey.new()
				ev.physical_keycode = event_type
			elif event_type is MouseButton:
				ev = InputEventMouseButton.new()
				ev.button_index = event_type
			if ev:
				InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("camera_orbit"):
			rotate_by(event.relative.x * 0.3)
		elif Input.is_action_pressed("camera_pan"):
			var scale := (distance / 14.0) * 0.02
			pan_by(Vector2(event.relative.x * scale, -event.relative.y * scale))

	elif event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_by(0.9)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by(1.1)

func _process(delta: float) -> void:
	if Input.is_action_pressed("camera_rotate_left"):
		rotate_by(-90.0 * delta)
	if Input.is_action_pressed("camera_rotate_right"):
		rotate_by(90.0 * delta)

func rotate_by(degrees: float) -> void:
	yaw += degrees
	apply()

func zoom_by(factor: float) -> void:
	distance *= factor
	distance = clamp(distance, MIN_DIST, MAX_DIST)
	apply()

func pan_by(delta: Vector2) -> void:
	# delta.x along the camera's right and delta.y along its forward-on-the-ground direction
	# middle mouse drag pans (0.02 world units per pixel, scaled by distance / 14)
	var cam_basis := camera.global_transform.basis

	var right := cam_basis.x
	right.y = 0
	right = right.normalized()

	var forward := -cam_basis.z
	forward.y = 0
	forward = forward.normalized()

	target += right * delta.x
	target += forward * delta.y

	# clamp target to PAN_LIMIT from the origin
	if target.length() > PAN_LIMIT:
		target = target.normalized() * PAN_LIMIT

	apply()

func apply() -> void:
	var yaw_rad := deg_to_rad(yaw)
	var tilt_rad := deg_to_rad(TILT)

	# target + offset(yaw, TILT, distance), looking at target
	# offset(yaw, TILT, distance) = Vector3(sin(yaw), 0, cos(yaw)) * distance * cos(TILT) + Vector3.UP * distance * sin(TILT)
	var offset := Vector3(sin(yaw_rad), 0, cos(yaw_rad)) * distance * cos(tilt_rad)
	offset += Vector3.UP * distance * sin(tilt_rad)

	camera.global_position = target + offset
	camera.look_at(target)
