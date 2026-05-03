# Phase 5 — 知识大关框架 + Boss系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现完整的里程碑大关框架：从探索场景入口、多波次战斗、Boss战（4种特殊机制 + 多阶段）、到通关解锁。

**Architecture:** 分场景导航，每个场景单一职责。`GateWaveController` 和 `BossBattleController` 均 extends `BattleController`，重写问题来源、技能加成、以及胜负导航。GameState 携带 gate 状态（`pending_gate_config`、`gate_questions_pool` 等）跨场景。探索场景生成 `KnowledgeGateNode` 按钮，点击后进入大关流程。

**Tech Stack:** Godot 4 · GDScript · GUT · Phase 1–4 既有系统（BattleController、EnemyData、QuestionController、GameState）

**关键约定：**
- `battle_scene.tscn` 的 `QuestionUIInstance` 节点是普通 Control（非 question_ui.tscn 实例）；Gate 场景的问题 UI 在 `_ready()` 中以代码方式实例化，与 `ExplorationController._setup_question_ui()` 模式一致
- gate 内战斗 `is_gate_active=true`，`expedition_active=false`，`end_expedition()` 调用无效果，胜负由各 Gate 控制器自己处理
- 所有 Gate 场景路径前缀：`res://src/gate/`

---

## 文件结构

| 路径 | 动作 | 职责 |
|------|------|------|
| `src/core/autoloads/game_state.gd` | 修改 | 新增 gate 字段 + start_gate/complete_gate/fail_gate |
| `src/core/interfaces/content_pack_base.gd` | 修改 | 新增 `get_gates()` 接口 |
| `tests/mock_content_pack.gd` | 修改 | 实现 `get_gates()` |
| `src/gate/gate_wave_controller.gd` | 新建 | extends BattleController；从 pool 取题；无技能；波次衔接 |
| `src/gate/gate_wave_scene.tscn` | 新建 | 波次战斗场景 |
| `src/gate/boss_battle_controller.gd` | 新建 | extends BattleController；4种 boss action；阶段切换 |
| `src/gate/boss_battle_scene.tscn` | 新建 | Boss 战场景 |
| `src/gate/gate_intro_controller.gd` | 新建 | 入场台词 + 重置 pool + 启动波次 |
| `src/gate/gate_intro_scene.tscn` | 新建 | 大关入场场景 |
| `src/gate/gate_complete_controller.gd` | 新建 | 胜利台词 + complete_gate() + 返回探索 |
| `src/gate/gate_complete_scene.tscn` | 新建 | 大关通关场景 |
| `src/content/english/bosses/librarian_boss.gd` | 新建 | 遗忘图书管理员（2阶段）|
| `src/exploration/knowledge_gate_node.gd` | 新建 | extends Button；点击进入大关 |
| `src/exploration/exploration_controller.gd` | 修改 | 生成 KnowledgeGateNode；监听 gate_completed |
| `tests/test_gate_wave_controller.gd` | 新建 | GateWaveController 单元测试 |
| `tests/test_boss_battle_controller.gd` | 新建 | BossBattleController 单元测试（8条）|

---

## Task 1: GameState gate 状态字段 + 方法

**Files:**
- Modify: `src/core/autoloads/game_state.gd`

- [ ] **Step 1: 读取当前 game_state.gd**

读取 `/Users/norman/development/e-game/src/core/autoloads/game_state.gd` 确认现有字段。

- [ ] **Step 2: 新增 gate 字段**

在 `expedition_return_scene` 字段之后，`expedition_tracker` 字段之前，插入：

```gdscript
# 大关状态
var pending_gate_id: String = ""
var pending_gate_config: Dictionary = {}
var gate_wave_index: int = 0
var gate_wave_count: int = 0
var gate_questions_pool: Array[Dictionary] = []
var is_gate_active: bool = false
var gate_boss_defeat_lines: Array[String] = []
```

- [ ] **Step 3: 新增 start_gate() 方法**

在 `start_expedition()` 方法之后插入：

```gdscript
## 进入大关：存储配置、预设波数、重置状态
func start_gate(gate_config: Dictionary, questions: Array[Dictionary]) -> void:
	pending_gate_id = gate_config.get("gate_id", "")
	pending_gate_config = gate_config
	gate_wave_index = 0
	gate_wave_count = gate_config.get("wave_count", 0)
	gate_questions_pool = questions
	is_gate_active = true
	player_hp = player_max_hp
```

- [ ] **Step 4: 新增 fail_gate() 方法**

```gdscript
## 大关失败：重置波次和题目池，保留 gate config 供重试
func fail_gate() -> void:
	gate_wave_index = 0
	gate_questions_pool.clear()
	player_hp = player_max_hp
```

- [ ] **Step 5: 新增 complete_gate() 方法**

```gdscript
## 大关通关：写入解锁，触发信号，存档
func complete_gate() -> void:
	var gate_id: String = pending_gate_config.get("gate_id", "")
	if gate_id not in completed_gate_ids:
		completed_gate_ids.append(gate_id)
	var new_level: int = pending_gate_config.get("unlock_knowledge_level", knowledge_level)
	knowledge_level = max(knowledge_level, new_level)
	is_gate_active = false
	gate_completed.emit(gate_id)
	save_system.save_game_state()
```

- [ ] **Step 6: 提交**

```bash
git add src/core/autoloads/game_state.gd
git commit -m "feat: add gate state fields and start_gate/fail_gate/complete_gate to GameState"
```

---

## Task 2: ContentPackBase.get_gates() + MockContentPack 实现

**Files:**
- Modify: `src/core/interfaces/content_pack_base.gd`
- Modify: `tests/mock_content_pack.gd`

- [ ] **Step 1: 在 ContentPackBase 添加 get_gates() 接口**

读取 `src/core/interfaces/content_pack_base.gd`，在 `get_gate_questions()` 之后插入：

```gdscript
## 返回本学科包定义的大关列表
## 每项格式见设计文档 Phase 5 spec
func get_gates() -> Array[Dictionary]:
	return []
```

- [ ] **Step 2: 在 MockContentPack 实现 get_gates()**

读取 `tests/mock_content_pack.gd`，在 `get_gate_questions()` 之后插入：

```gdscript
func get_gates() -> Array[Dictionary]:
	return [{
		"gate_id": "gate_mock_01",
		"gate_name": "模拟大关",
		"required_knowledge_level": 1,
		"wave_count": 1,
		"questions_per_wave": 2,
		"wave_enemy": {
			"enemy_name": "模拟哨兵",
			"max_hp": 20,
			"base_attack": 3,
			"weaknesses": ["vocabulary"],
			"multipliers": { "vocabulary": 1.5 },
		},
		"boss_script_path": "",
		"boss_enemy": {
			"enemy_name": "模拟Boss",
			"max_hp": 50,
			"base_attack": 5,
			"weaknesses": [],
			"multipliers": {},
		},
		"unlock_knowledge_level": 2,
		"unlock_area_ids": [],
	}]
```

- [ ] **Step 3: 提交**

```bash
git add src/core/interfaces/content_pack_base.gd tests/mock_content_pack.gd
git commit -m "feat: add get_gates() to ContentPackBase interface and MockContentPack"
```

---

## Task 3: GateWaveController TDD

**Files:**
- Create: `src/gate/gate_wave_controller.gd`
- Create: `tests/test_gate_wave_controller.gd`

- [ ] **Step 1: 新建目录并写失败测试**

新建 `tests/test_gate_wave_controller.gd`：

```gdscript
extends GutTest

var controller: GateWaveController
var mock_pack: MockContentPack

func before_each() -> void:
	mock_pack = MockContentPack.new()
	controller = GateWaveController.new()
	add_child_autofree(controller)
	var enemy := EnemyData.new()
	enemy.enemy_name = "Test Wave Enemy"
	enemy.max_hp = 30
	enemy.base_attack = 4
	enemy.weaknesses = []
	enemy.weakness_multipliers = {}
	controller.setup(enemy, mock_pack)

func test_get_active_skill_instances_returns_empty() -> void:
	var skills: Array[SkillBase] = controller._get_active_skill_instances()
	assert_eq(skills.size(), 0)

func test_pop_gate_question_removes_from_pool() -> void:
	GameState.gate_questions_pool = [
		{ "id": "q1", "question": "Q1", "options": ["A", "B"], "correct_index": 0, "attack_type_id": "vocabulary" },
		{ "id": "q2", "question": "Q2", "options": ["A", "B"], "correct_index": 1, "attack_type_id": "vocabulary" },
	]
	var q: Dictionary = controller._pop_gate_question()
	assert_eq(q["id"], "q1")
	assert_eq(GameState.gate_questions_pool.size(), 1)

func test_pop_gate_question_returns_empty_when_pool_empty() -> void:
	GameState.gate_questions_pool = []
	var q: Dictionary = controller._pop_gate_question()
	assert_true(q.is_empty())

func test_handle_gate_victory_increments_wave_index() -> void:
	GameState.gate_wave_index = 0
	GameState.gate_wave_count = 2
	GameState.is_gate_active = true
	GameState.pending_gate_config = {
		"wave_count": 2,
		"wave_enemy": { "enemy_name": "E", "max_hp": 20, "base_attack": 3, "weaknesses": [], "multipliers": {} },
		"boss_enemy": { "enemy_name": "Boss", "max_hp": 50, "base_attack": 5, "weaknesses": [], "multipliers": {} },
		"gate_id": "gate_mock_01",
	}
	controller._handle_gate_victory()
	assert_eq(GameState.gate_wave_index, 1)

func test_handle_gate_failure_resets_wave_index() -> void:
	GameState.gate_wave_index = 1
	GameState.gate_questions_pool = [{ "id": "q1" }]
	controller._handle_gate_failure()
	assert_eq(GameState.gate_wave_index, 0)
	assert_true(GameState.gate_questions_pool.is_empty())
```

- [ ] **Step 2: 新建 `src/gate/` 目录结构并实现 GateWaveController**

确认目录存在（若无则创建文件即可），新建 `src/gate/gate_wave_controller.gd`：

```gdscript
class_name GateWaveController extends BattleController

var _question_ui: Control = null
var _question_controller: QuestionController = null

func _ready() -> void:
	var enemy_name_lbl := get_node_or_null("EnemyArea/EnemyNameLabel") as Label
	var enemy_hp_bar_node := get_node_or_null("EnemyArea/EnemyHpBar") as ProgressBar
	var weakness_lbl := get_node_or_null("EnemyArea/WeaknessLabel") as Label
	var player_hp_bar_node := get_node_or_null("PlayerArea/PlayerHpBar") as ProgressBar
	var combo_lbl := get_node_or_null("PlayerArea/ComboLabel") as Label
	var attack_btns := get_node_or_null("AttackButtons") as HBoxContainer
	if enemy_name_lbl:
		setup_scene_nodes(enemy_name_lbl, enemy_hp_bar_node, weakness_lbl,
			player_hp_bar_node, combo_lbl, attack_btns, null)
		_setup_question_ui()
	if GameState.pending_enemy != null and GameState.is_gate_active:
		setup(GameState.pending_enemy, GameState.content_loader.get_active_pack())
		refresh_enemy_ui()
		build_attack_buttons()
		start_player_turn()
	battle_ended.connect(_on_battle_ended)

func _setup_question_ui() -> void:
	var scene: PackedScene = load("res://src/battle/question_ui.tscn")
	_question_ui = scene.instantiate() as Control
	_question_ui.visible = false
	add_child(_question_ui)
	_question_controller = _question_ui as QuestionController
	_question_controller.answered.connect(func(correct: bool, qid: String):
		_question_ui.visible = false
		on_question_answered(correct, qid))

func _get_active_skill_instances() -> Array[SkillBase]:
	return []

func _pop_gate_question() -> Dictionary:
	if GameState.gate_questions_pool.is_empty():
		return {}
	return GameState.gate_questions_pool.pop_front()

func select_attack(attack_type_id: String) -> void:
	if state != State.PLAYER_TURN:
		return
	current_attack_type = attack_type_id
	state = State.QUESTION
	var question: Dictionary = _pop_gate_question()
	if question.is_empty():
		state = State.PLAYER_TURN
		return
	if _question_controller:
		_question_controller.load_question(question)
		_question_ui.visible = true
	attack_selected.emit(attack_type_id, question)

## 供单元测试调用：处理波次胜利逻辑（不做场景跳转）
func _handle_gate_victory() -> void:
	GameState.gate_wave_index += 1

## 供单元测试调用：处理大关失败逻辑
func _handle_gate_failure() -> void:
	GameState.fail_gate()

func _on_battle_ended(victory: bool) -> void:
	GameState.pending_enemy = null
	if not victory:
		_handle_gate_failure()
		get_tree().change_scene_to_file("res://src/gate/gate_intro_scene.tscn")
		return
	_handle_gate_victory()
	if GameState.gate_wave_index < GameState.gate_wave_count:
		var cfg: Dictionary = GameState.pending_gate_config
		var wave_cfg: Dictionary = cfg.get("wave_enemy", {})
		var ed := EnemyData.new()
		ed.enemy_id = "gate_wave_enemy"
		ed.enemy_name = wave_cfg.get("enemy_name", "关卡敌人")
		ed.max_hp = wave_cfg.get("max_hp", 20)
		ed.base_attack = wave_cfg.get("base_attack", 3)
		ed.weaknesses = wave_cfg.get("weaknesses", [])
		ed.weakness_multipliers = wave_cfg.get("multipliers", {})
		GameState.pending_enemy = ed
		get_tree().change_scene_to_file("res://src/gate/gate_wave_scene.tscn")
	else:
		var cfg: Dictionary = GameState.pending_gate_config
		var boss_cfg: Dictionary = cfg.get("boss_enemy", {})
		var ed := EnemyData.new()
		ed.enemy_id = cfg.get("gate_id", "boss") + "_boss"
		ed.enemy_name = boss_cfg.get("enemy_name", "Boss")
		ed.max_hp = boss_cfg.get("max_hp", 150)
		ed.base_attack = boss_cfg.get("base_attack", 10)
		ed.weaknesses = boss_cfg.get("weaknesses", [])
		ed.weakness_multipliers = boss_cfg.get("multipliers", {})
		GameState.pending_enemy = ed
		get_tree().change_scene_to_file("res://src/gate/boss_battle_scene.tscn")
```

- [ ] **Step 3: 新建 gate_wave_scene.tscn**

新建 `src/gate/gate_wave_scene.tscn`（与 battle_scene.tscn 相同结构，仅换脚本）：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/gate/gate_wave_controller.gd" id="1_gwc"]

[node name="GateWaveScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_gwc")

[node name="EnemyArea" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 300.0
offset_top = 80.0
offset_right = 600.0
offset_bottom = 250.0

[node name="EnemyNameLabel" type="Label" parent="EnemyArea"]
text = "关卡敌人"

[node name="EnemyHpBar" type="ProgressBar" parent="EnemyArea"]

[node name="WeaknessLabel" type="Label" parent="EnemyArea"]
text = ""

[node name="PlayerArea" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 50.0
offset_top = 80.0
offset_right = 250.0
offset_bottom = 250.0

[node name="PlayerHpBar" type="ProgressBar" parent="PlayerArea"]

[node name="ComboLabel" type="Label" parent="PlayerArea"]
text = "连击: 0"

[node name="AttackButtons" type="HBoxContainer" parent="."]
layout_mode = 1
offset_left = 50.0
offset_top = 300.0
offset_right = 700.0
offset_bottom = 400.0
```

- [ ] **Step 4: 提交**

```bash
git add src/gate/gate_wave_controller.gd src/gate/gate_wave_scene.tscn \
    tests/test_gate_wave_controller.gd
git commit -m "feat: add GateWaveController with pool-based questions and wave navigation"
```

---

## Task 4: BossBattleController TDD — 4种机制 + 阶段切换

**Files:**
- Create: `src/gate/boss_battle_controller.gd`
- Create: `src/gate/boss_battle_scene.tscn`
- Create: `tests/test_boss_battle_controller.gd`

- [ ] **Step 1: 写失败测试**

新建 `tests/test_boss_battle_controller.gd`：

```gdscript
extends GutTest

var controller: BossBattleController
var mock_pack: MockContentPack

func before_each() -> void:
	mock_pack = MockContentPack.new()
	controller = BossBattleController.new()
	add_child_autofree(controller)
	var enemy := EnemyData.new()
	enemy.enemy_name = "Test Boss"
	enemy.max_hp = 100
	enemy.base_attack = 10
	enemy.weaknesses = []
	enemy.weakness_multipliers = {}
	controller.setup(enemy, mock_pack)
	controller.enemy_hp = 100
	GameState.player_hp = 100
	GameState.player_max_hp = 100

func test_boss_action_damage_reduces_player_hp() -> void:
	var action: Dictionary = { "type": "damage", "value": 15, "message": "" }
	controller._apply_boss_action(action)
	assert_eq(GameState.player_hp, 85)

func test_boss_action_seal_attack_adds_to_sealed_types() -> void:
	var action: Dictionary = { "type": "seal_attack", "value": "vocabulary", "message": "" }
	controller._apply_boss_action(action)
	assert_true("vocabulary" in controller._sealed_types)

func test_boss_action_seal_attack_no_duplicate() -> void:
	controller._sealed_types = ["vocabulary"]
	var action: Dictionary = { "type": "seal_attack", "value": "vocabulary", "message": "" }
	controller._apply_boss_action(action)
	assert_eq(controller._sealed_types.count("vocabulary"), 1)

func test_boss_action_shorten_timer_applies_reduction() -> void:
	controller._timer_reduction = 0.0
	var action: Dictionary = { "type": "shorten_timer", "value": 3.0, "message": "" }
	controller._apply_boss_action(action)
	assert_almost_eq(controller._timer_reduction, 3.0, 0.001)

func test_boss_action_shorten_timer_caps_at_max_reduction() -> void:
	controller._timer_reduction = 6.0
	var action: Dictionary = { "type": "shorten_timer", "value": 5.0, "message": "" }
	controller._apply_boss_action(action)
	assert_almost_eq(controller._timer_reduction, 7.0, 0.001)  # capped at 7.0

func test_boss_action_shuffle_options_sets_pending_flag() -> void:
	var action: Dictionary = { "type": "shuffle_options", "value": true, "message": "" }
	controller._apply_boss_action(action)
	assert_true(controller._pending_shuffle)

func test_phase_transition_2phase_at_50_percent() -> void:
	controller._boss = null  # no concrete boss needed for phase check
	controller._current_phase = 1
	controller.enemy_hp = 50   # exactly 50%
	controller._check_phase_transition(2)
	assert_eq(controller._current_phase, 2)

func test_phase_transition_does_not_downgrade() -> void:
	controller._current_phase = 2
	controller.enemy_hp = 80  # above 50% — but we're already phase 2
	controller._check_phase_transition(2)
	assert_eq(controller._current_phase, 2)

func test_shuffle_question_options_remaps_correct_index() -> void:
	var q: Dictionary = {
		"id": "q1",
		"options": ["A", "B", "C", "D"],
		"correct_index": 0,  # correct answer is "A"
	}
	var shuffled: Dictionary = controller._shuffle_question_options(q)
	var correct_answer: String = shuffled["options"][shuffled["correct_index"]]
	assert_eq(correct_answer, "A")
```

- [ ] **Step 2: 实现 BossBattleController**

新建 `src/gate/boss_battle_controller.gd`：

```gdscript
class_name BossBattleController extends BattleController

var _boss: BossBase = null
var _current_phase: int = 1
var _sealed_types: Array[String] = []
var _pending_shuffle: bool = false
var _timer_reduction: float = 0.0

var _question_ui: Control = null
var _question_controller: QuestionController = null

func _ready() -> void:
	var enemy_name_lbl := get_node_or_null("EnemyArea/EnemyNameLabel") as Label
	var enemy_hp_bar_node := get_node_or_null("EnemyArea/EnemyHpBar") as ProgressBar
	var weakness_lbl := get_node_or_null("EnemyArea/WeaknessLabel") as Label
	var player_hp_bar_node := get_node_or_null("PlayerArea/PlayerHpBar") as ProgressBar
	var combo_lbl := get_node_or_null("PlayerArea/ComboLabel") as Label
	var attack_btns := get_node_or_null("AttackButtons") as HBoxContainer
	if enemy_name_lbl:
		setup_scene_nodes(enemy_name_lbl, enemy_hp_bar_node, weakness_lbl,
			player_hp_bar_node, combo_lbl, attack_btns, null)
		_setup_question_ui()
	# 实例化 Boss 脚本
	var boss_path: String = GameState.pending_gate_config.get("boss_script_path", "")
	if not boss_path.is_empty():
		var boss_script := load(boss_path)
		if boss_script:
			_boss = boss_script.new() as BossBase
			if _boss:
				add_child(_boss)
	if GameState.pending_enemy != null and GameState.is_gate_active:
		setup(GameState.pending_enemy, GameState.content_loader.get_active_pack())
		refresh_enemy_ui()
		build_attack_buttons()
		start_player_turn()
	battle_ended.connect(_on_battle_ended)

func _setup_question_ui() -> void:
	var scene: PackedScene = load("res://src/battle/question_ui.tscn")
	_question_ui = scene.instantiate() as Control
	_question_ui.visible = false
	add_child(_question_ui)
	_question_controller = _question_ui as QuestionController
	_question_controller.answered.connect(func(correct: bool, qid: String):
		_question_ui.visible = false
		on_question_answered(correct, qid))

func _get_active_skill_instances() -> Array[SkillBase]:
	return []

func _pop_gate_question() -> Dictionary:
	if GameState.gate_questions_pool.is_empty():
		return {}
	return GameState.gate_questions_pool.pop_front()

func _shuffle_question_options(q: Dictionary) -> Dictionary:
	var shuffled: Dictionary = q.duplicate()
	var options: Array = shuffled.get("options", []).duplicate()
	if options.is_empty():
		return shuffled
	var correct_answer: String = options[shuffled.get("correct_index", 0)]
	options.shuffle()
	shuffled["options"] = options
	shuffled["correct_index"] = options.find(correct_answer)
	return shuffled

func select_attack(attack_type_id: String) -> void:
	if state != State.PLAYER_TURN:
		return
	if attack_type_id in _sealed_types:
		return
	current_attack_type = attack_type_id
	state = State.QUESTION
	var question: Dictionary = _pop_gate_question()
	if question.is_empty():
		state = State.PLAYER_TURN
		return
	if _pending_shuffle:
		question = _shuffle_question_options(question)
		_pending_shuffle = false
	if _question_controller:
		var base_time: float = 10.0
		_question_controller.time_limit = max(3.0, base_time - _timer_reduction)
		_question_controller.load_question(question)
		_question_ui.visible = true
	attack_selected.emit(attack_type_id, question)

func build_attack_buttons() -> void:
	if not attack_buttons_container or not _pack:
		return
	for child in attack_buttons_container.get_children():
		child.queue_free()
	for attack_type in _pack.get_attack_types():
		var type_id: String = attack_type["id"]
		if type_id in _sealed_types:
			continue
		var btn: Button = Button.new()
		btn.text = attack_type.get("icon", "") + " " + attack_type.get("name", "")
		btn.pressed.connect(func(): select_attack(type_id))
		attack_buttons_container.add_child(btn)

## 供单元测试调用：应用单条 boss action
func _apply_boss_action(action: Dictionary) -> void:
	match action.get("type", "none"):
		"damage":
			GameState.take_damage(action.get("value", 0))
		"seal_attack":
			var type_id: String = action.get("value", "")
			if type_id and type_id not in _sealed_types:
				_sealed_types.append(type_id)
				build_attack_buttons()
		"shuffle_options":
			_pending_shuffle = true
		"shorten_timer":
			_timer_reduction = min(_timer_reduction + action.get("value", 0.0), 7.0)
		"none":
			pass

## 供单元测试调用：阶段切换检测
func _check_phase_transition(phase_count: int) -> void:
	if _current_phase >= phase_count:
		return
	var hp_pct: float = float(enemy_hp) / float(_enemy.max_hp if _enemy else 100)
	var new_phase: int = _current_phase
	if phase_count == 2:
		if hp_pct <= 0.5:
			new_phase = 2
	elif phase_count == 3:
		if hp_pct <= 0.33:
			new_phase = 3
		elif hp_pct <= 0.66:
			new_phase = 2
	if new_phase > _current_phase:
		_current_phase = new_phase
		if _boss:
			var bs: Dictionary = _build_battle_state()
			bs["phase"] = _current_phase
			bs["sealed_types"] = _sealed_types
			_boss.on_phase_start(_current_phase, bs)
			var new_seals: Array = bs.get("seal_types", [])
			for t in new_seals:
				if t not in _sealed_types:
					_sealed_types.append(t)
			build_attack_buttons()

func _execute_boss_action() -> void:
	if not _boss:
		return
	var bs: Dictionary = _build_battle_state()
	bs["phase"] = _current_phase
	bs["sealed_types"] = _sealed_types
	var action: Dictionary = _boss.boss_action(bs)
	_apply_boss_action(action)

func _apply_player_attack() -> void:
	super._apply_player_attack()
	if state != State.END:
		var pc: int = _boss.get_phase_count() if _boss else 1
		_check_phase_transition(pc)
		_execute_boss_action()

func _apply_enemy_attack() -> void:
	super._apply_enemy_attack()
	if state != State.END:
		_execute_boss_action()

func _on_battle_ended(victory: bool) -> void:
	GameState.pending_enemy = null
	if not victory:
		GameState.fail_gate()
		get_tree().change_scene_to_file("res://src/gate/gate_intro_scene.tscn")
		return
	if _boss:
		GameState.gate_boss_defeat_lines = _boss.get_defeat_dialogue()
	GameState.complete_gate()
	get_tree().change_scene_to_file("res://src/gate/gate_complete_scene.tscn")
```

- [ ] **Step 3: 新建 boss_battle_scene.tscn**

新建 `src/gate/boss_battle_scene.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/gate/boss_battle_controller.gd" id="1_bbc"]

[node name="BossBattleScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_bbc")

[node name="EnemyArea" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 300.0
offset_top = 80.0
offset_right = 600.0
offset_bottom = 250.0

[node name="EnemyNameLabel" type="Label" parent="EnemyArea"]
text = "Boss"

[node name="EnemyHpBar" type="ProgressBar" parent="EnemyArea"]

[node name="WeaknessLabel" type="Label" parent="EnemyArea"]
text = ""

[node name="PlayerArea" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 50.0
offset_top = 80.0
offset_right = 250.0
offset_bottom = 250.0

[node name="PlayerHpBar" type="ProgressBar" parent="PlayerArea"]

[node name="ComboLabel" type="Label" parent="PlayerArea"]
text = "连击: 0"

[node name="PhaseLabel" type="Label" parent="PlayerArea"]
text = "阶段: 1"

[node name="SealedLabel" type="Label" parent="PlayerArea"]
text = ""

[node name="AttackButtons" type="HBoxContainer" parent="."]
layout_mode = 1
offset_left = 50.0
offset_top = 300.0
offset_right = 700.0
offset_bottom = 400.0
```

- [ ] **Step 4: 提交**

```bash
git add src/gate/boss_battle_controller.gd src/gate/boss_battle_scene.tscn \
    tests/test_boss_battle_controller.gd
git commit -m "feat: add BossBattleController with 4 boss actions and phase transitions"
```

---

## Task 5: LibrarianBoss — 遗忘图书管理员

**Files:**
- Create: `src/content/english/bosses/librarian_boss.gd`

- [ ] **Step 1: 确认目录存在**

```bash
ls /Users/norman/development/e-game/src/content/english/ 2>/dev/null || mkdir -p /Users/norman/development/e-game/src/content/english/bosses
```

- [ ] **Step 2: 实现 LibrarianBoss**

新建 `src/content/english/bosses/librarian_boss.gd`：

```gdscript
class_name LibrarianBoss extends BossBase

var _phase2_sealed: bool = false

func _init() -> void:
	boss_id = "librarian"
	max_hp = 150
	gate_id = "gate_en_01_basics"

func get_intro_dialogue() -> Array[String]:
	return [
		"这里是遗忘之渊的最后屏障。",
		"你以为凭一点记忆就能通过？",
		"让我来测试你——你真的记住了吗？",
	]

func get_phase_count() -> int:
	return 2

func on_phase_start(phase: int, battle_state: Dictionary) -> void:
	if phase == 2 and not _phase2_sealed:
		_phase2_sealed = true
		var seals: Array = battle_state.get("seal_types", [])
		seals.append("vocabulary")
		battle_state["seal_types"] = seals

func on_player_correct(attack_type: String, combo: int) -> Dictionary:
	if combo >= 5:
		return { "message": "…不可能，你怎么记得这么清楚！" }
	return {}

func on_player_wrong(attack_type: String) -> Dictionary:
	return { "message": "遗忘侵蚀你的记忆…" }

func boss_action(battle_state: Dictionary) -> Dictionary:
	var phase: int = battle_state.get("phase", 1)
	var combo: int = battle_state.get("combo", 0)
	if phase == 2:
		if combo >= 3:
			return { "type": "shuffle_options", "value": true, "message": "图书管理员打乱了选项！" }
		return { "type": "damage", "value": 12, "message": "遗忘之力强化侵袭！" }
	if combo >= 3:
		return { "type": "shuffle_options", "value": true, "message": "图书管理员打乱了选项！" }
	return { "type": "damage", "value": 8, "message": "遗忘之力侵蚀你的记忆…" }

func get_defeat_dialogue() -> Array[String]:
	return [
		"…不可思议。记忆…竟然如此顽强。",
		"你通过了遗忘的考验。",
		"大关已解封。更深处的知识，等待你去发现。",
	]
```

- [ ] **Step 3: 提交**

```bash
git add src/content/english/bosses/librarian_boss.gd
git commit -m "feat: add LibrarianBoss with 2-phase seal+shuffle mechanics"
```

---

## Task 6: Gate 场景控制器 + 场景文件

**Files:**
- Create: `src/gate/gate_intro_controller.gd`
- Create: `src/gate/gate_intro_scene.tscn`
- Create: `src/gate/gate_complete_controller.gd`
- Create: `src/gate/gate_complete_scene.tscn`

- [ ] **Step 1: 实现 GateIntroController**

新建 `src/gate/gate_intro_controller.gd`：

```gdscript
extends Control

@onready var _gate_name_label: Label = $GateNameLabel
@onready var _dialogue_label: Label = $DialogueLabel
@onready var _start_button: Button = $StartButton
@onready var _back_button: Button = $BackButton

var _lines: Array[String] = []
var _line_index: int = 0

func _ready() -> void:
	_reload_gate_for_attempt()
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	if _gate_name_label:
		_gate_name_label.text = GameState.pending_gate_config.get("gate_name", "大关")
	_show_current_line()

func _reload_gate_for_attempt() -> void:
	var cfg: Dictionary = GameState.pending_gate_config
	if cfg.is_empty():
		return
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	var questions_per_wave: int = cfg.get("questions_per_wave", 3)
	var wave_count: int = cfg.get("wave_count", 0)
	var total: int = questions_per_wave * (wave_count + 1)  # +1 for boss round
	GameState.gate_questions_pool = pack.get_gate_questions(cfg["gate_id"], total)
	GameState.gate_wave_index = 0
	# 读取入场台词
	var boss_path: String = cfg.get("boss_script_path", "")
	if not boss_path.is_empty():
		var boss_script := load(boss_path)
		if boss_script:
			var boss: BossBase = boss_script.new() as BossBase
			if boss:
				_lines = boss.get_intro_dialogue()
				return
	_lines = ["准备好了吗？大关开始！"]

func _show_current_line() -> void:
	if _lines.is_empty():
		_dialogue_label.text = ""
		return
	_dialogue_label.text = _lines[min(_line_index, _lines.size() - 1)]

func _on_start_pressed() -> void:
	if _line_index < _lines.size() - 1:
		_line_index += 1
		_show_current_line()
		return
	_start_wave()

func _start_wave() -> void:
	var cfg: Dictionary = GameState.pending_gate_config
	if cfg.get("wave_count", 0) == 0:
		_go_to_boss()
		return
	var wave_cfg: Dictionary = cfg.get("wave_enemy", {})
	var ed := EnemyData.new()
	ed.enemy_id = "gate_wave_enemy"
	ed.enemy_name = wave_cfg.get("enemy_name", "关卡敌人")
	ed.max_hp = wave_cfg.get("max_hp", 20)
	ed.base_attack = wave_cfg.get("base_attack", 3)
	ed.weaknesses = wave_cfg.get("weaknesses", [])
	ed.weakness_multipliers = wave_cfg.get("multipliers", {})
	GameState.pending_enemy = ed
	get_tree().change_scene_to_file("res://src/gate/gate_wave_scene.tscn")

func _go_to_boss() -> void:
	var cfg: Dictionary = GameState.pending_gate_config
	var boss_cfg: Dictionary = cfg.get("boss_enemy", {})
	var ed := EnemyData.new()
	ed.enemy_id = cfg.get("gate_id", "boss") + "_boss"
	ed.enemy_name = boss_cfg.get("enemy_name", "Boss")
	ed.max_hp = boss_cfg.get("max_hp", 150)
	ed.base_attack = boss_cfg.get("base_attack", 10)
	ed.weaknesses = boss_cfg.get("weaknesses", [])
	ed.weakness_multipliers = boss_cfg.get("multipliers", {})
	GameState.pending_enemy = ed
	get_tree().change_scene_to_file("res://src/gate/boss_battle_scene.tscn")

func _on_back_pressed() -> void:
	GameState.is_gate_active = false
	GameState.pending_gate_id = ""
	GameState.pending_gate_config = {}
	GameState.gate_questions_pool.clear()
	get_tree().change_scene_to_file("res://src/exploration/exploration_scene.tscn")
```

- [ ] **Step 2: 新建 gate_intro_scene.tscn**

新建 `src/gate/gate_intro_scene.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/gate/gate_intro_controller.gd" id="1_gic"]

[node name="GateIntroScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_gic")

[node name="GateNameLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 10.0
offset_right = 700.0
offset_bottom = 50.0
text = "大关"

[node name="DialogueLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 80.0
offset_right = 700.0
offset_bottom = 250.0
text = ""
autowrap_mode = 3

[node name="StartButton" type="Button" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 280.0
offset_right = 200.0
offset_bottom = 320.0
text = "继续"

[node name="BackButton" type="Button" parent="."]
layout_mode = 1
offset_left = 220.0
offset_top = 280.0
offset_right = 400.0
offset_bottom = 320.0
text = "放弃挑战"
```

- [ ] **Step 3: 实现 GateCompleteController**

新建 `src/gate/gate_complete_controller.gd`：

```gdscript
extends Control

@onready var _title_label: Label = $TitleLabel
@onready var _dialogue_label: Label = $DialogueLabel
@onready var _next_button: Button = $NextButton
@onready var _return_button: Button = $ReturnButton

var _lines: Array[String] = []
var _line_index: int = 0

func _ready() -> void:
	_title_label.text = "🏆 大关通过！"
	_lines = GameState.gate_boss_defeat_lines
	if _lines.is_empty():
		_lines = ["恭喜通关！"]
	_show_current_line()
	_next_button.pressed.connect(_on_next_pressed)
	_return_button.pressed.connect(_on_return_pressed)
	_return_button.visible = false

func _show_current_line() -> void:
	_dialogue_label.text = _lines[min(_line_index, _lines.size() - 1)]
	var is_last: bool = _line_index >= _lines.size() - 1
	_next_button.visible = not is_last
	_return_button.visible = is_last

func _on_next_pressed() -> void:
	_line_index = min(_line_index + 1, _lines.size() - 1)
	_show_current_line()

func _on_return_pressed() -> void:
	GameState.pending_gate_id = ""
	GameState.pending_gate_config = {}
	GameState.gate_boss_defeat_lines = []
	get_tree().change_scene_to_file("res://src/exploration/exploration_scene.tscn")
```

- [ ] **Step 4: 新建 gate_complete_scene.tscn**

新建 `src/gate/gate_complete_scene.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/gate/gate_complete_controller.gd" id="1_gcc"]

[node name="GateCompleteScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_gcc")

[node name="TitleLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 10.0
offset_right = 700.0
offset_bottom = 60.0
text = "🏆 大关通过！"

[node name="DialogueLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 80.0
offset_right = 700.0
offset_bottom = 300.0
text = ""
autowrap_mode = 3

[node name="NextButton" type="Button" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 320.0
offset_right = 180.0
offset_bottom = 360.0
text = "继续"

[node name="ReturnButton" type="Button" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 320.0
offset_right = 200.0
offset_bottom = 360.0
text = "返回探索"
visible = false
```

- [ ] **Step 5: 提交**

```bash
git add src/gate/gate_intro_controller.gd src/gate/gate_intro_scene.tscn \
    src/gate/gate_complete_controller.gd src/gate/gate_complete_scene.tscn
git commit -m "feat: add gate intro and gate complete scenes with dialogue flow"
```

---

## Task 7: KnowledgeGateNode + ExplorationController 接线

**Files:**
- Create: `src/exploration/knowledge_gate_node.gd`
- Modify: `src/exploration/exploration_controller.gd`

- [ ] **Step 1: 实现 KnowledgeGateNode**

新建 `src/exploration/knowledge_gate_node.gd`：

```gdscript
class_name KnowledgeGateNode extends Button

var gate_config: Dictionary = {}

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(cfg: Dictionary) -> void:
	gate_config = cfg
	var gate_id: String = cfg.get("gate_id", "")
	var required_level: int = cfg.get("required_knowledge_level", 1)
	var gate_name: String = cfg.get("gate_name", "大关")
	var is_completed: bool = gate_id in GameState.completed_gate_ids
	var is_locked: bool = GameState.knowledge_level < required_level
	if is_completed:
		text = "✅ " + gate_name + "（已通关）"
		disabled = false   # 允许重进
	elif is_locked:
		text = "🔒 " + gate_name + "（需知识层级 %d）" % required_level
		disabled = true
	else:
		text = "⚔️ " + gate_name + " 【大关挑战】"
		disabled = false

func _on_pressed() -> void:
	if gate_config.is_empty():
		return
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	var cfg: Dictionary = gate_config
	var questions_per_wave: int = cfg.get("questions_per_wave", 3)
	var wave_count: int = cfg.get("wave_count", 0)
	var total: int = questions_per_wave * (wave_count + 1)
	var questions: Array[Dictionary] = []
	questions.assign(pack.get_gate_questions(cfg["gate_id"], total))
	GameState.start_gate(cfg, questions)
	get_tree().change_scene_to_file("res://src/gate/gate_intro_scene.tscn")
```

- [ ] **Step 2: 修改 ExplorationController**

读取 `src/exploration/exploration_controller.gd`，做两处修改：

**a) 在 `_ready()` 中，`_spawn_enemy_nodes()` 之后追加**：

```gdscript
	_spawn_gate_nodes()
	GameState.gate_completed.connect(_on_gate_completed)
```

**b) 在文件末尾追加两个方法**：

```gdscript
func _spawn_gate_nodes() -> void:
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	if not pack:
		return
	var gates: Array[Dictionary] = []
	gates.assign(pack.get_gates())
	for cfg in gates:
		var gn := KnowledgeGateNode.new()
		_node_area.add_child(gn)
		gn.setup(cfg)

func _on_gate_completed(gate_id: String) -> void:
	for child in _node_area.get_children():
		if child is KnowledgeGateNode:
			child.setup(child.gate_config)
```

- [ ] **Step 3: 提交**

```bash
git add src/exploration/knowledge_gate_node.gd \
    src/exploration/exploration_controller.gd
git commit -m "feat: add KnowledgeGateNode and wire exploration scene to spawn gate entries"
```

- [ ] **Step 4: Push 到 GitHub**

```bash
git push
```

---

## Phase 5 完成标准

- [ ] `test_gate_wave_controller.gd` — 5 条 GUT 测试全部通过
- [ ] `test_boss_battle_controller.gd` — 9 条 GUT 测试全部通过
- [ ] 探索场景显示大关按钮，knowledge_level 不足时置灰
- [ ] 完整流程可跑通：点击大关 → intro 台词 → wave 战 × N → boss 战 → 通关 → 返回探索
- [ ] 4种 boss action 全部生效：封印类型按钮消失、打乱选项保留正确答案索引、缩短时限不低于3秒、直接伤害
- [ ] 2阶段切换：Boss HP降至50%时触发 `on_phase_start(2)`，LibrarianBoss 封印词汇类型
- [ ] 失败后回 gate_intro 可重试，HP 恢复满血，题目池重新加载
- [ ] 通关后 `knowledge_level` 提升，`completed_gate_ids` 包含 gate_id，`gate_completed` 信号触发，探索节点刷新

---

## 与其他 Phase 的接口约定

- **Phase 6（英语内容包）**：在真实 `EnglishGrade46ContentPack.get_gates()` 中定义多个大关，`boss_script_path` 指向 `librarian_boss.gd` 及后续 Boss；`get_gate_questions()` 返回精选陷阱题
- **Phase 7（Supabase）**：`complete_gate()` 调用 `save_system.save_game_state()` 已存在，Supabase sync 只需在 save_system 中追加云端写入
- **Phase 8（语音）**：`gate_intro_controller` 和 `gate_complete_controller` 的 `_lines` 数组每条可附带 `audio_text` 字段，Phase 8 为 TTS 播放预留
