extends Node

@export var player_scene: PackedScene
@export var projectile_scene: PackedScene
@export var players_root_path: NodePath = NodePath("../Players")
@export var projectiles_root_path: NodePath = NodePath("../Projectiles")
@export var score_label_path: NodePath = NodePath("../UI/ScoreLabel")
@export var connection_label_path: NodePath = NodePath("../UI/ConnectionLabel")
@export var maze_path: NodePath = NodePath("..")
@export var port: int = 7000
@export var address: String = "127.0.0.1"
@export var expected_players: int = 2
@export var match_length_seconds: float = 600.0
@export var auto_start_match: bool = true
@export var spawn_height: float = 0.8
@export var spawn_padding: float = 0.85
@export var spawn_attempts: int = 8
@export var wall_check_tolerance: float = 0.4

var _players_root: Node
var _projectiles_root: Node
var _score_label: Label
var _connection_label: Label
var _maze: Node3D
var _scores: Dictionary = {}
var _player_skins: Dictionary = {}
var _maze_seed: int = 0
var _match_time_left: float = 0.0
var _match_active: bool = false

func _ready() -> void:
	_players_root = get_node_or_null(players_root_path)
	_projectiles_root = get_node_or_null(projectiles_root_path)
	_score_label = get_node_or_null(score_label_path)
	_connection_label = get_node_or_null(connection_label_path)
	_maze = get_node_or_null(maze_path)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	_update_score_label()
	_update_connection_label()
	call_deferred("_try_auto_connect")

func _try_auto_connect() -> void:
	var tree := get_tree()
	if tree.has_meta("match_mode"):
		var mode := str(tree.get_meta("match_mode"))
		tree.set_meta("match_mode", "")
		if mode == "host":
			if tree.has_meta("host_port"):
				port = int(tree.get_meta("host_port"))
			if tree.has_meta("host_max_players"):
				expected_players = int(tree.get_meta("host_max_players"))
			host_match()
		elif mode == "join":
			if tree.has_meta("join_address"):
				address = str(tree.get_meta("join_address"))
			if tree.has_meta("join_port"):
				port = int(tree.get_meta("join_port"))
			join_match()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			host_match()
		elif event.keycode == KEY_J:
			join_match()
		elif event.keycode == KEY_M and multiplayer.is_server():
			_start_match()

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if not _match_active:
		return
	_match_time_left = maxf(0.0, _match_time_left - delta)
	rpc("client_update_timer", _match_time_left)
	if _match_time_left == 0.0:
		_match_active = false
		rpc("client_match_ended", _scores)

func host_match() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(port, expected_players)
	multiplayer.multiplayer_peer = peer
	_scores.clear()
	_player_skins.clear()
	_player_skins[1] = _get_local_skin_path()
	_maze_seed = _generate_maze_seed()
	_apply_maze_seed(_maze_seed)
	rpc("client_set_scores", _scores)
	call_deferred("_spawn_player_for_peer", 1)
	if auto_start_match and expected_players <= 1:
		_start_match()
	_update_connection_label()

func join_match() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	multiplayer.multiplayer_peer = peer
	_update_connection_label()

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		call_deferred("_spawn_player_for_peer", peer_id)
		call_deferred("_sync_existing_players_to_peer", peer_id)
		rpc_id(peer_id, "client_set_maze_seed", _maze_seed)
		if auto_start_match and _should_start_match():
			_start_match()
	_update_connection_label()

func _on_connected_to_server() -> void:
	_send_local_skin_to_server()
	_request_maze_seed()
	_update_connection_label()

func _on_peer_disconnected(peer_id: int) -> void:
	if _players_root:
		var node := _players_root.get_node_or_null("Player_%d" % peer_id)
		if node:
			node.queue_free()
	_scores.erase(peer_id)
	_player_skins.erase(peer_id)
	rpc("client_set_scores", _scores)
	_update_connection_label()

func _sync_existing_players_to_peer(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _players_root == null:
		return
	for child in _players_root.get_children():
		var name_str := str(child.name)
		if not name_str.begins_with("Player_"):
			continue
		var id_str := name_str.get_slice("_", 1)
		if id_str == "":
			continue
		var existing_id: int = int(id_str)
		var skin_path := ""
		if _player_skins.has(existing_id):
			skin_path = str(_player_skins[existing_id])
		rpc_id(target_peer_id, "client_spawn_player", existing_id, child.global_transform, skin_path)

func _should_start_match() -> bool:
	var total := multiplayer.get_peers().size() + 1
	return total >= expected_players

func _start_match() -> void:
	_match_time_left = match_length_seconds
	_match_active = true
	rpc("client_match_started", _match_time_left)

@rpc("authority", "reliable", "call_local")
func client_match_started(time_left: float) -> void:
	_match_time_left = time_left
	_match_active = true
	_update_score_label()

@rpc("authority", "reliable", "call_local")
func client_match_ended(scores: Dictionary) -> void:
	_match_active = false
	_scores = scores
	_update_score_label()

@rpc("authority", "unreliable", "call_local")
func client_update_timer(time_left: float) -> void:
	_match_time_left = time_left
	_update_score_label()

@rpc("authority", "reliable", "call_local")
func client_set_scores(scores: Dictionary) -> void:
	_scores = scores
	_update_score_label()

func _spawn_player_for_peer(peer_id: int) -> void:
	if player_scene == null or _players_root == null:
		return
	var spawn_transform := _get_spawn_transform(peer_id)
	var skin_path := ""
	if _player_skins.has(peer_id):
		skin_path = str(_player_skins[peer_id])
	rpc("client_spawn_player", peer_id, spawn_transform, skin_path)

@rpc("authority", "reliable", "call_local")
func client_spawn_player(peer_id: int, spawn_transform: Transform3D, skin_path: String = "") -> void:
	if player_scene == null or _players_root == null:
		return
	var node_name := "Player_%d" % peer_id
	if _players_root.has_node(node_name):
		return
	var player := player_scene.instantiate()
	player.name = node_name
	player.set("multiplayer_manager_path", NodePath("../../MultiplayerManager"))
	if player.has_method("set_peer_id"):
		player.call("set_peer_id", peer_id)
	player.set_multiplayer_authority(peer_id)
	player.global_transform = spawn_transform
	_players_root.add_child(player)
	if skin_path != "" and player.has_method("apply_skin_path"):
		player.call("apply_skin_path", skin_path)
	if not _scores.has(peer_id):
		_scores[peer_id] = 0
	_update_score_label()

@rpc("any_peer", "reliable")
func server_register_skin(skin_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var resolved := _sanitize_skin_path(skin_path)
	_player_skins[sender] = resolved
	rpc("client_set_player_skin", sender, resolved)

@rpc("authority", "reliable", "call_local")
func client_set_player_skin(peer_id: int, skin_path: String) -> void:
	var node := _get_player(peer_id)
	if node and node.has_method("apply_skin_path"):
		node.call("apply_skin_path", skin_path)

@rpc("any_peer", "reliable")
func server_request_maze_seed() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	rpc_id(sender, "client_set_maze_seed", _maze_seed)

@rpc("authority", "reliable", "call_local")
func client_set_maze_seed(seed_value: int) -> void:
	_maze_seed = seed_value
	_apply_maze_seed(seed_value)

@rpc("any_peer", "unreliable")
func server_update_transform(peer_id: int, transform: Transform3D) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != peer_id:
		return
	var node := _get_player(peer_id)
	if node:
		node.global_transform = transform
	rpc("client_update_transform", peer_id, transform)

@rpc("authority", "unreliable", "call_local")
func client_update_transform(peer_id: int, transform: Transform3D) -> void:
	var node := _get_player(peer_id)
	if node and not node.is_multiplayer_authority():
		node.global_transform = transform

@rpc("any_peer", "reliable")
func server_request_fire(muzzle_transform: Transform3D, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var owner_id := multiplayer.get_remote_sender_id()
	if owner_id == 0:
		owner_id = 1
	rpc("client_spawn_projectile", muzzle_transform, direction, owner_id)

@rpc("authority", "reliable", "call_local")
func client_spawn_projectile(muzzle_transform: Transform3D, direction: Vector3, owner_id: int) -> void:
	if projectile_scene == null or _projectiles_root == null:
		return
	var projectile := projectile_scene.instantiate()
	projectile.global_transform = muzzle_transform
	if projectile.has_method("setup"):
		projectile.call("setup", direction, owner_id)
	_projectiles_root.add_child(projectile)

func add_score(peer_id: int, delta: int) -> void:
	if not multiplayer.is_server():
		return
	if not _match_active:
		return
	if not _scores.has(peer_id):
		_scores[peer_id] = 0
	_scores[peer_id] = int(_scores[peer_id]) + delta
	rpc("client_set_scores", _scores)

func server_handle_death(victim_id: int, attacker_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _match_active:
		if attacker_id > 0:
			add_score(attacker_id, 2)
		add_score(victim_id, -2)
	_respawn_player(victim_id)

func _respawn_player(peer_id: int) -> void:
	var node := _get_player(peer_id)
	if node == null:
		return
	var spawn_transform := _get_spawn_transform(peer_id)
	node.global_transform = spawn_transform
	if node.has_method("reset_health"):
		node.call("reset_health")
	rpc("client_update_transform", peer_id, spawn_transform)

func _get_player(peer_id: int) -> Node:
	if _players_root == null:
		return null
	return _players_root.get_node_or_null("Player_%d" % peer_id)

func _get_spawn_transform(peer_id: int) -> Transform3D:
	if _maze and _maze.has_method("get_corner_cell_world"):
		var corner_index := (peer_id - 1) % 4
		var is_south := corner_index >= 2
		var is_west := corner_index % 2 == 0
		var corner_pos: Vector3 = _maze.get_corner_cell_world(is_south, is_west)
		var pos: Vector3 = _find_safe_spawn_position(corner_pos)
		pos.y = spawn_height
		return Transform3D(Basis.IDENTITY, pos)
	return Transform3D(Basis.IDENTITY, Vector3.ZERO)

func _get_spawn_padding() -> float:
	if _maze and _maze.has_method("cell_size"):
		var size := float(_maze.get("cell_size"))
		return min(spawn_padding, size * 0.35)
	return spawn_padding

func _find_safe_spawn_position(corner_pos: Vector3) -> Vector3:
	var pos := corner_pos
	if _maze == null or not _maze.has_method("world_to_cell") or not _maze.has_method("get_cell_center"):
		return pos
	var start_cell: Vector2i = _maze.world_to_cell(corner_pos)
	pos = _maze.get_cell_center(start_cell)
	if not _is_wall_at_position(pos):
		return pos

	var cols: int = int(_maze.get("cols")) if _maze.has_method("get") else 0
	var rows: int = int(_maze.get("rows")) if _maze.has_method("get") else 0
	if cols <= 0 or rows <= 0:
		return pos

	var max_radius: int = max(cols, rows)
	for radius in range(1, max_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var cell := Vector2i(start_cell.x + dx, start_cell.y + dy)
				if _maze.has_method("is_cell_blocked") and _maze.is_cell_blocked(cell):
					continue
				var candidate: Vector3 = _maze.get_cell_center(cell)
				if _is_wall_at_position(candidate):
					continue
				return candidate

	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(x, y)
			if _maze.has_method("is_cell_blocked") and _maze.is_cell_blocked(cell):
				continue
			var candidate: Vector3 = _maze.get_cell_center(cell)
			if _is_wall_at_position(candidate):
				continue
			return candidate

	return pos

func _is_wall_at_position(pos: Vector3) -> bool:
	if _maze and _maze.has_method("is_wall_world_position"):
		return _maze.is_wall_world_position(pos, wall_check_tolerance)
	return false

func _update_score_label() -> void:
	if _score_label == null:
		return
	var local_id := multiplayer.get_unique_id()
	var score := 0
	if _scores.has(local_id):
		score = int(_scores[local_id])
	var time_text := _format_time(_match_time_left)
	if _match_active:
		_score_label.text = "Score: %d  Time: %s" % [score, time_text]
	else:
		_score_label.text = "Score: %d  Time: --:--" % score

func _update_connection_label() -> void:
	if _connection_label == null:
		return
	if multiplayer.multiplayer_peer == null:
		_connection_label.text = "Status: Offline"
		return
	if multiplayer.is_server():
		var current := multiplayer.get_peers().size() + 1
		_connection_label.text = "Status: Hosting (%d/%d)" % [current, expected_players]
		return
	var status := "Connecting..."
	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		status = "Connected"
	_connection_label.text = "Status: %s (%s:%d)" % [status, address, port]

func _generate_maze_seed() -> int:
	return int(int(Time.get_unix_time_from_system()) % 2147483647)

func _apply_maze_seed(seed_value: int) -> void:
	if _maze == null:
		return
	if _maze.has_method("apply_seed"):
		_maze.call("apply_seed", seed_value)

func _request_maze_seed() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		return
	rpc_id(1, "server_request_maze_seed")

func _send_local_skin_to_server() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		_player_skins[1] = _get_local_skin_path()
		rpc("client_set_player_skin", 1, _player_skins[1])
		return
	var skin_path := _get_local_skin_path()
	rpc_id(1, "server_register_skin", skin_path)

func _get_local_skin_path() -> String:
	var tree := get_tree()
	if tree and tree.has_meta("player_skin_path"):
		var meta_path := str(tree.get_meta("player_skin_path"))
		if meta_path != "":
			return meta_path
	return ""

func _sanitize_skin_path(path: String) -> String:
	if path == "":
		return ""
	if path.begins_with("res://"):
		return path
	return ""

func _format_time(seconds: float) -> String:
	var secs := int(round(seconds))
	var minutes := secs / 60
	var remaining := secs % 60
	return "%02d:%02d" % [minutes, remaining]
