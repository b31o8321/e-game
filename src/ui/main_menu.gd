## MainMenu — 5-button main entry per spec
##   开始新冒险 / 继续旅程 / 图鉴馆 / 设置 / 关于
##
## Legacy buttons "我的城市" / "探索" have been removed; the player should always
## land in 知识城 via 开始新冒险（with optional intro cutscene for first run）or
## 继续旅程（loads existing save and goes straight to city）.
##
## 详见: docs/superpowers/specs/2026-05-04-english-pack-narrative.md
extends Control

const CITY_SCENE: String = "res://src/city/city_scene.tscn"
const SETTINGS_SCENE: String = "res://src/ui/settings_scene.tscn"
const CODEX_SCENE: String = "res://src/city/buildings/codex_hall_scene.tscn"
const ABOUT_SCENE: String = "res://src/ui/settings_scene.tscn"  # TODO Phase 4: dedicated about scene

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var codex_button: Button = $VBoxContainer/CodexButton
@onready var _settings_button: Button = $VBoxContainer/SettingsButton
@onready var _about_button: Button = $VBoxContainer/AboutButton
@onready var _bg_texture: TextureRect = get_node_or_null("BackgroundTexture")


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_about_button.pressed.connect(_on_about_pressed)
	# Light SFX hooks for the 5 buttons (silent if file missing).
	for btn in [start_button, continue_button, codex_button, _settings_button, _about_button]:
		if btn != null:
			btn.pressed.connect(func(): _play_click_sfx())
			btn.mouse_entered.connect(func(): _play_hover_sfx())
	_apply_placeholder_bg()
	_update_continue_state()
	_play_menu_bgm()


func _play_menu_bgm() -> void:
	if typeof(AudioBus) == TYPE_NIL or AudioBus == null:
		return
	# Pack-supplied path takes priority; fall back to bundled track.
	var path: String = ""
	if typeof(GameState) != TYPE_NIL and GameState != null and GameState.content_loader != null:
		var pack: ContentPackBase = GameState.content_loader.get_active_pack()
		if pack != null and pack.has_method("get_main_menu_bgm_path"):
			path = pack.get_main_menu_bgm_path()
	if path == "" or not ResourceLoader.exists(path):
		path = "res://assets/audio/bgm/main_menu.ogg"
	AudioBus.play_bgm(path)


func _play_click_sfx() -> void:
	if typeof(AudioBus) != TYPE_NIL and AudioBus != null:
		AudioBus.play_sfx("button_click")


func _play_hover_sfx() -> void:
	if typeof(AudioBus) != TYPE_NIL and AudioBus != null:
		AudioBus.play_sfx("button_hover")


## 优先用 ContentPack 提供的主菜单背景图（res://assets/visual/...）。
## 没有真实美术资源时回退到 PlaceholderAssets 渐变。
func _apply_placeholder_bg() -> void:
	if _bg_texture == null:
		return
	if typeof(GameState) != TYPE_NIL and GameState != null and GameState.content_loader != null:
		var pack: ContentPackBase = GameState.content_loader.get_active_pack()
		if pack != null and pack.has_method("get_main_menu_bg_path"):
			var path: String = pack.get_main_menu_bg_path()
			if path != "" and ResourceLoader.exists(path):
				var tex: Texture2D = load(path) as Texture2D
				if tex != null:
					_bg_texture.texture = tex
					_bg_texture.visible = true
					return
	_bg_texture.texture = PlaceholderAssets.make_background_for("main_menu")
	_bg_texture.visible = true


## 没存档时禁用 [继续旅程]
func _update_continue_state() -> void:
	if continue_button == null:
		return
	var has_save: bool = _has_existing_save()
	continue_button.disabled = not has_save


func _has_existing_save() -> bool:
	if typeof(GameState) == TYPE_NIL or GameState == null:
		return false
	if GameState.save_system == null:
		return false
	var path: String = GameState.save_system.get_save_path()
	return FileAccess.file_exists(path)


func _on_start_pressed() -> void:
	# 开始新冒险：触发 intro cutscene（首次）→ 知识城
	if await _maybe_play_intro_cutscene():
		pass
	get_tree().change_scene_to_file(CITY_SCENE)


func _on_continue_pressed() -> void:
	# 继续旅程：直接进入知识城（intro 不再播放）
	get_tree().change_scene_to_file(CITY_SCENE)


func _maybe_play_intro_cutscene() -> bool:
	if typeof(GameState) == TYPE_NIL or GameState == null:
		return false
	if GameState.content_loader == null:
		return false
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	if pack == null:
		return false
	var panels: Array[CutscenePanel] = pack.get_intro_panels()
	if panels.is_empty():
		return false
	if typeof(CutscenePlayer) == TYPE_NIL or CutscenePlayer == null:
		return false
	# Persistent skip: if already played once, don't replay.
	if GameState.save_system != null:
		var state: Dictionary = GameState.save_system.load_game_state()
		if bool(state.get("intro_cutscene_played", false)):
			return false
	CutscenePlayer.play("game_intro", panels)
	await CutscenePlayer.cutscene_finished
	if GameState.save_system != null:
		var state2: Dictionary = GameState.save_system.load_game_state()
		state2["intro_cutscene_played"] = true
		GameState.save_system.save_game_state(state2)
	return true


func _on_codex_pressed() -> void:
	get_tree().change_scene_to_file(CODEX_SCENE)


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_about_pressed() -> void:
	# TODO Phase 4: dedicated about scene with credits + 家长说明
	get_tree().change_scene_to_file(ABOUT_SCENE)
