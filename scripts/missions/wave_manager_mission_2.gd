extends "res://scripts/wave_manager.gd"

## Ondas da Missão 2 — um pouco mais puxada que a Missão 1: menos tempo pra
## aquecer, mais tanques e rápidas misturados desde cedo. Ajuste os números
## à vontade, é só mexer aqui, não afeta a Missão 1.

func _define_waves() -> void:
	var basic := preload("res://scenes/enemy_basic.tscn")
	var fast := preload("res://scenes/enemy_fast.tscn")
	var tank := preload("res://scenes/enemy_tank.tscn")
	var supreme := preload("res://scenes/enemy_supreme.tscn")
	_waves = [
		# Onda 1: já entra com básicas + rápidas juntas
		Wave.new([
			WaveEntry.new(basic, 8, 0.8),
			WaveEntry.new(fast, 4, 0.9),
		], 6.0),

		# Onda 2: primeiros tanques
		Wave.new([
			WaveEntry.new(tank, 3, 1.8),
			WaveEntry.new(fast, 6, 0.6),
		], 7.0),

		# Onda 3: pressão alta, pouco espaço pra respirar
		Wave.new([
			WaveEntry.new(tank, 4, 1.5),
			WaveEntry.new(basic, 10, 0.4),
		], 8.0),

		# Onda 4: bastante rápida + tanque junto
		Wave.new([
			WaveEntry.new(tank, 5, 1.2),
			WaveEntry.new(fast, 10, 0.4),
		], 9.0),

		Wave.new([
			WaveEntry.new(basic, 12, 0.4),
			WaveEntry.new(tank, 6, 1.0),
			WaveEntry.new(fast, 10, 0.4),
		], 11.0),
		
		Wave.new([
			WaveEntry.new(tank, 5, 1.2),
			WaveEntry.new(supreme, 2, 1.5),
			WaveEntry.new(fast, 8, 0.4),
		], 0.0),
	]
