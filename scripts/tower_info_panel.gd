extends CanvasLayer

## Painel que abre ao clicar numa torre: mostra os status atuais e, se
## houver upgrade disponível, os status do próximo nível lado a lado pra
## comparação. NÃO pausa o jogo — o jogador continua vendo a partida
## rolando enquanto decide se compra o upgrade.

@onready var _box: PanelContainer = $Box
@onready var _title_label: Label = $Box/Content/TitleLabel

@onready var _range_current: Label = $Box/Content/StatsGrid/RangeCurrentLabel
@onready var _range_next: Label = $Box/Content/StatsGrid/RangeNextLabel
@onready var _speed_current: Label = $Box/Content/StatsGrid/SpeedCurrentLabel
@onready var _speed_next: Label = $Box/Content/StatsGrid/SpeedNextLabel
@onready var _proj_speed_current: Label = $Box/Content/StatsGrid/ProjSpeedCurrentLabel
@onready var _proj_speed_next: Label = $Box/Content/StatsGrid/ProjSpeedNextLabel
@onready var _damage_current: Label = $Box/Content/StatsGrid/DamageCurrentLabel
@onready var _damage_next: Label = $Box/Content/StatsGrid/DamageNextLabel
@onready var _effects_current: Label = $Box/Content/StatsGrid/EffectsCurrentLabel
@onready var _effects_next: Label = $Box/Content/StatsGrid/EffectsNextLabel

@onready var _upgrade_button: Button = $Box/Content/UpgradeButton

var _selected_tower: Tower = null


func _ready() -> void:
	Game.tower_clicked.connect(_on_tower_clicked)
	Game.gold_changed.connect(_on_gold_changed)
	Game.base_destroyed.connect(_on_game_ended)
	Game.mission_completed.connect(_on_game_ended)


func _on_game_ended() -> void:
	_on_close_pressed()


func _on_tower_clicked(tower: Node) -> void:
	if not (tower is Tower):
		return

	_selected_tower = tower
	_box.visible = true
	_refresh()


func _on_close_pressed() -> void:
	_selected_tower = null
	_box.visible = false


func _on_gold_changed(_new_gold: int) -> void:
	if _box.visible:
		_update_upgrade_button()


func _refresh() -> void:
	if not is_instance_valid(_selected_tower):
		_on_close_pressed()
		return

	_title_label.text = _selected_tower.display_name

	_range_current.text = "%.0f" % _selected_tower.attack_range
	_speed_current.text = "%.1f/s" % _selected_tower.attack_speed
	_proj_speed_current.text = "%.0f" % _selected_tower.projectile_speed
	_damage_current.text = "%d" % _selected_tower.damage
	_effects_current.text = _selected_tower.effects_description if _selected_tower.effects_description != "" else "—"

	var next := _selected_tower.get_next_upgrade()

	if next:
		_range_next.text = "→ %.0f" % next.attack_range
		_speed_next.text = "→ %.1f/s" % next.attack_speed
		_proj_speed_next.text = "→ %.0f" % next.projectile_speed
		_damage_next.text = "→ %d" % next.damage
		_effects_next.text = "→ %s" % (next.effects_description if next.effects_description != "" else "—")
	else:
		_range_next.text = ""
		_speed_next.text = ""
		_proj_speed_next.text = ""
		_damage_next.text = ""
		_effects_next.text = ""

	_update_upgrade_button()


func _update_upgrade_button() -> void:
	var next := _selected_tower.get_next_upgrade() if is_instance_valid(_selected_tower) else null

	if next == null:
		_upgrade_button.text = "Nível máximo"
		_upgrade_button.disabled = true
	else:
		_upgrade_button.text = "Upgrade (%d de ouro)" % next.cost
		_upgrade_button.disabled = not Game.can_afford(next.cost)


func _on_upgrade_pressed() -> void:
	if not is_instance_valid(_selected_tower):
		return

	if _selected_tower.try_upgrade():
		_refresh()
