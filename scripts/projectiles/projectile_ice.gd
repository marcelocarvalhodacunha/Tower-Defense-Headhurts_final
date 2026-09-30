extends "res://scripts/Projectile.gd"

## Além do (pequeno) dano de impacto normal (herdado de Projectile),
## congela o inimigo atingido: reduz a velocidade de movimento por um tempo.

@export var freeze_slow_factor: float = 0.5  # 0.5 = anda a 50% da velocidade normal
@export var freeze_duration: float = 2.5
@export var freeze_tint: Color = Color(0.6, 0.9, 1.0)  # tom azulado enquanto congelado


func _on_hit(enemy: Enemy) -> void:
	super._on_hit(enemy)
	enemy.apply_slow(
		"freeze",
		freeze_slow_factor,
		freeze_duration,
		freeze_tint
	)
