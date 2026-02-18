extends Control

# NPC Relationships tab for PauseMenu. Shows friendship status, gift preference
# discovery, and conversation tracking for all met NPCs.
const UITokens = preload("res://scripts/ui/ui_tokens.gd")

const TIER_THRESHOLDS = {
	"hate": -60,
	"dislike": -20,
	"neutral": 20,
	"like": 60,
}

const TIER_COLORS = {
	"hate": UITokens.ACCENT_TOMATO,
	"dislike": Color("C27A40"),
	"neutral": UITokens.INK_PRIMARY,
	"like": UITokens.ACCENT_BASIL,
	"love": UITokens.ACCENT_HONEY,
}

var npc_list_container: VBoxContainer
var detail_panel: VBoxContainer
var split: HSplitContainer
var _selected_npc_id: String = ""

func _ready() -> void:
	UITheme.init()
	_build_ui()
	PlayerData.friendships_changed.connect(_refresh_list)

func _build_ui() -> void:
	split = HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.split_offset = UITheme.scaled(220)
	add_child(split)

	# Left: NPC list
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size.x = UITheme.scaled(200)
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left_scroll)

	npc_list_container = VBoxContainer.new()
	npc_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(npc_list_container)

	# Right: Detail panel
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)

	detail_panel = VBoxContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(detail_panel)

func activate() -> void:
	_refresh_list()

func deactivate() -> void:
	_selected_npc_id = ""

func _refresh_list() -> void:
	for child in npc_list_container.get_children():
		child.queue_free()

	DataRegistry.ensure_loaded()
	var friendships: Dictionary = PlayerData.npc_friendships

	if friendships.is_empty():
		var lbl := Label.new()
		lbl.text = "No NPCs met yet."
		UITheme.style_body(lbl)
		npc_list_container.add_child(lbl)
		_clear_detail()
		return

	# Title
	var title := Label.new()
	UITheme.style_section(title, "NPCs")
	npc_list_container.add_child(title)

	for npc_id in friendships:
		var fs: Dictionary = friendships[npc_id]
		var npc_def = DataRegistry.get_npc(npc_id)
		var display_name: String = npc_def.display_name if npc_def else npc_id
		var occupation: String = npc_def.occupation if npc_def and "occupation" in npc_def else ""
		var points: int = int(fs.get("points", 0))
		var tier: String = _get_tier(points)
		var talked: bool = fs.get("talked_today", false)

		var btn := Button.new()
		var talked_mark := " *" if talked else ""
		btn.text = display_name + " (" + str(points) + ")" + talked_mark
		btn.tooltip_text = occupation + " | " + tier.capitalize()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var is_selected: bool = npc_id == _selected_npc_id
		if is_selected:
			UITheme.style_button(btn, "primary")
		else:
			UITheme.style_button(btn, "secondary")

		# Color the text by tier
		btn.add_theme_color_override("font_color", TIER_COLORS.get(tier, UITokens.INK_PRIMARY))
		btn.add_theme_color_override("font_hover_color", TIER_COLORS.get(tier, UITokens.INK_PRIMARY))
		btn.pressed.connect(_on_npc_selected.bind(npc_id))
		npc_list_container.add_child(btn)

	# Refresh detail if one is selected
	if _selected_npc_id != "" and _selected_npc_id in friendships:
		_show_detail(_selected_npc_id)
	elif not friendships.is_empty():
		# Auto-select first NPC
		var first_id: String = friendships.keys()[0]
		_selected_npc_id = first_id
		_show_detail(first_id)
	else:
		_clear_detail()

func _on_npc_selected(npc_id: String) -> void:
	_selected_npc_id = npc_id
	_refresh_list()

func _clear_detail() -> void:
	for child in detail_panel.get_children():
		child.queue_free()

func _show_detail(npc_id: String) -> void:
	_clear_detail()

	DataRegistry.ensure_loaded()
	var friendships: Dictionary = PlayerData.npc_friendships
	if npc_id not in friendships:
		return
	var fs: Dictionary = friendships[npc_id]
	var npc_def = DataRegistry.get_npc(npc_id)
	var display_name: String = npc_def.display_name if npc_def else npc_id
	var occupation: String = npc_def.occupation if npc_def and "occupation" in npc_def else ""
	var points: int = int(fs.get("points", 0))
	var tier: String = _get_tier(points)
	var tier_color: Color = TIER_COLORS.get(tier, UITokens.INK_PRIMARY)

	# Header
	var header := Label.new()
	UITheme.style_title(header, display_name)
	detail_panel.add_child(header)

	if occupation != "":
		var occ_lbl := Label.new()
		UITheme.style_caption(occ_lbl, occupation)
		detail_panel.add_child(occ_lbl)

	# Friendship bar
	_add_separator()
	var tier_lbl := Label.new()
	UITheme.style_section(tier_lbl, tier.capitalize() + " (" + str(points) + ")")
	tier_lbl.add_theme_color_override("font_color", tier_color)
	detail_panel.add_child(tier_lbl)

	# Progress bar -100 to 100
	var bar := ProgressBar.new()
	bar.min_value = -100
	bar.max_value = 100
	bar.value = points
	bar.custom_minimum_size.y = UITheme.scaled(16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	# Style the bar fill color by tier
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = tier_color
	bar_style.set_corner_radius_all(UITokens.CORNER_RADIUS_SM)
	bar.add_theme_stylebox_override("fill", bar_style)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = UITokens.PAPER_EDGE
	bar_bg.set_corner_radius_all(UITokens.CORNER_RADIUS_SM)
	bar.add_theme_stylebox_override("background", bar_bg)
	detail_panel.add_child(bar)

	# Interaction status
	_add_separator()
	var talked_today: bool = fs.get("talked_today", false)
	var last_day: int = int(fs.get("last_interaction_day", 0))
	var talk_lbl := Label.new()
	if talked_today:
		UITheme.style_body_text(talk_lbl, "Talked today")
		talk_lbl.add_theme_color_override("font_color", UITokens.TEXT_SUCCESS)
	elif last_day > 0:
		UITheme.style_body_text(talk_lbl, "Last talked: Day " + str(last_day))
		talk_lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
	else:
		UITheme.style_body_text(talk_lbl, "Never talked")
		talk_lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
	detail_panel.add_child(talk_lbl)

	var gifted_today: bool = fs.get("gifted_today", false)
	var gift_status_lbl := Label.new()
	if gifted_today:
		UITheme.style_body_text(gift_status_lbl, "Already gifted today")
		gift_status_lbl.add_theme_color_override("font_color", UITokens.TEXT_WARNING)
	else:
		UITheme.style_body_text(gift_status_lbl, "Gift available")
		gift_status_lbl.add_theme_color_override("font_color", UITokens.TEXT_SUCCESS)
	detail_panel.add_child(gift_status_lbl)

	# Gift Preferences (progressive discovery)
	_add_separator()
	var pref_title := Label.new()
	UITheme.style_section(pref_title, "Gift Preferences")
	detail_panel.add_child(pref_title)

	var gift_history: Dictionary = fs.get("gift_history", {})
	var categories := ["loved", "liked", "disliked", "hated"]
	var category_colors := {
		"loved": TIER_COLORS["love"],
		"liked": TIER_COLORS["like"],
		"disliked": TIER_COLORS["dislike"],
		"hated": TIER_COLORS["hate"],
	}

	for cat in categories:
		var cat_label := Label.new()
		UITheme.style_body_text(cat_label, cat.capitalize() + ":")
		cat_label.add_theme_color_override("font_color", category_colors.get(cat, UITokens.INK_PRIMARY))
		detail_panel.add_child(cat_label)

		# Find items in gift_history matching this category
		var items_in_cat: Array = []
		for item_id in gift_history:
			if str(gift_history[item_id]) == cat:
				var info = DataRegistry.get_item_display_info(str(item_id))
				items_in_cat.append(info.get("display_name", str(item_id)))

		var items_lbl := Label.new()
		items_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		items_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if items_in_cat.is_empty():
			UITheme.style_caption(items_lbl, "  None discovered yet")
		else:
			UITheme.style_caption(items_lbl, "  " + ", ".join(items_in_cat))
		detail_panel.add_child(items_lbl)

func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", UITheme.scaled(8))
	detail_panel.add_child(sep)

static func _get_tier(points: int) -> String:
	if points < TIER_THRESHOLDS["hate"]:
		return "hate"
	elif points < TIER_THRESHOLDS["dislike"]:
		return "dislike"
	elif points < TIER_THRESHOLDS["neutral"]:
		return "neutral"
	elif points < TIER_THRESHOLDS["like"]:
		return "like"
	else:
		return "love"
