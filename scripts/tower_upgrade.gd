extends Resource
class_name TowerUpgrade

## Um nível de upgrade de uma torre. Crie um .tres desses por nível
## (ex: tower_basic_upgrade_1.tres, tower_basic_upgrade_2.tres...) e
## coloque no array "Upgrade Levels" da torre (ou na lista de caminhos
## padrão em default_upgrade_paths do Tower.gd).

@export var cost: int = 50
@export var damage: int = 5
@export var attack_range: float = 150.0
@export var attack_speed: float = 1.0        # ataques por segundo
@export var projectile_speed: float = 400.0  # velocidade do projétil dessa torre

## Texto livre pra descrever efeitos especiais (DOT, etc), mostrado no
## painel de informação da torre. Ex: "Veneno: 2 dano/tick por 3s".
@export var effects_description: String = ""

## Sobrescreve QUALQUER propriedade exportada do projétil dessa torre ao
## disparar (ex: {"poison_damage_per_tick": 2}). Use isso pra fortalecer
## efeitos específicos (veneno, queimadura...) que não são genéricos o
## bastante pra virar um campo próprio aqui.
@export var projectile_overrides: Dictionary = {}

## Opcional: sprites do upgrade (você falou que já tem os seus — é só
## arrastar aqui, em cada nível de upgrade que quiser trocar visual).
@export var turret_sprite_frames: SpriteFrames
@export var base_sprite_texture: Texture2D
