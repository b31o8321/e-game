extends GutTest

const APConnection = preload("res://src/battle/ap_connection.gd")
const Card = preload("res://src/battle/cards/card.gd")

func test_create_basic():
	var c = APConnection.new()
	c.slot_index = 0
	c.challenge_index = 1
	c.question_slot_index = 0
	assert_eq(c.slot_index, 0)
	assert_eq(c.challenge_index, 1)

func test_to_dict_roundtrip():
	var c = APConnection.new()
	c.slot_index = 2
	c.challenge_index = 1
	c.question_slot_index = 0
	c.preview = {"damage": 12}
	var d = c.to_dict()
	assert_eq(d["slot_index"], 2)
	assert_eq(d["challenge_index"], 1)
	assert_eq(d["preview"]["damage"], 12)

func test_to_dict_with_card():
	var c = APConnection.new()
	var card = Card.new()
	card.id = "card_brave"
	card.text = "brave"
	c.card = card
	var d = c.to_dict()
	assert_eq(d["card_id"], "card_brave")

func test_to_dict_no_card():
	var c = APConnection.new()
	var d = c.to_dict()
	assert_eq(d["card_id"], "")
