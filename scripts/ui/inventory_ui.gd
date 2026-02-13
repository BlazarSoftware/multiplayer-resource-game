extends CanvasLayer

@onready var item_list: VBoxContainer = $Panel/VBox/ItemList
@onready var seed_label: Label = $Panel/VBox/SeedSelect/SeedLabel
@onready var close_button: Button = $Panel/VBox/CloseButton

func _ready() -> void:
	close_button.pressed.connect(func(): visible = false)
	PlayerData.inventory_changed.connect(_refresh)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		visible = !visible
		if visible:
			_refresh()

func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()
	DataRegistry.ensure_loaded()
	for item_id in PlayerData.inventory:
		var count = PlayerData.inventory[item_id]
		var ingredient = DataRegistry.get_ingredient(item_id)
		var hbox = HBoxContainer.new()
		item_list.add_child(hbox)
		# Color indicator
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(20, 20)
		color_rect.color = ingredient.icon_color if ingredient else Color.GRAY
		hbox.add_child(color_rect)
		# Name and count
		var label = Label.new()
		label.text = "  %s x%d" % [ingredient.display_name if ingredient else item_id, count]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		# Select as seed button (for farm crops)
		if ingredient and ingredient.category == "farm_crop":
			var btn = Button.new()
			btn.text = "Select Seed"
			var sid = item_id
			btn.pressed.connect(func(): _select_seed(sid))
			hbox.add_child(btn)
	# Show selected seed
	if PlayerData.selected_seed_id != "":
		var ingredient = DataRegistry.get_ingredient(PlayerData.selected_seed_id)
		seed_label.text = "Selected Seed: %s" % (ingredient.display_name if ingredient else PlayerData.selected_seed_id)
	else:
		seed_label.text = "Selected Seed: None"

func _select_seed(seed_id: String) -> void:
	PlayerData.selected_seed_id = seed_id
	PlayerData.set_tool(PlayerData.Tool.SEEDS)
	_refresh()
