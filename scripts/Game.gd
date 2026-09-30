extends Node

# ==== Sinais (a HUD e outras cenas escutam esses eventos) ====
signal gold_changed(new_gold: int)
signal base_health_changed(current: int, max: int)
signal base_destroyed
signal wave_changed(current_wave: int, total_waves: int)
signal mission_completed
signal tower_clicked(tower: Node)

# ==== Configuração inicial ====
@export var starting_gold: int = 150
@export var starting_base_health: int = 20

# ==== Estado atual da partida ====
var gold: int
var base_health: int
var max_base_health: int
var is_game_over: bool = false
var current_wave: int = 0
var total_waves: int = 0
var enemies_total: int = 0   # quantos inimigos foram gerados na missão até agora
var enemies_killed: int = 0  # quantos desses morreram (o resto chegou na base)

# Progresso entre missões — NÃO é afetado por reset() (reset() é só da
# partida atual; isso aqui precisa sobreviver de missão pra missão).
var completed_mission_ids: Array[String] = []


func _ready() -> void:
	reset()


# Chame isso ao (re)iniciar uma missão/partida.
func reset() -> void:
	gold = starting_gold
	max_base_health = starting_base_health
	base_health = starting_base_health
	is_game_over = false
	current_wave = 0
	total_waves = 0
	enemies_total = 0
	enemies_killed = 0

	gold_changed.emit(gold)
	base_health_changed.emit(base_health, max_base_health)
	wave_changed.emit(current_wave, total_waves)


# ==== Ouro ====
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func can_afford(amount: int) -> bool:
	return gold >= amount


# Tenta gastar ouro (ex: comprar/upgradar uma torre).
# Retorna true se conseguiu pagar, false se não tinha ouro suficiente.
func spend_gold(amount: int) -> bool:
	if not can_afford(amount):
		return false

	gold -= amount
	gold_changed.emit(gold)
	return true


# ==== Vida da base ====
func damage_base(amount: int) -> void:
	if is_game_over:
		return

	base_health = max(base_health - amount, 0)
	base_health_changed.emit(base_health, max_base_health)

	if base_health <= 0:
		_game_over()


func _game_over() -> void:
	is_game_over = true
	base_destroyed.emit()
	print("GAME OVER — a base caiu!")


# ==== Waves ====
# O WaveManager chama isso uma vez no início, com quantas waves o jogo tem.
func set_total_waves(total: int) -> void:
	total_waves = total
	wave_changed.emit(current_wave, total_waves)


# O WaveManager chama isso toda vez que uma wave nova começa.
func set_current_wave(wave_number: int) -> void:
	current_wave = wave_number
	wave_changed.emit(current_wave, total_waves)


# ==== Progresso de missões ====
func mark_mission_completed(mission_id: String) -> void:
	if mission_id != "" and not completed_mission_ids.has(mission_id):
		completed_mission_ids.append(mission_id)


# Chamado pelo WaveManager quando todo mundo já spawnou E morreu/chegou na
# base — aí sim a missão está de verdade terminada.
func finish_mission(mission_id: String) -> void:
	mark_mission_completed(mission_id)
	mission_completed.emit()


# Uma missão está liberada se todas as missões que ela exige já foram
# concluídas (lista vazia = sempre liberada, ex: a primeira missão).
func is_mission_unlocked(mission_data: MissionData) -> bool:
	for required_id in mission_data.required_mission_ids:
		if not completed_mission_ids.has(required_id):
			return false
	return true


# ==== Contadores de inimigos (pra tela de estatísticas no fim da missão) ====
func register_enemy_spawned() -> void:
	enemies_total += 1


func register_enemy_killed() -> void:
	enemies_killed += 1
