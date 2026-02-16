extends CanvasLayer

var npc_name_label: Label = null
var friendship_label: Label = null
var friendship_bar: ProgressBar = null
var dialogue_text: RichTextLabel = null
var choices_container: VBoxContainer = null
var action_container: HBoxContainer = null
var give_gift_button: Button = null
var close_button: Button = null

# Gift panel
var gift_panel: PanelContainer = null
var gift_list: VBoxContainer = null
var gift_back_button: Button = null

var current_npc_id: String = ""
var current_friendship: int = 0
var current_tier: String = "neutral"
var showing_gift_panel: bool = false

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.anchors_preset = Control.PRESET_CENTER
	panel.custom_minimum_size = Vector2(550, 350)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	# NPC name
	npc_name_label = Label.new()
	npc_name_label.text = "NPC Name"
	npc_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(npc_name_label)

	# Friendship bar
	var friend_row = HBoxContainer.new()
	vbox.add_child(friend_row)

	friendship_label = Label.new()
	friendship_label.text = "Neutral (0)"
	friendship_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friend_row.add_child(friendship_label)

	friendship_bar = ProgressBar.new()
	friendship_bar.min_value = -100
	friendship_bar.max_value = 100
	friendship_bar.value = 0
	friendship_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friendship_bar.custom_minimum_size.x = 200
	friendship_bar.show_percentage = false
	friend_row.add_child(friendship_bar)

	# Dialogue text
	dialogue_text = RichTextLabel.new()
	dialogue_text.bbcode_enabled = true
	dialogue_text.fit_content = true
	dialogue_text.custom_minimum_size.y = 80
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(dialogue_text)

	# Choices container
	choices_container = VBoxContainer.new()
	vbox.add_child(choices_container)

	# Action buttons (Give Gift + Close)
	action_container = HBoxContainer.new()
	action_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(action_container)

	give_gift_button = Button.new()
	give_gift_button.text = "Give Gift"
	give_gift_button.pressed.connect(_show_gift_panel)
	action_container.add_child(give_gift_button)

	close_button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close)
	action_container.add_child(close_button)

	# Gift selection panel (hidden by default)
	gift_panel = PanelContainer.new()
	gift_panel.name = "GiftPanel"
	gift_panel.anchors_preset = Control.PRESET_CENTER
	gift_panel.custom_minimum_size = Vector2(400, 300)
	gift_panel.visible = false
	add_child(gift_panel)

	var gift_margin = MarginContainer.new()
	gift_margin.add_theme_constant_override("margin_left", 10)
	gift_margin.add_theme_constant_override("margin_right", 10)
	gift_margin.add_theme_constant_override("margin_top", 10)
	gift_margin.add_theme_constant_override("margin_bottom", 10)
	gift_panel.add_child(gift_margin)

	var gift_vbox = VBoxContainer.new()
	gift_margin.add_child(gift_vbox)

	var gift_title = Label.new()
	gift_title.text = "Select a Gift"
	gift_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gift_title.add_theme_font_size_override("font_size", 18)
	gift_vbox.add_child(gift_title)

	var gift_scroll = ScrollContainer.new()
	gift_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gift_scroll.custom_minimum_size.y = 200
	gift_vbox.add_child(gift_scroll)

	gift_list = VBoxContainer.new()
	gift_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift_scroll.add_child(gift_list)

	gift_back_button = Button.new()
	gift_back_button.text = "Back"
	gift_back_button.pressed.connect(_hide_gift_panel)
	gift_vbox.add_child(gift_back_button)

# === Public methods called by SocialManager RPCs ===

func show_dialogue(npc_id: String, text: String, choices: Array, friendship_points: int, tier: String) -> void:
	current_npc_id = npc_id
	current_friendship = friendship_points
	current_tier = tier
	showing_gift_panel = false

	DataRegistry.ensure_loaded()
	var npc_def = DataRegistry.get_npc(npc_id)
	npc_name_label.text = npc_def.display_name if npc_def else npc_id

	_update_friendship_display(friendship_points, tier)
	dialogue_text.text = text

	# Build choice buttons
	_clear_choices()
	if choices.size() > 0:
		for i in range(choices.size()):
			var btn = Button.new()
			btn.text = choices[i]
			var idx = i
			btn.pressed.connect(_on_choice_pressed.bind(idx))
			choices_container.add_child(btn)
		action_container.visible = false
	else:
		# Simple dialogue — just show Continue + action buttons
		var continue_btn = Button.new()
		continue_btn.text = "Continue"
		continue_btn.pressed.connect(_on_continue)
		choices_container.add_child(continue_btn)
		action_container.visible = false

	gift_panel.visible = false
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkManager.request_set_busy.rpc_id(1, true)

func show_choice_result(response: String, new_points: int, new_tier: String) -> void:
	current_friendship = new_points
	current_tier = new_tier
	dialogue_text.text = response
	_update_friendship_display(new_points, new_tier)

	# Show action buttons after choice result
	_clear_choices()
	action_container.visible = true

func show_gift_response(message: String, points_change: int) -> void:
	dialogue_text.text = message
	if points_change > 0:
		dialogue_text.text += "\n[color=green](+" + str(points_change) + " friendship)[/color]"
	elif points_change < 0:
		dialogue_text.text += "\n[color=red](" + str(points_change) + " friendship)[/color]"

	# Update from synced PlayerData
	var fs = PlayerData.npc_friendships.get(current_npc_id, {})
	var pts: int = int(fs.get("points", current_friendship))
	_update_friendship_display(pts, _get_friendship_tier(pts))

	_hide_gift_panel()

# === Internal ===

func _update_friendship_display(points: int, tier: String) -> void:
	var tier_colors = {
		"hate": Color.RED,
		"dislike": Color.ORANGE,
		"neutral": Color.WHITE,
		"like": Color.GREEN,
		"love": Color.GOLD,
	}
	var color: Color = tier_colors.get(tier, Color.WHITE)
	friendship_label.text = tier.capitalize() + " (" + str(points) + ")"
	friendship_label.modulate = color
	friendship_bar.value = points

func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()

func _on_choice_pressed(idx: int) -> void:
	# Disable all choice buttons while waiting
	for child in choices_container.get_children():
		if child is Button:
			child.disabled = true
	# Send choice to server
	var social_mgr = get_node_or_null("/root/Main/GameWorld/SocialManager")
	if social_mgr:
		social_mgr.request_dialogue_choice.rpc_id(1, idx)

func _on_continue() -> void:
	_clear_choices()
	action_container.visible = true

func _show_gift_panel() -> void:
	showing_gift_panel = true
	gift_panel.visible = true
	_populate_gift_list()

func _hide_gift_panel() -> void:
	showing_gift_panel = false
	gift_panel.visible = false

func _populate_gift_list() -> void:
	for child in gift_list.get_children():
		child.queue_free()

	# Get NPC gift preferences for color coding
	DataRegistry.ensure_loaded()
	var npc_def = DataRegistry.get_npc(current_npc_id)

	for item_id in PlayerData.inventory:
		var count: int = PlayerData.inventory[item_id]
		if count <= 0:
			continue
		# Skip tools from gift list
		var info = DataRegistry.get_item_display_info(item_id)
		if info.get("category", "") == "tool":
			continue

		var btn = Button.new()
		var display_name: String = info.get("display_name", item_id)
		var gift_tier: String = "neutral"
		if npc_def:
			gift_tier = _get_npc_gift_tier(npc_def, item_id)

		var tier_indicator = ""
		match gift_tier:
			"loved":
				tier_indicator = " [color=gold]★★★[/color]"
			"liked":
				tier_indicator = " [color=green]★★[/color]"
			"disliked":
				tier_indicator = " [color=orange]✗[/color]"
			"hated":
				tier_indicator = " [color=red]✗✗[/color]"

		# Use plain text for button (RichTextLabel doesn't work well in buttons)
		var tier_plain = ""
		match gift_tier:
			"loved":
				tier_plain = " ★★★"
			"liked":
				tier_plain = " ★★"
			"disliked":
				tier_plain = " ✗"
			"hated":
				tier_plain = " ✗✗"

		btn.text = display_name + " (x" + str(count) + ")" + tier_plain
		var captured_id = item_id
		btn.pressed.connect(_give_gift.bind(captured_id))

		# Color the button based on tier
		match gift_tier:
			"loved":
				btn.modulate = Color.GOLD
			"liked":
				btn.modulate = Color.GREEN_YELLOW
			"disliked":
				btn.modulate = Color.ORANGE
			"hated":
				btn.modulate = Color.INDIAN_RED

		gift_list.add_child(btn)

	if gift_list.get_child_count() == 0:
		var empty_label = Label.new()
		empty_label.text = "No items to give"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gift_list.add_child(empty_label)

func _give_gift(item_id: String) -> void:
	# Find the nearest social NPC and send gift RPC
	var social_npcs = get_tree().get_nodes_in_group("social_npc")
	for npc in social_npcs:
		if npc.has_method("request_give_gift") and "npc_id" in npc and npc.npc_id == current_npc_id:
			npc.request_give_gift.rpc_id(1, item_id)
			break
	_hide_gift_panel()

func _get_friendship_tier(points: int) -> String:
	if points < -60:
		return "hate"
	elif points < -20:
		return "dislike"
	elif points < 20:
		return "neutral"
	elif points < 60:
		return "like"
	else:
		return "love"

func _get_npc_gift_tier(npc_def: Resource, item_id: String) -> String:
	var prefs: Dictionary = npc_def.gift_preferences
	if item_id in prefs.get("loved", []):
		return "loved"
	elif item_id in prefs.get("liked", []):
		return "liked"
	elif item_id in prefs.get("disliked", []):
		return "disliked"
	elif item_id in prefs.get("hated", []):
		return "hated"
	return "neutral"

func _close() -> void:
	visible = false
	gift_panel.visible = false
	showing_gift_panel = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	NetworkManager.request_set_busy.rpc_id(1, false)
	# Cancel any pending dialogue on server
	var social_mgr = get_node_or_null("/root/Main/GameWorld/SocialManager")
	if social_mgr:
		social_mgr.cancel_dialogue.rpc_id(1)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
