extends CanvasLayer

@onready var season_label: Label = $TopBar/SeasonLabel
@onready var day_label: Label = $TopBar/DayLabel
@onready var tool_label: Label = $ToolBar/ToolLabel
@onready var water_label: Label = $ToolBar/WaterLabel
@onready var grass_indicator: ColorRect = $GrassIndicator
@onready var grass_hint_label: Label = $GrassHintLabel
@onready var battle_transition: ColorRect = $BattleTransition

var money_label: Label = null

func _ready() -> void:
	PlayerData.tool_changed.connect(_on_tool_changed)
	# Create money label dynamically
	money_label = Label.new()
	money_label.text = "$0"
	money_label.add_theme_font_size_override("font_size", 16)
	var top_bar = get_node_or_null("TopBar")
	if top_bar:
		top_bar.add_child(money_label)

func _process(_delta: float) -> void:
	water_label.text = "Water: %d/%d" % [PlayerData.watering_can_current, PlayerData.watering_can_capacity]
	var season_mgr = get_node_or_null("/root/Main/GameWorld/SeasonManager")
	if season_mgr:
		season_label.text = "Season: %s" % season_mgr.get_season_name().capitalize()
		day_label.text = "Day %d" % season_mgr.day_count
	if money_label:
		money_label.text = "$%d" % PlayerData.money

func _on_tool_changed(tool_name: String) -> void:
	tool_label.text = "Tool: %s" % tool_name.capitalize()

func show_grass_indicator(visible_state: bool) -> void:
	grass_indicator.visible = visible_state
	grass_hint_label.visible = visible_state

func play_battle_transition() -> void:
	battle_transition.visible = true
	var tween = create_tween()
	tween.tween_property(battle_transition, "color:a", 1.0, 0.3)
	tween.tween_callback(func(): battle_transition.visible = false; battle_transition.color.a = 0)
