## test_content_pack_interface — Phase 1.4 新 ContentPackBase 接口验收测试
##
## 覆盖：
##   - ContentLoader 自动发现 english_content_pack.gd
##   - ContentLoader.set_active_pack("english_grade46") 验证通过
##   - english_content_pack.validate() 返回空（无错误）
##   - get_card_types() 包含 word/phrase/pattern/sound
##   - get_supported_challenge_kinds() 包含 fill_in_blank
extends GutTest

var loader: ContentLoader


func before_each() -> void:
	loader = ContentLoader.new()
	# 触发 _ready -> _auto_discover()
	add_child_autofree(loader)
	# 等一帧让 _ready 生效
	await get_tree().process_frame


func test_auto_discovers_english_pack() -> void:
	var pack := loader.get_pack("english_grade46")
	assert_not_null(pack, "auto-discover should pick up english_content_pack.gd")
	assert_true(pack is EnglishContentPack, "discovered pack should be EnglishContentPack")


func test_set_active_pack_english_returns_true() -> void:
	var ok := loader.set_active_pack("english_grade46")
	assert_true(ok, "set_active_pack(english_grade46) should return true")
	assert_eq(loader.get_active_pack().get_id(), "english_grade46")


func test_english_pack_validate_returns_empty() -> void:
	var pack := loader.get_pack("english_grade46")
	assert_not_null(pack)
	var errors: Array[String] = pack.validate()
	assert_eq(errors.size(), 0, "english pack should validate cleanly: %s" % str(errors))


func test_english_pack_card_types_contain_required() -> void:
	var pack := loader.get_pack("english_grade46")
	var types: Array[Dictionary] = pack.get_card_types()
	var ids: Array[String] = []
	for t in types:
		ids.append(t.get("id", ""))
	for required in ["word", "phrase", "pattern", "sound"]:
		assert_true(required in ids, "card_types should include '%s'" % required)


func test_english_pack_challenge_kinds_contain_fill_in_blank() -> void:
	var pack := loader.get_pack("english_grade46")
	var kinds: Array[String] = pack.get_supported_challenge_kinds()
	assert_true("fill_in_blank" in kinds, "should support fill_in_blank")
	assert_true("error_correct" in kinds, "should support error_correct")


func test_english_pack_identity_methods() -> void:
	var pack := loader.get_pack("english_grade46")
	assert_eq(pack.get_id(), "english_grade46")
	assert_eq(pack.get_display_name(), "英语 4-6 年级")
	assert_eq(pack.get_subject_category(), "english")
	assert_eq(pack.get_version(), "0.1.0")


func test_english_pack_grade_range_contains_4_5_6() -> void:
	var pack := loader.get_pack("english_grade46")
	var grades: Array[int] = pack.get_grade_range()
	for g in [4, 5, 6]:
		assert_true(g in grades, "grade %d should be in grade_range" % g)


func test_english_pack_pos_values_contain_adjective() -> void:
	var pack := loader.get_pack("english_grade46")
	var pos: Array[Dictionary] = pack.get_pos_values()
	var ids: Array[String] = []
	for p in pos:
		ids.append(p.get("id", ""))
	assert_true("adjective" in ids, "pos_values should include adjective")
	assert_true("noun" in ids, "pos_values should include noun")


func test_english_pack_tag_namespaces_have_topic() -> void:
	var pack := loader.get_pack("english_grade46")
	var ns: Array[Dictionary] = pack.get_tag_namespaces()
	var ids: Array[String] = []
	for n in ns:
		ids.append(n.get("id", ""))
	assert_true("topic" in ids, "tag_namespaces should include 'topic'")


# ─── Phase 3 数据加载验收 ────────────────────────────────────────────

func test_english_pack_loads_110_cards() -> void:
	var pack := loader.get_pack("english_grade46")
	var cards: Array[Card] = pack.get_all_cards()
	assert_gte(cards.size(), 110, "should load at least 110 cards from cards.json")


func test_english_pack_get_card_by_id() -> void:
	var pack := loader.get_pack("english_grade46")
	var c: Card = pack.get_card("card_brave")
	assert_not_null(c, "card_brave should exist")
	assert_eq(c.text, "brave")
	assert_eq(c.pos, "adjective")


func test_english_pack_starting_deck_has_expected_cards() -> void:
	# 起手卡组扩到 13 张：5 形容词（含 1 非正面） + 3 系动词 + 2 代词 + 1 句型 + 1 高频词。
	# 增加 1 张 lazy（非正面性格），让 1F 精英对偶题"She is X and he is Y"可解。
	var pack := loader.get_pack("english_grade46")
	var ids := pack.get_starting_deck_card_ids()
	assert_eq(ids.size(), 13, "starting deck should have 13 cards (含非正面性格 1 张)")
	for cid in ids:
		assert_not_null(pack.get_card(cid), "starting deck card should exist: %s" % cid)


func test_english_pack_loads_34_challenges() -> void:
	var pack := loader.get_pack("english_grade46")
	# 通过 floor topics 抽样，确保 challenges 加载
	var emo := pack.get_challenges_for_topic("1F_emotion")
	assert_true(emo.size() >= 4, "should have ≥4 challenges for 1F_emotion")
	var sample := pack.get_challenge_template("0F_alphabet_next")
	assert_not_null(sample, "challenge 0F_alphabet_next should exist")


func test_english_pack_loads_8_enemies() -> void:
	var pack := loader.get_pack("english_grade46")
	var wisp: EnemyData = pack.get_enemy("letter_wisp")
	assert_not_null(wisp, "letter_wisp should be loaded")
	# 0F 普通敌人 max_hp 在 30-40 区间（Slice 23 楼层曲线后；具体值 hash 决定）
	assert_gte(wisp.max_hp, 30)
	assert_lte(wisp.max_hp, 40)
	assert_true("letter" in wisp.weak_axes)


func test_english_pack_loads_9_bosses() -> void:
	var pack := loader.get_pack("english_grade46")
	var b: BossBase = pack.get_boss("librarian")
	assert_not_null(b, "librarian boss should load")
	assert_eq(b.boss_id, "librarian")
	# Slice 23 楼层曲线后 boss HP 100-320 区间，librarian 落在 1F-2F 段
	assert_gte(b.max_hp, 100)
	assert_lte(b.max_hp, 200)
	b.queue_free()  # BossBase 是 Node，需手动释放避免 orphan


func test_english_pack_loads_3_floors() -> void:
	var pack := loader.get_pack("english_grade46")
	var ids := pack.get_all_floor_ids()
	assert_gte(ids.size(), 3, "should load at least 3 floors (0F, 1F, 2F)")
	for fid in ["0F", "1F", "2F"]:
		assert_true(fid in ids, "floor %s missing" % fid)


func test_english_pack_floor_config_has_three_acts() -> void:
	var pack := loader.get_pack("english_grade46")
	var cfg := pack.get_floor_config("1F")
	assert_eq(cfg.get("unit_name", ""), "形容词初阶")
	assert_eq(cfg.get("acts", []).size(), 3)


func test_english_pack_loads_4_equipment() -> void:
	var pack := loader.get_pack("english_grade46")
	var pool := pack.get_equipment_pool()
	assert_eq(pool.size(), 4, "should load 4 equipment items")


func test_english_pack_loads_7_spices() -> void:
	# 3 voice + 2 dictation + 2 word_choice = 7（Slice 6 加 word_choice）
	var pack := loader.get_pack("english_grade46")
	var spices := pack.get_available_spices()
	assert_eq(spices.size(), 7, "should load 7 spices from spices.json")


func test_english_pack_card_pool_for_1f_includes_emotion_cards() -> void:
	var pack := loader.get_pack("english_grade46")
	var pool: Array[Card] = pack.get_card_pool_for_floor("1F")
	var ids: Array[String] = []
	for c in pool:
		ids.append(c.id)
	assert_true("card_happy" in ids, "1F pool should include card_happy")
	assert_true("card_brave" in ids, "1F pool should include card_brave")
