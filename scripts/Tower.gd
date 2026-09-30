extends Node2D
class_name Tower

# ==== Sinais ====
signal target_acquired(target: Enemy)
signal target_lost
signal attacked(target: Enemy)
signal upgraded(new_level: int)

# ==== Atributos exportados (sobrescreva nos valores da cena herdada) ====
@export var display_name: String = "Torre"
@export var damage: int = 5
@export var attack_range: float = 150.0
@export var attack_speed: float = 1.0     # ataques por segundo
@export var projectile_speed: float = 400.0  # velocidade do projétil, aplicada a cada disparo
@export var cost: int = 50
@export var effects_description: String = ""  # texto livre pra mostrar no painel de info (ex: DOT)
@export var projectile_scene: PackedScene # deixe vazio se a torre não atira projétil (ex: dano em área instantâneo)

# ==== Upgrade ====
@export var upgrade_levels: Array[TowerUpgrade] = []
# Caminhos de .tres carregados automaticamente se upgrade_levels estiver
# vazio no Inspector — assim cada torre já nasce com seus upgrades sem
# precisar montar o array manualmente na cena.
@export var default_upgrade_paths: Array[String] = []
var current_level: int = 0
var _projectile_overrides: Dictionary = {}

# ==== Estratégia de alvo ====
enum TargetPriority { FIRST, LAST, CLOSEST, STRONGEST, WEAKEST }
@export var target_priority: TargetPriority = TargetPriority.FIRST

# ==== Estado interno ====
var enemies_in_range: Array[Enemy] = []
var current_target: Enemy = null
var can_attack: bool = true

@onready var base_sprite: Sprite2D = $Base
@onready var turret: AnimatedSprite2D = $Turret
@onready var range_area: Area2D = $EnemyDetectionArea
@onready var range_shape: CollisionShape2D = $EnemyDetectionArea/CollisionShape2D
@onready var click_area: Area2D = $ClickArea
@onready var attack_timer: Timer = $ReloadTimer


func _ready() -> void:
	if upgrade_levels.is_empty():
		for path in default_upgrade_paths:
			var data: TowerUpgrade = load(path)
			if data:
				upgrade_levels.append(data)

	_update_range_shape()

	range_area.body_entered.connect(_on_body_entered)
	range_area.body_exited.connect(_on_body_exited)

	click_area.input_event.connect(_on_click_area_input_event)
	# Evita que o próprio clique que POSICIONA a torre seja "repicado" pela
	# área de clique dela mesma (a torre nasce exatamente embaixo do cursor
	# no instante do clique). Só liga a detecção de clique alguns frames
	# físicos depois.
	click_area.input_pickable = false
	_enable_click_area_after_delay()

	attack_timer.wait_time = 1.0 / attack_speed
	attack_timer.timeout.connect(_on_reload_timer_timeout)
	attack_timer.start()


func _enable_click_area_after_delay() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(click_area):
		click_area.input_pickable = true


func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Game.tower_clicked.emit(self)


func _process(_delta: float) -> void:
	if is_instance_valid(current_target):
		_face_target(current_target)
	else:
		_select_target()


func _update_range_shape() -> void:
	if range_shape.shape is CircleShape2D:
		range_shape.shape.radius = attack_range


# ==== Detecção de inimigos ====
func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		enemies_in_range.append(body)
		body.tree_exiting.connect(_on_enemy_removed.bind(body), CONNECT_ONE_SHOT)
		if current_target == null:
			_select_target()


func _on_body_exited(body: Node2D) -> void:
	if body is Enemy:
		_remove_enemy(body)


func _on_enemy_removed(enemy: Enemy) -> void:
	_remove_enemy(enemy)


func _remove_enemy(enemy: Enemy) -> void:
	enemies_in_range.erase(enemy)
	if current_target == enemy:
		current_target = null
		target_lost.emit()
		_select_target()


# ==== Seleção de alvo ====
func _select_target() -> void:
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))

	if enemies_in_range.is_empty():
		current_target = null
		return

	match target_priority:
		TargetPriority.FIRST:
			current_target = enemies_in_range[0]
		TargetPriority.LAST:
			current_target = enemies_in_range[-1]
		TargetPriority.CLOSEST:
			current_target = enemies_in_range.reduce(
				func(a, b): return a if global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position) else b
			)
		TargetPriority.STRONGEST:
			current_target = enemies_in_range.reduce(
				func(a, b): return a if a.current_health > b.current_health else b
			)
		TargetPriority.WEAKEST:
			current_target = enemies_in_range.reduce(
				func(a, b): return a if a.current_health < b.current_health else b
			)

	if current_target:
		target_acquired.emit(current_target)


func _face_target(target: Enemy) -> void:
	# só a torreta gira; a base fica fixa apontando pra baixo/padrão
	turret.rotation = (target.global_position - global_position).angle() + deg_to_rad(90)


# ==== Ataque ====
func _on_reload_timer_timeout() -> void:
	if is_instance_valid(current_target):
		_attack(current_target)


func _attack(target: Enemy) -> void:
	attacked.emit(target)

	if turret.sprite_frames and turret.sprite_frames.has_animation("shoot"):
		turret.play("shoot")

	if projectile_scene:
		_shoot_projectile(target)
	else:
		# torre de dano instantâneo (ex: laser, área) — sobrescreva _apply_direct_damage se precisar
		_apply_direct_damage(target)


func _shoot_projectile(target: Enemy) -> void:
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position

	if "speed" in projectile:
		projectile.speed = projectile_speed

	for key in _projectile_overrides:
		var value = _projectile_overrides[key]
		if projectile.has_method(key):
			projectile.call(key, value)
		elif key in projectile:
			projectile.set(key, value)

	if projectile.has_method("launch"):
		projectile.launch(target, damage)


func _apply_direct_damage(target: Enemy) -> void:
	target.take_damage(damage)


# ==== Upgrade ====
func get_next_upgrade() -> TowerUpgrade:
	if current_level < upgrade_levels.size():
		return upgrade_levels[current_level]
	return null


func can_upgrade() -> bool:
	return get_next_upgrade() != null


## Tenta comprar o próximo nível de upgrade. Retorna true se conseguiu
## (e já aplica os novos status na hora), false se não tinha ouro ou não
## tem mais upgrade disponível.
func try_upgrade() -> bool:
	var next := get_next_upgrade()
	if next == null:
		return false

	if not Game.spend_gold(next.cost):
		return false

	damage = next.damage
	attack_range = next.attack_range
	attack_speed = next.attack_speed
	projectile_speed = next.projectile_speed
	effects_description = next.effects_description
	_projectile_overrides = next.projectile_overrides

	_update_range_shape()
	attack_timer.wait_time = 1.0 / attack_speed

	if next.turret_sprite_frames:
		turret.sprite_frames = next.turret_sprite_frames
	if next.base_sprite_texture:
		base_sprite.texture = next.base_sprite_texture

	current_level += 1
	upgraded.emit(current_level)
	return true
