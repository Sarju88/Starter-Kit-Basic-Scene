extends Node3D

@export var rotation_speed_deg: float = PI/6;

func _process(delta: float) -> void:
	rotate_y(rotation_speed_deg * delta)
