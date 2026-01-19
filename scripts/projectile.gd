extends Area3D

@export var speed: float = 6.0
@export var lifetime: float = 2.0
@export var damage: int = 1

var _direction: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _speed: float = 0.0
var _owner_peer_id: int = -1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_speed = speed
	if _direction == Vector3.ZERO:
		_direction = -global_transform.basis.z
	_direction = _direction.normalized()

func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()

func setup(direction: Vector3, owner_peer_id: int) -> void:
	_direction = direction.normalized()
	_owner_peer_id = owner_peer_id

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		queue_free()
		return
	if body and body.has_method("apply_damage"):
		if body.has_method("get_peer_id") and body.call("get_peer_id") == _owner_peer_id:
			queue_free()
			return
		body.call("apply_damage", damage, _owner_peer_id)
	queue_free()
