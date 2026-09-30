extends "res://scripts/wave_manager.gd"

## Ondas da Missão 1. Pra criar a Missão 2, 3 etc., NÃO edite este arquivo —
## crie um novo (ex: wave_manager_mission_2.gd) do mesmo jeito, com as ondas
## daquela missão.

func _define_waves() -> void:
	var basic := preload("res://scenes/enemy_basic.tscn")
	var fast := preload("res://scenes/enemy_fast.tscn")
	var tank := preload("res://scenes/enemy_tank.tscn")
	var supreme := preload("res://scenes/enemy_supreme.tscn")

	_waves = [
		# Onda 1: só fadas básicas, pra aquecer
		Wave.new([
			WaveEntry.new(basic, 6, 1.0),
		], 6.0),

		# Onda 2: mais básicas + as primeiras rápidas
		Wave.new([
			WaveEntry.new(basic, 8, 0.8),
			WaveEntry.new(fast, 3, 1.0),
		], 7.0),

		# Onda 3: rápidas e a primeira tanque
		Wave.new([
			WaveEntry.new(tank, 2, 2.0),
			WaveEntry.new(fast, 6, 0.6),
		], 8.0),

		# Onda 4: mistura pesada de tudo
		Wave.new([
			WaveEntry.new(basic, 10, 0.5),
			WaveEntry.new(tank, 4, 1.2),
			WaveEntry.new(fast, 6, 0.5),
		], 10.0),
		
		Wave.new([
			WaveEntry.new(fast, 4, 1.0),
			WaveEntry.new(supreme, 1, 1.0),
			WaveEntry.new(fast, 4, 1.0),
		], 0.0),
	]
