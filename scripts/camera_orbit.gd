extends Camera3D

@export var semi_major: float = 5.1
@export var semi_minor: float = 3.6
@export var height: float = 2
@export var angular_speed_rad: float = 0.6

var _angle: float = 0.0
var orbit_enabled: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_O and event.pressed and not event.echo:
		orbit_enabled = not orbit_enabled

func _process(delta: float) -> void:
	if not orbit_enabled:
		return
	_angle = wrapf(_angle + angular_speed_rad * delta, 0.0, TAU)
	var pos := Vector3(
		semi_major * cos(_angle),
		height,
		semi_minor * sin(_angle)
	)
	global_transform.origin = pos
	look_at(Vector3.ZERO, Vector3.UP)
