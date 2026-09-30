extends Node2D

## Sistema de waves (ondas) de inimigos.
##
## Essa classe é genérica e não deve ser usada diretamente numa cena — cada
## missão tem sua PRÓPRIA subclasse (ex: scripts/missions/wave_manager_mission_1.gd)
## que só sobrescreve _define_waves() com as ondas daquela missão específica.
## O resto do motor (spawn, timing, sinais, contagem de missão completa) é
## compartilhado por todas as missões e não precisa mudar.
##
## Cada Wave tem uma lista de WaveEntry (um grupo de inimigos daquela onda)
## e um "delay_after" (segundos de descanso antes da próxima onda começar).
## Cada WaveEntry diz qual inimigo, quantos, e o intervalo entre cada spawn
## desse grupo.

signal wave_started(wave_number: int)
signal wave_finished(wave_number: int)
signal all_waves_finished

@export var path: Path2D
@export var delay_before_first_wave: float = 5.0
@export var mission_id: String = ""  # usado pra marcar a missão como concluída ao terminar a última wave


# ==== Estrutura de dados de uma onda ====
class WaveEntry:
	var enemy_scene: PackedScene
	var count: int
	var interval: float  # segundos entre cada spawn desse grupo

	func _init(p_enemy_scene: PackedScene, p_count: int, p_interval: float) -> void:
		enemy_scene = p_enemy_scene
		count = p_count
		interval = p_interval


class Wave:
	var entries: Array[WaveEntry]
	var delay_after: float  # segundos de espera depois que essa onda termina

	func _init(p_entries: Array[WaveEntry], p_delay_after: float = 3.0) -> void:
		entries = p_entries
		delay_after = p_delay_after


var _waves: Array[Wave] = []
var _all_waves_dispatched: bool = false
var _enemies_alive: int = 0


func _ready() -> void:
	_define_waves()
	Game.set_total_waves(_waves.size())
	_run_waves()


# ==== EDITE AQUI PRA MUDAR AS ONDAS DO JOGO ====
func _define_waves() -> void:
	push_warning("WaveManager: _define_waves() não foi sobrescrito por nenhuma missão — nenhuma onda vai rodar.")


# ==== Motor genérico (não precisa mexer daqui pra baixo) ====
func _run_waves() -> void:
	await get_tree().create_timer(delay_before_first_wave).timeout

	for i in _waves.size():
		wave_started.emit(i + 1)
		Game.set_current_wave(i + 1)
		await _run_wave(_waves[i])
		wave_finished.emit(i + 1)

		var is_last_wave := i == _waves.size() - 1
		if not is_last_wave and _waves[i].delay_after > 0.0:
			await get_tree().create_timer(_waves[i].delay_after).timeout

	all_waves_finished.emit()
	_all_waves_dispatched = true
	_check_mission_complete()  # cobre o caso raro de já não sobrar ninguém vivo nesse instante


func _run_wave(wave: Wave) -> void:
	for entry in wave.entries:
		for i in entry.count:
			_spawn_enemy(entry.enemy_scene)
			if i < entry.count - 1:
				await get_tree().create_timer(entry.interval).timeout


func _spawn_enemy(enemy_scene: PackedScene) -> void:
	var path_follow := PathFollow2D.new()
	path_follow.loop = false
	path.add_child(path_follow)

	var enemy: Enemy = enemy_scene.instantiate()
	path_follow.add_child(enemy)

	_enemies_alive += 1
	Game.register_enemy_spawned()

	enemy.died.connect(_on_enemy_died)
	enemy.reached_end.connect(_on_enemy_reached_end)


func _on_enemy_died(enemy: Enemy) -> void:
	Game.add_gold(enemy.gold_reward)
	Game.register_enemy_killed()
	_enemies_alive -= 1
	_check_mission_complete()


func _on_enemy_reached_end(enemy: Enemy) -> void:
	Game.damage_base(enemy.damage)
	_enemies_alive -= 1
	_check_mission_complete()


# Só considera a missão terminada quando TODAS as waves já foram despachadas
# E não sobra nenhum inimigo vivo no mapa (morto ou tendo chegado na base).
func _check_mission_complete() -> void:
	if Game.is_game_over:
		return
	if _all_waves_dispatched and _enemies_alive <= 0:
		Game.finish_mission(mission_id)
