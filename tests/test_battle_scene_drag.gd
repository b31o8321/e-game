## T16: drag card from hand to slot — verifies CardView._get_drag_data
## payload contract used by SlotDropZone.
extends GutTest

const Card = preload("res://src/battle/cards/card.gd")
const CardViewScene = preload("res://src/battle/card_view.tscn")
const SlotDropZone = preload("res://src/battle/slot_drop_zone.gd")


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


func test_card_view_get_drag_data_returns_card_marker():
	var v = CardViewScene.instantiate()
	add_child_autofree(v)
	var card = _make_card("brave")
	v.set_card(card)
	var data = v._get_drag_data(Vector2.ZERO)
	assert_not_null(data)
	assert_eq(data.get("type"), "card")
	assert_eq(data.get("card_id"), "brave")
	assert_eq(data.get("ref"), card)


func test_card_view_get_drag_data_null_card_returns_null():
	var v = CardViewScene.instantiate()
	add_child_autofree(v)
	var data = v._get_drag_data(Vector2.ZERO)
	assert_null(data)


func test_slot_drop_zone_accepts_card_payload():
	var zone: SlotDropZone = SlotDropZone.new()
	add_child_autofree(zone)
	var card = _make_card("brave")
	var data = {"type": "card", "card_id": "brave", "ref": card}
	assert_true(zone._can_drop_data(Vector2.ZERO, data))


func test_slot_drop_zone_rejects_non_card_payload():
	var zone: SlotDropZone = SlotDropZone.new()
	add_child_autofree(zone)
	assert_false(zone._can_drop_data(Vector2.ZERO, {"type": "ap_block", "from_index": 0}))
	assert_false(zone._can_drop_data(Vector2.ZERO, "not a dict"))
	assert_false(zone._can_drop_data(Vector2.ZERO, null))


func test_slot_drop_zone_emits_card_dropped_signal():
	var zone: SlotDropZone = SlotDropZone.new()
	add_child_autofree(zone)
	var card = _make_card("brave")
	var received: Array = []
	zone.card_dropped.connect(func(c): received.append(c))
	zone._drop_data(Vector2.ZERO, {"type": "card", "ref": card})
	assert_eq(received.size(), 1)
	assert_eq(received[0], card)
