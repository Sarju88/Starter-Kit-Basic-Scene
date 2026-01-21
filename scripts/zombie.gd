extends CharacterBody3D

@export var move_speed: float = 2.0
@export var repath_interval: float = 1.0
@export var path_point_tolerance: float = 0.25
@export var maze_path: NodePath = NodePath("../..")
@export var players_root_path: NodePath = NodePath("../../Players")
@export var multiplayer_manager_path: NodePath = NodePath("../../MultiplayerManager")
@export var path_network_path: NodePath = NodePath("../../ZombiePaths/MainLoop")

@onready var _maze: Node = get_node_or_null(maze_path)
@onready var _players_root: Node = get_node_or_null(players_root_path)
@onready var _manager: Node = get_node_or_null(multiplayer_manager_path)
@onready var _path_network: Path3D = get_node_or_null(path_network_path)

var zombie_id: int = 0
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _repath_timer: float = 0.0
var _net_timer: float = 0.0
var _net_interval: float = 0.1
var _direct_target: Vector3 = Vector3.ZERO
var _has_direct_target: bool = false
var _path_points: PackedVector3Array = PackedVector3Array()

@onready var _anim_player: AnimationPlayer = _find_animation_player()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = repath_interval
		_update_path()
	_move_along_path(delta)
	_sync_transform(delta)

func set_zombie_id(new_id: int) -> void:
	zombie_id = new_id

func _ready() -> void:
	_cache_path_points()
	_play_walk_animation()

func _update_path() -> void:
	if _maze == null or _players_root == null:
		_path = PackedVector3Array()
		_path_index = 0
		_has_direct_target = false
		return
	var target = _get_nearest_player_position()
	if target == null:
		_path = PackedVector3Array()
		_path_index = 0
		_has_direct_target = false
		return
	_direct_target = target
	_has_direct_target = true
	if _path_points.size() > 1:
		_path = _get_path_network_points(global_position, target)
		_path_index = 0
	elif _maze and _maze.has_method("get_path_points"):
		_path = _maze.call("get_path_points", global_position, target)
		_path_index = 0

func _get_nearest_player_position() -> Variant:
	var nearest: Vector3
	var found := false
	var best_dist := 0.0
	for child in _players_root.get_children():
		if not (child is Node3D):
			continue
		var pos := (child as Node3D).global_position
		var dist := global_position.distance_squared_to(pos)
		if not found or dist < best_dist:
			found = true
			best_dist = dist
			nearest = pos
	if found:
		return nearest
	return null

func _move_along_path(_delta: float) -> void:
	if _path.is_empty():
		_move_directly()
		return
	if _path_index >= _path.size():
		_move_directly()
		return
	var target := _path[_path_index]
	var to_target := target - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= path_point_tolerance:
		_path_index += 1
		return
	var direction := to_target.normalized()
	velocity = direction * move_speed
	if direction.length_squared() > 0.000001:
		rotation.y = atan2(-direction.x, -direction.z)
	move_and_slide()

func _get_path_network_points(start_pos: Vector3, end_pos: Vector3) -> PackedVector3Array:
	if _path_points.is_empty():
		return PackedVector3Array()
	var start_index := _find_closest_path_index(start_pos)
	var end_index := _find_closest_path_index(end_pos)
	if start_index == -1 or end_index == -1:
		return PackedVector3Array()
	var forward := _collect_path_segment(start_index, end_index, 1)
	var backward := _collect_path_segment(start_index, end_index, -1)
	if backward.size() == 0 or forward.size() <= backward.size():
		return forward
	return backward

func _collect_path_segment(start_index: int, end_index: int, dir: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	var count := _path_points.size()
	var index := start_index
	for i in range(count):
		points.append(_path_points[index])
		if index == end_index:
			break
		index = (index + dir + count) % count
	return points

func _find_closest_path_index(pos: Vector3) -> int:
	if _path_points.is_empty():
		return -1
	var best := 0
	var best_dist := INF
	for i in range(_path_points.size()):
		var dist := pos.distance_squared_to(_path_points[i])
		if dist < best_dist:
			best_dist = dist
			best = i
	return best

func _cache_path_points() -> void:
	if _path_network == null:
		return
	var curve := _path_network.curve
	if curve == null:
		return
	_path_points = curve.get_baked_points()
	if _path_points.size() < 2:
		_path_points = PackedVector3Array()

func _find_animation_player() -> AnimationPlayer:
	return _find_animation_player_recursive(self)

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player_recursive(child)
		if found:
			return found
	return null

func _play_walk_animation() -> void:
	if _anim_player == null:
		return
	var anims := _anim_player.get_animation_list()
	if anims.is_empty():
		return
	var name := "walk"
	if not anims.has(name):
		name = anims[0]
	_anim_player.play(name)
func _move_directly() -> void:
	if not _has_direct_target:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var to_target := _direct_target - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= path_point_tolerance:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var direction := to_target.normalized()
	velocity = direction * move_speed
	if direction.length_squared() > 0.000001:
		rotation.y = atan2(-direction.x, -direction.z)
	move_and_slide()
func _sync_transform(delta: float) -> void:
	_net_timer = maxf(0.0, _net_timer - delta)
	if _net_timer > 0.0:
		return
	_net_timer = _net_interval
	if _manager and _manager.has_method("server_update_zombie_transform"):
		_manager.call("server_update_zombie_transform", zombie_id, global_transform)
