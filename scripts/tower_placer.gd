extends Node2D

## Fluxo: jogador clica num ícone de torre (canto superior direito) -> entra
## em "modo colocação" -> um preview (tile + alcance) segue o mouse -> clique
## esquerdo no mapa instancia a torre ali (se tiver ouro e o tile tiver livre).
## Clique direito ou Esc cancela a colocação.

@export var tower_options: Array[TowerData] = []
@export var tile_map: TileMapLayer  # arraste o TileMapLayer do mapa aqui (usado só pra converter espaço local/global)
@export var path: Path2D  # arraste o Path2D dos inimigos aqui — usado pra bloquear construção em cima do caminho
@export var placement_cell_size: Vector2i = Vector2i(64, 64)  # tamanho do "slot" de construção — independente do tile_size do mapa

const BUTTON_SIZE := 56
const DEFAULT_TOWER_DATA_PATHS: Array[String] = [
	"res://resources/tower_data_basic.tres",
	"res://resources/tower_data_poison.tres",
	"res://resources/tower_data_flame.tres",
	"res://resources/tower_data_ice.tres",
]
const PATH_SAMPLE_STEP := 8.0  # distância entre amostras ao percorrer a curva — bem menor que a célula, pra não pular nenhuma

var _occupied_tiles: Dictionary = {}  # Vector2i -> true (torres já colocadas)
var _path_tiles: Dictionary = {}      # Vector2i -> true (células que o caminho atravessa)

var _selected_tower: TowerData = null
var _selected_cost: int = 0
var _selected_range: float = 0.0

var _preview: TowerPlacementPreview
var _ui_layer: CanvasLayer


func _ready() -> void:
	if tower_options.is_empty():
		for tower_data_path in DEFAULT_TOWER_DATA_PATHS:
			var default_data: TowerData = load(tower_data_path)
			if default_data:
				tower_options.append(default_data)

	_mark_path_tiles()
	_build_ui()
	_build_preview()


# Percorre a curva do Path2D de ponta a ponta e marca toda célula da grade
# de construção por onde ela passa, pra não deixar torre em cima do caminho.
func _mark_path_tiles() -> void:
	if not path or not path.curve:
		return

	var curve := path.curve
	var length := curve.get_baked_length()
	var distance := 0.0

	while distance <= length:
		var world_point := path.to_global(curve.sample_baked(distance))
		_path_tiles[_world_to_tile(world_point)] = true
		distance += PATH_SAMPLE_STEP

	# garante que o ponto final também seja marcado (o loop pode parar antes dele)
	var end_point := path.to_global(curve.sample_baked(length))
	_path_tiles[_world_to_tile(end_point)] = true


func _is_tile_buildable(tile_coord: Vector2i) -> bool:
	return not _occupied_tiles.has(tile_coord) and not _path_tiles.has(tile_coord)


# ==== UI (ícones de torre no canto superior direito) ====
func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)

	var container := HBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	container.offset_top = 12
	container.offset_right = -12
	container.add_theme_constant_override("separation", 8)
	_ui_layer.add_child(container)

	for data in tower_options:
		container.add_child(_create_tower_slot(data))


func _create_tower_slot(data: TowerData) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 2)
	slot.alignment = BoxContainer.ALIGNMENT_CENTER

	slot.add_child(_create_tower_button(data))
	slot.add_child(_create_price_label(data))

	return slot


func _create_tower_button(data: TowerData) -> TextureButton:
	var button := TextureButton.new()
	button.texture_normal = data.icon
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.tooltip_text = data.display_name
	button.pressed.connect(_on_tower_button_pressed.bind(data))
	return button


func _create_price_label(data: TowerData) -> Label:
	# instancia só pra ler o cost da torre real (fonte única da verdade
	# fica no script da torre, não duplicada aqui)
	var temp: Node = data.scene.instantiate()
	var cost: int = temp.cost if "cost" in temp else 0
	temp.free()

	var label := Label.new()
	label.text = "%d" % cost
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	return label


func _on_tower_button_pressed(data: TowerData) -> void:
	if _selected_tower == data:
		_cancel_placement()
		return

	# instancia só pra ler cost/attack_range da torre real (fonte única da
	# verdade fica no script da torre, não duplicada aqui)
	var temp: Node = data.scene.instantiate()
	_selected_cost = temp.cost if "cost" in temp else 0
	_selected_range = temp.attack_range if "attack_range" in temp else 0.0
	temp.free()

	_selected_tower = data
	_preview.range_radius = _selected_range
	_preview.visible = true
	_update_preview_position()


func _cancel_placement() -> void:
	_selected_tower = null
	_preview.visible = false


# ==== Preview (tile highlight + alcance seguindo o mouse) ====
func _build_preview() -> void:
	_preview = TowerPlacementPreview.new()
	_preview.tile_size = Vector2(placement_cell_size)
	_preview.visible = false
	add_child(_preview)


func _update_preview_position() -> void:
	var tile_coord := _world_to_tile(get_global_mouse_position())
	_preview.global_position = _tile_to_world_center(tile_coord)
	_preview.is_valid = _is_tile_buildable(tile_coord)


# ==== Input ====
func _unhandled_input(event: InputEvent) -> void:
	if _selected_tower == null:
		return

	if event is InputEventMouseMotion:
		_update_preview_position()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_placement()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_tower()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placement()


func _try_place_tower() -> void:
	var tile_coord := _world_to_tile(get_global_mouse_position())

	if not _is_tile_buildable(tile_coord):
		return  # já tem torre aqui ou é o caminho dos inimigos

	if not Game.spend_gold(_selected_cost):
		return  # ouro insuficiente

	var tower: Node2D = _selected_tower.scene.instantiate()
	get_tree().current_scene.add_child(tower)
	tower.global_position = _tile_to_world_center(tile_coord)

	_occupied_tiles[tile_coord] = true
	_cancel_placement()


# ==== Conversão mundo <-> grid de construção (independente do TileSet) ====
func _world_to_tile(world_pos: Vector2) -> Vector2i:
	var local_pos := tile_map.to_local(world_pos) if tile_map else world_pos
	return Vector2i(
		floori(local_pos.x / placement_cell_size.x),
		floori(local_pos.y / placement_cell_size.y)
	)


func _tile_to_world_center(tile_coord: Vector2i) -> Vector2:
	var local_pos := Vector2(
		tile_coord.x * placement_cell_size.x + placement_cell_size.x / 2.0,
		tile_coord.y * placement_cell_size.y + placement_cell_size.y / 2.0
	)
	return tile_map.to_global(local_pos) if tile_map else local_pos
