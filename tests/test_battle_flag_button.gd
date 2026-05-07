extends GutTest


func test_battle_scene_has_feedback_modal_preload():
	# 验证 battle_scene.gd 引用了 feedback_modal
	var f := FileAccess.open("res://src/battle/battle_scene.gd", FileAccess.READ)
	assert_not_null(f, "battle_scene.gd should exist")
	var content := f.get_as_text()
	assert_true(
		"feedback_modal" in content or "FeedbackModalScene" in content,
		"battle_scene.gd should preload the feedback modal scene"
	)


func test_battle_scene_has_on_flag_pressed_method():
	var f := FileAccess.open("res://src/battle/battle_scene.gd", FileAccess.READ)
	assert_not_null(f, "battle_scene.gd should exist")
	var content := f.get_as_text()
	assert_true(
		"_on_flag_pressed" in content,
		"battle_scene.gd should declare _on_flag_pressed"
	)
