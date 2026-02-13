extends CanvasLayer

const StatusEffects = preload("res://scripts/battle/status_effects.gd")

@onready var enemy_name: Label = $EnemyPanel/EnemyName
@onready var enemy_hp_bar: ProgressBar = $EnemyPanel/EnemyHPBar
@onready var enemy_status: Label = $EnemyPanel/EnemyStatus
@onready var enemy_mesh_rect: ColorRect = $EnemyMesh
@onready var player_name: Label = $PlayerPanel/PlayerCreatureName
@onready var player_hp_bar: ProgressBar = $PlayerPanel/PlayerHPBar
@onready var player_status: Label = $PlayerPanel/PlayerStatus
@onready var battle_log: RichTextLabel = $LogPanel/BattleLog
@onready var move_buttons: Array = [
	$ActionPanel/MoveGrid/Move1,
	$ActionPanel/MoveGrid/Move2,
	$ActionPanel/MoveGrid/Move3,
	$ActionPanel/MoveGrid/Move4
]
@onready var flee_button: Button = $ActionPanel/BottomButtons/FleeButton
@onready var switch_button: Button = $ActionPanel/BottomButtons/SwitchButton

var battle_mgr: Node = null

const TYPE_COLORS = {
	"spicy": Color(0.9, 0.2, 0.1),
	"sweet": Color(0.9, 0.5, 0.7),
	"sour": Color(0.7, 0.8, 0.2),
	"herbal": Color(0.2, 0.7, 0.2),
	"umami": Color(0.5, 0.3, 0.2),
	"grain": Color(0.8, 0.7, 0.3),
}

func _ready() -> void:
	for i in range(move_buttons.size()):
		var idx = i
		move_buttons[i].pressed.connect(func(): _on_move_pressed(idx))
	flee_button.pressed.connect(_on_flee_pressed)
	switch_button.pressed.connect(_on_switch_pressed)

func setup(battle_manager: Node) -> void:
	battle_mgr = battle_manager
	battle_mgr.battle_started.connect(_on_battle_started)
	battle_mgr.battle_ended.connect(_on_battle_ended)
	battle_mgr.turn_result_received.connect(_on_turn_result)

func _on_battle_started() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	battle_log.clear()
	battle_log.append_text("A wild creature appeared!\n")
	_refresh_ui()

func _on_battle_ended(victory: bool) -> void:
	if victory:
		battle_log.append_text("\n[color=green]Victory![/color]\n")
		# Brief delay then close
		await get_tree().create_timer(2.0).timeout
	else:
		battle_log.append_text("\n[color=red]Battle over.[/color]\n")
		await get_tree().create_timer(1.5).timeout
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_ui() -> void:
	if battle_mgr == null:
		return
	# Enemy info
	var enemy = battle_mgr.client_enemy
	enemy_name.text = "Wild %s Lv.%d" % [enemy.get("nickname", "???"), enemy.get("level", 1)]
	var enemy_max_hp = enemy.get("max_hp", 1)
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy.get("hp", 0)
	enemy_status.text = StatusEffects.get_status_display_name(enemy.get("status", ""))
	# Set enemy color
	var species = DataRegistry.get_species(enemy.get("species_id", ""))
	if species:
		enemy_mesh_rect.color = species.mesh_color
	# Player creature
	var active_idx = battle_mgr.client_active_creature_idx
	if active_idx < PlayerData.party.size():
		var creature = PlayerData.party[active_idx]
		player_name.text = "%s Lv.%d" % [creature.get("nickname", "???"), creature.get("level", 1)]
		var max_hp = creature.get("max_hp", 1)
		player_hp_bar.max_value = max_hp
		player_hp_bar.value = creature.get("hp", 0)
		player_status.text = StatusEffects.get_status_display_name(creature.get("status", ""))
		# Move buttons
		var moves = creature.get("moves", [])
		var pp = creature.get("pp", [])
		for i in range(4):
			if i < moves.size():
				DataRegistry.ensure_loaded()
				var move = DataRegistry.get_move(moves[i])
				if move:
					var pp_text = ""
					if i < pp.size():
						pp_text = " (%d PP)" % pp[i]
					move_buttons[i].text = "%s%s" % [move.display_name, pp_text]
					var color = TYPE_COLORS.get(move.type, Color.GRAY)
					move_buttons[i].modulate = color.lerp(Color.WHITE, 0.5)
					move_buttons[i].visible = true
					move_buttons[i].disabled = (i < pp.size() and pp[i] <= 0)
				else:
					move_buttons[i].visible = false
			else:
				move_buttons[i].visible = false

func _on_move_pressed(idx: int) -> void:
	if battle_mgr == null or not battle_mgr.awaiting_action:
		return
	var active_idx = battle_mgr.client_active_creature_idx
	if active_idx >= PlayerData.party.size():
		return
	var moves = PlayerData.party[active_idx].get("moves", [])
	if idx < moves.size():
		battle_mgr.send_move(moves[idx])
		_set_buttons_enabled(false)

func _on_flee_pressed() -> void:
	if battle_mgr:
		battle_mgr.send_flee()
		_set_buttons_enabled(false)

func _on_switch_pressed() -> void:
	# Show switch dialog (simple: cycle to next alive creature)
	if battle_mgr == null:
		return
	var current = battle_mgr.client_active_creature_idx
	for i in range(PlayerData.party.size()):
		if i != current and PlayerData.party[i].get("hp", 0) > 0:
			battle_mgr.send_switch(i)
			_set_buttons_enabled(false)
			return
	battle_log.append_text("No other creatures available!\n")

func _on_turn_result(turn_log: Array) -> void:
	for entry in turn_log:
		var msg = _format_log_entry(entry)
		if msg != "":
			battle_log.append_text(msg + "\n")
	_refresh_ui()
	if battle_mgr and battle_mgr.awaiting_action:
		_set_buttons_enabled(true)

func _format_log_entry(entry: Dictionary) -> String:
	var entry_type = entry.get("type", "move")
	match entry_type:
		"move":
			var actor_name = "You" if entry.get("actor") == "player" else "Enemy"
			var move_name = entry.get("move", "???")
			var text = "%s used %s!" % [actor_name, move_name]
			if entry.get("missed", false):
				return text + " But it missed!"
			if entry.get("skipped", false):
				return "%s %s" % [actor_name, entry.get("message", "can't move!")]
			if entry.has("damage"):
				text += " Dealt %d damage." % entry.damage
			if entry.get("effectiveness") == "super_effective":
				text += " [color=green]Super effective![/color]"
			elif entry.get("effectiveness") == "not_very_effective":
				text += " [color=yellow]Not very effective...[/color]"
			if entry.get("critical", false):
				text += " Critical hit!"
			if entry.has("status_applied"):
				text += " Inflicted %s!" % StatusEffects.get_status_display_name(entry.status_applied)
			if entry.has("heal"):
				text += " Healed %d HP!" % entry.heal
			if entry.has("drain_heal"):
				text += " Drained %d HP!" % entry.drain_heal
			if entry.has("stat_changes"):
				for stat in entry.stat_changes:
					var change = entry.stat_changes[stat]
					var direction = "rose" if change > 0 else "fell"
					var amount = "sharply " if abs(change) >= 2 else ""
					text += " %s %s%s!" % [stat.capitalize(), amount, direction]
			return text
		"status_damage":
			var actor_name = "Your creature" if entry.get("actor") == "player" else "Enemy"
			return "%s %s (%d damage)" % [actor_name, entry.get("message", ""), entry.get("damage", 0)]
		"victory":
			var drops = entry.get("drops", {})
			var drop_text = ""
			for item_id in drops:
				var ingredient = DataRegistry.get_ingredient(item_id)
				var name = ingredient.display_name if ingredient else item_id
				drop_text += "%s x%d " % [name, drops[item_id]]
			return "[color=green]Enemy defeated![/color] Got: %s" % drop_text
		"defeat":
			return "[color=red]All your creatures fainted![/color]"
		"fled":
			return "Got away safely!"
		"flee_failed":
			return "Couldn't escape!"
		"fainted":
			return "[color=red]Your creature fainted![/color] Switch to another!"
		"switch":
			return "Switched creature!"
	return ""

func _set_buttons_enabled(enabled: bool) -> void:
	for btn in move_buttons:
		btn.disabled = not enabled
	flee_button.disabled = not enabled
	switch_button.disabled = not enabled
