extends GutTest

const BattleController = preload("res://src/battle/battle_controller.gd")
const Card = preload("res://src/battle/cards/card.gd")
const ChallengeTemplate = preload("res://src/battle/cards/challenge_template.gd")
const ChallengeSlot = preload("res://src/battle/cards/challenge_slot.gd")
const APConnection = preload("res://src/battle/ap_connection.gd")


func _make_card(id: String, dmg: int = 8) -> Card:
	var c = Card.new()
	c.id = id
	c.text = id
	c.type = "word"
	c.pos = "adjective"
	var tags: Array[String] = ["positive_emotion"]
	c.tags = tags
	c.skill = "vocab"
	c.base_damage = dmg
	return c


func _make_template_accepting(template_id: String, accept_card_ids: Array[String]) -> ChallengeTemplate:
	var t = ChallengeTemplate.new()
	t.template_id = template_id
	t.dialogue = "I am ___"
	t.kind = "fill_in_blank"
	t.topic_id = "test_topic"
	var s = ChallengeSlot.new()
	s.required_type = "word"
	s.required_pos = "adjective"
	s.accept_card_ids = accept_card_ids
	var slots: Array[ChallengeSlot] = [s]
	t.slots = slots
	t.effect_type = "damage"
	t.effect_magnitude = 0
	t.perfect_match_card_ids = accept_card_ids
	return t


func _make_template_3slot_accepting(template_id: String, accept_card_ids: Array[String]) -> ChallengeTemplate:
	# 3-slot variant: lets a single challenge absorb 3 connections so we can verify
	# perfect combo across the whole AP queue without running into the index-shift
	# behaviour of submit_challenge (which removes solved challenges mid-loop).
	var t = ChallengeTemplate.new()
	t.template_id = template_id
	t.dialogue = "I am ___ ___ ___"
	t.kind = "fill_in_blank"
	t.topic_id = "test_topic"
	var slots: Array[ChallengeSlot] = []
	for _i in 3:
		var s = ChallengeSlot.new()
		s.required_type = "word"
		s.required_pos = "adjective"
		s.accept_card_ids = accept_card_ids
		slots.append(s)
	t.slots = slots
	t.effect_type = "damage"
	t.effect_magnitude = 0
	t.perfect_match_card_ids = accept_card_ids
	return t


func test_e2e_perfect_combo_grants_next_turn_bonus():
	# 1. Setup BattleController with 1 multi-slot challenge + 3 matching cards.
	# Each card targets a different slot of the same challenge, so when the
	# challenge resolves on the final connection it doesn't disturb earlier
	# connections.
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3
	c.ap_bonus_next_turn = 0

	var card_a = _make_card("card_a")
	var card_b = _make_card("card_b")
	var card_c = _make_card("card_c")
	c.set_hand_for_test([card_a, card_b, card_c])

	var all_ids: Array[String] = ["card_a", "card_b", "card_c"]
	var t1 = _make_template_3slot_accepting("t1", all_ids)
	var chals: Array[ChallengeTemplate] = [t1]
	c.available_challenges = chals
	c.available_filled_slots = [[null, null, null]]

	# Provide minimum deps for submit_challenge path (perfect resolution triggers it)
	var enemy := EnemyData.new()
	enemy.enemy_id = "test_enemy"
	enemy.enemy_name = "Test"
	enemy.max_hp = 100
	enemy.base_attack = 0
	c._enemy = enemy
	c.enemy_hp = 100
	c.enemy_max_hp = 100
	c.set_combo_system(ComboSystem.new())
	c.set_selector(ChallengeSelector.new())

	# 2. Add 3 correct connections to AP queue (one per slot of the same challenge)
	assert_true(c.add_to_ap_queue(card_a, 0, 0))
	assert_true(c.add_to_ap_queue(card_b, 0, 1))
	assert_true(c.add_to_ap_queue(card_c, 0, 2))
	assert_eq(c.ap_queue.size(), 3)

	# 3. Submit all
	c.submit_all_ap()

	# 4. Verify perfect combo
	assert_eq(c.ap_queue.size(), 0, "AP queue cleared")
	assert_eq(c.ap_bonus_next_turn, 1, "Perfect combo grants +1 AP")


func test_e2e_imperfect_no_bonus():
	# Setup with 1 correct + 1 wrong
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3

	var card_correct = _make_card("card_correct")
	var card_wrong = _make_card("card_wrong")
	c.set_hand_for_test([card_correct, card_wrong])

	var correct_ids: Array[String] = ["card_correct"]
	var other_ids: Array[String] = ["card_other"]  # card_wrong not in accept list
	var t1 = _make_template_accepting("t1", correct_ids)
	var t2 = _make_template_accepting("t2", other_ids)
	var chals: Array[ChallengeTemplate] = [t1, t2]
	c.available_challenges = chals
	c.available_filled_slots = [[null], [null]]

	# Provide minimum deps for submit_challenge path
	var enemy := EnemyData.new()
	enemy.enemy_id = "test_enemy"
	enemy.enemy_name = "Test"
	enemy.max_hp = 100
	enemy.base_attack = 0
	c._enemy = enemy
	c.enemy_hp = 100
	c.enemy_max_hp = 100
	c.set_combo_system(ComboSystem.new())
	c.set_selector(ChallengeSelector.new())

	c.add_to_ap_queue(card_correct, 0, 0)
	c.add_to_ap_queue(card_wrong, 1, 0)

	c.submit_all_ap()

	assert_eq(c.ap_queue.size(), 0)
	assert_eq(c.ap_bonus_next_turn, 0, "Imperfect resolution clears bonus")


func test_e2e_reorder_then_submit():
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3

	var card_a = _make_card("card_a")
	var card_b = _make_card("card_b")
	c.set_hand_for_test([card_a, card_b])

	# Both templates accept both cards so reorder + index shift after the first
	# resolution still leaves valid placements for the second connection.
	var both_ids: Array[String] = ["card_a", "card_b"]
	var t1 = _make_template_accepting("t1", both_ids)
	var t2 = _make_template_accepting("t2", both_ids)
	var chals: Array[ChallengeTemplate] = [t1, t2]
	c.available_challenges = chals
	c.available_filled_slots = [[null], [null]]

	# Provide minimum deps for submit_challenge path
	var enemy := EnemyData.new()
	enemy.enemy_id = "test_enemy"
	enemy.enemy_name = "Test"
	enemy.max_hp = 100
	enemy.base_attack = 0
	c._enemy = enemy
	c.enemy_hp = 100
	c.enemy_max_hp = 100
	c.set_combo_system(ComboSystem.new())
	c.set_selector(ChallengeSelector.new())

	c.add_to_ap_queue(card_a, 0, 0)
	c.add_to_ap_queue(card_b, 1, 0)
	# Reorder: swap them
	c.reorder_ap_queue(0, 1)
	# Verify slot indices renumbered
	assert_eq(c.ap_queue[0].slot_index, 0)
	assert_eq(c.ap_queue[1].slot_index, 1)
	# Submit
	c.submit_all_ap()
	assert_eq(c.ap_queue.size(), 0)


func test_e2e_multi_template_perfect_combo():
	# Task 24 regression: with multi-template AP submissions, the original
	# implementation used conn.challenge_index directly. When the first connection
	# resolves and submit_challenge() removes that template from
	# available_challenges, all later indices shift left by one. The 2nd
	# connection then either points to the wrong template (random pass/fail) or
	# out-of-range. Fix: _resolve_connection now looks up the template by
	# preview.template_id (stable id) at resolution time.
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3
	c.ap_bonus_next_turn = 0

	var card_a = _make_card("card_a")
	var card_b = _make_card("card_b")
	c.set_hand_for_test([card_a, card_b])

	# Two separate templates, each with one slot. card_a → t1, card_b → t2.
	var ids_a: Array[String] = ["card_a"]
	var ids_b: Array[String] = ["card_b"]
	var t1 = _make_template_accepting("t_alpha", ids_a)
	var t2 = _make_template_accepting("t_beta", ids_b)
	var chals: Array[ChallengeTemplate] = [t1, t2]
	c.available_challenges = chals
	c.available_filled_slots = [[null], [null]]

	# Min deps for submit_challenge
	var enemy := EnemyData.new()
	enemy.enemy_id = "test_enemy"
	enemy.enemy_name = "Test"
	enemy.max_hp = 100
	enemy.base_attack = 0
	c._enemy = enemy
	c.enemy_hp = 100
	c.enemy_max_hp = 100
	c.set_combo_system(ComboSystem.new())
	c.set_selector(ChallengeSelector.new())

	# Queue: card_a → ch_idx 0 (t_alpha), card_b → ch_idx 1 (t_beta).
	# After 1st resolves, ap_queue[1].challenge_index would point to bad index.
	assert_true(c.add_to_ap_queue(card_a, 0, 0))
	assert_true(c.add_to_ap_queue(card_b, 1, 0))
	c.submit_all_ap()

	# Both templates should have been resolved → board cleared, perfect combo.
	assert_eq(c.ap_queue.size(), 0, "AP queue cleared")
	assert_eq(c.available_challenges.size(), 0, "Both challenges resolved (board empty)")
	assert_eq(c.ap_bonus_next_turn, 1, "Multi-template perfect combo grants +1 AP")


func test_e2e_remove_returns_card_to_hand():
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3

	var card = _make_card("card_x")
	c.set_hand_for_test([card])

	var card_x_ids: Array[String] = ["card_x"]
	var t1 = _make_template_accepting("t1", card_x_ids)
	var chals: Array[ChallengeTemplate] = [t1]
	c.available_challenges = chals
	c.available_filled_slots = [[null]]

	c.add_to_ap_queue(card, 0, 0)
	assert_eq(c.hand.size(), 0)
	c.remove_from_ap_queue(0)
	assert_eq(c.hand.size(), 1)
	assert_eq(c.hand[0].id, "card_x")
