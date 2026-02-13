extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var text_label: Label = $Panel/VBox/TextLabel
@onready var ok_button: Button = $Panel/VBox/OkButton

func _ready() -> void:
	visible = false
	ok_button.pressed.connect(_on_ok)

func show_dialogue(trainer_name: String, text: String) -> void:
	name_label.text = trainer_name
	text_label.text = text
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Auto-dismiss after 4 seconds
	await get_tree().create_timer(4.0).timeout
	if visible:
		visible = false

func _on_ok() -> void:
	visible = false
