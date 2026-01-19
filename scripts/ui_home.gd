extends Control

@onready var _home_panel: Control = $HomePanel
@onready var _options_panel: Control = $OptionsPanel
@onready var _host_panel: Control = $HostPanel
@onready var _join_panel: Control = $JoinPanel
@onready var _host_button: Button = $HomePanel/MarginContainer/VBoxContainer/HostButton
@onready var _join_button: Button = $HomePanel/MarginContainer/VBoxContainer/JoinButton
@onready var _options_button: Button = $HomePanel/MarginContainer/VBoxContainer/OptionsButton
@onready var _exit_button: Button = $HomePanel/MarginContainer/VBoxContainer/ExitButton
@onready var _back_button: Button = $OptionsPanel/MarginContainer/VBoxContainer/BackButton
@onready var _credits_button: Button = $OptionsPanel/MarginContainer/VBoxContainer/CreditsButton
@onready var _credits_label: Label = $OptionsPanel/MarginContainer/VBoxContainer/CreditsLabel
@onready var _skin_option: OptionButton = $OptionsPanel/MarginContainer/VBoxContainer/SkinOption
@onready var _skin_choose_button: Button = $OptionsPanel/MarginContainer/VBoxContainer/SkinChooseButton
@onready var _skin_path_label: Label = $OptionsPanel/MarginContainer/VBoxContainer/SkinPathLabel
@onready var _skin_dialog: FileDialog = $SkinFileDialog
@onready var _host_start_button: Button = $HostPanel/MarginContainer/VBoxContainer/HostStartButton
@onready var _host_back_button: Button = $HostPanel/MarginContainer/VBoxContainer/HostBackButton
@onready var _join_start_button: Button = $JoinPanel/MarginContainer/VBoxContainer/JoinStartButton
@onready var _join_back_button: Button = $JoinPanel/MarginContainer/VBoxContainer/JoinBackButton
@onready var _server_name_edit: LineEdit = $HostPanel/MarginContainer/VBoxContainer/ServerNameEdit
@onready var _port_edit: LineEdit = $HostPanel/MarginContainer/VBoxContainer/PortEdit
@onready var _max_players_edit: LineEdit = $HostPanel/MarginContainer/VBoxContainer/MaxPlayersEdit
@onready var _address_edit: LineEdit = $JoinPanel/MarginContainer/VBoxContainer/AddressEdit
@onready var _join_port_edit: LineEdit = $JoinPanel/MarginContainer/VBoxContainer/JoinPortEdit

const SKIN_TEXTURES_DIR := "res://kenney_blocky-characters_20/Models/GLB format/Textures"
const SKIN_NAME_MAP := {
	"texture-a.png": "Bearded Adventurer",
	"texture-b.png": "Backpacker",
	"texture-c.png": "Gamer Tee",
	"texture-d.png": "Crash Test Suit",
	"texture-e.png": "Village Girl",
	"texture-f.png": "Pierced Skater",
	"texture-g.png": "Red Robot",
	"texture-h.png": "Purple Robot",
	"texture-i.png": "Scientist",
	"texture-j.png": "Officer",
	"texture-k.png": "Cowboy",
	"texture-l.png": "Mutant Agent",
	"texture-m.png": "Ranger",
	"texture-n.png": "Kimono Girl",
	"texture-o.png": "Swamp Ogre",
	"texture-p.png": "Pirate",
	"texture-q.png": "Business Suit",
	"texture-r.png": "Ninja",
}

var _skin_textures: Array[Dictionary] = []

func _ready() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_options_button.pressed.connect(_on_options_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_credits_button.pressed.connect(_on_credits_pressed)
	_skin_option.item_selected.connect(_on_skin_selected)
	_skin_choose_button.pressed.connect(_on_skin_choose_pressed)
	_skin_dialog.file_selected.connect(_on_skin_file_selected)
	_host_start_button.pressed.connect(_on_host_start_pressed)
	_host_back_button.pressed.connect(_on_host_back_pressed)
	_join_start_button.pressed.connect(_on_join_start_pressed)
	_join_back_button.pressed.connect(_on_join_back_pressed)
	_setup_skin_picker()
	_show_home()

func _on_host_pressed() -> void:
	_show_host()

func _on_join_pressed() -> void:
	_show_join()

func _on_options_pressed() -> void:
	_show_options()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	_show_home()

func _on_credits_pressed() -> void:
	_credits_label.visible = true

func _on_skin_selected(index: int) -> void:
	if index < 0 or index >= _skin_textures.size():
		return
	var skin_path := str(_skin_textures[index]["path"])
	_set_player_skin_path(skin_path)

func _on_skin_choose_pressed() -> void:
	_skin_dialog.popup_centered()

func _on_skin_file_selected(path: String) -> void:
	_set_player_skin_path(path)

func _on_host_start_pressed() -> void:
	var port := int(_port_edit.text.strip_edges())
	var max_players := int(_max_players_edit.text.strip_edges())
	var server_name := _server_name_edit.text.strip_edges()
	get_tree().set_meta("match_mode", "host")
	get_tree().set_meta("host_port", port)
	get_tree().set_meta("host_max_players", max_players)
	get_tree().set_meta("host_name", server_name)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_host_back_pressed() -> void:
	_show_home()

func _on_join_start_pressed() -> void:
	var address := _address_edit.text.strip_edges()
	var port := int(_join_port_edit.text.strip_edges())
	get_tree().set_meta("match_mode", "join")
	get_tree().set_meta("join_address", address)
	get_tree().set_meta("join_port", port)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_join_back_pressed() -> void:
	_show_home()

func _set_match_mode_and_start(mode: String) -> void:
	get_tree().set_meta("match_mode", mode)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _show_home() -> void:
	_options_panel.visible = false
	_home_panel.visible = true
	_host_panel.visible = false
	_join_panel.visible = false
	_credits_label.visible = false

func _show_options() -> void:
	_home_panel.visible = false
	_options_panel.visible = true
	_host_panel.visible = false
	_join_panel.visible = false
	_credits_label.visible = false

func _show_host() -> void:
	_home_panel.visible = false
	_options_panel.visible = false
	_join_panel.visible = false
	_host_panel.visible = true
	_credits_label.visible = false

func _show_join() -> void:
	_home_panel.visible = false
	_options_panel.visible = false
	_host_panel.visible = false
	_join_panel.visible = true
	_credits_label.visible = false

func _setup_skin_picker() -> void:
	_skin_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_skin_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_skin_dialog.filters = PackedStringArray(["*.png ; PNG Images", "*.jpg ; JPEG Images"])
	_skin_option.clear()
	_skin_textures = _load_skin_textures()
	if _skin_textures.is_empty():
		_skin_path_label.text = "Current: Missing skins"
		return
	for skin in _skin_textures:
		_skin_option.add_item(str(skin["name"]))
	var stored_path := _get_player_skin_path()
	if stored_path == "":
		_set_player_skin_path(str(_skin_textures[0]["path"]), false)
		stored_path = _get_player_skin_path()
	var selected_index := 0
	for i in _skin_textures.size():
		if str(_skin_textures[i]["path"]) == stored_path:
			selected_index = i
			break
	_skin_option.select(selected_index)
	_update_skin_label()

func _set_player_skin_path(path: String, update_label: bool = true) -> void:
	get_tree().set_meta("player_skin_path", path)
	if update_label:
		_update_skin_label()

func _get_player_skin_path() -> String:
	var tree := get_tree()
	if tree.has_meta("player_skin_path"):
		return str(tree.get_meta("player_skin_path"))
	return ""

func _update_skin_label() -> void:
	var path := _get_player_skin_path()
	if path == "":
		_skin_path_label.text = "Current: Default"
	else:
		_skin_path_label.text = "Current: %s" % path

func _load_skin_textures() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var dir := DirAccess.open(SKIN_TEXTURES_DIR)
	if dir == null:
		return results
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if not file_name.to_lower().ends_with(".png"):
			continue
		var name := str(SKIN_NAME_MAP.get(file_name, file_name.replace(".png", "").capitalize()))
		var path := "%s/%s" % [SKIN_TEXTURES_DIR, file_name]
		results.append({"name": name, "path": path})
	dir.list_dir_end()
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]) < str(b["name"])
	)
	return results
