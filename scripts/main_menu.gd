extends Control

@onready var _missions_button: Button = $CenterBox/MissionsButton
@onready var _quit_button: Button = $CenterBox/QuitButton


func _ready() -> void:
	_missions_button.pressed.connect(_on_missions_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _on_missions_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/missions_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
