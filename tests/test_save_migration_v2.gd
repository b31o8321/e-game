extends GutTest

## SaveSystem._migrate_save (v1 → v2) 单元测试
##
## 验证：
##   - 旧字段 current_deck 重命名到 enabled_library_card_ids
##   - hand-retention 相关字段被清理
##   - save_version 写入 2
##   - 重复调用幂等
##   - 缺失 save_version 字段视为 v1

const SaveSystem = preload("res://src/core/systems/save_system.gd")


func test_migrate_v1_to_v2_renames_deck_to_library() -> void:
	var s := SaveSystem.new()
	add_child_autofree(s)
	var old_data: Dictionary = {
		"save_version": 1,
		"current_deck": ["card_brave", "card_kind"],
		"retained_card_ids": ["card_brave"],
		"unlocked_card_ids": ["card_brave", "card_kind", "card_happy"],
	}
	var migrated: Dictionary = s._migrate_save(old_data)
	assert_eq(int(migrated.save_version), 2, "save_version bumped to 2")
	assert_true(migrated.has("enabled_library_card_ids"), "new field present")
	assert_eq(migrated.enabled_library_card_ids.size(), 2, "library has 2 cards")
	assert_false(migrated.has("retained_card_ids"), "retained_card_ids removed")


func test_migrate_v2_is_noop() -> void:
	var s := SaveSystem.new()
	add_child_autofree(s)
	var current: Dictionary = {
		"save_version": 2,
		"enabled_library_card_ids": ["card_a"],
		"unlocked_card_ids": ["card_a"],
	}
	var migrated: Dictionary = s._migrate_save(current.duplicate(true))
	assert_eq(int(migrated.save_version), 2, "version stays at 2")
	assert_eq(migrated.enabled_library_card_ids.size(), 1, "library untouched")


func test_migrate_idempotent() -> void:
	var s := SaveSystem.new()
	add_child_autofree(s)
	var old_data: Dictionary = {
		"save_version": 1,
		"current_deck": ["a"],
		"unlocked_card_ids": ["a"],
	}
	var once: Dictionary = s._migrate_save(old_data.duplicate(true))
	var twice: Dictionary = s._migrate_save(once.duplicate(true))
	assert_eq(once, twice, "calling migrate twice yields the same dict")


func test_migrate_missing_version_treated_as_v1() -> void:
	var s := SaveSystem.new()
	add_child_autofree(s)
	var data: Dictionary = {"current_deck": ["a"]}
	var migrated: Dictionary = s._migrate_save(data)
	assert_eq(int(migrated.save_version), 2, "missing version treated as v1, bumped")
	assert_true(migrated.has("enabled_library_card_ids"), "library field present")
