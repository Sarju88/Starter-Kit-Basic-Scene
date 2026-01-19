extends Node3D

@export var cols: int = 6
@export var rows: int = 6
@export var cell_size: float = 2.0
@export var wall_scene: PackedScene
@export var corner_scene: PackedScene
@export var use_random_seed: bool = true
@export var seed_value: int = 1
@export var player_path: NodePath = NodePath("../Player")

@onready var maze_root: Node3D = $Maze

# Use untyped outer arrays to avoid nested type collection issues in Godot.
var _horizontal_walls: Array = []
var _vertical_walls: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _wall_height: float = 8.0
var _origin_cache: Vector3 = Vector3.ZERO
var _astar: AStar2D = AStar2D.new()
var _directions: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]
var _defer_generation: bool = false

func _ready() -> void:
	var tree := get_tree()
	if tree and tree.has_meta("match_mode") and str(tree.get_meta("match_mode")) == "join":
		_defer_generation = true
		return
	_build_from_current_seed()

func _build_from_current_seed() -> void:
	if not use_random_seed:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	if wall_scene == null or corner_scene == null:
		push_warning("Maze generator missing wall or corner scene.")
		return
	_generate_maze()
	_build_geometry()
	_build_navigation()
	_place_spawn_points()

func apply_seed(new_seed: int) -> void:
	use_random_seed = false
	seed_value = new_seed
	_rng.seed = seed_value
	_defer_generation = false
	_build_from_current_seed()

func _generate_maze() -> void:
	_horizontal_walls.clear()
	for r in range(rows + 1):
		var row_walls: Array[bool] = []
		for _c in range(cols):
			row_walls.append(true)
		_horizontal_walls.append(row_walls)

	_vertical_walls.clear()
	for r in range(rows):
		var col_walls: Array[bool] = []
		for _c in range(cols + 1):
			col_walls.append(true)
		_vertical_walls.append(col_walls)

	var visited: Array = []
	for _r in range(rows):
		var row: Array[bool] = []
		for _c in range(cols):
			row.append(false)
		visited.append(row)

	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	visited[0][0] = true
	while stack.size() > 0:
		var current: Vector2i = stack.back()
		var neighbors: Array[Vector2i] = []
		for dir in _directions:
			var next: Vector2i = current + dir
			if next.x >= 0 and next.x < cols and next.y >= 0 and next.y < rows and not visited[next.y][next.x]:
				neighbors.append(next)
		if neighbors.is_empty():
			stack.pop_back()
			continue
		var chosen: Vector2i = neighbors[_rng.randi_range(0, neighbors.size() - 1)]
		_remove_wall(current, chosen)
		visited[chosen.y][chosen.x] = true
		stack.append(chosen)

func _remove_wall(a: Vector2i, b: Vector2i) -> void:
	if a.x == b.x:
		var row_line: int = max(a.y, b.y)
		_horizontal_walls[row_line][a.x] = false
	else:
		var col_line: int = max(a.x, b.x)
		_vertical_walls[a.y][col_line] = false

func _build_geometry() -> void:
	_clear_maze()
	_origin_cache = Vector3(-cols * cell_size * 0.5, 0, -rows * cell_size * 0.5)
	var origin := _origin_cache

	for r in range(rows + 1):
		for c in range(cols):
			if _horizontal_walls[r][c]:
				var wall: Node3D = wall_scene.instantiate()
				var x := origin.x + (c + 0.5) * cell_size
				var z := origin.z + r * cell_size
				wall.transform.origin = Vector3(x, 0, z)
				wall.scale.x *= cell_size
				wall.scale.y *= 4.0
				maze_root.add_child(wall)
				_add_wall_collider(wall.transform.origin, false)

	for r in range(rows):
		for c in range(cols + 1):
			if _vertical_walls[r][c]:
				var wall_v: Node3D = wall_scene.instantiate()
				var x_v := origin.x + c * cell_size
				var z_v := origin.z + (r + 0.5) * cell_size
				wall_v.transform.origin = Vector3(x_v, 0, z_v)
				wall_v.rotate_y(PI * 0.5)
				wall_v.scale.x *= cell_size
				wall_v.scale.y *= 4.0
				maze_root.add_child(wall_v)
				_add_wall_collider(wall_v.transform.origin, true)

	_place_corners(origin)

func _build_navigation() -> void:
	_astar.clear()
	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(x, y)
			_astar.add_point(_cell_to_id(cell), Vector2(x, y))

	for y in range(rows):
		for x in range(cols):
			var cell := Vector2i(x, y)
			var id := _cell_to_id(cell)
			for dir in _directions:
				var neighbor: Vector2i = cell + dir
				if not _is_in_bounds(neighbor):
					continue
				if _is_wall_between(cell, neighbor):
					continue
				var neighbor_id := _cell_to_id(neighbor)
				if not _astar.are_points_connected(id, neighbor_id):
					_astar.connect_points(id, neighbor_id, false)

func _cell_to_id(cell: Vector2i) -> int:
	return cell.y * cols + cell.x

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows

func _is_wall_between(a: Vector2i, b: Vector2i) -> bool:
	if a.x == b.x:
		var row_line: int = max(a.y, b.y)
		return _horizontal_walls[row_line][a.x]
	var col_line: int = max(a.x, b.x)
	return _vertical_walls[a.y][col_line]

func _place_corners(origin: Vector3) -> void:
	var corners: Array[Dictionary] = [
		{ "pos": Vector3(origin.x, 0, origin.z), "rot": 0.0 },
		{ "pos": Vector3(origin.x + cols * cell_size, 0, origin.z), "rot": PI * 0.5 },
		{ "pos": Vector3(origin.x, 0, origin.z + rows * cell_size), "rot": PI * 1.5 },
		{ "pos": Vector3(origin.x + cols * cell_size, 0, origin.z + rows * cell_size), "rot": PI }
	]
	for c in corners:
		var corner: Node3D = corner_scene.instantiate()
		var pos: Vector3 = c["pos"]
		var rot: float = c["rot"]
		corner.transform.origin = pos
		corner.rotate_y(rot)
		corner.scale.x *= cell_size
		corner.scale.z *= cell_size
		maze_root.add_child(corner)

func _clear_maze() -> void:
	for child in maze_root.get_children():
		child.queue_free()

func _add_wall_collider(origin: Vector3, is_vertical: bool) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	if is_vertical:
		shape.size = Vector3(0.6, _wall_height, cell_size)
	else:
		shape.size = Vector3(cell_size, _wall_height, 0.6)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.transform.origin = origin + Vector3(0, _wall_height * 0.5, 0)
	maze_root.add_child(body)

func get_origin_offset() -> Vector3:
	return _origin_cache

func get_maze_center_world() -> Vector3:
	return _origin_cache + Vector3(cols * cell_size * 0.5, 0.0, rows * cell_size * 0.5)

func get_corner_cell_world(is_south: bool, is_west: bool) -> Vector3:
	var x_index := 0 if is_west else cols - 1
	var y_index := rows - 1 if is_south else 0
	return get_cell_center(Vector2i(x_index, y_index))

func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local := world_pos - _origin_cache
	var x := int(floor(local.x / cell_size))
	var y := int(floor(local.z / cell_size))
	return Vector2i(x, y)

func get_path_points(start_pos: Vector3, end_pos: Vector3) -> PackedVector3Array:
	if rows <= 0 or cols <= 0:
		return PackedVector3Array()
	var start_cell := world_to_cell(start_pos)
	var end_cell := world_to_cell(end_pos)
	if not _is_in_bounds(start_cell) or not _is_in_bounds(end_cell):
		return PackedVector3Array()
	var start_id := _cell_to_id(start_cell)
	var end_id := _cell_to_id(end_cell)
	if not _astar.has_point(start_id) or not _astar.has_point(end_id):
		return PackedVector3Array()
	var path_2d: PackedVector2Array = _astar.get_point_path(start_id, end_id)
	if path_2d.is_empty():
		return PackedVector3Array()
	var path_3d := PackedVector3Array()
	for point in path_2d:
		var cell := Vector2i(int(point.x), int(point.y))
		var pos := get_cell_center(cell)
		pos.y = start_pos.y
		path_3d.append(pos)
	return path_3d

func get_open_neighbors(cell: Vector2i) -> Array[Vector2i]:
	if not _is_in_bounds(cell):
		return []
	var neighbors: Array[Vector2i] = []
	for dir in _directions:
		var next: Vector2i = cell + dir
		if not _is_in_bounds(next):
			continue
		if _is_wall_between(cell, next):
			continue
		neighbors.append(next)
	return neighbors

func is_cell_blocked(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell):
		return true
	return get_open_neighbors(cell).is_empty()

func get_cell_center(cell: Vector2i) -> Vector3:
	return _origin_cache + Vector3((cell.x + 0.5) * cell_size, 0.0, (cell.y + 0.5) * cell_size)

func get_random_cell_position(cell: Vector2i, padding: float = 0.35) -> Vector3:
	var safe_padding: float = min(padding, cell_size * 0.45)
	var base: Vector3 = _origin_cache + Vector3(cell.x * cell_size, 0.0, cell.y * cell_size)
	var x: float = base.x + _rng.randf_range(safe_padding, cell_size - safe_padding)
	var z: float = base.z + _rng.randf_range(safe_padding, cell_size - safe_padding)
	return Vector3(x, 0.0, z)

func is_wall_world_position(world_pos: Vector3, tolerance: float = 0.35) -> bool:
	var local := world_pos - _origin_cache
	for r in range(rows + 1):
		var z_line := r * cell_size
		if absf(local.z - z_line) > tolerance:
			continue
		for c in range(cols):
			if not _horizontal_walls[r][c]:
				continue
			var x_start := c * cell_size
			var x_end := (c + 1) * cell_size
			if local.x >= x_start - tolerance and local.x <= x_end + tolerance:
				return true

	for r in range(rows):
		for c in range(cols + 1):
			if not _vertical_walls[r][c]:
				continue
			var x_line := c * cell_size
			if absf(local.x - x_line) > tolerance:
				continue
			var z_start := r * cell_size
			var z_end := (r + 1) * cell_size
			if local.z >= z_start - tolerance and local.z <= z_end + tolerance:
				return true
	return false

func get_random_cell(exclude: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	if cols <= 0 or rows <= 0:
		return Vector2i.ZERO
	var cell := Vector2i.ZERO
	var attempts := 0
	while attempts < 50:
		cell = Vector2i(_rng.randi_range(0, cols - 1), _rng.randi_range(0, rows - 1))
		if cell != exclude:
			break
		attempts += 1
	return cell

func _place_spawn_points() -> void:
	var player_node: Node3D = get_node_or_null(player_path)
	if player_node:
		# Spawn player in the south-west corner of the maze.
		var corner_pos := get_corner_cell_world(true, true)
		corner_pos.y = player_node.global_position.y
		player_node.global_position = corner_pos
