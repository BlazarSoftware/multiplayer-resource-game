extends Control

# Inventory tab content for PauseMenu. Card grid with detail panel + action buttons.
const UITokens = preload("res://scripts/ui/ui_tokens.gd")

var tab_bar: TabBar
var card_grid: GridContainer
var detail_panel: VBoxContainer
var seed_label: Label
var content_scroll: ScrollContainer
var detail_scroll: ScrollContainer
var current_tab: int = 0
var _selected_item_id: String = ""

const TAB_NAMES = ["All", "Seeds", "Ingredients", "Held Items", "Food", "Tools", "Scrolls", "Battle Items"]
const TAB_CATEGORIES = ["all", "seed", "ingredient", "held_item", "food", "tool", "recipe_scroll", "battle_item"]

func _ready() -> void:
	UITheme.init()
	_build_ui()
	PlayerData.inventory_changed.connect(_refresh)

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# Tab bar
	tab_bar = TabBar.new()
	for tab_name in TAB_NAMES:
		tab_bar.add_tab(tab_name)
	tab_bar.tab_changed.connect(_on_tab_changed)
	vbox.add_child(tab_bar)

	# HSplit: card grid (left) + detail panel (right)
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hsplit)

	# Left: scrollable card grid
	content_scroll = ScrollContainer.new()
	content_scroll.custom_minimum_size = Vector2(380, 0)
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(content_scroll)

	card_grid = GridContainer.new()
	card_grid.columns = 4
	card_grid.add_theme_constant_override("h_separation", 8)
	card_grid.add_theme_constant_override("v_separation", 8)
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(card_grid)

	# Right: detail panel
	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(detail_scroll)

	detail_panel = VBoxContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_panel)

	# Selected seed display
	var seed_row := HBoxContainer.new()
	vbox.add_child(seed_row)
	seed_label = Label.new()
	seed_label.text = "Selected Seed: None"
	UITheme.style_small(seed_label)
	seed_row.add_child(seed_label)

func _on_tab_changed(tab_idx: int) -> void:
	current_tab = tab_idx
	_selected_item_id = ""
	_refresh()

func activate() -> void:
	_refresh()

func deactivate() -> void:
	pass

func _refresh() -> void:
	_clear_children(card_grid)
	_clear_children(detail_panel)
	DataRegistry.ensure_loaded()
	var filter_category = TAB_CATEGORIES[current_tab] if current_tab < TAB_CATEGORIES.size() else "all"

	for item_id in PlayerData.inventory:
		var count = PlayerData.inventory[item_id]
		if count <= 0:
			continue
		var info = DataRegistry.get_item_display_info(item_id)
		var is_seed_item = _is_seed_item(item_id)
		if filter_category != "all":
			var cat = info.get("category", "unknown")
			if filter_category == "seed":
				if not is_seed_item:
					continue
			elif filter_category == "ingredient":
				if cat != "ingredient" or is_seed_item:
					continue
			elif filter_category == "recipe_scroll" and cat == "fragment":
				pass
			elif cat != filter_category:
				continue

		var card := _build_item_card(item_id, info, count)
		card_grid.add_child(card)

	# Restore selection
	if _selected_item_id != "" and _selected_item_id in PlayerData.inventory and PlayerData.inventory[_selected_item_id] > 0:
		_show_item_detail(_selected_item_id)

	_update_seed_label()

func _build_item_card(item_id: String, info: Dictionary, count: int) -> PanelContainer:
	var card := PanelContainer.new()
	var card_w := UITheme.scaled(88)
	var card_h := UITheme.scaled(100)
	card.custom_minimum_size = Vector2(card_w, card_h)

	var style := StyleBoxFlat.new()
	style.bg_color = UITokens.PAPER_CARD
	style.border_color = UITokens.ACCENT_CHESTNUT
	style.set_corner_radius_all(UITokens.CORNER_RADIUS)
	style.set_border_width_all(1)
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# Icon
	var icon := UITheme.create_item_icon(info, 32)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = info.get("display_name", item_id)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_caption(name_lbl)
	name_lbl.add_theme_font_size_override("font_size", UITheme.scaled(UITokens.FONT_TINY))
	vbox.add_child(name_lbl)

	# Quantity badge
	var qty_lbl := Label.new()
	qty_lbl.text = "x%d" % count
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_caption(qty_lbl)
	qty_lbl.add_theme_font_size_override("font_size", UITheme.scaled(UITokens.FONT_TINY))
	qty_lbl.add_theme_color_override("font_color", UITokens.INK_SECONDARY)
	vbox.add_child(qty_lbl)

	# Click overlay
	var btn := Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var sid = item_id
	btn.pressed.connect(func(): _show_item_detail(sid))
	card.add_child(btn)

	return card

func _show_item_detail(item_id: String) -> void:
	_selected_item_id = item_id
	_clear_children(detail_panel)

	DataRegistry.ensure_loaded()
	var info = DataRegistry.get_item_display_info(item_id)
	var count = PlayerData.inventory.get(item_id, 0)

	# Large icon
	var detail_icon := UITheme.create_item_icon(info, 64)
	detail_panel.add_child(detail_icon)

	# Name
	var name_label := Label.new()
	name_label.text = info.get("display_name", item_id)
	UITheme.style_heading(name_label)
	name_label.add_theme_font_size_override("font_size", UITheme.scaled(UITokens.FONT_BODY))
	name_label.add_theme_color_override("font_color", info.get("icon_color", UITokens.INK_DARK))
	detail_panel.add_child(name_label)

	# Category
	var cat_label := Label.new()
	var category: String = info.get("category", "unknown")
	cat_label.text = "Category: " + category.replace("_", " ").capitalize()
	UITheme.style_small(cat_label)
	cat_label.add_theme_color_override("font_color", UITokens.INK_MEDIUM)
	detail_panel.add_child(cat_label)

	# Quantity
	var qty_label := Label.new()
	qty_label.text = "Owned: x%d" % count
	UITheme.style_small(qty_label)
	detail_panel.add_child(qty_label)

	# Sell price
	var sell_price = DataRegistry.get_sell_price(item_id)
	if sell_price > 0:
		var price_label := Label.new()
		price_label.text = "Sell Price: $%d" % sell_price
		UITheme.style_small(price_label)
		detail_panel.add_child(price_label)

	# Separator before actions
	var sep := HSeparator.new()
	detail_panel.add_child(sep)

	# Context-dependent action buttons
	var is_seed_item = _is_seed_item(item_id)
	match category:
		"ingredient":
			if is_seed_item:
				var seed_btn := Button.new()
				seed_btn.text = "Select Seed"
				UITheme.style_button(seed_btn, "primary")
				var sid = item_id
				seed_btn.pressed.connect(func(): _select_seed(sid))
				detail_panel.add_child(seed_btn)
				_add_hotbar_button(item_id, "seed")
		"food":
			var food = DataRegistry.get_food(item_id)
			if food:
				if food.buff_type != "" and food.buff_type != "none":
					var eat_btn := Button.new()
					eat_btn.text = "Eat"
					UITheme.style_button(eat_btn, "primary")
					var fid = item_id
					eat_btn.pressed.connect(func(): _use_food(fid))
					detail_panel.add_child(eat_btn)
				if food.sell_price > 0:
					var sell_btn := Button.new()
					sell_btn.text = "Sell ($%d)" % food.sell_price
					UITheme.style_button(sell_btn, "secondary")
					var sid = item_id
					sell_btn.pressed.connect(func(): _sell_item(sid))
					detail_panel.add_child(sell_btn)
				_add_hotbar_button(item_id, "food")
		"recipe_scroll":
			var use_btn := Button.new()
			use_btn.text = "Use"
			UITheme.style_button(use_btn, "primary")
			var sid = item_id
			use_btn.pressed.connect(func(): _use_scroll(sid))
			detail_panel.add_child(use_btn)
		"battle_item":
			_add_hotbar_button(item_id, "battle_item")
		"tool":
			var tool_def = DataRegistry.get_tool(item_id)
			if tool_def:
				var equipped_id = PlayerData.equipped_tools.get(tool_def.tool_type, "")
				if equipped_id != item_id:
					var equip_btn := Button.new()
					equip_btn.text = "Equip"
					UITheme.style_button(equip_btn, "primary")
					var tid = item_id
					equip_btn.pressed.connect(func(): _equip_tool(tid))
					detail_panel.add_child(equip_btn)
				else:
					var lbl := Label.new()
					lbl.text = "[Equipped]"
					UITheme.style_small(lbl)
					lbl.add_theme_color_override("font_color", UITokens.TEXT_SUCCESS)
					detail_panel.add_child(lbl)
				_add_hotbar_button(tool_def.tool_type, "tool_slot")

func _add_hotbar_button(item_id: String, item_type: String) -> void:
	var hb_btn := Button.new()
	hb_btn.text = "Hotbar"
	UITheme.style_button(hb_btn, "secondary")
	var hb_id = item_id
	var hb_type = item_type
	hb_btn.pressed.connect(func(): _show_hotbar_assign(hb_id, hb_type))
	detail_panel.add_child(hb_btn)

func _update_seed_label() -> void:
	if PlayerData.selected_seed_id != "":
		var ingredient = DataRegistry.get_ingredient(PlayerData.selected_seed_id)
		seed_label.text = "Selected Seed: %s" % (ingredient.display_name if ingredient else PlayerData.selected_seed_id)
	else:
		seed_label.text = "Selected Seed: None"

func _is_seed_item(item_id: String) -> bool:
	var ingredient = DataRegistry.get_ingredient(item_id)
	if ingredient == null:
		return false
	if ingredient.category == "farm_crop":
		return true
	if item_id.ends_with("_seed"):
		return true
	return ingredient.display_name.to_lower().ends_with(" seed")

func _select_seed(seed_id: String) -> void:
	PlayerData.selected_seed_id = seed_id
	PlayerData.set_tool("seeds")
	_refresh()

func _use_food(food_id: String) -> void:
	NetworkManager.request_use_food.rpc_id(1, food_id)

func _sell_item(item_id: String) -> void:
	NetworkManager.request_sell_item.rpc_id(1, item_id, 1)

func _use_scroll(scroll_id: String) -> void:
	NetworkManager.request_use_recipe_scroll.rpc_id(1, scroll_id)

func _equip_tool(tool_id: String) -> void:
	NetworkManager.request_equip_tool.rpc_id(1, tool_id)

var _hotbar_popup: PopupPanel = null

func _show_hotbar_assign(item_id: String, item_type: String) -> void:
	if _hotbar_popup and is_instance_valid(_hotbar_popup):
		_hotbar_popup.queue_free()
	_hotbar_popup = PopupPanel.new()
	var vbox := VBoxContainer.new()
	_hotbar_popup.add_child(vbox)
	var title := Label.new()
	title.text = "Assign to slot:"
	UITheme.style_small(title)
	vbox.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 4
	vbox.add_child(grid)
	var key_labels = ["1", "2", "3", "4", "5", "6", "7", "8"]
	for i in range(PlayerData.HOTBAR_SIZE):
		var btn := Button.new()
		btn.text = key_labels[i]
		btn.custom_minimum_size = Vector2(36, 36)
		UITheme.style_button(btn, "secondary")
		var slot_idx = i
		var sid = item_id
		var stype = item_type
		btn.pressed.connect(func():
			PlayerData.assign_hotbar_slot(slot_idx, sid, stype)
			if _hotbar_popup and is_instance_valid(_hotbar_popup):
				_hotbar_popup.hide()
		)
		grid.add_child(btn)
	add_child(_hotbar_popup)
	_hotbar_popup.popup_centered(Vector2(200, 120))

func _clear_children(node: Control) -> void:
	for child in node.get_children():
		child.queue_free()
