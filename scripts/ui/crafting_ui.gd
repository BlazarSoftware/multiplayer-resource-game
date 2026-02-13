extends CanvasLayer

@onready var recipe_list: VBoxContainer = $Panel/VBox/RecipeList
@onready var close_button: Button = $Panel/VBox/CloseButton

var crafting_system: Node = null

func _ready() -> void:
	close_button.pressed.connect(func(): visible = false)

func setup(craft_sys: Node) -> void:
	crafting_system = craft_sys
	if crafting_system:
		crafting_system.craft_result.connect(_on_craft_result)

func refresh() -> void:
	# Clear old entries
	for child in recipe_list.get_children():
		child.queue_free()
	if crafting_system == null:
		return
	var recipes = crafting_system.get_available_recipes()
	for recipe in recipes:
		var hbox = HBoxContainer.new()
		recipe_list.add_child(hbox)
		# Recipe name
		var label = Label.new()
		label.text = recipe.display_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		# Ingredients
		var ing_label = Label.new()
		var ing_text = ""
		for ing_id in recipe.ingredients:
			var info = recipe.ingredients[ing_id]
			var ingredient = DataRegistry.get_ingredient(ing_id)
			var name = ingredient.display_name if ingredient else ing_id
			var color = "green" if info.have >= info.needed else "red"
			ing_text += "[%s] %s: %d/%d  " % [color, name, info.have, info.needed]
		ing_label.text = ing_text
		hbox.add_child(ing_label)
		# Craft button
		var btn = Button.new()
		btn.text = "Craft"
		btn.disabled = not recipe.can_craft
		var rid = recipe.recipe_id
		btn.pressed.connect(func(): _craft(rid))
		hbox.add_child(btn)

func _craft(recipe_id: String) -> void:
	if crafting_system:
		crafting_system.request_craft_creature.rpc_id(1, recipe_id)

func _on_craft_result(success: bool, creature_name: String) -> void:
	if success:
		print(creature_name, " joined your party!")
	refresh()
