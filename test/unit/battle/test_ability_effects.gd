extends GutTest

# Tests for AbilityEffects static methods.
# Requires RegistrySeeder for ability lookups.

func before_each():
	RegistrySeeder.seed_all()

func after_each():
	RegistrySeeder.clear_all()

# --- on_enter ---

func test_sour_aura_lowers_foe_defense():
	var creature = BattleFactory.creature({"ability_id": "sour_aura"})
	var foe = BattleFactory.creature({"defense_stage": 0})
	var battle = BattleFactory.battle()
	var msgs = AbilityEffects.on_enter(creature, foe, battle)
	assert_eq(foe["defense_stage"], -1)
	assert_eq(msgs.size(), 1)

func test_grain_shield_boosts_in_grain_weather():
	var creature = BattleFactory.creature({"ability_id": "grain_shield", "defense_stage": 0})
	var foe = BattleFactory.creature()
	var battle = BattleFactory.battle({"weather": "grain"})
	AbilityEffects.on_enter(creature, foe, battle)
	assert_eq(creature["defense_stage"], 1)

func test_grain_shield_no_effect_without_weather():
	var creature = BattleFactory.creature({"ability_id": "grain_shield", "defense_stage": 0})
	var foe = BattleFactory.creature()
	var battle = BattleFactory.battle({"weather": ""})
	var msgs = AbilityEffects.on_enter(creature, foe, battle)
	assert_eq(creature["defense_stage"], 0)
	assert_eq(msgs.size(), 0)

func test_scoville_aura_sets_spicy_weather():
	var creature = BattleFactory.creature({"ability_id": "scoville_aura"})
	var foe = BattleFactory.creature()
	var battle = BattleFactory.battle({"weather": ""})
	AbilityEffects.on_enter(creature, foe, battle)
	assert_eq(battle["weather"], "spicy")
	assert_eq(battle["weather_turns"], FieldEffects.WEATHER_DURATION)

func test_ferment_cloud_sets_sour_weather():
	var creature = BattleFactory.creature({"ability_id": "ferment_cloud"})
	var foe = BattleFactory.creature()
	var battle = BattleFactory.battle()
	AbilityEffects.on_enter(creature, foe, battle)
	assert_eq(battle["weather"], "sour")

func test_no_ability_no_effect():
	var creature = BattleFactory.creature({"ability_id": ""})
	var foe = BattleFactory.creature({"defense_stage": 0})
	var battle = BattleFactory.battle()
	var msgs = AbilityEffects.on_enter(creature, foe, battle)
	assert_eq(msgs.size(), 0)
	assert_eq(foe["defense_stage"], 0)

# --- on_attack ---

func test_deep_umami_boosts_umami_moves():
	var attacker = BattleFactory.creature({"ability_id": "deep_umami"})
	var move = MockMove.special(60, "umami")
	var result = AbilityEffects.on_attack(attacker, move, 100)
	assert_eq(result.damage, 130) # 100 * 1.3

func test_deep_umami_no_boost_other_type():
	var attacker = BattleFactory.creature({"ability_id": "deep_umami"})
	var move = MockMove.special(60, "spicy")
	var result = AbilityEffects.on_attack(attacker, move, 100)
	assert_eq(result.damage, 100)

func test_sharp_zest_boosts_sour():
	var attacker = BattleFactory.creature({"ability_id": "sharp_zest"})
	var move = MockMove.special(60, "sour")
	var result = AbilityEffects.on_attack(attacker, move, 100)
	assert_eq(result.damage, 130)

func test_scoville_boost_boosts_spicy():
	var attacker = BattleFactory.creature({"ability_id": "scoville_boost"})
	var move = MockMove.physical(50, "spicy")
	var result = AbilityEffects.on_attack(attacker, move, 100)
	assert_eq(result.damage, 130)

func test_stretchy_boosts_physical():
	var attacker = BattleFactory.creature({"ability_id": "stretchy"})
	var move = MockMove.physical(50, "grain")
	var result = AbilityEffects.on_attack(attacker, move, 100)
	assert_eq(result.damage, 120) # 1.2x

func test_stretchy_no_boost_special():
	var attacker = BattleFactory.creature({"ability_id": "stretchy"})
	var move = MockMove.special(50, "grain")
	var result = AbilityEffects.on_attack(attacker, move, 100)
	assert_eq(result.damage, 100)

func test_on_attack_zero_damage_passthrough():
	var attacker = BattleFactory.creature({"ability_id": "deep_umami"})
	var move = MockMove.special(60, "umami")
	var result = AbilityEffects.on_attack(attacker, move, 0)
	assert_eq(result.damage, 0) # early return for 0 damage

# --- on_defend ---

func test_brine_body_reduces_special():
	var defender = BattleFactory.creature({"ability_id": "brine_body"})
	var move = MockMove.special(60, "spicy")
	var result = AbilityEffects.on_defend(defender, move, 100)
	assert_eq(result.damage, 80)

func test_brine_body_no_effect_physical():
	var defender = BattleFactory.creature({"ability_id": "brine_body"})
	var move = MockMove.physical(50, "spicy")
	var result = AbilityEffects.on_defend(defender, move, 100)
	assert_eq(result.damage, 100)

func test_crusty_armor_reduces_physical():
	var defender = BattleFactory.creature({"ability_id": "crusty_armor"})
	var move = MockMove.physical(50, "spicy")
	var result = AbilityEffects.on_defend(defender, move, 100)
	assert_eq(result.damage, 80)

func test_herbivore_heals_from_herbal():
	var defender = BattleFactory.creature({"ability_id": "herbivore", "hp": 30, "max_hp": 80})
	var move = MockMove.physical(50, "herbal")
	var result = AbilityEffects.on_defend(defender, move, 100)
	assert_eq(result.damage, 0) # absorbed
	assert_eq(result.heal, 20) # 80 * 0.25
	assert_eq(defender["hp"], 50) # 30 + 20

func test_flavor_absorb_heals_from_sweet():
	var defender = BattleFactory.creature({"ability_id": "flavor_absorb", "hp": 30, "max_hp": 80})
	var move = MockMove.special(50, "sweet")
	var result = AbilityEffects.on_defend(defender, move, 100)
	assert_eq(result.damage, 0)
	assert_eq(defender["hp"], 50)

func test_herbivore_no_effect_other_type():
	var defender = BattleFactory.creature({"ability_id": "herbivore", "hp": 30, "max_hp": 80})
	var move = MockMove.physical(50, "spicy")
	var result = AbilityEffects.on_defend(defender, move, 100)
	assert_eq(result.damage, 100)
	assert_eq(defender["hp"], 30)

# --- on_status_attempt ---

func test_sugar_coat_blocks_status():
	var c = BattleFactory.creature({"ability_id": "sugar_coat"})
	var result = AbilityEffects.on_status_attempt(c, "burned")
	assert_true(result.blocked)

func test_sugar_coat_does_not_block_stat_drop():
	var c = BattleFactory.creature({"ability_id": "sugar_coat"})
	var result = AbilityEffects.on_status_attempt(c, "stat_drop")
	assert_false(result.blocked)

func test_firm_press_blocks_stat_drop():
	var c = BattleFactory.creature({"ability_id": "firm_press"})
	var result = AbilityEffects.on_status_attempt(c, "stat_drop")
	assert_true(result.blocked)

func test_firm_press_does_not_block_status():
	var c = BattleFactory.creature({"ability_id": "firm_press"})
	var result = AbilityEffects.on_status_attempt(c, "burned")
	assert_false(result.blocked)

func test_no_ability_does_not_block():
	var c = BattleFactory.creature({"ability_id": ""})
	var result = AbilityEffects.on_status_attempt(c, "burned")
	assert_false(result.blocked)

# --- end_of_turn ---

func test_starter_culture_heals():
	var c = BattleFactory.creature({"ability_id": "starter_culture", "hp": 60, "max_hp": 80})
	var heal = AbilityEffects.end_of_turn(c, "")
	assert_eq(heal, 5) # 80 * 0.0625 = 5
	assert_eq(c["hp"], 65)

func test_starter_culture_min_one_heal():
	var c = BattleFactory.creature({"ability_id": "starter_culture", "hp": 5, "max_hp": 8})
	var heal = AbilityEffects.end_of_turn(c, "")
	assert_eq(heal, 1) # max(1, 8*0.0625=0) = 1

func test_mycelium_net_heals_in_umami():
	var c = BattleFactory.creature({"ability_id": "mycelium_net", "hp": 60, "max_hp": 80})
	var heal = AbilityEffects.end_of_turn(c, "umami")
	assert_eq(heal, 5)
	assert_eq(c["hp"], 65)

func test_mycelium_net_no_heal_without_umami():
	var c = BattleFactory.creature({"ability_id": "mycelium_net", "hp": 60, "max_hp": 80})
	var heal = AbilityEffects.end_of_turn(c, "")
	assert_eq(heal, 0)
	assert_eq(c["hp"], 60)

func test_photosynthesis_heals_in_herbal():
	var c = BattleFactory.creature({"ability_id": "photosynthesis", "hp": 60, "max_hp": 80})
	var heal = AbilityEffects.end_of_turn(c, "herbal")
	assert_eq(heal, 10) # 80 * 0.125
	assert_eq(c["hp"], 70)

func test_photosynthesis_no_heal_without_herbal():
	var c = BattleFactory.creature({"ability_id": "photosynthesis", "hp": 60, "max_hp": 80})
	var heal = AbilityEffects.end_of_turn(c, "spicy")
	assert_eq(heal, 0)

func test_no_ability_no_heal():
	var c = BattleFactory.creature({"ability_id": "", "hp": 60, "max_hp": 80})
	assert_eq(AbilityEffects.end_of_turn(c, "umami"), 0)

func test_heal_does_not_exceed_max_hp():
	var c = BattleFactory.creature({"ability_id": "starter_culture", "hp": 79, "max_hp": 80})
	AbilityEffects.end_of_turn(c, "")
	assert_eq(c["hp"], 80) # capped at max_hp

# --- on_weather ---

func test_fermentation_doubles_speed_in_sour():
	var c = BattleFactory.creature({"ability_id": "fermentation"})
	var result = AbilityEffects.on_weather(c, "sour")
	assert_eq(result.get("speed_multiplier"), 2.0)

func test_fermentation_no_effect_other_weather():
	var c = BattleFactory.creature({"ability_id": "fermentation"})
	var result = AbilityEffects.on_weather(c, "spicy")
	assert_false(result.has("speed_multiplier"))

func test_no_ability_on_weather():
	var c = BattleFactory.creature({"ability_id": ""})
	var result = AbilityEffects.on_weather(c, "sour")
	assert_eq(result.size(), 0)
