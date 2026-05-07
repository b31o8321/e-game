## test_main_menu — verify the main menu only contains the canonical 5 buttons.
##
## Per spec: 开始新冒险 / 继续旅程 / 图鉴馆 / 设置 / 关于
## Legacy buttons "我的城市" / "探索" must NOT exist.
extends GutTest

const MAIN_MENU_SCENE: String = "res://src/ui/main_menu.tscn"


func _instantiate_menu() -> Control:
	var packed: PackedScene = load(MAIN_MENU_SCENE)
	assert_not_null(packed, "main_menu.tscn should load")
	var inst: Control = packed.instantiate()
	add_child_autofree(inst)
	# 不调用 _ready 以避免触及 PlaceholderAssets / GameState autoloads
	return inst


func test_main_menu_has_canonical_5_buttons() -> void:
	var menu: Control = _instantiate_menu()
	var vbox: Node = menu.get_node_or_null("VBoxContainer")
	assert_not_null(vbox, "VBoxContainer expected")
	var expected_button_names: Array[String] = [
		"StartButton", "ContinueButton", "CodexButton", "SettingsButton", "AboutButton",
	]
	for n in expected_button_names:
		var btn: Node = vbox.get_node_or_null(n)
		assert_not_null(btn, "missing canonical button: %s" % n)
		assert_true(btn is Button, "%s should be a Button" % n)


func test_main_menu_has_no_legacy_buttons() -> void:
	var menu: Control = _instantiate_menu()
	var vbox: Node = menu.get_node_or_null("VBoxContainer")
	assert_not_null(vbox)
	# Legacy buttons must not exist in the scene.
	assert_null(vbox.get_node_or_null("CityButton"), "CityButton should be removed")
	assert_null(vbox.get_node_or_null("ExploreButton"), "ExploreButton should be removed")


func test_main_menu_button_texts_match_spec() -> void:
	var menu: Control = _instantiate_menu()
	var vbox: Node = menu.get_node_or_null("VBoxContainer")
	assert_not_null(vbox)
	var expected_texts: Dictionary = {
		"StartButton": "开始新冒险",
		"ContinueButton": "继续旅程",
		"CodexButton": "图鉴馆",
		"SettingsButton": "设置",
		"AboutButton": "关于",
	}
	for n in expected_texts.keys():
		var btn: Button = vbox.get_node_or_null(n) as Button
		assert_not_null(btn, "missing button: %s" % n)
		assert_eq(btn.text, str(expected_texts[n]), "%s text should match spec" % n)


func test_main_menu_script_has_no_legacy_handlers() -> void:
	# 检查脚本源代码不再含旧的处理函数
	var f: FileAccess = FileAccess.open("res://src/ui/main_menu.gd", FileAccess.READ)
	assert_not_null(f, "main_menu.gd should be readable")
	var src: String = f.get_as_text()
	f.close()
	assert_false(src.contains("_on_explore_pressed"), "explore handler should be removed")
	assert_false(src.contains("_on_city_pressed"), "city handler should be removed")
