class_name ToolDef
extends Resource

@export var tool_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var tool_type: String = "" # hoe, axe, watering_can
@export var tier: int = 0 # 0=basic, 1=bronze, 2=iron, 3=gold
@export var icon_color: Color = Color.WHITE
@export var effectiveness: Dictionary = {} # e.g. {"capacity": 15} or {"speed_mult": 1.3}
