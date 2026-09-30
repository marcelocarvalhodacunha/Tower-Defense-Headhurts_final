extends Resource
class_name MissionData

## Representa uma missão selecionável na tela de Missions.
## required_mission_ids vazio = sempre liberada (ex: a primeira missão).
## Pra travar uma missão atrás de outra(s), coloque o "id" da(s) exigida(s)
## aqui (ex: ["mission_1"] só libera depois da Missão 1 ser concluída).

@export var id: String = ""
@export var display_name: String = "Missão"
@export var scene: PackedScene
@export var required_mission_ids: Array[String] = []
