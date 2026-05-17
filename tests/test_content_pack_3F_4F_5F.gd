extends GutTest

var _pack: EnglishContentPack

func before_each() -> void:
	_pack = EnglishContentPack.new()
	add_child(_pack)
	GameState.player_grade = 5

func after_each() -> void:
	_pack.queue_free()

# ── 3F 楼层配置 ───────────────────────────────────────────────────────

func test_3F_floor_config_not_empty() -> void:
	var cfg: Dictionary = _pack.get_floor_config("3F")
	assert_false(cfg.is_empty(), "3F floor config should not be empty")

func test_3F_floor_config_has_acts() -> void:
	var cfg: Dictionary = _pack.get_floor_config("3F")
	var acts: Array = cfg.get("acts", [])
	assert_eq(acts.size(), 3, "3F should have 3 acts")

func test_3F_starting_deck_length() -> void:
	var ids: Array[String] = _pack.get_starting_deck_for_floor("3F")
	assert_gte(ids.size(), 10, "3F starting deck should have >= 10 cards")

func test_3F_new_verb_card_exists() -> void:
	var card: Card = _pack.get_card("card_verb_run")
	assert_not_null(card, "card_verb_run should exist in cards.json")

func test_3F_verb_cards_all_exist() -> void:
	var verb_ids: Array[String] = [
		"card_verb_run", "card_verb_eat", "card_verb_play",
		"card_verb_swim", "card_verb_read", "card_verb_write",
		"card_verb_go", "card_verb_like",
	]
	for cid in verb_ids:
		var card: Card = _pack.get_card(cid)
		assert_not_null(card, "verb card should exist: %s" % cid)

func test_3F_enemy_pool_not_empty() -> void:
	var pool: Array = _pack.get_enemy_pool_for_floor("3F")
	assert_gt(pool.size(), 0, "3F enemy pool should not be empty")

# ── 4F 楼层配置 ───────────────────────────────────────────────────────

func test_4F_floor_config_not_empty() -> void:
	var cfg: Dictionary = _pack.get_floor_config("4F")
	assert_false(cfg.is_empty(), "4F floor config should not be empty")

func test_4F_floor_config_has_acts() -> void:
	var cfg: Dictionary = _pack.get_floor_config("4F")
	var acts: Array = cfg.get("acts", [])
	assert_eq(acts.size(), 3, "4F should have 3 acts")

func test_4F_starting_deck_length() -> void:
	var ids: Array[String] = _pack.get_starting_deck_for_floor("4F")
	assert_gte(ids.size(), 10, "4F starting deck should have >= 10 cards")

func test_4F_number_cards_all_exist() -> void:
	var num_ids: Array[String] = [
		"card_num_one", "card_num_two", "card_num_three", "card_num_four",
		"card_num_five", "card_num_six", "card_num_seven", "card_num_eight",
		"card_num_nine", "card_num_ten",
	]
	for cid in num_ids:
		var card: Card = _pack.get_card(cid)
		assert_not_null(card, "number card should exist: %s" % cid)

func test_4F_time_cards_exist() -> void:
	assert_not_null(_pack.get_card("card_time_morning"), "card_time_morning should exist")
	assert_not_null(_pack.get_card("card_time_afternoon"), "card_time_afternoon should exist")

func test_4F_enemy_pool_not_empty() -> void:
	var pool: Array = _pack.get_enemy_pool_for_floor("4F")
	assert_gt(pool.size(), 0, "4F enemy pool should not be empty")

# ── 5F 楼层配置 ───────────────────────────────────────────────────────

func test_5F_floor_config_not_empty() -> void:
	var cfg: Dictionary = _pack.get_floor_config("5F")
	assert_false(cfg.is_empty(), "5F floor config should not be empty")

func test_5F_floor_config_has_acts() -> void:
	var cfg: Dictionary = _pack.get_floor_config("5F")
	var acts: Array = cfg.get("acts", [])
	assert_eq(acts.size(), 3, "5F should have 3 acts")

func test_5F_starting_deck_length() -> void:
	var ids: Array[String] = _pack.get_starting_deck_for_floor("5F")
	assert_gte(ids.size(), 10, "5F starting deck should have >= 10 cards")

func test_5F_enemy_pool_not_empty() -> void:
	var pool: Array = _pack.get_enemy_pool_for_floor("5F")
	assert_gt(pool.size(), 0, "5F enemy pool should not be empty")

# ── challenges.json 总量 ──────────────────────────────────────────────

func test_challenges_total_count_gte_80() -> void:
	# challenges.json 原有 50 题 + 新增 36 题 = 86 题，
	# 用行数代理（每题约 14 行）— 改为直接统计 get_challenge 可用数
	# 用文件读取方式验证 template_id 总数
	var file: FileAccess = FileAccess.open(
		"res://src/content/english/data/challenges.json", FileAccess.READ)
	assert_not_null(file, "challenges.json should be readable")
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var count: int = text.count("\"template_id\"")
	assert_gte(count, 80, "challenges.json should have >= 80 template_ids, got %d" % count)
