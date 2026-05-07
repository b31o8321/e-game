extends GutTest

const BattleController = preload("res://src/battle/battle_controller.gd")
const APConnection = preload("res://src/battle/ap_connection.gd")
const Card = preload("res://src/battle/cards/card.gd")
const ChallengeTemplate = preload("res://src/battle/cards/challenge_template.gd")
const ChallengeSlot = preload("res://src/battle/cards/challenge_slot.gd")
const ComboSystem = preload("res://src/battle/combo_system.gd")
const ChallengeSelector = preload("res://src/battle/challenge_selector.gd")


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


func _make_template(tid: String, dialogue: String, accept_card_ids: Array[String], effect_type: String = "damage", magnitude: int = 0) -> ChallengeTemplate:
	var t = ChallengeTemplate.new()
	t.template_id = tid
	t.dialogue = dialogue
	t.kind = "fill_in_blank"
	t.topic_id = "test_topic"
	var s = ChallengeSlot.new()
	s.required_type = "word"
	s.required_pos = "adjective"
	s.accept_card_ids = accept_card_ids
	var slots: Array[ChallengeSlot] = [s]
	t.slots = slots
	t.effect_type = effect_type
	t.effect_magnitude = magnitude
	return t


func test_submit_all_clears_queue():
	# Test that submit_all_ap clears the ap_queue regardless
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3
	# Manually add a connection that will fail validation safely
	var conn = APConnection.new()
	conn.slot_index = 0
	conn.card = _make_card("dummy")
	conn.challenge_index = -1   # Will fail validation safely
	c.ap_queue.append(conn)
	c.submit_all_ap()
	assert_eq(c.ap_queue.size(), 0)


func test_submit_all_imperfect_clears_bonus():
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3
	c.ap_bonus_next_turn = 5  # Some prior bonus
	# Add a connection that will fail (challenge_index out of range)
	var conn = APConnection.new()
	conn.slot_index = 0
	conn.card = _make_card("dummy")
	conn.challenge_index = -1
	c.ap_queue.append(conn)
	c.submit_all_ap()
	assert_eq(c.ap_bonus_next_turn, 0)


func test_submit_empty_queue_safe():
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3
	# No connections — should not crash; bonus untouched
	c.ap_bonus_next_turn = 2
	c.submit_all_ap()
	assert_eq(c.ap_queue.size(), 0)
	# Empty queue path returns early — bonus shouldn't be reset
	assert_eq(c.ap_bonus_next_turn, 2)


func test_submit_all_perfect_combo_grants_bonus():
	# When all connections succeed → ap_bonus_next_turn = 1
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3
	c.ap_bonus_next_turn = 0
	# Set up a single solvable challenge on the board
	var card = _make_card("happy", 6)
	var ids: Array[String] = ["happy"]
	var tmpl = _make_template("t1", "How do you feel?", ids, "damage", 0)
	# Place template directly in available_challenges with empty filled_slots
	var chals: Array[ChallengeTemplate] = [tmpl]
	c.available_challenges = chals
	c.available_filled_slots = [[null]]
	# Fake some hp so damage application doesn't crash
	c.enemy_hp = 100
	c.enemy_max_hp = 100
	# submit_challenge needs _enemy + _combo + _selector
	var enemy := EnemyData.new()
	enemy.enemy_id = "test_enemy"
	enemy.enemy_name = "Test"
	enemy.max_hp = 100
	enemy.base_attack = 0
	c._enemy = enemy
	c.set_combo_system(ComboSystem.new())
	c.set_selector(ChallengeSelector.new())
	# Build a valid connection
	var conn = APConnection.new()
	conn.slot_index = 0
	conn.card = card
	conn.challenge_index = 0
	conn.question_slot_index = 0
	c.ap_queue.append(conn)
	c.submit_all_ap()
	assert_eq(c.ap_queue.size(), 0)
	assert_eq(c.ap_bonus_next_turn, 1)
