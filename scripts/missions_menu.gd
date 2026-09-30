extends Control

## Lista as missões disponíveis. Cada botão vem de um MissionData (.tres) —
## pra adicionar uma missão nova, crie um resources/mission_data_X.tres
## (igual ao mission_data_1.tres) e coloque o caminho em DEFAULT_MISSION_PATHS,
## ou arraste ele no array "Missions" do Inspector direto nesta cena.

@export var missions: Array[MissionData] = []

const DEFAULT_MISSION_PATHS: Array[String] = [
	"res://resources/mission_data_1.tres",
	"res://resources/mission_data_2.tres",
]

@onready var _mission_list: VBoxContainer = $CenterBox/MissionList
@onready var _back_button: Button = $CenterBox/BackButton


func _ready() -> void:
	if missions.is_empty():
		for mission_path in DEFAULT_MISSION_PATHS:
			var data: MissionData = load(mission_path)
			if data:
				missions.append(data)

	_build_mission_buttons()
	_back_button.pressed.connect(_on_back_pressed)


func _build_mission_buttons() -> void:
	for mission_data in missions:
		var button := Button.new()
		button.custom_minimum_size = Vector2(240, 48)

		var unlocked := Game.is_mission_unlocked(mission_data)
		button.text = mission_data.display_name if unlocked else "%s (bloqueada)" % mission_data.display_name
		button.disabled = not unlocked

		if unlocked:
			button.pressed.connect(_on_mission_pressed.bind(mission_data))

		_mission_list.add_child(button)


func _on_mission_pressed(mission_data: MissionData) -> void:
	get_tree().change_scene_to_packed(mission_data.scene)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
