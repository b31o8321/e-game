# 知识神塔 Phase 4 — 撤退报告 + 专项练习场

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现完整的远征生命周期（开始/统计/结束）、撤退报告统计屏、以及城市训练道场，让每次远征都有数据闭环和复习入口。

**Architecture:** `ExpeditionTracker` 在远征期间收集答题记录与峰值连击；`GameState.end_expedition()` 聚合统计生成报告存入 `last_expedition_report`；`RetreatReportController` 读取并展示；`PracticeArenaController` 从 SRS 记录或报告中的错题 ID 生成专项练习，通过新增的 `ContentPackBase.get_question_by_id()` 接口获取题目。

**Tech Stack:** Godot 4 · GDScript · GUT · Phase 1 SRSSystem · Phase 2 QuestionController · Phase 3 ResourceNode/ExplorationController

**依赖 Phase 1–3：**
- `GameState.srs_system` — `record_answer()`, `get_priority()`, `serialize()`
- `GameState.expedition_active`, `expedition_loot`, `last_expedition_report`（新增）
- `QuestionController` （`question_ui.tscn` 已存在）
- `ExpeditionSetupController` — 需补充 `start_expedition()` 调用和场景导航
- `ExplorationController._on_return_pressed()` — 需改为撤退报告路径
- `BattleController._on_battle_ended()` — 失败时需跳撤退报告

---

## 文件结构

```
src/core/systems/expedition_tracker.gd     # 远征答题统计追踪器
src/ui/retreat_report_scene.tscn           # 撤退报告场景
src/ui/retreat_report_controller.gd        # 撤退报告控制器
src/city/practice_arena_scene.tscn         # 专项练习场景
src/city/practice_arena_controller.gd      # 专项练习控制器

tests/test_expedition_tracker.gd
```

**修改已有文件：**
- `src/core/autoloads/game_state.gd` — 新增 `expedition_tracker`、`last_expedition_report`、`practice_target_ids`、`start_expedition()`、更新 `end_expedition()`/`increment_combo()`
- `src/core/interfaces/content_pack_base.gd` — 新增 `get_question_by_id()` 接口方法
- `tests/mock_content_pack.gd` — 实现 `get_question_by_id()`
- `src/battle/expedition_setup_controller.gd` — 调用 `start_expedition()` 并跳转探索场景
- `src/battle/battle_controller.gd` — `on_question_answered` 接入追踪器；`_on_battle_ended` 失败时跳撤退报告
- `src/exploration/exploration_controller.gd` — `_on_question_answered` 接入追踪器；`_on_return_pressed` 改为撤退报告
- `src/city/city_scene_controller.gd` — 添加"训练道场"按钮

---

## Task 1: ExpeditionTracker — 答题统计追踪器 TDD

**Files:**
- Create: `src/core/systems/expedition_tracker.gd`
- Create: `tests/test_expedition_tracker.gd`

- [ ] **Step 1: 写失败测试**

新建 `tests/test_expedition_tracker.gd`：

```gdscript
extends GutTest

var tracker: ExpeditionTracker

func before_each() -> void:
	tracker = ExpeditionTracker.new()
	add_child_autofree(tracker)

func test_initial_report_has_zero_questions() -> void:
	var report: Dictionary = tracker.build_report()
	assert_eq(report.get("total_questions", -1), 0)

func test_record_answer_increments_total() -> void:
	tracker.record_answer("q1", "vocabulary", true)
	tracker.record_answer("q2", "vocabulary", false)
	tracker.record_answer("q3", "grammar", true)
	var report: Dictionary = tracker.build_report()
	assert_eq(report["total_questions"], 3)

func test_correct_count_tracks_only_correct() -> void:
	tracker.record_answer("q1", "vocabulary", true)
	tracker.record_answer("q2", "vocabulary", false)
	tracker.record_answer("q3", "grammar", true)
	var report: Dictionary = tracker.build_report()
	assert_eq(report["correct_count"], 2)

func test_accuracy_calculation() -> void:
	tracker.record_answer("q1", "vocabulary", true)
	tracker.record_answer("q2", "vocabulary", true)
	tracker.record_answer("q3", "grammar", false)
	tracker.record_answer("q4", "grammar", false)
	var report: Dictionary = tracker.build_report()
	assert_almost_eq(report["accuracy"], 0.5, 0.001)

func test_by_attack_type_tracking() -> void:
	tracker.record_answer("q1", "vocabulary", true)
	tracker.record_answer("q2", "vocabulary", false)
	tracker.record_answer("q3", "vocabulary", true)  # vocab: 2/3
	tracker.record_answer("q4", "grammar", true)     # grammar: 1/1
	var report: Dictionary = tracker.build_report()
	var by_type: Dictionary = report["by_attack_type"]
	assert_eq(by_type["vocabulary"]["correct"], 2)
	assert_eq(by_type["vocabulary"]["total"], 3)
	assert_eq(by_type["grammar"]["correct"], 1)
	assert_eq(by_type["grammar"]["total"], 1)

func test_most_wrong_ids_contains_wrong_question() -> void:
	tracker.record_answer("q_bad", "vocabulary", false)
	tracker.record_answer("q_bad", "vocabulary", false)
	tracker.record_answer("q_good", "vocabulary", true)
	var report: Dictionary = tracker.build_report()
	var wrong_ids: Dictionary = report["most_wrong_ids"]
	assert_true(wrong_ids.has("q_bad"))
	assert_eq(wrong_ids["q_bad"], 2)
	assert_false(wrong_ids.has("q_good"))

func test_peak_combo_tracked() -> void:
	tracker.update_peak_combo(3)
	tracker.update_peak_combo(7)
	tracker.update_peak_combo(5)  # lower — shouldn't override
	var report: Dictionary = tracker.build_report()
	assert_eq(report["peak_combo"], 7)

func test_reset_clears_all_data() -> void:
	tracker.record_answer("q1", "vocabulary", true)
	tracker.update_peak_combo(10)
	tracker.reset()
	var report: Dictionary = tracker.build_report()
	assert_eq(report["total_questions"], 0)
	assert_eq(report["peak_combo"], 0)
```

- [ ] **Step 2: 实现 ExpeditionTracker**

新建 `src/core/systems/expedition_tracker.gd`：

```gdscript
class_name ExpeditionTracker extends Node

## 每条答题记录：{question_id, attack_type, correct}
var _answers: Array[Dictionary] = []
var _peak_combo: int = 0

func reset() -> void:
	_answers.clear()
	_peak_combo = 0

func record_answer(question_id: String, attack_type: String, correct: bool) -> void:
	_answers.append({
		"question_id": question_id,
		"attack_type": attack_type,
		"correct": correct,
	})

func update_peak_combo(combo: int) -> void:
	if combo > _peak_combo:
		_peak_combo = combo

## 聚合报告：返回本次远征完整统计
func build_report() -> Dictionary:
	var total: int = _answers.size()
	var correct_count: int = 0
	var by_type: Dictionary = {}
	var wrong_counts: Dictionary = {}

	for a in _answers:
		var is_correct: bool = a["correct"]
		var attack_type: String = a["attack_type"]
		var qid: String = a["question_id"]

		if is_correct:
			correct_count += 1
		else:
			wrong_counts[qid] = wrong_counts.get(qid, 0) + 1

		if not by_type.has(attack_type):
			by_type[attack_type] = { "correct": 0, "total": 0 }
		by_type[attack_type]["total"] += 1
		if is_correct:
			by_type[attack_type]["correct"] += 1

	return {
		"total_questions": total,
		"correct_count": correct_count,
		"accuracy": float(correct_count) / float(total) if total > 0 else 0.0,
		"by_attack_type": by_type,
		"most_wrong_ids": wrong_counts,
		"peak_combo": _peak_combo,
	}
```

- [ ] **Step 3: 提交**

```bash
git add src/core/systems/expedition_tracker.gd tests/test_expedition_tracker.gd
git commit -m "feat: add ExpeditionTracker with per-type accuracy and wrong-ID tracking"
```

---

## Task 2: GameState 扩展 + 全生命周期接线

**Files:**
- Modify: `src/core/autoloads/game_state.gd`
- Modify: `src/core/interfaces/content_pack_base.gd`
- Modify: `tests/mock_content_pack.gd`
- Modify: `src/battle/expedition_setup_controller.gd`
- Modify: `src/battle/battle_controller.gd`
- Modify: `src/exploration/exploration_controller.gd`

- [ ] **Step 1: 更新 `src/core/autoloads/game_state.gd`**

读取文件，做以下修改：

**a) 在 `expedition_return_scene` 后追加三个新字段：**

```gdscript
var expedition_tracker: ExpeditionTracker
## 上次远征完整统计报告，供 RetreatReportController 读取
var last_expedition_report: Dictionary = {}
## 专项练习指定题目 ID 列表；空 = 自动从 SRS 选取
var practice_target_ids: Array[String] = []
```

**b) 在 `_ready()` 中，`srs_system` 初始化之后追加：**

```gdscript
	expedition_tracker = ExpeditionTracker.new()
	add_child(expedition_tracker)
```

**c) 新增 `start_expedition()` 方法（替换原 `reset_expedition()` 中 expedition_active = false 的问题）：**

```gdscript
## 开始新远征：重置状态并启动追踪器
func start_expedition() -> void:
	expedition_loot = {}
	combo_count = 0
	player_hp = player_max_hp
	active_bd_skills.clear()
	expedition_tracker.reset()
	expedition_active = true
```

**d) 将 `end_expedition()` 替换为：**

```gdscript
func end_expedition(victory: bool) -> void:
	if not expedition_active:
		return
	var tracker_report: Dictionary = expedition_tracker.build_report()
	last_expedition_report = {
		"victory": victory,
		"loot": expedition_loot.duplicate(),
		"peak_combo": tracker_report.get("peak_combo", 0),
		"total_questions": tracker_report.get("total_questions", 0),
		"correct_count": tracker_report.get("correct_count", 0),
		"accuracy": tracker_report.get("accuracy", 0.0),
		"by_attack_type": tracker_report.get("by_attack_type", {}),
		"most_wrong_ids": tracker_report.get("most_wrong_ids", {}),
	}
	reset_expedition()
	expedition_ended.emit(last_expedition_report)
	save_system.save_game_state()
```

**e) 在 `increment_combo()` 末尾追加追踪器更新：**

```gdscript
func increment_combo() -> void:
	combo_count += 1
	combo_changed.emit(combo_count)
	if expedition_tracker:
		expedition_tracker.update_peak_combo(combo_count)
```

- [ ] **Step 2: 在 ContentPackBase 添加 `get_question_by_id()`**

在 `src/core/interfaces/content_pack_base.gd` 的 `get_question()` 之后追加：

```gdscript
## 根据题目 ID 直接获取题目；若不存在返回空 Dictionary
## 调用方须检查返回值 is_empty() 后再使用
func get_question_by_id(question_id: String) -> Dictionary:
	return {}
```

- [ ] **Step 3: 在 MockContentPack 实现 `get_question_by_id()`**

在 `tests/mock_content_pack.gd` 的 `get_question()` 之后插入：

```gdscript
func get_question_by_id(question_id: String) -> Dictionary:
	if question_id.begins_with("q_mock") or question_id.begins_with("q_gate"):
		return get_question("vocabulary", 1, [])
	return {}
```

- [ ] **Step 4: 修改 `expedition_setup_controller.gd` 的 `_on_skill_selected()`**

将 `_on_skill_selected()` 替换为：

```gdscript
func _on_skill_selected(skill_id: String) -> void:
	selected_skill_id = skill_id
	GameState.active_bd_skills = [skill_id]
	GameState.start_expedition()
	skill_chosen.emit(skill_id)
	get_tree().change_scene_to_file("res://src/exploration/exploration_scene.tscn")
```

- [ ] **Step 5: 修改 `battle_controller.gd` 的 `on_question_answered()`**

在 `on_question_answered()` 中，`GameState.srs_system.record_answer(question_id, correct)` 这行之后追加：

```gdscript
	if GameState.expedition_active:
		GameState.expedition_tracker.record_answer(question_id, current_attack_type, correct)
```

完整更新后的方法：

```gdscript
func on_question_answered(correct: bool, question_id: String) -> void:
	if state != State.QUESTION:
		return
	state = State.RESOLVING
	GameState.srs_system.record_answer(question_id, correct)
	if GameState.expedition_active:
		GameState.expedition_tracker.record_answer(question_id, current_attack_type, correct)
	if correct:
		_apply_player_attack()
	else:
		_apply_enemy_attack()
```

- [ ] **Step 6: 修改 `battle_controller.gd` 的 `_on_battle_ended()`**

将 `_on_battle_ended()` 替换为：

```gdscript
func _on_battle_ended(victory: bool) -> void:
	GameState.pending_enemy = null
	var return_scene: String = GameState.expedition_return_scene
	GameState.expedition_return_scene = ""
	if return_scene.is_empty():
		return  # 单元测试：不跳转
	if victory:
		get_tree().change_scene_to_file(return_scene)  # 胜利 → 继续探索
	else:
		# 失败：end_expedition 可能已经通过 take_damage→player_hp==0 触发
		if GameState.expedition_active:
			GameState.end_expedition(false)
		get_tree().change_scene_to_file("res://src/ui/retreat_report_scene.tscn")
```

- [ ] **Step 7: 修改 `exploration_controller.gd` 的 `_on_question_answered()` 和 `_on_return_pressed()`**

将 `_on_question_answered()` 替换为：

```gdscript
func _on_question_answered(correct: bool, question_id: String) -> void:
	_question_ui.visible = false
	GameState.srs_system.record_answer(question_id, correct)
	if _pending_node and GameState.expedition_active:
		GameState.expedition_tracker.record_answer(question_id, _pending_node.attack_type_id, correct)
	if _pending_node:
		_pending_node.on_question_answered(correct)
		_pending_node = null
	_update_resource_bar()
```

将 `_on_return_pressed()` 替换为：

```gdscript
func _on_return_pressed() -> void:
	if GameState.expedition_active:
		GameState.end_expedition(false)
		get_tree().change_scene_to_file("res://src/ui/retreat_report_scene.tscn")
	else:
		get_tree().change_scene_to_file("res://src/city/city_scene.tscn")
```

- [ ] **Step 8: 提交**

```bash
git add src/core/autoloads/game_state.gd \
    src/core/interfaces/content_pack_base.gd \
    tests/mock_content_pack.gd \
    src/battle/expedition_setup_controller.gd \
    src/battle/battle_controller.gd \
    src/exploration/exploration_controller.gd
git commit -m "feat: wire expedition lifecycle — start/track/end with retreat report navigation"
```

---

## Task 3: RetreatReport 撤退报告场景

**Files:**
- Create: `src/ui/retreat_report_controller.gd`
- Create: `src/ui/retreat_report_scene.tscn`

- [ ] **Step 1: 实现 RetreatReportController**

新建 `src/ui/retreat_report_controller.gd`：

```gdscript
extends Control

@onready var _title_label: Label = $TitleLabel
@onready var _stats_label: Label = $StatsLabel
@onready var _type_stats_label: Label = $TypeStatsLabel
@onready var _combo_label: Label = $ComboLabel
@onready var _loot_label: Label = $LootLabel
@onready var _wrong_label: Label = $WrongLabel
@onready var _practice_button: Button = $PracticeButton
@onready var _return_button: Button = $ReturnButton
@onready var _retry_button: Button = $RetryButton

func _ready() -> void:
	_display_report(GameState.last_expedition_report)
	_practice_button.pressed.connect(_on_practice_pressed)
	_return_button.pressed.connect(_on_return_pressed)
	_retry_button.pressed.connect(_on_retry_pressed)

func _display_report(report: Dictionary) -> void:
	if report.is_empty():
		_title_label.text = "暂无报告"
		return
	var victory: bool = report.get("victory", false)
	_title_label.text = "🏆 远征胜利！" if victory else "📋 撤退报告"
	# 答题统计
	var total: int = report.get("total_questions", 0)
	var correct: int = report.get("correct_count", 0)
	var pct: int = int(report.get("accuracy", 0.0) * 100)
	_stats_label.text = "答题: %d / %d   正确率: %d%%" % [correct, total, pct]
	# 分学科
	var by_type: Dictionary = report.get("by_attack_type", {})
	var lines: Array[String] = []
	for t in by_type:
		var td: Dictionary = by_type[t]
		var tc: int = td.get("correct", 0)
		var tt: int = td.get("total", 0)
		var ta: int = int(float(tc) / float(tt) * 100) if tt > 0 else 0
		lines.append("  %s: %d/%d (%d%%)" % [t, tc, tt, ta])
	_type_stats_label.text = "\n".join(lines) if not lines.is_empty() else ""
	# 连击峰值
	_combo_label.text = "最高连击: %d" % report.get("peak_combo", 0)
	# 战利品
	var loot: Dictionary = report.get("loot", {})
	var loot_parts: Array[String] = []
	for k in loot:
		loot_parts.append("%s ×%d" % [k, loot[k]])
	_loot_label.text = "获得: " + (", ".join(loot_parts) if not loot_parts.is_empty() else "无")
	# 薄弱知识点
	var wrong_ids: Dictionary = report.get("most_wrong_ids", {})
	if wrong_ids.is_empty():
		_wrong_label.text = "无错题记录"
		_practice_button.visible = false
	else:
		_wrong_label.text = "薄弱知识点: %d 个" % wrong_ids.size()
		_practice_button.visible = true

func _on_practice_pressed() -> void:
	var wrong_ids: Dictionary = GameState.last_expedition_report.get("most_wrong_ids", {})
	GameState.practice_target_ids = wrong_ids.keys()
	get_tree().change_scene_to_file("res://src/city/practice_arena_scene.tscn")

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://src/city/city_scene.tscn")

func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file("res://src/battle/expedition_setup.tscn")
```

- [ ] **Step 2: 创建 retreat_report_scene.tscn**

新建 `src/ui/retreat_report_scene.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/retreat_report_controller.gd" id="1_rrc"]

[node name="RetreatReportScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_rrc")

[node name="TitleLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 10.0
offset_right = 600.0
offset_bottom = 50.0
text = "📋 撤退报告"

[node name="StatsLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 60.0
offset_right = 600.0
offset_bottom = 90.0
text = ""

[node name="TypeStatsLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 100.0
offset_right = 600.0
offset_bottom = 180.0
text = ""

[node name="ComboLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 190.0
offset_right = 400.0
offset_bottom = 220.0
text = "最高连击: 0"

[node name="LootLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 230.0
offset_right = 600.0
offset_bottom = 260.0
text = "获得: 无"

[node name="WrongLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 270.0
offset_right = 500.0
offset_bottom = 300.0
text = ""

[node name="PracticeButton" type="Button" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 310.0
offset_right = 200.0
offset_bottom = 350.0
text = "一键专项练习"

[node name="ReturnButton" type="Button" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 370.0
offset_right = 180.0
offset_bottom = 410.0
text = "返回城市"

[node name="RetryButton" type="Button" parent="."]
layout_mode = 1
offset_left = 200.0
offset_top = 370.0
offset_right = 380.0
offset_bottom = 410.0
text = "再次远征"
```

- [ ] **Step 3: 提交**

```bash
git add src/ui/retreat_report_controller.gd src/ui/retreat_report_scene.tscn
git commit -m "feat: add retreat report scene with per-type stats and practice shortcut"
```

---

## Task 4: PracticeArena 专项练习场

**Files:**
- Create: `src/city/practice_arena_controller.gd`
- Create: `src/city/practice_arena_scene.tscn`
- Modify: `src/city/city_scene_controller.gd`

- [ ] **Step 1: 实现 PracticeArenaController**

新建 `src/city/practice_arena_controller.gd`：

```gdscript
class_name PracticeArenaController extends Control

const SESSION_SIZE: int = 10

var _question_ids: Array[String] = []
var _current_index: int = 0
var _correct_count: int = 0
var _pack: ContentPackBase = null
var _question_controller: QuestionController = null
var _question_ui: Control = null

@onready var _progress_label: Label = $ProgressLabel
@onready var _result_panel: Control = $ResultPanel
@onready var _result_label: Label = $ResultPanel/ResultLabel
@onready var _next_button: Button = $NextButton
@onready var _finish_button: Button = $ResultPanel/FinishButton
@onready var _back_button: Button = $BackButton

func _ready() -> void:
	_pack = GameState.content_loader.get_active_pack()
	_build_question_list()
	_setup_question_ui()
	_next_button.pressed.connect(_on_next_pressed)
	_finish_button.pressed.connect(_on_finish_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_result_panel.visible = false
	if _question_ids.is_empty():
		_show_no_data()
	else:
		_show_next_question()

func _build_question_list() -> void:
	# 优先使用撤退报告中指定的错题 ID
	if not GameState.practice_target_ids.is_empty():
		_question_ids = GameState.practice_target_ids.duplicate()
		GameState.practice_target_ids = []
		return
	# 否则从 SRS 记录中选出答错过的题，按优先级排序
	var all_records: Dictionary = GameState.srs_system.serialize()
	var candidates: Array[String] = []
	for qid in all_records:
		if all_records[qid].get("wrong", 0) > 0:
			candidates.append(qid)
	candidates.sort_custom(func(a: String, b: String) -> bool:
		return GameState.srs_system.get_priority(a) > GameState.srs_system.get_priority(b))
	_question_ids = candidates.slice(0, min(SESSION_SIZE, candidates.size()))

func _setup_question_ui() -> void:
	var scene: PackedScene = load("res://src/battle/question_ui.tscn")
	_question_ui = scene.instantiate() as Control
	_question_ui.visible = false
	add_child(_question_ui)
	_question_controller = _question_ui as QuestionController
	_question_controller.answered.connect(_on_question_answered)

func _show_next_question() -> void:
	if _current_index >= _question_ids.size():
		_show_results()
		return
	if _pack == null:
		_show_no_data()
		return
	var qid: String = _question_ids[_current_index]
	var q: Dictionary = _pack.get_question_by_id(qid)
	if q.is_empty():
		_current_index += 1
		_show_next_question()
		return
	_progress_label.text = "第 %d / %d 题" % [_current_index + 1, _question_ids.size()]
	_question_controller.load_question(q)
	_question_ui.visible = true
	_next_button.visible = false

func _on_question_answered(correct: bool, question_id: String) -> void:
	GameState.srs_system.record_answer(question_id, correct)
	if correct:
		_correct_count += 1
	_current_index += 1
	_next_button.visible = true

func _on_next_pressed() -> void:
	_next_button.visible = false
	_question_ui.visible = false
	_show_next_question()

func _show_results() -> void:
	_question_ui.visible = false
	_progress_label.visible = false
	_next_button.visible = false
	# 每答对2题奖励1个词汇结晶
	var reward: int = _correct_count / 2
	if reward > 0:
		GameState.inventory_resources["vocabulary_crystal"] = \
			GameState.inventory_resources.get("vocabulary_crystal", 0) + reward
		GameState.save_system.save_game_state()
	_result_label.text = "练习完成！\n答对 %d / %d 题\n获得词汇结晶 ×%d" % [
		_correct_count, _question_ids.size(), reward]
	_result_panel.visible = true

func _show_no_data() -> void:
	_progress_label.text = "暂无薄弱知识点记录\n先去野外探索积累答题记录！"
	_next_button.visible = false

func _on_finish_pressed() -> void:
	get_tree().change_scene_to_file("res://src/city/city_scene.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/city/city_scene.tscn")
```

- [ ] **Step 2: 创建 practice_arena_scene.tscn**

新建 `src/city/practice_arena_scene.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/city/practice_arena_controller.gd" id="1_pac"]

[node name="PracticeArenaScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_pac")

[node name="ProgressLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 10.0
offset_right = 600.0
offset_bottom = 50.0
text = "专项练习"

[node name="NextButton" type="Button" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 560.0
offset_right = 200.0
offset_bottom = 600.0
text = "下一题"
visible = false

[node name="BackButton" type="Button" parent="."]
layout_mode = 1
offset_left = 220.0
offset_top = 560.0
offset_right = 380.0
offset_bottom = 600.0
text = "返回城市"

[node name="ResultPanel" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
visible = false

[node name="ResultLabel" type="Label" parent="ResultPanel"]
layout_mode = 1
offset_left = 10.0
offset_top = 10.0
offset_right = 600.0
offset_bottom = 120.0
text = ""

[node name="FinishButton" type="Button" parent="ResultPanel"]
layout_mode = 1
offset_left = 10.0
offset_top = 130.0
offset_right = 200.0
offset_bottom = 170.0
text = "返回城市"
```

- [ ] **Step 3: 在城市场景控制器添加"训练道场"按钮**

读取 `src/city/city_scene_controller.gd` 文件。在 `_ready()` 中已有 `_start_button` 和 `_back_button` 的 pressed 连接，在它们之后追加：

```gdscript
	var practice_btn: Button = Button.new()
	practice_btn.text = "训练道场"
	practice_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://src/city/practice_arena_scene.tscn"))
	add_child(practice_btn)
```

完整更新后的 `_ready()` 末尾（在 `_update_resource_bar()` 之前插入上面代码）：

```gdscript
func _ready() -> void:
	add_child(_city_controller)
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	if pack:
		_city_controller.setup(pack)
		_build_building_slots()
	_start_button.pressed.connect(_on_start_expedition)
	_back_button.pressed.connect(_on_back_to_menu)
	_city_controller.building_upgraded.connect(_on_any_building_upgraded)
	var practice_btn: Button = Button.new()
	practice_btn.text = "训练道场"
	practice_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://src/city/practice_arena_scene.tscn"))
	add_child(practice_btn)
	_update_resource_bar()
```

- [ ] **Step 4: 提交**

```bash
git add src/city/practice_arena_controller.gd src/city/practice_arena_scene.tscn \
    src/city/city_scene_controller.gd
git commit -m "feat: add practice arena scene with SRS-driven question selection and city button"
```

---

## Phase 4 完成标准

- [ ] `tests/test_expedition_tracker.gd` — 8 条 GUT 测试全部通过
- [ ] 在 `expedition_setup` 选择技能后自动跳转探索场景，`expedition_active = true`
- [ ] 战斗失败（HP归零）跳转至 `retreat_report_scene.tscn`
- [ ] 探索场景"返回城市"按钮触发 `end_expedition` 并跳转撤退报告
- [ ] 撤退报告显示：标题、答题数/正确率、分学科、峰值连击、战利品、薄弱知识点
- [ ] 撤退报告"一键专项练习"跳转练习场，使用报告中的错题 ID
- [ ] 城市"训练道场"按钮跳转练习场，自动从 SRS 选取高优先级题目
- [ ] 练习场完成后给予资源奖励并回到城市

---

## 与其他 Phase 的接口约定

Phase 5（大关 + Boss）通过 `GameState.completed_gate_ids` 记录通关历史，大关内战斗不触发 `end_expedition`，而是触发独立的 `gate_completed` 信号。

Phase 6（内容包）通过实现 `get_question_by_id()` 将真实题目暴露给练习场；`expedition_loot` 中的资源 ID 来自内容包定义。
