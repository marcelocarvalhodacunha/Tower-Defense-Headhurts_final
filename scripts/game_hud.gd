extends CanvasLayer

## HUD principal. Os labels (vida, ouro, wave, tempo) e os painéis de Pausa
## e Game Over são todos nós de verdade definidos em hud.tscn — esse script
## só conecta nos sinais/botões e faz a lógica.
##
## A própria HUD (esse nó) roda com process_mode = ALWAYS, pra sempre
## detectar o ESC mesmo com o jogo pausado. O ramo "Margin" (labels comuns)
## é explicitamente PAUSABLE, então continua congelando normalmente — só os
## painéis de overlay (Pause/GameOver) é que ficam sempre ativos.

@onready var _health_label: Label = $Margin/HealthLabel
@onready var _gold_label: Label = $Margin/GoldLabel
@onready var _wave_label: Label = $Margin/WaveLabel
@onready var _time_label: Label = $Margin/TimeLabel

@onready var _pause_panel: Control = $PausePanel
@onready var _game_over_panel: Control = $GameOverPanel
@onready var _mission_complete_panel: Control = $MissionCompletePanel

const SPEED_OPTIONS: Array[float] = [1.0, 1.5, 2.0, 4.0]
@onready var _speed_buttons: Array[Button] = [
	$SpeedPanel/Speed1xButton,
	$SpeedPanel/Speed15xButton,
	$SpeedPanel/Speed2xButton,
	$SpeedPanel/Speed4xButton,
]

var _elapsed_seconds: int = 0


func _ready() -> void:
	Engine.time_scale = 1.0  # garante que a missão sempre começa na velocidade normal

	Game.gold_changed.connect(_on_gold_changed)
	Game.base_health_changed.connect(_on_base_health_changed)
	Game.wave_changed.connect(_on_wave_changed)
	Game.base_destroyed.connect(_on_base_destroyed)
	Game.mission_completed.connect(_on_mission_completed)

	$PausePanel/CenterBox/ResumeButton.pressed.connect(_on_resume_pressed)
	$PausePanel/CenterBox/RestartButton.pressed.connect(_on_restart_pressed)
	$PausePanel/CenterBox/MenuButton.pressed.connect(_on_menu_pressed)
	$PausePanel/CenterBox/QuitButton.pressed.connect(_on_quit_pressed)

	$GameOverPanel/CenterBox/RestartButton.pressed.connect(_on_restart_pressed)
	$GameOverPanel/CenterBox/MenuButton.pressed.connect(_on_menu_pressed)
	$GameOverPanel/CenterBox/QuitButton.pressed.connect(_on_quit_pressed)

	$MissionCompletePanel/CenterBox/MenuButton.pressed.connect(_on_menu_pressed)
	$MissionCompletePanel/CenterBox/MissionsButton.pressed.connect(_on_missions_pressed)

	for i in _speed_buttons.size():
		_speed_buttons[i].pressed.connect(_on_speed_button_pressed.bind(i))

	# mostra o estado atual assim que a HUD entra na árvore
	_on_gold_changed(Game.gold)
	_on_base_health_changed(Game.base_health, Game.max_base_health)
	_on_wave_changed(Game.current_wave, Game.total_waves)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _on_gold_changed(new_gold: int) -> void:
	_gold_label.text = "Ouro: %d" % new_gold


func _on_base_health_changed(current: int, max_health: int) -> void:
	_health_label.text = "Vida: %d/%d" % [current, max_health]


func _on_wave_changed(current_wave: int, total_waves: int) -> void:
	_wave_label.text = "Wave: %d/%d" % [current_wave, total_waves]


# Conectado ao Timer de 1s dentro do TimeLabel (na cena).
func _on_timer_timeout() -> void:
	_elapsed_seconds += 1
	_time_label.text = "Time: %d" % _elapsed_seconds


# ==== Velocidade do jogo ====
func _on_speed_button_pressed(index: int) -> void:
	Engine.time_scale = SPEED_OPTIONS[index]
	_update_speed_buttons(index)


func _update_speed_buttons(active_index: int) -> void:
	for i in _speed_buttons.size():
		_speed_buttons[i].disabled = (i == active_index)


# ==== Pausa (ESC) ====
func _toggle_pause() -> void:
	if Game.is_game_over or _mission_complete_panel.visible:
		return  # não abre o menu de pausa por cima de Game Over / Missão Concluída

	if get_tree().paused:
		_on_resume_pressed()
	else:
		_pause_panel.visible = true
		get_tree().paused = true


func _on_resume_pressed() -> void:
	_pause_panel.visible = false
	get_tree().paused = false


# ==== Game Over ====
func _on_base_destroyed() -> void:
	_game_over_panel.visible = true
	get_tree().paused = true  # congela torres, timers, spawner, tudo


# ==== Missão concluída ====
func _on_mission_completed() -> void:
	_fill_mission_complete_stats()
	_mission_complete_panel.visible = true
	get_tree().paused = true


func _fill_mission_complete_stats() -> void:
	var box := _mission_complete_panel.get_node("CenterBox")
	box.get_node("EnemiesLabel").text = "Inimigos mortos: %d/%d" % [Game.enemies_killed, Game.enemies_total]
	box.get_node("TimeLabel").text = "Tempo total: %ds" % _elapsed_seconds
	box.get_node("HealthLabel").text = "Vida final: %d/%d" % [Game.base_health, Game.max_base_health]
	box.get_node("GoldLabel").text = "Ouro final: %d" % Game.gold


# ==== Ações compartilhadas entre Pausa, Game Over e Missão Concluída ====
func _on_restart_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false  # despausa ANTES de recarregar, senão a cena nova nasce pausada
	Game.reset()
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_missions_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/missions_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
