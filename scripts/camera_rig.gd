class_name CameraRig
extends Node3D

const TILT := 58.0               # degrees above the horizon, fixed (50 squashed the far rows: hard to click)
const MIN_DIST := 4.0
const MAX_DIST := 22.0           # zoom-out limit; raised to fit the island when a window needs more (fit_island)
# screen kept free around the island (fractions of width / height): the HUD covers the bottom (tool bar and
# controls line) and the top-left corner
const FIT_SIDE := 0.04
const FIT_TOP := 0.07
const FIT_BOTTOM := 0.12
const PAN_LIMIT := 9.0           # the target stays within this distance of the island centre (0, 0, 0)

var camera: Camera3D             # created in _ready() as a child (current = true, fov 50)
var yaw: float = 0.0             # degrees, around the y axis
var distance: float = 14.0
var target: Vector3 = Vector3.ZERO
var home_distance: float = 14.0  # the distance that shows the whole island in this window (fit_island)
var max_dist: float = MAX_DIST
var _fit_points: Array = []      # world points that must stay on screen at home_distance
var _fit_centre := Vector3.ZERO  # the island centre; the aim point slides from here along z to balance the frame
var _user_zoomed := false        # after the player zooms, window resizes no longer reframe
var input_enabled := true        # camera keys and wheel (main.gd turns them off while a menu is open)

# T18 camera shake: a decaying random offset applied to the camera position, so the
# view jolts (rather than merely the lens turning) when a mine goes off.
var shake_offset: Vector3 = Vector3.ZERO
var _shake_strength: float = 0.0
var _shake_seconds: float = 0.0
var _shake_remaining: float = 0.0
var _shaking: bool = false

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 50.0
	camera.current = true
	add_child(camera)

	_setup_input_actions()
	get_viewport().size_changed.connect(_on_viewport_resized)
	apply()


## Frame the island: the smallest distance at which every point (hex corners, prop tops) is on screen with a
## margin, for the current window shape. Wide windows fix the vertical field of view, tall ones the horizontal one,
## so the island fits either way (a fixed 14 cropped it in 16:9 and wasted space in tall windows).
func fit_island(points: Array, centre: Vector3) -> void:
	_fit_points = points
	_fit_centre = centre
	_refit()
	distance = home_distance
	apply()


func _on_viewport_resized() -> void:
	if _fit_points.is_empty():
		return
	var kept := target
	_refit()
	if _user_zoomed:          # the player moved the camera: keep their view
		target = kept
	else:
		distance = home_distance
		apply()


func _refit() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT if aspect >= 1.0 else Camera3D.KEEP_WIDTH
	# perspective makes the near side of the island look bigger, so aiming at its centre leaves empty sea at the
	# top: try aim points along z and keep the one that lets the camera come closest
	var best_d := INF
	var best_z := 0.0
	for i in 17:
		var dz := -4.0 + i * 0.5
		target = _fit_centre + Vector3(0, 0, dz)
		var d := fit_distance(_fit_points, aspect)
		if d < best_d:
			best_d = d
			best_z = dz
	target = _fit_centre + Vector3(0, 0, best_z)
	home_distance = best_d
	max_dist = maxf(MAX_DIST, home_distance * 1.25)


## Smallest distance (binary search) at which all points fit a window of this aspect (width / height).
func fit_distance(points: Array, aspect: float) -> float:
	var lo := MIN_DIST
	var hi := 80.0
	for i in 30:
		var mid := (lo + hi) * 0.5
		if _fits(points, mid, aspect):
			hi = mid
		else:
			lo = mid
	return hi


func _fits(points: Array, d: float, aspect: float) -> bool:
	# measured for the play view (yaw 0): the intro spins the camera, and the result must not depend on when the
	# window was resized
	var tilt_rad := deg_to_rad(TILT)
	var pos := target + Vector3(0, 0, 1) * d * cos(tilt_rad) + Vector3.UP * d * sin(tilt_rad)
	var inv := Basis.looking_at(target - pos).inverse()
	var half := tan(deg_to_rad(camera.fov) * 0.5)
	var tan_h := half * aspect if aspect >= 1.0 else half
	var tan_v := half if aspect >= 1.0 else half / aspect
	for p in points:
		var l: Vector3 = inv * ((p as Vector3) - pos)
		if l.z >= -0.01:
			return false
		var nx := (l.x / -l.z) / tan_h   # -1..1 across the screen
		var ny := (l.y / -l.z) / tan_v   # -1 bottom .. 1 top
		if absf(nx) > 1.0 - 2.0 * FIT_SIDE or ny > 1.0 - 2.0 * FIT_TOP or ny < -1.0 + 2.0 * FIT_BOTTOM:
			return false
	return true

func _setup_input_actions() -> void:
	var actions := {
		"camera_rotate_left": [KEY_Q],
		"camera_rotate_right": [KEY_E],
		"camera_zoom_in": [MOUSE_BUTTON_WHEEL_UP],
		"camera_zoom_out": [MOUSE_BUTTON_WHEEL_DOWN],
		"camera_zoom_in_key": [KEY_EQUAL, KEY_KP_ADD],
		"camera_zoom_out_key": [KEY_MINUS, KEY_KP_SUBTRACT],
		"camera_pan_left": [KEY_A, KEY_LEFT],
		"camera_pan_right": [KEY_D, KEY_RIGHT],
		"camera_pan_up": [KEY_W, KEY_UP],
		"camera_pan_down": [KEY_S, KEY_DOWN],
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
	# drags (pan, rotate) and touch gestures are handled by main.gd, which tells a drag from a click; the wheel here
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.1)


## Camera keys act unless main.gd turned them off or a text field has the keyboard (the nickname on the end panel:
## the Input state sees every key, so typing W, A, S, D, Q, E moved the camera behind the panel).
func _keys_active() -> bool:
	return input_enabled and not get_viewport().gui_get_focus_owner() is LineEdit


func _process(delta: float) -> void:
	if _keys_active():
		if Input.is_action_pressed("camera_rotate_left"):
			rotate_by(-90.0 * delta)
		if Input.is_action_pressed("camera_rotate_right"):
			rotate_by(90.0 * delta)
		var pan := Vector2(Input.get_axis("camera_pan_left", "camera_pan_right"), Input.get_axis("camera_pan_down", "camera_pan_up"))
		if pan != Vector2.ZERO:
			pan_by(pan * distance * 0.6 * delta)   # about 60 % of the view distance per second
		if Input.is_action_just_pressed("camera_zoom_in_key"):
			zoom_by(0.9)
		if Input.is_action_just_pressed("camera_zoom_out_key"):
			zoom_by(1.1)

	# T18 camera shake: every frame while it runs, re-roll the random offset and
	# decay it with the remaining time, then settle back to zero when it ends.
	if _shaking:
		if _shake_remaining <= 0.0:
			shake_offset = Vector3.ZERO
			apply()
			_shaking = false
		else:
			var factor := _shake_strength * _shake_remaining / _shake_seconds
			shake_offset.x = randf_range(-1.0, 1.0) * factor
			shake_offset.y = randf_range(-1.0, 1.0) * factor
			shake_offset.z = randf_range(-1.0, 1.0) * factor
			apply()
			_shake_remaining -= delta


## Pan by a pointer drag in viewport pixels, so the ground follows the finger or the mouse.
func pan_pixels(d: Vector2) -> void:
	var size := get_viewport().get_visible_rect().size
	var span := size.y if camera.keep_aspect == Camera3D.KEEP_HEIGHT else size.x
	var per_px := 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5) / maxf(span, 1.0)
	pan_by(Vector2(-d.x * per_px, d.y * per_px / sin(deg_to_rad(TILT))))


## Animated turn by a fixed step (the on-screen buttons).
func rotate_step(degrees: float) -> void:
	create_tween().tween_method(func(y): yaw = y; apply(), yaw, yaw + degrees, 0.25)


## Back to the framing that shows the whole island.
func go_home() -> void:
	_user_zoomed = false
	var from := target
	_refit()                 # sets the home target and distance
	var to := target
	target = from
	yaw = wrapf(yaw, -180.0, 180.0)   # the shortest way back: yaw adds up with every turn, and 720 spun twice
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "distance", home_distance, 0.35)
	tw.tween_property(self, "target", to, 0.35)
	tw.tween_method(func(y): yaw = y; apply(), yaw, 0.0, 0.35)

func rotate_by(degrees: float) -> void:
	yaw += degrees
	apply()

func zoom_by(factor: float) -> void:
	distance *= factor
	distance = clamp(distance, MIN_DIST, max_dist)
	_user_zoomed = true
	apply()


## T18: jitter the camera for `seconds`, peaking at a random offset of `strength`
## (per-axis randf_range(-1, 1) scaled by strength * remaining / seconds), then
## decay back to a still camera. Called by Fx.explosion() when a mine goes off.
func shake(strength: float, seconds: float) -> void:
	_shake_strength = strength
	_shake_seconds = maxf(seconds, 0.001)
	_shake_remaining = _shake_seconds
	_shaking = seconds > 0.0

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
	_user_zoomed = true   # (any camera move by the player: window resizes stop reframing)

	# clamp target to PAN_LIMIT from the island centre (the origin until fit_island)
	var off := target - _fit_centre
	if off.length() > PAN_LIMIT:
		target = _fit_centre + off.normalized() * PAN_LIMIT

	apply()

func apply() -> void:
	var yaw_rad := deg_to_rad(yaw)
	var tilt_rad := deg_to_rad(TILT)

	# target + offset(yaw, TILT, distance), looking at target
	# offset(yaw, TILT, distance) = Vector3(sin(yaw), 0, cos(yaw)) * distance * cos(TILT) + Vector3.UP * distance * sin(TILT)
	var offset := Vector3(sin(yaw_rad), 0, cos(yaw_rad)) * distance * cos(tilt_rad)
	offset += Vector3.UP * distance * sin(tilt_rad)

	# T18 shake: offset the position, and look slightly off so the whole view
	# jolts rather than the lens merely turning.
	camera.global_position = target + offset + shake_offset
	camera.look_at(target + shake_offset * 0.5)
