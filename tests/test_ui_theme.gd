## tests/test_ui_theme.gd — GUT tests for the Kenney UI theme resource
extends GutTest


func test_theme_file_exists() -> void:
	assert_true(
		ResourceLoader.exists("res://assets/themes/main_theme.tres"),
		"main_theme.tres must exist at res://assets/themes/main_theme.tres"
	)


func test_theme_loads_as_theme() -> void:
	var theme := load("res://assets/themes/main_theme.tres") as Theme
	assert_not_null(theme, "main_theme.tres should load as a Theme resource")


func test_button_normal_stylebox_is_texture() -> void:
	var theme := load("res://assets/themes/main_theme.tres") as Theme
	if theme == null:
		fail_test("Could not load theme")
		return
	var sbox := theme.get_stylebox("normal", "Button")
	assert_not_null(sbox, "Button/normal stylebox must not be null")
	assert_true(sbox is StyleBoxTexture, "Button/normal must be a StyleBoxTexture")


func test_button_hover_differs_from_normal() -> void:
	var theme := load("res://assets/themes/main_theme.tres") as Theme
	if theme == null:
		fail_test("Could not load theme")
		return
	var normal  := theme.get_stylebox("normal", "Button") as StyleBoxTexture
	var hover   := theme.get_stylebox("hover",  "Button") as StyleBoxTexture
	assert_not_null(hover, "Button/hover stylebox must not be null")
	# They must differ — either different texture or different modulate
	var different := (normal == null or hover == null or
		normal.texture != hover.texture or
		normal.modulate_color != hover.modulate_color)
	assert_true(different, "Button/hover must differ from Button/normal")


func test_button_pressed_stylebox_not_null() -> void:
	var theme := load("res://assets/themes/main_theme.tres") as Theme
	if theme == null:
		fail_test("Could not load theme")
		return
	var pressed := theme.get_stylebox("pressed", "Button")
	assert_not_null(pressed, "Button/pressed stylebox must not be null")


func test_panel_stylebox_not_null() -> void:
	var theme := load("res://assets/themes/main_theme.tres") as Theme
	if theme == null:
		fail_test("Could not load theme")
		return
	var panel := theme.get_stylebox("panel", "Panel")
	assert_not_null(panel, "Panel/panel stylebox must not be null")


func test_theme_has_default_font() -> void:
	var theme := load("res://assets/themes/main_theme.tres") as Theme
	if theme == null:
		fail_test("Could not load theme")
		return
	assert_not_null(theme.default_font, "Theme must carry a default_font (NotoSansSC)")


func test_button_texture_uses_kenney_png() -> void:
	var theme := load("res://assets/themes/main_theme.tres") as Theme
	if theme == null:
		fail_test("Could not load theme")
		return
	var sbox := theme.get_stylebox("normal", "Button") as StyleBoxTexture
	if sbox == null:
		fail_test("Button/normal is not a StyleBoxTexture")
		return
	# Verify the texture path contains the Kenney pack identifier
	var tex_path := sbox.texture.resource_path if sbox.texture else ""
	assert_true(
		tex_path.contains("kenney_ui_pack"),
		"Button/normal texture must come from kenney_ui_pack, got: " + tex_path
	)
