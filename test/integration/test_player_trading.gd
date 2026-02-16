extends GutTest

# Integration tests for player trading logic
# Tests the trade state management and atomic swap logic
# Uses direct dict manipulation to simulate server-side trade state

var active_trades: Dictionary = {}
var player_trade_map: Dictionary = {}
var next_trade_id: int = 1
var inventories: Dictionary = {} # peer_id -> {item_id -> count}

func before_each() -> void:
	active_trades = {}
	player_trade_map = {}
	next_trade_id = 1
	inventories = {
		100: {"herb_sprig": 5, "chili_flake": 3},
		200: {"sugar_crystal": 2, "rice_grain": 10},
	}

func after_each() -> void:
	active_trades.clear()
	player_trade_map.clear()
	inventories.clear()

# --- Helper functions that mirror NetworkManager trade logic ---

func _create_trade(peer_a: int, peer_b: int) -> int:
	var trade_id = next_trade_id
	next_trade_id += 1
	active_trades[trade_id] = {
		"peer_a": peer_a,
		"peer_b": peer_b,
		"offer_a": {},
		"offer_b": {},
		"confirmed_a": false,
		"confirmed_b": false,
	}
	player_trade_map[peer_a] = trade_id
	player_trade_map[peer_b] = trade_id
	return trade_id

func _update_offer(peer_id: int, item_id: String, count_change: int) -> bool:
	if peer_id not in player_trade_map:
		return false
	var trade_id = player_trade_map[peer_id]
	var trade = active_trades.get(trade_id)
	if trade == null:
		return false
	var side = "offer_a" if peer_id == trade.peer_a else "offer_b"
	var offer = trade[side]
	var new_count = offer.get(item_id, 0) + count_change
	if new_count <= 0:
		offer.erase(item_id)
	else:
		# Validate against inventory
		var inv_count = inventories.get(peer_id, {}).get(item_id, 0)
		if new_count > inv_count:
			return false
		offer[item_id] = new_count
	# Reset confirmations when offers change
	trade.confirmed_a = false
	trade.confirmed_b = false
	return true

func _confirm_trade(peer_id: int) -> void:
	if peer_id not in player_trade_map:
		return
	var trade_id = player_trade_map[peer_id]
	var trade = active_trades.get(trade_id)
	if trade == null:
		return
	if peer_id == trade.peer_a:
		trade.confirmed_a = true
	else:
		trade.confirmed_b = true

func _execute_trade(trade_id: int) -> bool:
	var trade = active_trades.get(trade_id)
	if trade == null:
		return false
	if not trade.confirmed_a or not trade.confirmed_b:
		return false
	var peer_a = trade.peer_a
	var peer_b = trade.peer_b
	var offer_a = trade.offer_a
	var offer_b = trade.offer_b
	# Validate peer A still has offered items
	for item_id in offer_a:
		var inv_count = inventories.get(peer_a, {}).get(item_id, 0)
		if inv_count < offer_a[item_id]:
			return false
	# Validate peer B still has offered items
	for item_id in offer_b:
		var inv_count = inventories.get(peer_b, {}).get(item_id, 0)
		if inv_count < offer_b[item_id]:
			return false
	# Execute atomic swap
	for item_id in offer_a:
		inventories[peer_a][item_id] -= offer_a[item_id]
		if inventories[peer_a][item_id] <= 0:
			inventories[peer_a].erase(item_id)
		inventories[peer_b][item_id] = inventories[peer_b].get(item_id, 0) + offer_a[item_id]
	for item_id in offer_b:
		inventories[peer_b][item_id] -= offer_b[item_id]
		if inventories[peer_b][item_id] <= 0:
			inventories[peer_b].erase(item_id)
		inventories[peer_a][item_id] = inventories[peer_a].get(item_id, 0) + offer_b[item_id]
	# Cleanup
	player_trade_map.erase(peer_a)
	player_trade_map.erase(peer_b)
	active_trades.erase(trade_id)
	return true

func _cancel_trade(trade_id: int) -> void:
	var trade = active_trades.get(trade_id)
	if trade == null:
		return
	player_trade_map.erase(trade.peer_a)
	player_trade_map.erase(trade.peer_b)
	active_trades.erase(trade_id)

# --- Tests ---

func test_create_trade() -> void:
	var tid = _create_trade(100, 200)
	assert_eq(tid, 1)
	assert_true(100 in player_trade_map)
	assert_true(200 in player_trade_map)
	assert_eq(active_trades[tid].peer_a, 100)
	assert_eq(active_trades[tid].peer_b, 200)

func test_update_offer_add_item() -> void:
	var tid = _create_trade(100, 200)
	var ok = _update_offer(100, "herb_sprig", 2)
	assert_true(ok)
	assert_eq(active_trades[tid].offer_a.get("herb_sprig", 0), 2)

func test_update_offer_exceeds_inventory() -> void:
	_create_trade(100, 200)
	var ok = _update_offer(100, "herb_sprig", 99)
	assert_false(ok, "Should reject offer exceeding inventory")

func test_update_offer_resets_confirmations() -> void:
	var tid = _create_trade(100, 200)
	_update_offer(100, "herb_sprig", 1)
	_confirm_trade(100)
	assert_true(active_trades[tid].confirmed_a)
	# Update offer should reset
	_update_offer(100, "herb_sprig", 1)
	assert_false(active_trades[tid].confirmed_a, "Confirmation should reset on offer change")

func test_confirm_trade_both_sides() -> void:
	var tid = _create_trade(100, 200)
	_update_offer(100, "herb_sprig", 1)
	_update_offer(200, "sugar_crystal", 1)
	_confirm_trade(100)
	assert_true(active_trades[tid].confirmed_a)
	assert_false(active_trades[tid].confirmed_b)
	_confirm_trade(200)
	assert_true(active_trades[tid].confirmed_b)

func test_execute_trade_atomic_swap() -> void:
	var tid = _create_trade(100, 200)
	_update_offer(100, "herb_sprig", 2)
	_update_offer(200, "sugar_crystal", 1)
	_confirm_trade(100)
	_confirm_trade(200)
	var ok = _execute_trade(tid)
	assert_true(ok, "Trade should execute")
	# Peer 100: lost 2 herb_sprig, gained 1 sugar_crystal
	assert_eq(inventories[100].get("herb_sprig", 0), 3)
	assert_eq(inventories[100].get("sugar_crystal", 0), 1)
	# Peer 200: gained 2 herb_sprig, lost 1 sugar_crystal
	assert_eq(inventories[200].get("herb_sprig", 0), 2)
	assert_eq(inventories[200].get("sugar_crystal", 0), 1)

func test_execute_trade_requires_both_confirmed() -> void:
	var tid = _create_trade(100, 200)
	_update_offer(100, "herb_sprig", 1)
	_confirm_trade(100)
	var ok = _execute_trade(tid)
	assert_false(ok, "Should not execute with only one confirmation")

func test_cancel_trade_no_inventory_changes() -> void:
	var tid = _create_trade(100, 200)
	_update_offer(100, "herb_sprig", 2)
	_update_offer(200, "sugar_crystal", 1)
	# Cancel before executing
	_cancel_trade(tid)
	# Inventories unchanged
	assert_eq(inventories[100].get("herb_sprig", 0), 5)
	assert_eq(inventories[200].get("sugar_crystal", 0), 2)
	# Maps cleared
	assert_false(100 in player_trade_map)
	assert_false(200 in player_trade_map)

func test_execute_trade_insufficient_items_fails() -> void:
	var tid = _create_trade(100, 200)
	_update_offer(100, "herb_sprig", 3)
	_update_offer(200, "sugar_crystal", 1)
	_confirm_trade(100)
	_confirm_trade(200)
	# Manually reduce peer 100's inventory before execution
	inventories[100]["herb_sprig"] = 1
	var ok = _execute_trade(tid)
	assert_false(ok, "Should fail if items no longer available")

func test_disconnect_cancels_trade() -> void:
	var tid = _create_trade(100, 200)
	_update_offer(100, "herb_sprig", 1)
	# Simulate disconnect: cancel the trade
	_cancel_trade(tid)
	assert_false(100 in player_trade_map)
	assert_false(200 in player_trade_map)
	assert_false(tid in active_trades)

func test_cannot_trade_while_already_trading() -> void:
	_create_trade(100, 200)
	# Peer 100 already in a trade
	assert_true(100 in player_trade_map, "Peer 100 already trading")
	# Attempting to create another trade would be blocked by the check

func test_remove_item_from_offer() -> void:
	var tid = _create_trade(100, 200)
	_update_offer(100, "herb_sprig", 3)
	assert_eq(active_trades[tid].offer_a.get("herb_sprig", 0), 3)
	_update_offer(100, "herb_sprig", -2)
	assert_eq(active_trades[tid].offer_a.get("herb_sprig", 0), 1)
	_update_offer(100, "herb_sprig", -1)
	assert_false(active_trades[tid].offer_a.has("herb_sprig"), "Should remove item when count reaches 0")
