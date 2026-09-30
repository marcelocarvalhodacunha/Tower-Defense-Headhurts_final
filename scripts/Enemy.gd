extends CharacterBody2D
class_name Enemy

# ==== Sinais ====
signal died(enemy: Enemy)
signal reached_end(enemy: Enemy)
signal health_changed(current: int, max: int)

# ==== Atributos exportados (sobrescreva nos valores da cena herdada) ====
@export var max_health: int = 10
@export var speed: float = 80.0
@export var damage: int = 1        # dano causado à base/vida do jogador ao chegar no fim
@export var gold_reward: int = 5
@export var armor: int = 0         # reduz dano recebido, opcional

# ==== Estado interno ====
var current_health: int
var is_dead: bool = false
var has_reached_end: bool = false
var path_follow: PathFollow2D
var _base_speed: float  # velocidade original, antes de qualquer lentidão aplicada

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# Se você tiver uma barra de vida, descomente e ajuste o path:
# @onready var health_bar: ProgressBar = $HealthBar


func _ready() -> void:
	current_health = max_health
	_base_speed = speed
	# Só agora o nó já está na árvore, então get_parent() funciona de verdade
	# (pegar isso no topo da classe sempre retornava null).
	path_follow = get_parent() as PathFollow2D
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if is_dead or has_reached_end:
		return
	_move_along_path(delta)


# Renomeado de "_process" pra "_move_along_path": o nome "_process" é
# reservado pela engine e ela chamava esse método sozinha todo frame,
# então o inimigo andava rápido demais (dobro da velocidade real).
func _move_along_path(delta: float) -> void:
	if not is_instance_valid(path_follow):
		return

	path_follow.progress += speed * delta
	if path_follow.progress_ratio >= 1.0:
		_on_reached_end()


func take_damage(amount: int) -> void:
	if is_dead or has_reached_end:
		return

	var final_damage: int = max(amount - armor, 0)
	current_health -= final_damage
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		_die()


func _die() -> void:
	if is_dead or has_reached_end:
		return
	is_dead = true
	died.emit(self)
	_on_death()  # hook para cenas herdadas sobrescreverem (efeitos, drops, etc.)
	_free_self()


func _on_reached_end() -> void:
	if is_dead or has_reached_end:
		return
	has_reached_end = true
	reached_end.emit(self)
	_free_self()


func _free_self() -> void:
	# Liberar o PathFollow2D já libera o inimigo junto (ele é filho dele).
	if is_instance_valid(path_follow):
		path_follow.queue_free()
	else:
		queue_free()


# ==== DOT (Damage over Time) ====
# Sistema genérico de efeito de dano contínuo — qualquer torre pode chamar
# apply_dot() com nomes/valores diferentes (ex: "poison", "burn", "bleed"),
# sem precisar de código específico aqui pra cada tipo de efeito.
var _active_dots: Dictionary = {}  # nome do efeito (String) -> {timer, damage_per_tick, ticks_remaining, armor_reduction}


## Aplica (ou renova) um efeito de dano contínuo neste inimigo.
## Ex: enemy.apply_dot("poison", 2, 0.5, 3.0, 1, Color(0.6, 1.0, 0.6))
##     -> 2 de dano a cada 0.5s, durante 3s, reduz 1 de armadura enquanto
##        durar, e deixa o sprite esverdeado como feedback visual.
func apply_dot(
	effect_name: String,
	damage_per_tick: int,
	tick_interval: float,
	duration: float,
	armor_reduction: int = 0,
	tint_color: Color = Color.WHITE
) -> void:
	if is_dead or has_reached_end:
		return

	var ticks := maxi(roundi(duration / tick_interval), 1)

	# já está com esse efeito ativo: só renova a duração/dano, não empilha
	# (evita, por exemplo, 5 flechas envenenadas deixarem 5 timers rodando juntos)
	if _active_dots.has(effect_name):
		var effect: Dictionary = _active_dots[effect_name]
		effect["damage_per_tick"] = damage_per_tick
		effect["ticks_remaining"] = ticks
		return

	if armor_reduction > 0:
		armor = maxi(armor - armor_reduction, 0)

	if tint_color != Color.WHITE:
		sprite.modulate = tint_color

	var timer := Timer.new()
	timer.wait_time = tick_interval
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_on_dot_tick.bind(effect_name))
	timer.start()

	_active_dots[effect_name] = {
		"timer": timer,
		"damage_per_tick": damage_per_tick,
		"ticks_remaining": ticks,
		"armor_reduction": armor_reduction,
	}


func _on_dot_tick(effect_name: String) -> void:
	if not _active_dots.has(effect_name):
		return

	if is_dead or has_reached_end:
		_end_dot(effect_name)
		return

	var effect: Dictionary = _active_dots[effect_name]
	take_damage(effect["damage_per_tick"])
	effect["ticks_remaining"] -= 1

	if effect["ticks_remaining"] <= 0:
		_end_dot(effect_name)


func _end_dot(effect_name: String) -> void:
	if not _active_dots.has(effect_name):
		return

	var effect: Dictionary = _active_dots[effect_name]

	if effect["armor_reduction"] > 0:
		armor += effect["armor_reduction"]  # devolve a armadura ao acabar o efeito

	effect["timer"].queue_free()
	_active_dots.erase(effect_name)
	_update_status_tint()


# ==== Lentidão (Freeze/Slow) ====
# Sistema genérico de redução de velocidade — qualquer torre pode chamar
# apply_slow() com nomes/valores diferentes (ex: "freeze"), sem precisar de
# código específico aqui pra cada torre. Se dois efeitos de lentidão
# diferentes estiverem ativos ao mesmo tempo, vale o mais forte (não empilha).
var _active_slows: Dictionary = {}  # nome do efeito (String) -> {timer, factor}


## Aplica (ou renova) uma redução de velocidade neste inimigo.
## Ex: enemy.apply_slow("freeze", 0.5, 2.5, Color(0.6, 0.9, 1.0))
##     -> anda a 50% da velocidade normal por 2.5s, com tom azulado.
func apply_slow(
	effect_name: String,
	slow_factor: float,
	duration: float,
	tint_color: Color = Color.WHITE
) -> void:
	if is_dead or has_reached_end:
		return

	if _active_slows.has(effect_name):
		# já está com esse efeito ativo: só renova a duração (reinicia o timer)
		var effect: Dictionary = _active_slows[effect_name]
		effect["timer"].start(duration)
		return

	if tint_color != Color.WHITE:
		sprite.modulate = tint_color

	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_slow_expired.bind(effect_name))
	timer.start()

	_active_slows[effect_name] = {
		"timer": timer,
		"factor": clampf(slow_factor, 0.0, 1.0),
	}
	_recalculate_speed()


func _on_slow_expired(effect_name: String) -> void:
	if not _active_slows.has(effect_name):
		return

	_active_slows[effect_name]["timer"].queue_free()
	_active_slows.erase(effect_name)
	_recalculate_speed()
	_update_status_tint()


# Vale sempre o efeito de lentidão MAIS FORTE ativo no momento (não soma
# vários — evita a velocidade ficar negativa ou o inimigo travar de vez).
func _recalculate_speed() -> void:
	var strongest_factor := 0.0
	for effect_name in _active_slows:
		strongest_factor = maxf(strongest_factor, _active_slows[effect_name]["factor"])
	speed = _base_speed * (1.0 - strongest_factor)


# Só volta o sprite pra cor normal quando NENHUM efeito (dano contínuo ou
# lentidão) estiver mais ativo — assim um não apaga visualmente o outro.
func _update_status_tint() -> void:
	if _active_dots.is_empty() and _active_slows.is_empty():
		sprite.modulate = Color.WHITE


# ==== Hooks virtuais para as cenas herdadas sobrescreverem ====
# Ex: numa cena herdada, você pode fazer:
#     func _on_death() -> void:
#         super._on_death()
#         spawn_particulas_de_morte()
func _on_death() -> void:
	pass
