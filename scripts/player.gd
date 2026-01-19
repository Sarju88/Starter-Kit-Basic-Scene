extends CharacterBody3D

@export var move_speed: float = 6.0
@export var fast_speed: float = 12.0
@export var mouse_sensitivity: float = 0.003
@export var capture_mouse: bool = true
@export var step_distance: float = 2.0
@export var min_step_interval: float = 0.35
@export var projectile_scene: PackedScene
@export var muzzle_path: NodePath = NodePath("Camera3D/GunPivot/Muzzle")
@export var camera_path: NodePath = NodePath("Camera3D")
@export var fire_cooldown: float = 0.2
@export var max_hit_points: int = 5
@export var multiplayer_manager_path: NodePath = NodePath("../MultiplayerManager")
@export var visual_root_path: NodePath = NodePath("VisualRoot")
@export var default_skin_path: String = "res://kenney_blocky-characters_20/Models/GLB format/Textures/texture-a.png"
@export var hide_local_body: bool = true

@onready var camera: Camera3D = get_node_or_null(camera_path)
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio
@onready var fire_audio: AudioStreamPlayer3D = $FireAudio
@onready var _muzzle: Node3D = get_node_or_null(muzzle_path)
@onready var _manager: Node = get_node_or_null(multiplayer_manager_path)
@onready var _visual_root: Node3D = get_node_or_null(visual_root_path)

var peer_id: int = 1
var hit_points: int = 0
var _yaw: float = 0.0
var _pitch: float = 0.0
var _distance_accum: float = 0.0
var _step_timer: float = 0.0
var _fire_timer: float = 0.0
var _is_firing: bool = false
var _last_position: Vector3 = Vector3.ZERO
var _net_timer: float = 0.0
var _net_interval: float = 0.05

func _ensure_input_actions() -> void:
	_add_action_key("move_forward", KEY_W)
	_add_action_key("move_back", KEY_S)
	_add_action_key("move_left", KEY_A)
	_add_action_key("move_right", KEY_D)
	_add_action_key("move_up", KEY_SPACE)
	_add_action_key("move_down", KEY_SHIFT)
	_add_action_key("move_fast", KEY_CTRL)
	_add_action_mouse("fire", MOUSE_BUTTON_LEFT)

func _add_action_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action, event)

func _add_action_mouse(action: String, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var event := InputEventMouseButton.new()
		event.button_index = button_index
		InputMap.action_add_event(action, event)

func _ready() -> void:
	_ensure_input_actions()
	hit_points = max_hit_points
	var euler := rotation
	_yaw = euler.y
	if camera:
		_pitch = camera.rotation.x
		camera.current = is_multiplayer_authority()
	_update_mouse_mode()
	call_deferred("_request_pointer_lock")
	_last_position = global_position
	_apply_initial_skin()
	_update_visual_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		capture_mouse = not capture_mouse
		_update_mouse_mode()
	if event is InputEventMouseButton and event.pressed and capture_mouse:
		_request_pointer_lock()
	if event is InputEventMouseMotion and capture_mouse:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, -PI * 0.45, PI * 0.45)
		rotation.y = _yaw
		if camera:
			camera.rotation.x = _pitch
	if event is InputEventAction and event.action == "fire":
		_is_firing = event.pressed

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var move_dir := Vector3.ZERO
	var transform_basis := global_transform.basis
	var forward := -transform_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := transform_basis.x
	right.y = 0.0
	right = right.normalized()

	if Input.is_action_pressed("move_forward"):
		move_dir += forward
	if Input.is_action_pressed("move_back"):
		move_dir -= forward
	if Input.is_action_pressed("move_right"):
		move_dir += right
	if Input.is_action_pressed("move_left"):
		move_dir -= right
	if Input.is_action_pressed("move_up"):
		move_dir += Vector3.UP
	if Input.is_action_pressed("move_down"):
		move_dir -= Vector3.UP

	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()

	var speed := move_speed
	if Input.is_action_pressed("move_fast"):
		speed = fast_speed

	velocity = move_dir * speed
	move_and_slide()
	_update_footsteps(delta)
	_fire_timer = maxf(0.0, _fire_timer - delta)
	_is_firing = Input.is_action_pressed("fire")
	if _is_firing:
		_fire()
	_sync_transform(delta)

func apply_damage(amount: int = 1, attacker_peer_id: int = -1) -> void:
	if not multiplayer.is_server():
		return
	hit_points -= amount
	if hit_points <= 0 and _manager and _manager.has_method("server_handle_death"):
		_manager.call("server_handle_death", peer_id, attacker_peer_id)

func _sync_transform(delta: float) -> void:
	_net_timer = maxf(0.0, _net_timer - delta)
	if _net_timer > 0.0:
		return
	_net_timer = _net_interval
	if _manager and _manager.has_method("server_update_transform"):
		if multiplayer.is_server():
			_manager.server_update_transform(peer_id, global_transform)
		else:
			_manager.rpc_id(1, "server_update_transform", peer_id, global_transform)

func _update_mouse_mode() -> void:
	if not is_multiplayer_authority():
		return
	if capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _request_pointer_lock() -> void:
	if not is_multiplayer_authority():
		return
	if not capture_mouse:
		return
	if OS.has_feature("web") and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
	if _muzzle == null or camera == null:
		return
	if _manager and _manager.has_method("server_request_fire"):
		var direction := -camera.global_transform.basis.z
		if multiplayer.is_server():
			_manager.server_request_fire(_muzzle.global_transform, direction)
		else:
			_manager.rpc_id(1, "server_request_fire", _muzzle.global_transform, direction)
	if fire_audio:
		fire_audio.play()
	_fire_timer = fire_cooldown

func set_peer_id(new_peer_id: int) -> void:
	peer_id = new_peer_id

func get_peer_id() -> int:
	return peer_id

func reset_health() -> void:
	hit_points = max_hit_points

func _apply_initial_skin() -> void:
	if is_multiplayer_authority():
		_apply_skin_from_path(_get_local_skin_path())
	else:
		_apply_skin_from_path(default_skin_path)

func apply_skin_path(path: String) -> void:
	var resolved := path
	if resolved == "":
		resolved = default_skin_path
	_apply_skin_from_path(resolved)

func _apply_skin_from_path(path: String) -> void:
	var texture := _load_skin_texture(path)
	if texture == null and path != default_skin_path:
		texture = _load_skin_texture(default_skin_path)
	if texture == null:
		return
	_apply_texture_to_visuals(texture)

func _get_local_skin_path() -> String:
	var tree := get_tree()
	if tree and tree.has_meta("player_skin_path"):
		var meta_path := str(tree.get_meta("player_skin_path"))
		if meta_path != "":
			return meta_path
	return default_skin_path

func _load_skin_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if path.begins_with("res://"):
		var tex := load(path)
		if tex is Texture2D:
			return tex
		return null
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)

func _apply_texture_to_visuals(texture: Texture2D) -> void:
	if _visual_root == null:
		return
	var meshes := _collect_meshes(_visual_root)
	for mesh in meshes:
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		mesh.material_override = material

func _collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	_collect_meshes_recursive(root, result)
	return result

func _collect_meshes_recursive(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes_recursive(child, out)

func _update_visual_visibility() -> void:
	if _visual_root == null:
		return
	if hide_local_body and is_multiplayer_authority():
		_visual_root.visible = false
	else:
		_visual_root.visible = true
