extends GutTest

const BattleController = preload("res://src/battle/battle_controller.gd")
const APConnection = preload("res://src/battle/ap_connection.gd")
const Card = preload("res://src/battle/cards/card.gd")


func _make_card(id: String) -> Card:
	var c = Card.new()
	c.id = id
	c.text = id
	c.type = "word"
	c.pos = "adjective"
	var tags: Array[String] = ["positive_emotion"]
	c.tags = tags
	c.base_damage = 5
	return c


func test_perfect_bonus_allows_extra_ap_next_turn():
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3
	c.ap_bonus_next_turn = 1   # Simulate prior perfect combo
	# Effective AP = ap_max + bonus = 4
	# Try to add 4 connections
	var cards: Array[Card] = []
	for i in 4:
		cards.append(_make_card("c%d" % i))
	c.set_library_for_test(cards)
	for i in 4:
		var ok = c.add_to_ap_queue(cards[i], 0, 0)
		assert_true(ok, "Connection %d should fit (cap=4)" % i)
	# 5th should reject
	var extra = _make_card("extra")
	var extra_hand: Array[Card] = [extra]
	c.set_library_for_test(extra_hand)
	assert_false(c.add_to_ap_queue(extra, 0, 0))
	assert_eq(c.ap_queue.size(), 4)


func test_perfect_bonus_consumed_after_turn():
	var c = BattleController.new()
	add_child_autofree(c)
	c.ap_max = 3
	c.ap_bonus_next_turn = 1
	# 调用 consume_ap_bonus_for_turn 模拟 turn start
	c.consume_ap_bonus_for_turn()
	# 这回合用了 bonus；下次重新设置才有
	# 之后 ap_bonus_next_turn 应被重置为 0
	assert_eq(c.ap_bonus_next_turn, 0)


func test_perfect_bonus_zero_default():
	var c = BattleController.new()
	add_child_autofree(c)
	assert_eq(c.ap_bonus_next_turn, 0)
