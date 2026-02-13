extends CanvasLayer

@onready var season_label: Label = $TopBar/SeasonLabel
@onready var day_label: Label = $TopBar/DayLabel
@onready var tool_label: Label = $ToolBar/ToolLabel
@onready var water_label: Label = $ToolBar/WaterLabel
@onready var grass_indicator: ColorRect = $GrassIndicator
@onready var grass_hint_label: Label = $GrassHintLabel
@onready var battle_transition: ColorRect = $BattleTransition

func _ready() -> void:
	PlayerData.tool_changed.connect(_on_tool_changed)

func _process(_delta: float) -> void:
	water_label.text = "Water: %d/%d" % [PlayerData.watering_can_current, PlayerData.watering_can_capacity]
	var season_mgr = get_node_or_null("/root/Main/GameWorld/SeasonManager")
	if season_mgr:
		season_label.text = "Season: %s" % season_mgr.get_season_name().capitalize()
		day_label.text = "Day %d" % season_mgr.day_count

func _on_tool_changed(tool_name: String) -> void:
	tool_label.text = "Tool: %s" % tool_name.capitalize()

func show_grass_indicator(show: bool) -> void:
	grass_indicator.visible = show
	grass_hint_label.visible = show

func play_battle_transition() -> void:
	battle_transition.visible = true
	var tween = create_tween()
	tween.tween_property(battle_transition, "color:a", 1.0, 0.3)
	tween.tween_callback(func(): battle_transition.visible = false; battle_transition.color.a = 0)
