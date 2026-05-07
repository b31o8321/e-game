## CityController — 知识城主场景控制器
##
## Phase 2.7 重写：从旧的"建筑升级"概念迁移到 6 大建筑入口模式。
## 静态俯视角小镇布局，每个建筑可点击进入子场景。
##
## 子场景路径常量集中维护，便于其他模块（如返回按钮）复用。
##
## 详见: docs/superpowers/specs/2026-05-04-knowledge-city-design.md
class_name CityController extends Control

const CITY_SCENE_PATH: String = "res://src/city/city_scene.tscn"
const TOWER_GATE_SCENE: String = "res://src/city/buildings/tower_gate_scene.tscn"
const TRAINING_GROUND_SCENE: String = "res://src/city/buildings/training_ground_scene.tscn"
const CODEX_HALL_SCENE: String = "res://src/city/buildings/codex_hall_scene.tscn"
const CRYSTAL_MARKET_SCENE: String = "res://src/city/buildings/crystal_market_scene.tscn"
const BLUEPRINT_WORKSHOP_SCENE: String = "res://src/city/buildings/blueprint_workshop_scene.tscn"
const GUARDIANS_QUARTERS_SCENE: String = "res://src/city/buildings/guardians_quarters_scene.tscn"
const SETTINGS_SCENE: String = "res://src/ui/settings_scene.tscn"
const MAIN_MENU_SCENE: String = "res://src/ui/main_menu.tscn"

signal building_selected(building_id: String)

var _pack: ContentPackBase = null

@onready var _bg_texture: TextureRect = $BackgroundTexture
@onready var _player_info_label: Label = $TopBar/PlayerInfoLabel
@onready var _settings_button: Button = $TopBar/SettingsButton
@onready var _wallet_label: Label = $BottomHud/WalletLabel
@onready var _back_to_menu_button: Button = $BottomHud/BackToMenuButton

# 6 建筑入口的 Hover 按钮 → 直接绑定到 Button.pressed 信号
@onready var _tower_gate_btn: Button = $BuildingLayer/TowerGate/Hover
@onready var _training_ground_btn: Button = $BuildingLayer/TrainingGround/Hover
@onready var _codex_hall_btn: Button = $BuildingLayer/CodexHall/Hover
@onready var _crystal_market_btn: Button = $BuildingLayer/CrystalMarket/Hover
@onready var _blueprint_workshop_btn: Button = $BuildingLayer/BlueprintWorkshop/Hover
@onready var _guardians_quarters_btn: Button = $BuildingLayer/GuardiansQuarters/Hover


func _ready() -> void:
	_resolve_pack()
	_apply_background()
	_apply_theme_colors()
	_refresh_player_info()
	_refresh_wallet()
	_hookup_buildings()
	_settings_button.pressed.connect(_on_settings_pressed)
	_back_to_menu_button.pressed.connect(_on_back_to_menu_pressed)
	_play_city_bgm()


func _play_city_bgm() -> void:
	if typeof(AudioBus) == TYPE_NIL or AudioBus == null:
		return
	# Optional: pack-supplied path takes priority; default fallback to bundled track.
	var path: String = ""
	if _pack != null and _pack.has_method("get_city_bgm_path"):
		path = _pack.get_city_bgm_path()
	if path == "":
		path = "res://assets/audio/bgm/city.ogg"
	AudioBus.play_bgm(path)


# ---------------------------------------------------------------------------
# 公共 API（供测试 / 子场景调用）
# ---------------------------------------------------------------------------

## 跳转到指定建筑子场景；未知 id 不动作
func enter_building(building_id: String) -> void:
	var path: String = _resolve_building_path(building_id)
	if path.is_empty():
		push_warning("[CityController] unknown building id: " + building_id)
		return
	building_selected.emit(building_id)
	get_tree().change_scene_to_file(path)


## 刷新钱包显示（公开供子场景返回时手动 refresh）
func refresh_display() -> void:
	_refresh_player_info()
	_refresh_wallet()


# ---------------------------------------------------------------------------
# 内部
# ---------------------------------------------------------------------------

func _resolve_pack() -> void:
	if typeof(GameState) == TYPE_NIL:
		return
	if GameState.content_loader == null:
		return
	_pack = GameState.content_loader.get_active_pack()


func _apply_background() -> void:
	if _bg_texture == null:
		return
	if _pack != null:
		var bg_path: String = _pack.get_city_bg_path()
		if bg_path != "" and ResourceLoader.exists(bg_path):
			var tex: Texture2D = load(bg_path) as Texture2D
			if tex != null:
				_bg_texture.texture = tex
				_bg_texture.visible = true
				return
	# Fallback: programmatic gradient placeholder.
	_bg_texture.texture = PlaceholderAssets.make_background_for("city")
	_bg_texture.visible = true


func _apply_theme_colors() -> void:
	if _pack == null:
		return
	var colors: Dictionary = _pack.get_theme_colors()
	if colors.is_empty():
		return
	# 浅着色：仅修改顶部 bar 文字色，建筑保持各自色块
	var primary: Variant = colors.get("primary", null)
	if primary is Color:
		_player_info_label.add_theme_color_override("font_color", primary)


func _refresh_player_info() -> void:
	# Phase 2.7: 玩家等级与职业暂用 GameState 兜底；后续接入 SaveSystem.permanent_upgrades
	var level: int = 1
	var class_name_text: String = "守护者"
	if typeof(GameState) != TYPE_NIL:
		# knowledge_level 是 Phase 1 概念；后续会被 permanent_upgrades 取代
		level = max(1, GameState.knowledge_level)
	_player_info_label.text = "Lv %d %s" % [level, class_name_text]


func _refresh_wallet() -> void:
	var crystals: int = 0
	var blueprints: int = 0
	if typeof(GameState) != TYPE_NIL and GameState.save_system != null:
		var wallet: Dictionary = GameState.save_system.get_wallet()
		crystals = int(wallet.get("crystals", 0))
		blueprints = int(wallet.get("blueprints", 0))
	_wallet_label.text = "🔮 词晶: %d    🧩 蓝图: %d" % [crystals, blueprints]


func _hookup_buildings() -> void:
	_tower_gate_btn.pressed.connect(func() -> void: enter_building("tower_gate"))
	_training_ground_btn.pressed.connect(func() -> void: enter_building("training_ground"))
	_codex_hall_btn.pressed.connect(func() -> void: enter_building("codex_hall"))
	_crystal_market_btn.pressed.connect(func() -> void: enter_building("crystal_market"))
	_blueprint_workshop_btn.pressed.connect(func() -> void: enter_building("blueprint_workshop"))
	_guardians_quarters_btn.pressed.connect(func() -> void: enter_building("guardians_quarters"))


func _resolve_building_path(building_id: String) -> String:
	match building_id:
		"tower_gate": return TOWER_GATE_SCENE
		"training_ground": return TRAINING_GROUND_SCENE
		"codex_hall": return CODEX_HALL_SCENE
		"crystal_market": return CRYSTAL_MARKET_SCENE
		"blueprint_workshop": return BLUEPRINT_WORKSHOP_SCENE
		"guardians_quarters": return GUARDIANS_QUARTERS_SCENE
	return ""


func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
