extends Control

@onready var _play_again_button: Button = $MarginContainer/VBoxContainer/PlayAgainButton
@onready var _quit_button: Button = $MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)

func _on_play_again_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
