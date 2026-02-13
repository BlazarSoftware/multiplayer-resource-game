class_name AbilityDef
extends Resource

@export var ability_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var trigger: String = "" # on_enter, on_attack, on_defend, on_status, end_of_turn, on_weather, passive
@export var effect: Dictionary = {} # trigger-specific params
