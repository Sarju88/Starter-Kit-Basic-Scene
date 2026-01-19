extends Area3D

@export var target_cell: Vector2i = Vector2i(-1, -1)
@export var spawn_height: float = 0.4
@export var multiplayer_manager_path: NodePath = NodePath("../MultiplayerManager")

var _claimed: bool = false
var _current_cell: Vector2i = Vector2i(-1, -1)
@onready var _manager: Node = get_node_or_null(multiplayer_manager_path)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	call_deferred("_position_in_cell")

func _on_body_entered(body: Node) -> void:
	if _claimed:
		return
	if body is CharacterBody3D:
		if multiplayer.is_server():
			_claimed = true
			_award_trophy(body)
		else:
			_request_trophy_claim(body)

func _position_in_cell() -> void:
	var maze := get_parent()
	if maze == null:
		return
	if not maze.has_method("get_origin_offset"):
		return
	var cell := target_cell
	if cell.x < 0 or cell.y < 0:
		cell = maze.get_random_cell()
	_current_cell = cell
	global_position = maze.get_cell_center(cell) + Vector3(0, spawn_height, 0)

func _relocate() -> void:
	var maze := get_parent()
	if maze == null or not maze.has_method("get_random_cell"):
		_claimed = false
		return
	var next_cell: Vector2i = maze.get_random_cell(_current_cell)
	_current_cell = next_cell
	global_position = maze.get_cell_center(next_cell) + Vector3(0, spawn_height, 0)
	_claimed = false

func _award_trophy(body: Node) -> void:
	if _manager and _manager.has_method("add_score"):
		var peer_id := 0
		if body.has_method("get_peer_id"):
			peer_id = body.call("get_peer_id")
		if peer_id > 0:
			_manager.call("add_score", peer_id, 5)
	_relocate()
	rpc("client_sync_position", global_position, _current_cell)

func _request_trophy_claim(body: Node) -> void:
	var peer_id := 0
	if body.has_method("get_peer_id"):
		peer_id = body.call("get_peer_id")
	if peer_id > 0:
		rpc_id(1, "server_claim_trophy", peer_id)

@rpc("any_peer", "reliable")
func server_claim_trophy(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _claimed:
		return
	_claimed = true
	if _manager and _manager.has_method("add_score"):
		_manager.call("add_score", peer_id, 5)
	_relocate()
	rpc("client_sync_position", global_position, _current_cell)

@rpc("authority", "reliable", "call_local")
func client_sync_position(new_pos: Vector3, cell: Vector2i) -> void:
	global_position = new_pos
	_current_cell = cell
