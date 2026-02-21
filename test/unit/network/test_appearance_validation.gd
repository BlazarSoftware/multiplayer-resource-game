extends GutTest

# Tests for appearance validation logic (mirrors NetworkManager._validate_appearance)
# We test the same logic inline since NetworkManager is an autoload and its
# methods aren't easily callable in unit tests.

func _validate_appearance(app: Dictionary) -> bool:
	var gender: String = app.get("gender", "")
	if gender != "female" and gender != "male":
		return false
	for required_key in ["head_id", "torso_id", "pants_id", "shoes_id"]:
		var val: String = app.get(required_key, "")
		if val == "":
			return false
	return true


func test_valid_appearance_female():
	var app := {
		"gender": "female",
		"head_id": "HEAD_01_1",
		"torso_id": "TORSO_01_1",
		"pants_id": "PANTS_01_1",
		"shoes_id": "SHOES_01_1",
	}
	assert_true(_validate_appearance(app))


func test_valid_appearance_male():
	var app := {
		"gender": "male",
		"head_id": "HEAD_02_1",
		"torso_id": "TORSO_03_1",
		"pants_id": "PANTS_02_1",
		"shoes_id": "SHOES_02_1",
	}
	assert_true(_validate_appearance(app))


func test_missing_gender_fails():
	var app := {
		"head_id": "HEAD_01_1",
		"torso_id": "TORSO_01_1",
		"pants_id": "PANTS_01_1",
		"shoes_id": "SHOES_01_1",
	}
	assert_false(_validate_appearance(app), "Missing gender should fail")


func test_invalid_gender_fails():
	var app := {
		"gender": "robot",
		"head_id": "HEAD_01_1",
		"torso_id": "TORSO_01_1",
		"pants_id": "PANTS_01_1",
		"shoes_id": "SHOES_01_1",
	}
	assert_false(_validate_appearance(app), "Invalid gender should fail")


func test_empty_gender_fails():
	var app := {
		"gender": "",
		"head_id": "HEAD_01_1",
		"torso_id": "TORSO_01_1",
		"pants_id": "PANTS_01_1",
		"shoes_id": "SHOES_01_1",
	}
	assert_false(_validate_appearance(app), "Empty gender should fail")


func test_missing_head_id_fails():
	var app := {
		"gender": "female",
		"torso_id": "TORSO_01_1",
		"pants_id": "PANTS_01_1",
		"shoes_id": "SHOES_01_1",
	}
	assert_false(_validate_appearance(app), "Missing head_id should fail")


func test_empty_head_id_fails():
	var app := {
		"gender": "female",
		"head_id": "",
		"torso_id": "TORSO_01_1",
		"pants_id": "PANTS_01_1",
		"shoes_id": "SHOES_01_1",
	}
	assert_false(_validate_appearance(app), "Empty head_id should fail")


func test_missing_torso_id_fails():
	var app := {
		"gender": "female",
		"head_id": "HEAD_01_1",
		"pants_id": "PANTS_01_1",
		"shoes_id": "SHOES_01_1",
	}
	assert_false(_validate_appearance(app), "Missing torso_id should fail")


func test_missing_pants_id_fails():
	var app := {
		"gender": "female",
		"head_id": "HEAD_01_1",
		"torso_id": "TORSO_01_1",
		"shoes_id": "SHOES_01_1",
	}
	assert_false(_validate_appearance(app), "Missing pants_id should fail")


func test_missing_shoes_id_fails():
	var app := {
		"gender": "female",
		"head_id": "HEAD_01_1",
		"torso_id": "TORSO_01_1",
		"pants_id": "PANTS_01_1",
	}
	assert_false(_validate_appearance(app), "Missing shoes_id should fail")


func test_optional_parts_can_be_empty():
	var app := {
		"gender": "female",
		"head_id": "HEAD_01_1",
		"torso_id": "TORSO_01_1",
		"pants_id": "PANTS_01_1",
		"shoes_id": "SHOES_01_1",
		"hair_id": "",
		"arms_id": "",
		"hat_id": "",
		"glasses_id": "",
	}
	assert_true(_validate_appearance(app), "Optional parts can be empty")


func test_male_with_beard_passes():
	var app := {
		"gender": "male",
		"head_id": "HEAD_01_1",
		"torso_id": "TORSO_01_1",
		"pants_id": "PANTS_01_1",
		"shoes_id": "SHOES_01_1",
		"beard_id": "BEARD_01_1",
	}
	assert_true(_validate_appearance(app))


func test_empty_dict_fails():
	assert_false(_validate_appearance({}), "Empty dict should fail")


func test_extra_keys_ignored():
	var app := {
		"gender": "female",
		"head_id": "HEAD_01_1",
		"torso_id": "TORSO_01_1",
		"pants_id": "PANTS_01_1",
		"shoes_id": "SHOES_01_1",
		"needs_customization": true,
		"unknown_key": "whatever",
	}
	assert_true(_validate_appearance(app), "Extra keys should be ignored")
