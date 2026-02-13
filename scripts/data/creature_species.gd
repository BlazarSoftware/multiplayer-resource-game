class_name CreatureSpecies
extends Resource

@export var species_id: String = ""
@export var display_name: String = ""
@export var types: PackedStringArray = [] # spicy, sweet, sour, herbal, umami, grain
@export var base_hp: int = 40
@export var base_attack: int = 10
@export var base_defense: int = 10
@export var base_sp_attack: int = 10
@export var base_sp_defense: int = 10
@export var base_speed: int = 10
@export var moves: PackedStringArray = [] # 4 move IDs
@export var mesh_type: String = "capsule" # capsule, sphere, box, cylinder
@export var mesh_color: Color = Color.WHITE
@export var mesh_scale: Vector3 = Vector3.ONE
@export var rarity: String = "common" # common, uncommon, rare
@export var drop_ingredient_ids: PackedStringArray = []
@export var drop_min: int = 1
@export var drop_max: int = 2
