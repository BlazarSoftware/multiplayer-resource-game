extends CanvasLayer

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

@onready var recipe_list: VBoxContainer = $Panel/VBox/RecipeList
@onready var close_button: Button = $Panel/VBox/CloseButton

var crafting_system: Node = null
var current_station: String = "" # "kitchen", "workbench", "cauldron", "" for all
var title_label: Label = null

func _ready() -> void:
	UITheme.init()
	UITheme.style_modal($Panel)
	UITheme.style_button(close_button, "danger")
	close_button.pressed.connect(_close)
	# Create title label
	title_label = Label.new()
	title_label.text = "Crafting"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_heading(title_label)
	var vbox = $Panel/VBox
	vbox.add_child(title_label)
	vbox.move_child(title_label, 0)

func _close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	NetworkManager.request_set_busy.rpc_id(1, false)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func setup(craft_sys: Node) -> void:
	crafting_system = craft_sys
	if crafting_system:
		crafting_system.craft_result.connect(_on_craft_result)

func open_for_station(station: String) -> void:
	current_station = station
	if title_label:
		match station:
			"kitchen":
				title_label.text = "Kitchen"
			"workbench":
				title_label.text = "Workbench"
			"cauldron":
				title_label.text = "Cauldron"
			_:
				title_label.text = "Crafting"
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkManager.request_set_busy.rpc_id(1, true)
	refresh()

func refresh() -> void:
	for child in recipe_list.get_children():
		child.queue_free()
	if crafting_system == null:
		return
	var recipes = crafting_system.get_available_recipes(current_station)

	# Group recipes by type
	var creature_recipes = []
	var item_recipes = []
	var food_recipes = []
	var tool_recipes = []
	for recipe in recipes:
		if recipe.get("result_species_id", "") != "":
			creature_recipes.append(recipe)
		elif recipe.get("result_tool_id", "") != "":
			tool_recipes.append(recipe)
		elif recipe.get("result_food_id", "") != "":
			food_recipes.append(recipe)
		elif recipe.get("result_item_id", "") != "":
			item_recipes.append(recipe)

	# Creature recipes section
	if creature_recipes.size() > 0:
		_add_section_header("-- Creature Recipes --")
		for recipe in creature_recipes:
			_add_recipe_row(recipe)

	# Food recipes section
	if food_recipes.size() > 0:
		_add_section_header("-- Food Recipes --")
		for recipe in food_recipes:
			_add_recipe_row(recipe)

	# Held item recipes section
	if item_recipes.size() > 0:
		_add_section_header("-- Held Item Recipes --")
		for recipe in item_recipes:
			_add_recipe_row(recipe)

	# Tool upgrade recipes section
	if tool_recipes.size() > 0:
		_add_section_header("-- Tool Upgrades --")
		for recipe in tool_recipes:
			_add_recipe_row(recipe)

func _add_section_header(text: String) -> void:
	var header = Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_subheading(header)
	recipe_list.add_child(header)

func _add_recipe_row(recipe: Dictionary) -> void:
	var hbox = HBoxContainer.new()
	recipe_list.add_child(hbox)

	# Lock icon for locked recipes
	if recipe.get("locked", false):
		var lock_label = Label.new()
		lock_label.text = "[Locked] "
		UITheme.style_small(lock_label)
		lock_label.add_theme_color_override("font_color", UITokens.INK_LIGHT)
		hbox.add_child(lock_label)

	# Recipe name
	var label = Label.new()
	label.text = recipe.display_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_small(label)
	if recipe.get("locked", false):
		label.add_theme_color_override("font_color", UITokens.INK_LIGHT)
	hbox.add_child(label)

	# Ingredients
	var ing_label = Label.new()
	UITheme.style_small(ing_label)
	var ing_text = ""
	DataRegistry.ensure_loaded()
	for ing_id in recipe.ingredients:
		var info = recipe.ingredients[ing_id]
		var item_info = DataRegistry.get_item_display_info(ing_id)
		var ing_name = item_info.get("display_name", ing_id)
		ing_text += "%s: %d/%d  " % [ing_name, info.have, info.needed]
	# Show tool requirement
	if recipe.get("requires_tool_ingredient", "") != "":
		var tool_info = DataRegistry.get_item_display_info(recipe.requires_tool_ingredient)
		var tool_name = tool_info.get("display_name", recipe.requires_tool_ingredient)
		var has_it = recipe.get("has_tool_ingredient", false)
		ing_text += "%s: %s  " % [tool_name, "OK" if has_it else "Need"]
	ing_label.text = ing_text
	hbox.add_child(ing_label)

	# Craft button
	var btn = Button.new()
	btn.text = "Craft"
	UITheme.style_button(btn, "primary")
	btn.disabled = not recipe.can_craft
	var rid = recipe.recipe_id
	btn.pressed.connect(func(): _craft(rid))
	hbox.add_child(btn)

func _craft(recipe_id: String) -> void:
	if crafting_system:
		crafting_system.request_craft.rpc_id(1, recipe_id)

func _on_craft_result(success: bool, result_name: String, message: String) -> void:
	if success:
		print(message)
	else:
		print("Crafting failed: ", message)
	refresh()
