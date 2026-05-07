extends GutTest

const APBlockViewScene = preload("res://src/battle/ap_block_view.tscn")
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
	c.base_damage = 8
	return c

func test_render_with_connection():
	var v = APBlockViewScene.instantiate()
	add_child_autofree(v)
	var conn = APConnection.new()
	conn.slot_index = 0
	conn.card = _make_card("brave")
	conn.challenge_index = 1
	conn.preview = {"damage": 8}
	v.render(conn)
	# Card text should appear somewhere in the view
	var card_label = v.get_node("VBox/CardLabel") as Label
	assert_eq(card_label.text, "brave")
	var slot_label = v.get_node("VBox/SlotLabel") as Label
	assert_eq(slot_label.text, "[1]")
	var preview_label = v.get_node("VBox/PreviewLabel") as Label
	assert_eq(preview_label.text, "⚔ 8")


func test_render_empty_connection():
	var v = APBlockViewScene.instantiate()
	add_child_autofree(v)
	var conn = APConnection.new()
	conn.slot_index = 1
	conn.card = null
	conn.preview = {}
	v.render(conn)
	var card_label = v.get_node("VBox/CardLabel") as Label
	assert_eq(card_label.text, "—")


func test_get_drag_data_returns_block_marker():
	var v = APBlockViewScene.instantiate()
	add_child_autofree(v)
	var conn = APConnection.new()
	conn.slot_index = 2
	conn.card = _make_card("brave")
	v.render(conn)
	var data = v._get_drag_data(Vector2.ZERO)
	assert_eq(data.get("type"), "ap_block")
	assert_eq(data.get("from_index"), 2)
