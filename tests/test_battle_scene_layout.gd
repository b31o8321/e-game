extends GutTest

const BattleSceneScene = preload("res://src/battle/battle_scene.tscn")


func test_loads_with_ap_row_section():
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	# 三层结构关键节点存在
	assert_not_null(s.get_node_or_null("ApRow"), "ApRow node should exist")
	assert_not_null(s.get_node_or_null("ChallengeBoardPanel"), "ChallengeBoardPanel should exist")
	assert_not_null(s.get_node_or_null("HandRow"), "HandRow should exist")


func test_ap_row_has_submit_button():
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	var btn = s.get_node_or_null("ApRow/Margin/HBox/SubmitButton")
	assert_not_null(btn, "ApRow/Margin/HBox/SubmitButton should exist")


func test_ap_row_has_blocks_container():
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	var box = s.get_node_or_null("ApRow/Margin/HBox/Blocks")
	assert_not_null(box, "ApRow/Margin/HBox/Blocks (HBoxContainer) should exist for AP block instances")


func test_existing_anchors_no_overlap():
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	var ap_row: Control = s.get_node("ApRow")
	var board: Control = s.get_node("ChallengeBoardPanel")
	# ApRow.anchor_bottom should be <= board.anchor_top
	assert_true(ap_row.anchor_bottom <= board.anchor_top + 0.01, "ApRow and Board should not overlap")
