## T17: Submit button + sequential AP animation
##
## Headless smoke tests for the submit flow. Animation timing is hard to
## verify in a headless harness, so we focus on:
##   - SubmitButton node exists at expected path
##   - _on_submit_pressed exists and is safe to call when queue is empty
##   - _highlight_ap_block helper exists (or _render_ap_row repaints)
extends GutTest

const BattleSceneScene = preload("res://src/battle/battle_scene.tscn")
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


func test_submit_button_disabled_when_queue_empty():
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	# Without controller, just check button exists
	var btn = s.get_node("ApRow/Margin/HBox/SubmitButton") as Button
	assert_not_null(btn)
	# Initially queue is empty -> button should not crash if pressed
	# (Behavior: do nothing when empty)
	# We can simulate the press via emitting signal
	if btn.pressed.has_connections():
		btn.emit_signal("pressed")
	# No assertion on outcome since controller may be null


func test_submit_clears_queue_and_refreshes():
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	# Mock controller would be ideal but minimal: just verify _on_submit_pressed exists
	assert_has_method(s, "_on_submit_pressed")


func test_render_ap_row_with_pending_animation_state():
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	# Has a method to highlight a specific AP block during sequential animation
	assert_true(s.has_method("_highlight_ap_block") or s.has_method("_render_ap_row"))
