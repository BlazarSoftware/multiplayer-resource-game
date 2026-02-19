class_name BattleItemDef
extends Resource

@export var item_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_color: Color = Color.WHITE
@export var icon_texture: Texture2D
@export var effect_type: String = "" # "heal_hp", "cure_status", "restore_pp", "revive"
@export var effect_value: int = 0 # HP amount, PP amount, % for revive
@export var target: String = "single" # "single" or "all"
@export var sell_price: int = 0
