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
