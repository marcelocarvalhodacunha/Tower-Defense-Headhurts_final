extends "res://scripts/Projectile.gd"

## Além do dano de impacto normal (herdado de Projectile), aplica veneno
## (DOT) no inimigo atingido.

@export var poison_damage_per_tick: int = 2
@export var poison_tick_interval: float = 0.5
@export var poison_duration: float = 3.0
@export var poison_armor_reduction: int = 1
@export var poison_tint: Color = Color(0.6, 1.0, 0.6)  # tom esverdeado enquanto envenenado


func _on_hit(enemy: Enemy) -> void:
	super._on_hit(enemy)
	enemy.apply_dot(
		"poison",
		poison_damage_per_tick,
		poison_tick_interval,
		poison_duration,
		poison_armor_reduction,
		poison_tint
	)
