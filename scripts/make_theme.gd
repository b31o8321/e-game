## scripts/make_theme.gd — run with: godot --headless -s scripts/make_theme.gd
## Builds assets/themes/main_theme.tres using Kenney Grey/Default PNGs (CC0).
extends SceneTree

func _initialize() -> void:
	var theme := Theme.new()

	# ── Font (carry over from default_theme.tres) ──────────────────────────────
	var font := load("res://assets/fonts/NotoSansSC-Regular.otf") as FontFile
	if font:
		theme.default_font = font
	theme.default_font_size = 22

	# ── Button textures ────────────────────────────────────────────────────────
	# Kenney 192×64 buttons have ~14 px rounded corners; 14 px margin all sides.
	const MARGIN := 14

	# normal — depth_flat: raised 3-D look
	var btn_normal := _make_sbt(
		"res://assets/external/kenney_ui_pack/PNG/Grey/Default/button_rectangle_depth_flat.png",
		MARGIN
	)

	# hover — depth_gloss: shiny highlight, brightened via modulate
	var btn_hover := _make_sbt(
		"res://assets/external/kenney_ui_pack/PNG/Grey/Default/button_rectangle_depth_gloss.png",
		MARGIN
	)
	btn_hover.modulate_color = Color(1.15, 1.15, 1.15, 1.0)

	# pressed — depth_border: recessed / border feel
	var btn_pressed := _make_sbt(
		"res://assets/external/kenney_ui_pack/PNG/Grey/Default/button_rectangle_depth_border.png",
		MARGIN
	)
	btn_pressed.modulate_color = Color(0.88, 0.88, 0.92, 1.0)

	# focus — same as hover with a slight blue tint
	var btn_focus := _make_sbt(
		"res://assets/external/kenney_ui_pack/PNG/Grey/Default/button_rectangle_depth_gloss.png",
		MARGIN
	)
	btn_focus.modulate_color = Color(0.95, 1.0, 1.2, 1.0)

	# disabled — flat (no depth), desaturated via modulate
	var btn_disabled := _make_sbt(
		"res://assets/external/kenney_ui_pack/PNG/Grey/Default/button_rectangle_flat.png",
		MARGIN
	)
	btn_disabled.modulate_color = Color(0.6, 0.6, 0.6, 0.8)

	theme.set_stylebox("normal",   "Button", btn_normal)
	theme.set_stylebox("hover",    "Button", btn_hover)
	theme.set_stylebox("pressed",  "Button", btn_pressed)
	theme.set_stylebox("focus",    "Button", btn_focus)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	# Button text colour to contrast against grey background
	theme.set_color("font_color",          "Button", Color(0.15, 0.15, 0.15, 1.0))
	theme.set_color("font_hover_color",    "Button", Color(0.05, 0.05, 0.05, 1.0))
	theme.set_color("font_pressed_color",  "Button", Color(0.1,  0.1,  0.2,  1.0))
	theme.set_color("font_disabled_color", "Button", Color(0.5,  0.5,  0.5,  1.0))

	# ── Panel background (no panel PNG in Grey/Default; use a neutral flat box) ─
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color        = Color(0.85, 0.85, 0.87, 0.95)
	panel_bg.border_width_left   = 2
	panel_bg.border_width_right  = 2
	panel_bg.border_width_top    = 2
	panel_bg.border_width_bottom = 2
	panel_bg.border_color        = Color(0.55, 0.55, 0.60, 1.0)
	panel_bg.corner_radius_top_left     = 6
	panel_bg.corner_radius_top_right    = 6
	panel_bg.corner_radius_bottom_left  = 6
	panel_bg.corner_radius_bottom_right = 6
	panel_bg.set_content_margin_all(8)

	theme.set_stylebox("panel", "Panel", panel_bg)

	# ── Save ──────────────────────────────────────────────────────────────────
	var err := ResourceSaver.save(theme, "res://assets/themes/main_theme.tres")
	if err == OK:
		print("make_theme: saved res://assets/themes/main_theme.tres  OK")
	else:
		push_error("make_theme: ResourceSaver.save failed, error=" + str(err))

	quit()


func _make_sbt(path: String, margin: int) -> StyleBoxTexture:
	var sbt := StyleBoxTexture.new()
	sbt.texture = load(path)
	sbt.texture_margin_left   = margin
	sbt.texture_margin_right  = margin
	sbt.texture_margin_top    = margin
	sbt.texture_margin_bottom = margin
	return sbt
