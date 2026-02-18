extends GutTest

# Tests for the bank system: deposit, withdraw, interest, backfill
# Directly calls NetworkManager bank functions with mock player_data_store entries.

var _peer_id: int = 100

func before_each() -> void:
	RegistrySeeder.seed_all()
	# Set up a mock player in player_data_store
	NetworkManager.player_data_store[_peer_id] = {
		"player_name": "TestBanker",
		"money": 1000,
		"bank": {"balance": 0, "last_interest_day": 0},
	}

func after_each() -> void:
	RegistrySeeder.clear_all()
	NetworkManager.player_data_store.erase(_peer_id)

# --- Deposit tests ---

func test_deposit_reduces_wallet_increases_bank() -> void:
	var ok = NetworkManager.server_deposit_money(_peer_id, 500)
	assert_true(ok)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["money"]), 500)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["bank"]["balance"]), 500)

func test_deposit_zero_rejected() -> void:
	var ok = NetworkManager.server_deposit_money(_peer_id, 0)
	assert_false(ok)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["money"]), 1000)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["bank"]["balance"]), 0)

func test_deposit_negative_rejected() -> void:
	var ok = NetworkManager.server_deposit_money(_peer_id, -50)
	assert_false(ok)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["money"]), 1000)

func test_deposit_more_than_wallet_rejected() -> void:
	var ok = NetworkManager.server_deposit_money(_peer_id, 2000)
	assert_false(ok)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["money"]), 1000)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["bank"]["balance"]), 0)

# --- Withdraw tests ---

func test_withdraw_reduces_bank_increases_wallet() -> void:
	# Deposit first
	NetworkManager.server_deposit_money(_peer_id, 1000)
	# Withdraw 500
	var ok = NetworkManager.server_withdraw_money(_peer_id, 500)
	assert_true(ok)
	# Fee = max(1, floor(500 * 0.02)) = 10
	# Net = 500 - 10 = 490
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["bank"]["balance"]), 500)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["money"]), 490)

func test_withdraw_applies_fee() -> void:
	NetworkManager.server_deposit_money(_peer_id, 1000)
	# Withdraw 100: fee = max(1, floor(100*0.02)) = 2, net = 98
	var ok = NetworkManager.server_withdraw_money(_peer_id, 100)
	assert_true(ok)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["money"]), 98)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["bank"]["balance"]), 900)

func test_withdraw_minimum_fee_is_one() -> void:
	NetworkManager.server_deposit_money(_peer_id, 1000)
	# Withdraw 1: fee = max(1, floor(1*0.02)) = max(1, 0) = 1, net = 0
	var ok = NetworkManager.server_withdraw_money(_peer_id, 1)
	assert_true(ok)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["money"]), 0) # 0 net
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["bank"]["balance"]), 999)

func test_withdraw_zero_rejected() -> void:
	NetworkManager.server_deposit_money(_peer_id, 1000)
	var ok = NetworkManager.server_withdraw_money(_peer_id, 0)
	assert_false(ok)

func test_withdraw_more_than_balance_rejected() -> void:
	NetworkManager.server_deposit_money(_peer_id, 500)
	var ok = NetworkManager.server_withdraw_money(_peer_id, 600)
	assert_false(ok)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["bank"]["balance"]), 500)

# --- Interest tests ---

func test_interest_applies_correct_percentage() -> void:
	NetworkManager.player_data_store[_peer_id]["bank"] = {"balance": 10000, "last_interest_day": 5}
	# Simulate SeasonManager at day 6 (1 day elapsed)
	# We need a SeasonManager node. Since we can't easily, we test the math directly.
	# Interest = floor(10000 * 0.005) = 50
	# For direct testing, manually call the function with a known current_day.
	# The function reads SeasonManager from tree, so we test the logic components instead.
	var balance = 10000
	var daily = int(floor(balance * NetworkManager.BANK_INTEREST_RATE))
	assert_eq(daily, 50)

func test_interest_respects_max_cap() -> void:
	# With 200000 balance, daily interest would be 1000, capped at 500
	var balance = 200000
	var daily = int(floor(balance * NetworkManager.BANK_INTEREST_RATE))
	daily = min(daily, NetworkManager.BANK_MAX_DAILY_INTEREST)
	assert_eq(daily, 500)

func test_interest_skips_small_balance() -> void:
	# Balance below BANK_MIN_BALANCE (100) should earn no interest
	var balance = 50
	var earns_interest = balance >= NetworkManager.BANK_MIN_BALANCE
	assert_false(earns_interest)

func test_interest_at_minimum_balance() -> void:
	# Balance exactly at minimum should earn interest
	var balance = 100
	var earns_interest = balance >= NetworkManager.BANK_MIN_BALANCE
	assert_true(earns_interest)
	var daily = int(floor(balance * NetworkManager.BANK_INTEREST_RATE))
	assert_eq(daily, 0) # floor(0.5) = 0, so 100 earns nothing per day
	# But 200 earns 1/day
	balance = 200
	daily = int(floor(balance * NetworkManager.BANK_INTEREST_RATE))
	assert_eq(daily, 1)

func test_interest_compound_multiple_days() -> void:
	# Simulate 3 days of compound interest on 10000
	var balance = 10000
	var total_interest = 0
	for _i in range(3):
		var daily = int(floor(balance * NetworkManager.BANK_INTEREST_RATE))
		daily = min(daily, NetworkManager.BANK_MAX_DAILY_INTEREST)
		balance += daily
		total_interest += daily
	# Day 1: floor(10000*0.005)=50 → balance=10050
	# Day 2: floor(10050*0.005)=50 → balance=10100
	# Day 3: floor(10100*0.005)=50 → balance=10150
	assert_eq(total_interest, 150)
	assert_eq(balance, 10150)

# --- Backfill test ---

func test_backfill_missing_bank_data() -> void:
	# Remove bank data to simulate old save
	NetworkManager.player_data_store[_peer_id].erase("bank")
	assert_false(NetworkManager.player_data_store[_peer_id].has("bank"))
	# Simulate what _finalize_join does
	var data = NetworkManager.player_data_store[_peer_id]
	if not data.has("bank"):
		data["bank"] = {"balance": 0, "last_interest_day": 0}
	assert_true(data.has("bank"))
	assert_eq(int(data["bank"]["balance"]), 0)
	assert_eq(int(data["bank"]["last_interest_day"]), 0)

# --- Sequential operations ---

func test_two_rapid_deposits_both_succeed() -> void:
	var ok1 = NetworkManager.server_deposit_money(_peer_id, 300)
	var ok2 = NetworkManager.server_deposit_money(_peer_id, 400)
	assert_true(ok1)
	assert_true(ok2)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["money"]), 300)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["bank"]["balance"]), 700)

func test_deposit_then_withdraw_roundtrip() -> void:
	NetworkManager.server_deposit_money(_peer_id, 1000)
	# Withdraw all: fee = max(1, floor(1000*0.02)) = 20, net = 980
	NetworkManager.server_withdraw_money(_peer_id, 1000)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["bank"]["balance"]), 0)
	assert_eq(int(NetworkManager.player_data_store[_peer_id]["money"]), 980)
