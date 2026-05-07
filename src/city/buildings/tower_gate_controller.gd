## TowerGateController — 神塔之门子场景
##
## Phase 2.7 MVP：楼层选择 + 简单楼层简介；备战编辑暂为占位列表。
## 点 [启程] 时：
##   1. CutscenePlayer.play("floor_intro_<floor_id>", pack.get_floor_intro_panels(floor_id))
##   2. 等 cutscene_finished → 切换到 RunMapScene
##
## TODO Phase 2.3：RunMapScene 落地后启用 _on_launch_pressed 中的实际跳转。
## TODO Phase 4：完整备战界面（卡组分析、推荐补全、装备/卷轴选择）。
##
## 详见: docs/superpowers/specs/2026-05-04-knowledge-city-design.md
extends Control

const CITY_SCENE_PATH: String = "res://src/city/city_scene.tscn"
const RUN_MAP_SCENE_PATH: String = "res://src/run/run_map_scene.tscn"  # TODO Phase 2.3
const PRE_RUN_SETUP_SCENE_PATH: String = "res://src/city/pre_run_setup_scene.tscn"

var _pack: ContentPackBase = null
var _selected_floor_id: String = ""

@onready var _back_button: Button = $Header/BackButton
@onready var _floor_list: VBoxContainer = $ContentArea/FloorList
@onready var _detail_panel: PanelContainer = $ContentArea/DetailPanel
@onready var _detail_label: Label = $ContentArea/DetailPanel/DetailVBox/DetailLabel
@onready var _deck_list: ItemList = $ContentArea/DetailPanel/DetailVBox/DeckList
@onready var _launch_button: Button = $ContentArea/DetailPanel/DetailVBox/LaunchButton
@onready var _status_label: Label = $StatusLabel


func _ready() -> void:
	_resolve_pack()
	_back_button.pressed.connect(_on_back_pressed)
	_launch_button.pressed.connect(_on_launch_pressed)
	_build_floor_list()


func _resolve_pack() -> void:
	if typeof(GameState) == TYPE_NIL or GameState.content_loader == null:
		return
	_pack = GameState.content_loader.get_active_pack()


func _build_floor_list() -> void:
	# 清空已有
	for child in _floor_list.get_children():
		child.queue_free()
	if _pack == null:
		_status_label.text = "[未加载内容包]"
		return
	var ids: Array[String] = _pack.get_all_floor_ids()
	if ids.is_empty():
		# Phase 2.7: 内容包尚未提供 floor 数据 → 给出占位项目
		var placeholder_ids: Array[String] = ["1F"]
		_render_floors(placeholder_ids, true)
		_status_label.text = "[Phase 3 内容包接入后会显示完整楼层]"
		return
	_render_floors(ids, false)


func _render_floors(ids: Array[String], is_placeholder: bool) -> void:
	var unlocked: Array[String] = _read_unlocked_floor_ids()
	var completed: Array[String] = _read_completed_floor_ids()
	var three_star: Dictionary = _read_three_star_progress()
	# 默认解锁兜底：玩家第一次进入时存档可能还不存在；保证 0F (教学层) 和 1F 都开放。
	var default_unlocked: Array[String] = ["0F", "1F"]
	for fid in ids:
		var btn: Button = Button.new()
		var is_unlocked: bool = is_placeholder or (fid in unlocked) or (fid in default_unlocked)
		var stars: Array = three_star.get(fid, [false, false, false])
		var star_str: String = ""
		for s in stars:
			star_str += "⭐" if bool(s) else "☆"
		var status: String = ""
		if not is_unlocked:
			status = " (锁)"
		elif fid in completed:
			status = " ✓"
		btn.text = "%s%s   %s" % [fid, status, star_str]
		btn.disabled = not is_unlocked
		btn.pressed.connect(_on_floor_selected.bind(fid))
		_floor_list.add_child(btn)


func _read_unlocked_floor_ids() -> Array[String]:
	var out: Array[String] = []
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return out
	var state: Dictionary = GameState.save_system.load_game_state()
	var arr: Variant = state.get("unlocked_floor_ids", [])
	if arr is Array:
		for v in arr:
			out.append(str(v))
	return out


func _read_completed_floor_ids() -> Array[String]:
	var out: Array[String] = []
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return out
	var state: Dictionary = GameState.save_system.load_game_state()
	var arr: Variant = state.get("completed_floor_ids", [])
	if arr is Array:
		for v in arr:
			out.append(str(v))
	return out


func _read_three_star_progress() -> Dictionary:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return {}
	var state: Dictionary = GameState.save_system.load_game_state()
	var prog: Variant = state.get("three_star_progress", {})
	return prog if prog is Dictionary else {}


func _on_floor_selected(floor_id: String) -> void:
	_selected_floor_id = floor_id
	var name_text: String = floor_id
	var recommended_minutes: int = 0
	if _pack != null:
		var cfg: Dictionary = _pack.get_floor_config(floor_id)
		name_text = str(cfg.get("unit_name", floor_id))
		recommended_minutes = int(cfg.get("recommended_run_minutes", 0))
	var line1: String = "楼层 %s · %s" % [floor_id, name_text]
	var line2: String = "推荐时长：%d 分钟" % recommended_minutes if recommended_minutes > 0 else ""
	_detail_label.text = "%s\n%s" % [line1, line2]
	_populate_deck_preview()
	_detail_panel.visible = true


func _populate_deck_preview() -> void:
	_deck_list.clear()
	if _pack == null:
		_deck_list.add_item("[Phase 3 接入卡数据后显示起手卡组]")
		return
	var deck_ids: Array[String] = _pack.get_starting_deck_card_ids()
	if deck_ids.is_empty():
		_deck_list.add_item("[Phase 3 起手卡组待接入]")
		return
	for cid in deck_ids:
		_deck_list.add_item(cid)


func _on_launch_pressed() -> void:
	if _selected_floor_id.is_empty():
		_status_label.text = "请先选择楼层"
		return
	# 触发楼层 intro cutscene（如果有）
	if _pack != null and CutscenePlayer != null:
		var panels: Array[CutscenePanel] = _pack.get_floor_intro_panels(_selected_floor_id)
		if not panels.is_empty():
			CutscenePlayer.play("floor_intro_" + _selected_floor_id, panels)
			await CutscenePlayer.cutscene_finished
	# Phase 4.2: 跳转到备战界面（PreRunSetupScene），由备战界面再去启动 RunMap
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.pending_floor_id = _selected_floor_id
	if ResourceLoader.exists(PRE_RUN_SETUP_SCENE_PATH):
		get_tree().change_scene_to_file(PRE_RUN_SETUP_SCENE_PATH)
		return
	# 兜底：备战场景缺失则尝试直跳 RunMap
	if ResourceLoader.exists(RUN_MAP_SCENE_PATH):
		get_tree().change_scene_to_file(RUN_MAP_SCENE_PATH)
		return
	_status_label.text = "[Phase 2.3 RunMap 场景待落地]"


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(CITY_SCENE_PATH)
