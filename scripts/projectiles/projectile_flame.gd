extends "res://scripts/Projectile.gd"

## Além do dano de impacto normal (herdado de Projectile), incendeia o
## inimigo atingido: dano contínuo RÁPIDO e ALTO (tique curto, dano grande).

@export var burn_damage_per_tick: int = 5
@export var burn_tick_interval: float = 0.25
@export var burn_duration: float = 2.0
@export var burn_tint: Color = Color(1.0, 0.55, 0.3)  # tom alaranjado enquanto queimando


func _on_hit(enemy: Enemy) -> void:
	super._on_hit(enemy)
	enemy.apply_dot(
		"burn",
		burn_damage_per_tick,
		burn_tick_interval,
		burn_duration,
		0,
		burn_tint
	)
