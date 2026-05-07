## test_save_defaults — verify SaveSystem includes 0F + 1F as default unlocked floors.
##
## Background: the user reported that 0F (alphabet floor / tutorial) was locked at game start.
## SaveSystem now both:
##   1. Migrates legacy saves missing the field, by appending defaults.
##   2. Treats absent field as full default.
extends GutTest

const SAVES_DIR := "user://saves"
const ACTIVE_CFG := "user://saves/active.cfg"

var save_sys: SaveSystem


func before_each() -> void:
	save_sys = SaveSystem.new()
	add_child_autofree(save_sys)
	save_sys.set_active_pack_id("test_unlock_pack")


func after_each() -> void:
	_remove_if_exists(SAVES_DIR + "/test_unlock_pack.json")
	_remove_if_exists(ACTIVE_CFG)


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_default_unlocked_floors_constant() -> void:
	# Spec: 0F (tutorial) + 1F unlocked from start; 2F unlocks after 1F boss.
	assert_true("0F" in SaveSystem.DEFAULT_UNLOCKED_FLOOR_IDS, "0F should be default-unlocked")
	assert_true("1F" in SaveSystem.DEFAULT_UNLOCKED_FLOOR_IDS, "1F should be default-unlocked")
	assert_false("2F" in SaveSystem.DEFAULT_UNLOCKED_FLOOR_IDS, "2F should NOT be default-unlocked")


func test_load_migrates_save_without_unlocked_floor_ids() -> void:
	# Simulate a legacy save lacking the field.
	save_sys.save_game_state({"player_hp": 80})
	var loaded: Dictionary = save_sys.load_game_state()
	var arr: Variant = loaded.get("unlocked_floor_ids", [])
	assert_true(arr is Array)
	assert_true("0F" in arr, "migration should add 0F: got %s" % str(arr))
	assert_true("1F" in arr, "migration should add 1F: got %s" % str(arr))


func test_load_migrates_save_with_only_1f() -> void:
	# Existing save has only 1F (the buggy state user reported).
	save_sys.save_game_state({"unlocked_floor_ids": ["1F"]})
	var loaded: Dictionary = save_sys.load_game_state()
	var arr: Variant = loaded.get("unlocked_floor_ids", [])
	assert_true(arr is Array)
	assert_true("0F" in arr, "0F should be backfilled")
	assert_true("1F" in arr, "1F preserved")


func test_load_does_not_clobber_existing_unlocks() -> void:
	# Player has already unlocked 0F, 1F, 2F (e.g. beat 1F boss).
	save_sys.save_game_state({"unlocked_floor_ids": ["0F", "1F", "2F"]})
	var loaded: Dictionary = save_sys.load_game_state()
	var arr: Array = loaded.get("unlocked_floor_ids", [])
	assert_true("0F" in arr)
	assert_true("1F" in arr)
	assert_true("2F" in arr, "should not lose 2F unlock")
	# No duplicates
	var seen: Dictionary = {}
	for v in arr:
		assert_false(seen.has(v), "duplicate floor id: %s" % str(v))
		seen[v] = true


func test_migration_persists_to_disk() -> void:
	# Write old-style save, then load (triggers migration), then re-read raw file
	# and verify the migrated state was persisted.
	save_sys.save_game_state({"unlocked_floor_ids": ["1F"]})
	save_sys.load_game_state()  # triggers migration + write-back
	var raw: FileAccess = FileAccess.open("user://saves/test_unlock_pack.json", FileAccess.READ)
	assert_not_null(raw)
	var parsed: Variant = JSON.parse_string(raw.get_as_text())
	raw.close()
	assert_true(parsed is Dictionary)
	var arr: Array = (parsed as Dictionary).get("unlocked_floor_ids", [])
	assert_true("0F" in arr, "migrated state should be persisted to disk")
	assert_true("1F" in arr)
