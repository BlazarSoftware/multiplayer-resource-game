extends GutTest

# Tests for CharacterAssembler constants and helper logic.
# Full assembly and fallback tests are deferred to MCP integration tests
# since they require Godot-imported GLB files (headless GUT cannot import).

func test_part_categories_keys():
	# Verify PART_CATEGORIES maps all expected categories
	var cats := CharacterAssembler.PART_CATEGORIES
	assert_eq(cats["head"], "head_id")
	assert_eq(cats["hair"], "hair_id")
	assert_eq(cats["torso"], "torso_id")
	assert_eq(cats["pants"], "pants_id")
	assert_eq(cats["shoes"], "shoes_id")
	assert_eq(cats["arms"], "arms_id")
	assert_eq(cats["hats"], "hat_id")
	assert_eq(cats["glasses"], "glasses_id")
	assert_eq(cats["beard"], "beard_id")
	assert_eq(cats.size(), 9, "Should have 9 part categories")


func test_mannequin_fallback_path_defined():
	assert_ne(CharacterAssembler.MANNEQUIN_FALLBACK, "",
		"Fallback path must be defined")
	assert_true(CharacterAssembler.MANNEQUIN_FALLBACK.begins_with("res://"),
		"Fallback path must start with res://")


func test_part_categories_match_registry():
	# Assembler and Registry should agree on category->key mappings
	for category in CharacterAssembler.PART_CATEGORIES:
		var assembler_key: String = CharacterAssembler.PART_CATEGORIES[category]
		var registry_key: String = CharacterPartRegistry.CATEGORY_KEYS.get(category, "")
		assert_eq(assembler_key, registry_key,
			"Assembler and Registry disagree on key for category: " + category)
