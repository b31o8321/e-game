## test_sfx_wired.gd — Slice 9: SFX 文件存在性验证
##
## 验证 res://assets/audio/sfx/<name>.ogg 文件都已就位。
## 不需要真播音，只用 FileAccess.file_exists 检查。
extends GutTest

const SFX_DIR := "res://assets/audio/sfx/"

func _assert_sfx(name: String) -> void:
	var path := SFX_DIR + name + ".ogg"
	assert_true(FileAccess.file_exists(path), "Missing SFX file: " + path)


func test_card_pickup_exists() -> void:
	_assert_sfx("card_pickup")


func test_card_drop_success_exists() -> void:
	_assert_sfx("card_drop_success")


func test_card_drop_fail_exists() -> void:
	_assert_sfx("card_drop_fail")


func test_damage_hit_exists() -> void:
	_assert_sfx("damage_hit")


func test_combo_3_exists() -> void:
	_assert_sfx("combo_3")


func test_combo_perfect_exists() -> void:
	_assert_sfx("combo_perfect")


func test_heal_exists() -> void:
	_assert_sfx("heal")


func test_shield_exists() -> void:
	_assert_sfx("shield")


func test_submit_swoosh_exists() -> void:
	_assert_sfx("submit_swoosh")


func test_enemy_defeated_exists() -> void:
	_assert_sfx("enemy_defeated")


func test_button_click_exists() -> void:
	_assert_sfx("button_click")
