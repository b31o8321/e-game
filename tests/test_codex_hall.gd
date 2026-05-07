## test_codex_hall — verify lore_title lookup + replay panel resolution.
##
## We test EnglishContentPack.get_lore_title / get_panels_containing_lore directly
## (CodexHallController is UI; covered indirectly).
extends GutTest

var loader: ContentLoader


func before_each() -> void:
	loader = ContentLoader.new()
	add_child_autofree(loader)
	await get_tree().process_frame


func test_get_lore_title_returns_friendly_name_for_intro() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	assert_not_null(pack)
	var title: String = pack.get_lore_title("lore_intro_1")
	assert_ne(title, "lore_intro_1", "should not return raw id when title is mapped")
	assert_true(title.contains("序章"), "intro title should mention 序章")


func test_get_lore_title_returns_friendly_for_floor_intro() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var title: String = pack.get_lore_title("lore_0f_intro_1")
	assert_true(title.contains("0F"), "0F intro title should contain 0F: %s" % title)


func test_get_lore_title_falls_back_to_id_when_unknown() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var unknown_id: String = "lore_does_not_exist_xyz"
	assert_eq(pack.get_lore_title(unknown_id), unknown_id, "should fall back to id")


func test_get_panels_containing_lore_returns_intro_set() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var panels: Array[CutscenePanel] = pack.get_panels_containing_lore("lore_intro_3")
	assert_gt(panels.size(), 0, "should find panels for lore_intro_3")
	# 重播整段：应该能找到原 lore_id 在面板列表中
	var found_ids: Array[String] = []
	for p in panels:
		found_ids.append(p.lore_codex_id)
	assert_true("lore_intro_3" in found_ids, "panel set should include the queried id")


func test_get_panels_containing_lore_for_boss_dialogue() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var panels: Array[CutscenePanel] = pack.get_panels_containing_lore("lore_letter_chaos_pre_1")
	assert_gt(panels.size(), 0, "letter_chaos pre dialog should resolve")


func test_get_panels_containing_lore_returns_empty_for_unknown() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var panels: Array[CutscenePanel] = pack.get_panels_containing_lore("lore_unknown_xyz")
	assert_eq(panels.size(), 0, "unknown id should return empty array")


func test_get_panels_containing_lore_handles_empty_string() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var panels: Array[CutscenePanel] = pack.get_panels_containing_lore("")
	assert_eq(panels.size(), 0)


func test_lore_title_for_letter_chaos_post_uses_friendly_name() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var title: String = pack.get_lore_title("lore_letter_chaos_post_1")
	assert_true(title.contains("字母混乱者"), "should display boss display name: %s" % title)
	assert_true(title.contains("觉醒"), "post-fight should be marked 觉醒: %s" % title)
