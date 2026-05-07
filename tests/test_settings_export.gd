extends GutTest


func test_settings_scene_loads():
	var ss = load("res://src/ui/settings_scene.tscn")
	assert_not_null(ss, "settings_scene.tscn should load")


func test_settings_scene_has_export_button_logic():
	var f := FileAccess.open("res://src/ui/settings_scene.gd", FileAccess.READ)
	assert_not_null(f, "settings_scene.gd should exist")
	var content := f.get_as_text()
	assert_true(
		"_on_export_feedback" in content or "export_json" in content,
		"settings_scene.gd should expose feedback export logic"
	)
