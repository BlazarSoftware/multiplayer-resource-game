extends CanvasLayer

@onready var season_label: Label = $TopBar/SeasonLabel
@onready var day_label: Label = $TopBar/DayLabel
@onready var tool_label: Label = $ToolBar/ToolLabel
@onready var water_label: Label = $ToolBar/WaterLabel
@onready var grass_indicator: ColorRect = $GrassIndicator
@onready var grass_hint_label: Label = $GrassHintLabel
@onready var battle_transition: ColorRect = $BattleTransition

var money_label: Label = null
var buff_label: Label = null

func _ready() -> void:
	PlayerData.tool_changed.connect(_on_tool_changed)
	# Create money label dynamically
	money_label = Label.new()
	money_label.text = "$0"
	money_label.add_theme_font_size_override("font_size", 16)
	var top_bar = get_node_or_null("TopBar")
	if top_bar:
		top_bar.add_child(money_label)
	# Create buff indicator label
	buff_label = Label.new()
	buff_label.text = ""
	buff_label.add_theme_font_size_override("font_size", 14)
	buff_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	if top_bar:
		top_bar.add_child(buff_label)

func _process(_delta: float) -> void:
	water_label.text = "Water: %d/%d" % [PlayerData.watering_can_current, PlayerData.get_watering_can_capacity()]
	var season_mgr = get_node_or_null("/root/Main/GameWorld/SeasonManager")
	if season_mgr:
		season_label.text = "Season: %s" % season_mgr.get_season_name().capitalize()
		day_label.text = "Day %d" % season_mgr.day_count
	if money_label:
		money_label.text = "$%d" % PlayerData.money
	# Update buff display
	if buff_label:
		var buff_text = ""
		var now = Time.get_unix_time_from_system()
		for buff in PlayerData.active_buffs:
			var remaining = float(buff.get("expires_at", 0)) - now
			if remaining > 0:
				var btype = buff.get("buff_type", "")
				var bval = buff.get("buff_value", 0.0)
				var mins = int(remaining / 60.0)
				var secs = int(remaining) % 60
				match btype:
					"speed_boost":
						buff_text += "SPD x%.1f %d:%02d  " % [bval, mins, secs]
					"xp_multiplier":
						buff_text += "XP x%.1f %d:%02d  " % [bval, mins, secs]
					"encounter_rate":
						buff_text += "ENC x%.1f %d:%02d  " % [bval, mins, secs]
		buff_label.text = buff_text

func _on_tool_changed(tool_slot: String) -> void:
	if tool_slot == "" or tool_slot == "seeds":
		tool_label.text = "Tool: %s" % ("Hands" if tool_slot == "" else "Seeds")
	else:
		var display = PlayerData.get_tool_display_name(tool_slot)
		tool_label.text = "Tool: %s" % display

func show_grass_indicator(visible_state: bool) -> void:
	grass_indicator.visible = visible_state
	grass_hint_label.visible = visible_state

func play_battle_transition() -> void:
	battle_transition.visible = true
	battle_transition.color.a = 0.0
	var tween = create_tween()
	tween.tween_property(battle_transition, "color:a", 1.0, 0.3)
	await tween.finished

func clear_battle_transition() -> void:
	if not battle_transition.visible:
		return
	var tween = create_tween()
	tween.tween_property(battle_transition, "color:a", 0.0, 0.3)
	await tween.finished
	battle_transition.visible = false
