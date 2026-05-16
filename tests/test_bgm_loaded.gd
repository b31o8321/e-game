## test_bgm_loaded — Verifies BGM files exist and are non-trivial in size.
##
## Checks:
##   - All 6 BGM resource paths are resolvable by ResourceLoader
##   - At least 3 files are > 50 KB (not empty placeholders)
##   - No audio files are missing from the bgm directory
extends GutTest


const BGM_PATHS := [
	"res://assets/audio/bgm/battle.ogg",
	"res://assets/audio/bgm/boss.ogg",
	"res://assets/audio/bgm/city.ogg",
	"res://assets/audio/bgm/main_menu.ogg",
	"res://assets/audio/bgm/retreat.ogg",
	"res://assets/audio/bgm/victory.ogg",
]

const MIN_REAL_SIZE_BYTES := 50 * 1024  # 50 KB


func test_all_bgm_paths_exist() -> void:
	for path in BGM_PATHS:
		assert_true(
			ResourceLoader.exists(path),
			"BGM file missing: %s" % path
		)


func test_battle_bgm_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/audio/bgm/battle.ogg"))


func test_boss_bgm_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/audio/bgm/boss.ogg"))


func test_main_menu_bgm_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/audio/bgm/main_menu.ogg"))


func test_victory_bgm_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/audio/bgm/victory.ogg"))


func test_city_bgm_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/audio/bgm/city.ogg"))


func test_retreat_bgm_exists() -> void:
	assert_true(ResourceLoader.exists("res://assets/audio/bgm/retreat.ogg"))


func test_at_least_three_files_are_real_music() -> void:
	var real_count := 0
	for path in BGM_PATHS:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var f := FileAccess.open(abs_path, FileAccess.READ)
			if f:
				var size := f.get_length()
				f.close()
				if size >= MIN_REAL_SIZE_BYTES:
					real_count += 1
	assert_true(
		real_count >= 3,
		"Expected >= 3 BGM files > 50 KB, found %d" % real_count
	)
