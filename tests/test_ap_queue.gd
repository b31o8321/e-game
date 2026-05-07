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

func _make_ctrl() -> BattleController:
	var c = BattleController.new()
	c.ap_max = 3
	add_child_autofree(c)
	return c


func test_add_to_ap_queue_appends():
	var c = _make_ctrl()
	var card = _make_card("test")
	var hand: Array[Card] = [card]
	c.set_hand_for_test(hand)
	assert_true(c.add_to_ap_queue(card, 0, 0))
	assert_eq(c.ap_queue.size(), 1)
	assert_eq(c.ap_queue[0].slot_index, 0)
	assert_eq(c.ap_queue[0].card.id, "test")

func test_add_to_ap_queue_full_rejects():
	var c = _make_ctrl()
	c.ap_max = 2
	var c1 = _make_card("a")
	var c2 = _make_card("b")
	var c3 = _make_card("c")
	var hand: Array[Card] = [c1, c2, c3]
	c.set_hand_for_test(hand)
	assert_true(c.add_to_ap_queue(c1, 0, 0))
	assert_true(c.add_to_ap_queue(c2, 1, 0))
	assert_false(c.add_to_ap_queue(c3, 2, 0))
	assert_eq(c.ap_queue.size(), 2)

func test_remove_from_ap_queue_returns_card():
	var c = _make_ctrl()
	var card = _make_card("a")
	var hand: Array[Card] = [card]
	c.set_hand_for_test(hand)
	c.add_to_ap_queue(card, 0, 0)
	# 卡进入队列后从手牌移出
	assert_eq(c.hand.size(), 0)
	c.remove_from_ap_queue(0)
	assert_eq(c.ap_queue.size(), 0)
	assert_eq(c.hand.size(), 1)
	assert_eq(c.hand[0].id, "a")

func test_reorder_ap_queue():
	var c = _make_ctrl()
	var c1 = _make_card("a")
	var c2 = _make_card("b")
	var c3 = _make_card("c")
	var hand: Array[Card] = [c1, c2, c3]
	c.set_hand_for_test(hand)
	c.add_to_ap_queue(c1, 0, 0)
	c.add_to_ap_queue(c2, 1, 0)
	c.add_to_ap_queue(c3, 2, 0)
	c.reorder_ap_queue(2, 0)  # 把 idx 2 移到 idx 0
	assert_eq(c.ap_queue[0].card.id, "c")
	assert_eq(c.ap_queue[1].card.id, "a")
	assert_eq(c.ap_queue[2].card.id, "b")
	# slot_index 也应该重排
	for i in c.ap_queue.size():
		assert_eq(c.ap_queue[i].slot_index, i)
