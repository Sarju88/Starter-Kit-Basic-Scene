extends CanvasLayer

@export var show_on_desktop: bool = false
@export var enable_web_pointer_lock: bool = true

func _ready() -> void:
	var is_touch := DisplayServer.is_touchscreen_available()
	var is_mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	var is_web := OS.has_feature("web")
	visible = show_on_desktop or is_touch or is_mobile or is_web
	if not visible:
		return
	for node in get_tree().get_nodes_in_group("mobile_action_buttons"):
		if node is BaseButton and node.has_meta("action_name"):
			var action_name := str(node.get_meta("action_name"))
			if action_name == "":
				continue
			node.button_down.connect(_on_button_down.bind(action_name))
			node.button_up.connect(_on_button_up.bind(action_name))

func _input(event: InputEvent) -> void:
	if not enable_web_pointer_lock:
		return
	if not OS.has_feature("web"):
		return
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event is InputEventScreenTouch and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_button_down(action_name: String) -> void:
	Input.action_press(action_name)

func _on_button_up(action_name: String) -> void:
	Input.action_release(action_name)
