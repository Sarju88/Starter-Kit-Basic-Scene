extends CharacterBody3D

@export var move_speed: float = 6.0
@export var fast_speed: float = 12.0
@export var mouse_sensitivity: float = 0.003
@export var capture_mouse: bool = true
@export var step_distance: float = 2.0
@export var min_step_interval: float = 0.35
@export var projectile_scene: PackedScene
@export var muzzle_path: NodePath = NodePath("Camera3D/GunPivot/Muzzle")
@export var fire_cooldown: float = 0.2

@onready var camera: Camera3D = $Camera3D
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio
@onready var fire_audio: AudioStreamPlayer3D = $FireAudio
@onready var _muzzle: Node3D = get_node_or_null(muzzle_path)

var _yaw: float = 0.0
var _pitch: float = 0.0
var _distance_accum: float = 0.0
var _step_timer: float = 0.0
var _fire_timer: float = 0.0
var _is_firing: bool = false
var _last_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	var euler := rotation
	_yaw = euler.y
	if camera:
		_pitch = camera.rotation.x
	_update_mouse_mode()
	_last_position = global_position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		capture_mouse = not capture_mouse
		_update_mouse_mode()
	if event is InputEventMouseMotion and capture_mouse:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, -PI * 0.45, PI * 0.45)
		rotation.y = _yaw
		if camera:
			camera.rotation.x = _pitch
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_firing = event.pressed

func _physics_process(delta: float) -> void:
	var move_dir := Vector3.ZERO
	var transform_basis := global_transform.basis
	var forward := -transform_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := transform_basis.x
	right.y = 0.0
	right = right.normalized()

	if Input.is_key_pressed(KEY_W):
		move_dir += forward
	if Input.is_key_pressed(KEY_S):
		move_dir -= forward
	if Input.is_key_pressed(KEY_D):
		move_dir += right
	if Input.is_key_pressed(KEY_A):
		move_dir -= right
	if Input.is_key_pressed(KEY_SPACE):
		move_dir += Vector3.UP
	if Input.is_key_pressed(KEY_SHIFT):
		move_dir -= Vector3.UP

	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()

	var speed := move_speed

	velocity = move_dir * speed
	move_and_slide()
	_update_footsteps(delta)
	_fire_timer = maxf(0.0, _fire_timer - delta)
	if _is_firing:
		_fire()

func _update_mouse_mode() -> void:
	if capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _update_footsteps(delta: float) -> void:
	if not footstep_audio:
		return
	_step_timer = maxf(0.0, _step_timer - delta)
	var delta_pos := global_position - _last_position
	delta_pos.y = 0.0
	var distance := delta_pos.length()
	_last_position = global_position
	if distance <= 0.0:
		return
	_distance_accum += distance
	if _distance_accum >= step_distance and _step_timer == 0.0:
		_distance_accum = fmod(_distance_accum, step_distance)
		footstep_audio.play()
		_step_timer = min_step_interval

func _fire() -> void:
	if _fire_timer > 0.0:
		return
	if projectile_scene == null or _muzzle == null or camera == null:
		return
	var projectile: Node3D = projectile_scene.instantiate()
	projectile.global_transform = _muzzle.global_transform
	var direction := -camera.global_transform.basis.z
	if projectile.has_method("setup"):
		projectile.call("setup", direction)
	get_tree().current_scene.add_child(projectile)
	if fire_audio:
		fire_audio.play()
	_fire_timer = fire_cooldown
