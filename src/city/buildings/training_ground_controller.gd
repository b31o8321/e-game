## TrainingGroundController — 训练场子场景
##
## Phase 2.7 MVP shell：
##   - 显示当前 SRS 中弱题数量
##   - 点 "开始训练" → 取最弱 10 题（用 SRSSystem 现有 priority 排序）
##   - 由于 Phase 2.1 战斗 UI（卡片对话战）尚未完成，此处仅作"模拟答题"占位
##   - Phase 2.1 落地后：复用同款 UI（去掉敌人血条），完成 10 题再结算
##
## 结算奖励规则：
##   全对 +50；≥80% +30；≥50% +10；其他 0
##
## TODO Phase 2.1：在 _start_training 中跳到 challenge UI；现在仅记录 stub。
## TODO 后续：可考虑接 SRSSystem.get_weakest_card_ids(n) 接口（spec 提及但当前实现仅有 get_priority）
##
## 详见: docs/superpowers/specs/2026-05-04-knowledge-city-design.md
extends Control

const CITY_SCENE_PATH: String = "res://src/city/city_scene.tscn"
const SESSION_SIZE: int = 10

@onready var _back_button: Button = $Header/BackButton
@onready var _start_button: Button = $CenterPanel/StartButton
@onready var _weak_count_label: Label = $CenterPanel/WeakCountLabel
@onready var _result_label: Label = $CenterPanel/ResultLabel
@onready var _status_label: Label = $StatusLabel


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_refresh_weak_count()


func _refresh_weak_count() -> void:
	var count: int = _count_weak_records()
	_weak_count_label.text = "当前 SRS 中有 %d 条记录" % count
	if count == 0:
		_status_label.text = "还没有答题记录 → 先去神塔之门战斗几局再回来"


func _count_weak_records() -> int:
	if typeof(GameState) == TYPE_NIL or GameState.srs_system == null:
		return 0
	var records: Dictionary = GameState.srs_system.serialize()
	return records.size()


func _get_weakest_ids(n: int) -> Array[String]:
	var out: Array[String] = []
	if typeof(GameState) == TYPE_NIL or GameState.srs_system == null:
		return out
	var records: Dictionary = GameState.srs_system.serialize()
	var ids: Array[String] = []
	for k in records.keys():
		ids.append(str(k))
	# 用 SRSSystem.get_priority 排序（高优先级 = 最弱）
	ids.sort_custom(func(a: String, b: String) -> bool:
		return GameState.srs_system.get_priority(a) > GameState.srs_system.get_priority(b))
	out.assign(ids.slice(0, min(n, ids.size())))
	return out


func _on_start_pressed() -> void:
	# Phase 2.7 shell: 暂时不打开战斗 UI（依赖 Phase 2.1）
	# 这里只演示结算奖励逻辑，便于走通存档流程
	var ids: Array[String] = _get_weakest_ids(SESSION_SIZE)
	if ids.is_empty():
		_status_label.text = "[暂未实现 — 等 Phase 2.1 战斗 UI / 等数据接入]"
		_result_label.text = "训练场（占位）：需要先有答题记录才能开练"
		return
	# TODO Phase 2.1: 这里跳转到复用的 ChallengeUI 场景；目前 stub
	_result_label.text = "[Phase 2.1 战斗 UI 待接入] 已为你挑选 %d 道弱题" % ids.size()
	_status_label.text = "Phase 2.1 完成后此处会进入答题流程"


func _award_crystals(correct: int, total: int) -> void:
	# 留作 Phase 2.1 完成后的结算入口；保持纯函数特性便于后续测试
	if total <= 0:
		return
	var ratio: float = float(correct) / float(total)
	var reward: int = 0
	if correct == total:
		reward = 50
	elif ratio >= 0.8:
		reward = 30
	elif ratio >= 0.5:
		reward = 10
	if reward > 0 and typeof(GameState) != TYPE_NIL and GameState.save_system != null:
		GameState.save_system.add_crystals(reward)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(CITY_SCENE_PATH)
