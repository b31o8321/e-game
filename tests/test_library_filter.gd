## T5: Smart context filter — 选中题后卡库按 slot type/pos 自动过滤。
##
## 关键设计：过滤只看 required_type + required_pos（粗匹配），
## 故意不看 accept_card_ids / required_tags（精匹配 = 暴露答案）。
extends GutTest

const Card = preload("res://src/battle/cards/card.gd")
const ChallengeTemplate = preload("res://src/battle/cards/challenge_template.gd")
const ChallengeSlot = preload("res://src/battle/cards/challenge_slot.gd")
const BattleSceneScene = preload("res://src/battle/battle_scene.tscn")


func _make_card(id: String, type: String = "word", pos: String = "adjective") -> Card:
	var c = Card.new()
	c.id = id
	c.text = id
	c.type = type
	c.pos = pos
	var tags: Array[String] = ["positive_emotion"]
	c.tags = tags
	c.base_damage = 5
	return c


func _make_slot(req_type: String, req_pos: String) -> ChallengeSlot:
	var s = ChallengeSlot.new()
	s.required_type = req_type
	s.required_pos = req_pos
	return s


func test_filter_mode_all_returns_full_library() -> void:
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	# Bypass _controller: directly test the filter helper.
	var lib: Array[Card] = [
		_make_card("a", "word", "adjective"),
		_make_card("b", "word", "noun"),
	]
	s._filter_mode = "all"
	var out: Array[Card] = s._apply_library_filter(lib)
	assert_eq(out.size(), 2, "filter_mode=all should return all cards")


func test_matches_by_type_pos_accepts_adjective_for_adjective_slot() -> void:
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	var slot := _make_slot("word", "adjective")
	var c := _make_card("adj1", "word", "adjective")
	assert_true(s._matches_by_type_pos(c, slot), "adjective word should match adjective slot")


func test_matches_by_type_pos_rejects_noun_for_adjective_slot() -> void:
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	var slot := _make_slot("word", "adjective")
	var c := _make_card("noun1", "word", "noun")
	assert_false(s._matches_by_type_pos(c, slot), "noun should not match adjective slot")


func test_matches_by_type_pos_ignores_required_tags_and_accept_card_ids() -> void:
	# CRITICAL: 过滤层故意不看 required_tags / accept_card_ids，
	# 否则会暴露答案（"哪张卡能放进 slot" = 哪张卡是正确答案）。
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	var slot := _make_slot("word", "adjective")
	var pos_tags: Array[String] = ["positive_emotion"]
	slot.required_tags = pos_tags
	slot.accept_card_ids = ["card_brave"]
	# 用一张"消极情绪"的形容词——按 required_tags 不应进，
	# 但 _matches_by_type_pos 只看 type+pos，应该通过。
	var c := _make_card("card_lazy", "word", "adjective")
	var neg_tags: Array[String] = ["negative_personality"]
	c.tags = neg_tags
	assert_true(
		s._matches_by_type_pos(c, slot),
		"filter must not leak answers via required_tags/accept_card_ids"
	)


func test_apply_library_filter_candidate_filters_by_slot_pos() -> void:
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	# 用真 BattleController（_controller 字段是 typed BattleController），
	# 直接塞入 available_challenges 即可。
	var ctrl := BattleController.new()
	add_child_autofree(ctrl)
	var tmpl := ChallengeTemplate.new()
	tmpl.template_id = "t1"
	tmpl.slots = [_make_slot("word", "adjective")]
	var available: Array[ChallengeTemplate] = [tmpl]
	ctrl.available_challenges = available
	ctrl.selected_challenge_index = 0
	s._controller = ctrl
	s._filter_mode = "candidate"

	var lib: Array[Card] = [
		_make_card("adj1", "word", "adjective"),
		_make_card("noun1", "word", "noun"),
		_make_card("adj2", "word", "adjective"),
	]
	var out: Array[Card] = s._apply_library_filter(lib)
	assert_eq(out.size(), 2, "should keep only the 2 adjectives")
	assert_true(out[0].pos == "adjective" and out[1].pos == "adjective")


func test_apply_library_filter_returns_all_when_no_challenge_selected() -> void:
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	var ctrl := BattleController.new()
	add_child_autofree(ctrl)
	# 没有 available_challenges → _get_selected_challenge() 返回 null。
	ctrl.selected_challenge_index = -1
	s._controller = ctrl
	s._filter_mode = "candidate"
	var lib: Array[Card] = [_make_card("a"), _make_card("b", "word", "noun")]
	var out: Array[Card] = s._apply_library_filter(lib)
	assert_eq(out.size(), 2, "no selected challenge → fall back to full library")


func test_hand_row_is_hflow_container() -> void:
	# T4：HandRow 从 HBoxContainer 改为 HFlowContainer（容纳 10-15 张卡换行）。
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	var hand_row = s.get_node_or_null("HandRow")
	assert_not_null(hand_row, "HandRow must exist")
	assert_true(hand_row is HFlowContainer, "HandRow should be an HFlowContainer for wrap")


func test_hand_label_row_has_filter_toggle() -> void:
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	var btn = s.get_node_or_null("HandLabelRow/FilterToggle")
	assert_not_null(btn, "FilterToggle button should exist in HandLabelRow")
