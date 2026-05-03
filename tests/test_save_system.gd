extends GutTest

var save_sys: SaveSystem

func before_each():
	save_sys = SaveSystem.new()
	add_child_autofree(save_sys)
	save_sys.save_path = "user://test_save.json"

func after_each():
	if FileAccess.file_exists("user://test_save.json"):
		DirAccess.remove_absolute("user://test_save.json")

func test_save_and_load_roundtrip():
	var data: Dictionary = { "player_hp": 80, "combo": 5, "unlocked": ["past_tense"] }
	save_sys.save(data)
	var loaded: Dictionary = save_sys.load_save()
	assert_eq(loaded["player_hp"], 80)
	assert_eq(loaded["unlocked"][0], "past_tense")

func test_load_returns_empty_when_no_file():
	var loaded: Dictionary = save_sys.load_save()
	assert_eq(loaded, {})
