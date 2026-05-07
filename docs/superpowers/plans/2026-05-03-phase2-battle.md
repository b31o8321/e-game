# 知识神塔 Phase 2 — 战斗系统

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现完整的战斗场景：玩家主动选攻击 → 弹出多选题（含发音/讲解）→ 连击系统 → 怪物弱点克制 → HP耗尽触发撤退报告。同时实现燃爆流和铁壁流 BD 技能初始组，以及远征开始时的技能选择流程。

**Architecture:** 战斗逻辑由 `BattleController` 状态机驱动，题目渲染由 `QuestionController` 独立负责，连击由 `ComboSystem` 单独管理。三者通过 Godot 信号解耦，不直接互相调用。技能通过 `SkillBase` 接口在战斗回调钩子中注入效果，战斗引擎不知道具体技能实现。所有敌人数据以 `EnemyData` Resource 定义，从 ContentPack 或本地 JSON 读取。

**Tech Stack:** Godot 4 · GDScript · GUT · ContentPackBase（Phase 1 已定义）· SkillBase（Phase 1 已定义）

**依赖 Phase 1：**
- `GameState` autoload（HP、combo_count、active_bd_skills、equipment_slots）
- `ContentPackBase`（提供题目：`get_question()`）
- `SkillBase`（技能钩子接口）
- `SRSSystem`（答题后调用 `record_answer()`）

---

## 文件结构

```
src/battle/
├── battle_scene.tscn              # 战斗主场景
├── battle_controller.gd           # 状态机：IDLE→QUESTION→RESOLVING→ENEMY_TURN→END
├── enemy_data.gd                  # Resource：敌人定义（id, name, hp, weaknesses）
├── combo_system.gd                # 连击计数，阈值触发信号
├── question_ui.tscn               # 题目弹出 UI 场景
├── question_controller.gd         # 渲染题目、倒计时、发音、讲解
├── expedition_setup.tscn          # 远征开始：随机抽3技能选1
├── expedition_setup_controller.gd
└── skills/
    ├── blaze/
    │   ├── blaze_accelerator.gd   # 燃爆流：连击加速（每连击+答题时限0.5s）
    │   ├── ember.gd               # 燃爆流：余烬（答对后敌人持续掉血）
    │   └── super_combo.gd         # 燃爆流：超连击（10连触发范围爆炸）
    └── tank/
        ├── error_shield.gd        # 铁壁流：错误护盾（每5题答错1次不断连击）
        ├── regeneration.gd        # 铁壁流：回血（每10连击回复15HP）
        └── unyielding.gd          # 铁壁流：不屈（HP<20%时攻击力×2）

tests/
├── test_battle_controller.gd
├── test_combo_system.gd
├── test_question_controller.gd
└── mock_content_pack.gd           # 测试用 ContentPackBase 子类
```

---

## Task 1: EnemyData Resource + MockContentPack

**Files:**
- Create: `src/battle/enemy_data.gd`
- Create: `tests/mock_content_pack.gd`

- [ ] **Step 1: 创建 EnemyData**

新建 `src/battle/enemy_data.gd`：

```gdscript
class_name EnemyData extends Resource

@export var enemy_id: String = ""
@export var enemy_name: String = ""
@export var max_hp: int = 100
## 弱点攻击类型列表，如 ["vocabulary", "grammar"]
@export var weaknesses: Array[String] = []
## 弱点倍率，如 { "vocabulary": 2.0, "grammar": 1.5 }
@export var weakness_multipliers: Dictionary = {}
## 基础攻击伤害
@export var base_attack: int = 10
## 精灵图路径（Phase 2 用占位符，美术后替换）
@export var sprite_path: String = ""

## 计算对此敌人使用 attack_type 的伤害倍率
func get_damage_multiplier(attack_type_id: String) -> float:
	return weakness_multipliers.get(attack_type_id, 1.0)
```

- [ ] **Step 2: 创建 MockContentPack（测试专用）**

新建 `tests/mock_content_pack.gd`：

```gdscript
class_name MockContentPack extends ContentPackBase

func _init() -> void:
	pack_id = "mock_pack"
	subject = "english"

func get_attack_types() -> Array[Dictionary]:
	return [
		{ "id": "vocabulary", "name": "词汇", "icon": "📚", "color": "#667eea", "element": "fire" },
		{ "id": "grammar", "name": "语法", "icon": "📝", "color": "#f5576c", "element": "ice" },
	]

func get_question(attack_type_id: String, difficulty: int, exclude_ids: Array[String]) -> Dictionary:
	return {
		"id": "q_mock_001",
		"attack_type_id": attack_type_id,
		"question": "What does 'brave' mean?",
		"options": ["勇敢的", "聪明的", "安静的", "友善的"],
		"correct_index": 0,
		"explanation": "Brave [breɪv] · 形容词 · 勇敢的\n例句：The brave knight saved the village.",
		"audio_text": "brave",
		"difficulty": difficulty,
	}
```

- [ ] **Step 3: 提交**

```bash
git add src/battle/enemy_data.gd tests/mock_content_pack.gd
git commit -m "feat: add EnemyData resource and MockContentPack for testing"
```

---

## Task 2: ComboSystem

**Files:**
- Create: `src/battle/combo_system.gd`
- Create: `tests/test_combo_system.gd`

- [ ] **Step 1: 写失败测试**

新建 `tests/test_combo_system.gd`：

```gdscript
extends GutTest

var combo: ComboSystem

func before_each() -> void:
	combo = ComboSystem.new()
	add_child_autofree(combo)

func test_initial_count_is_zero() -> void:
	assert_eq(combo.count, 0)

func test_increment_increases_count() -> void:
	combo.increment()
	assert_eq(combo.count, 1)

func test_reset_clears_count() -> void:
	combo.increment()
	combo.increment()
	combo.reset()
	assert_eq(combo.count, 0)

func test_threshold_3_signal_emitted() -> void:
	watch_signals(combo)
	combo.increment()
	combo.increment()
	combo.increment()
	assert_signal_emitted(combo, "threshold_reached")
	assert_signal_emitted_with_parameters(combo, "threshold_reached", [3])

func test_threshold_5_signal_emitted() -> void:
	watch_signals(combo)
	for i in 5:
		combo.increment()
	assert_signal_emitted_with_parameters(combo, "threshold_reached", [5])

func test_threshold_10_signal_emitted() -> void:
	watch_signals(combo)
	for i in 10:
		combo.increment()
	assert_signal_emitted_with_parameters(combo, "threshold_reached", [10])

func test_reset_after_wrong_answer() -> void:
	combo.increment()
	combo.increment()
	combo.on_wrong_answer()
	assert_eq(combo.count, 0)
```

- [ ] **Step 2: 运行测试确认失败**

Expected: FAIL（ComboSystem 未定义）

- [ ] **Step 3: 实现 ComboSystem**

新建 `src/battle/combo_system.gd`：

```gdscript
class_name ComboSystem extends Node

var count: int = 0

## 阈值列表，到达时触发 threshold_reached 信号
const THRESHOLDS: Array[int] = [3, 5, 10]

signal combo_updated(count: int)
signal threshold_reached(threshold: int)

func increment() -> void:
	count += 1
	combo_updated.emit(count)
	if count in THRESHOLDS:
		threshold_reached.emit(count)

func reset() -> void:
	count = 0
	combo_updated.emit(count)

func on_wrong_answer() -> void:
	reset()
```

- [ ] **Step 4: 运行测试确认通过**

Expected: 8 tests PASS

- [ ] **Step 5: 提交**

```bash
git add src/battle/combo_system.gd tests/test_combo_system.gd
git commit -m "feat: add ComboSystem with threshold signals"
```

---

## Task 3: QuestionController

**Files:**
- Create: `src/battle/question_ui.tscn`
- Create: `src/battle/question_controller.gd`
- Create: `tests/test_question_controller.gd`

- [ ] **Step 1: 写失败测试**

新建 `tests/test_question_controller.gd`：

```gdscript
extends GutTest

var controller: QuestionController
var mock_pack: MockContentPack

func before_each() -> void:
	controller = QuestionController.new()
	add_child_autofree(controller)
	mock_pack = MockContentPack.new()

func test_load_question_sets_current() -> void:
	var q: Dictionary = mock_pack.get_question("vocabulary", 1, [])
	controller.load_question(q)
	assert_eq(controller.current_question["id"], "q_mock_001")

func test_answer_correct_emits_signal() -> void:
	watch_signals(controller)
	var q: Dictionary = mock_pack.get_question("vocabulary", 1, [])
	controller.load_question(q)
	controller.submit_answer(0)
	assert_signal_emitted(controller, "answered")
	assert_signal_emitted_with_parameters(controller, "answered", [true, "q_mock_001"])

func test_answer_wrong_emits_signal() -> void:
	watch_signals(controller)
	var q: Dictionary = mock_pack.get_question("vocabulary", 1, [])
	controller.load_question(q)
	controller.submit_answer(1)
	assert_signal_emitted_with_parameters(controller, "answered", [false, "q_mock_001"])

func test_timer_expiry_counts_as_wrong() -> void:
	watch_signals(controller)
	var q: Dictionary = mock_pack.get_question("vocabulary", 1, [])
	controller.load_question(q)
	controller.on_timer_expired()
	assert_signal_emitted_with_parameters(controller, "answered", [false, "q_mock_001"])
```

- [ ] **Step 2: 实现 QuestionController**

新建 `src/battle/question_controller.gd`：

```gdscript
class_name QuestionController extends Node

var current_question: Dictionary = {}
var _answered: bool = false

## default time limit in seconds; skills can modify this
var time_limit: float = 10.0

signal answered(correct: bool, question_id: String)
signal explanation_ready(text: String, audio_text: String)

func load_question(question: Dictionary) -> void:
	current_question = question
	_answered = false

func submit_answer(option_index: int) -> void:
	if _answered or current_question.is_empty():
		return
	_answered = true
	var correct: bool = option_index == current_question.get("correct_index", -1)
	var qid: String = current_question.get("id", "")
	answered.emit(correct, qid)
	if not correct:
		var explanation: String = current_question.get("explanation", "")
		var audio_text: String = current_question.get("audio_text", "")
		explanation_ready.emit(explanation, audio_text)

func on_timer_expired() -> void:
	submit_answer(-1)
```

- [ ] **Step 3: 创建 question_ui.tscn**

新建 `src/battle/question_ui.tscn`：

```
[gd_scene load_steps=2 format=3 uid="uid://question_ui"]

[ext_resource type="Script" path="res://src/battle/question_controller.gd" id="1_qctrl"]

[node name="QuestionUI" type="Control"]
script = ExtResource("1_qctrl")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -150.0
offset_right = 200.0
offset_bottom = 150.0

[node name="QuestionLabel" type="Label" parent="VBoxContainer"]
text = ""

[node name="OptionA" type="Button" parent="VBoxContainer"]
text = "A"

[node name="OptionB" type="Button" parent="VBoxContainer"]
text = "B"

[node name="OptionC" type="Button" parent="VBoxContainer"]
text = "C"

[node name="OptionD" type="Button" parent="VBoxContainer"]
text = "D"

[node name="AudioButton" type="Button" parent="VBoxContainer"]
text = "🔊 发音"

[node name="TimerBar" type="ProgressBar" parent="VBoxContainer"]

[node name="ExplanationLabel" type="Label" parent="VBoxContainer"]
text = ""
visible = false
```

- [ ] **Step 4: 运行测试确认通过**

Expected: 4 tests PASS

- [ ] **Step 5: 提交**

```bash
git add src/battle/question_ui.tscn src/battle/question_controller.gd tests/test_question_controller.gd
git commit -m "feat: add QuestionController with answer/timer signals and question_ui scene"
```

---

## Task 4: BattleController 状态机

**Files:**
- Create: `src/battle/battle_controller.gd`
- Create: `tests/test_battle_controller.gd`

- [ ] **Step 1: 写失败测试**

新建 `tests/test_battle_controller.gd`：

```gdscript
extends GutTest

var bc: BattleController
var enemy: EnemyData
var mock_pack: MockContentPack

func before_each() -> void:
	bc = BattleController.new()
	add_child_autofree(bc)
	enemy = EnemyData.new()
	enemy.enemy_id = "goblin"
	enemy.max_hp = 50
	enemy.weaknesses = ["vocabulary"]
	enemy.weakness_multipliers = { "vocabulary": 2.0 }
	enemy.base_attack = 8
	mock_pack = MockContentPack.new()
	bc.setup(enemy, mock_pack)

func test_initial_state_is_idle() -> void:
	assert_eq(bc.state, BattleController.State.IDLE)

func test_start_player_turn_changes_state() -> void:
	bc.start_player_turn()
	assert_eq(bc.state, BattleController.State.PLAYER_TURN)

func test_select_attack_requires_player_turn_state() -> void:
	# In IDLE state, select_attack should be a no-op
	bc.select_attack("vocabulary")
	assert_eq(bc.state, BattleController.State.IDLE)

func test_correct_answer_damages_enemy() -> void:
	bc.start_player_turn()
	bc.select_attack("vocabulary")
	bc.on_question_answered(true, "q_mock_001")
	assert_lt(bc.enemy_hp, enemy.max_hp)

func test_weakness_multiplier_applied() -> void:
	bc.start_player_turn()
	bc.select_attack("vocabulary")  # vocabulary is a weakness (x2)
	bc.on_question_answered(true, "q_mock_001")
	# base damage is 10, weakness x2 = 20
	assert_eq(bc.enemy_hp, enemy.max_hp - 20)

func test_wrong_answer_damages_player() -> void:
	var hp_before: int = GameState.player_hp
	bc.start_player_turn()
	bc.select_attack("vocabulary")
	bc.on_question_answered(false, "q_mock_001")
	assert_lt(GameState.player_hp, hp_before)

func test_enemy_defeat_emits_signal() -> void:
	watch_signals(bc)
	bc.enemy_hp = 1
	bc.start_player_turn()
	bc.select_attack("vocabulary")
	bc.on_question_answered(true, "q_mock_001")
	assert_signal_emitted(bc, "battle_ended")
	assert_signal_emitted_with_parameters(bc, "battle_ended", [true])

func test_player_defeat_emits_signal() -> void:
	watch_signals(bc)
	GameState.player_hp = 1
	bc.start_player_turn()
	bc.select_attack("vocabulary")
	bc.on_question_answered(false, "q_mock_001")
	assert_signal_emitted_with_parameters(bc, "battle_ended", [false])
```

- [ ] **Step 2: 实现 BattleController**

新建 `src/battle/battle_controller.gd`：

```gdscript
class_name BattleController extends Node

enum State { IDLE, PLAYER_TURN, QUESTION, RESOLVING, ENEMY_TURN, END }

var state: State = State.IDLE
var enemy_hp: int = 0
var current_attack_type: String = ""
var base_player_damage: int = 10

var _enemy: EnemyData
var _pack: ContentPackBase

signal battle_ended(victory: bool)
signal attack_selected(attack_type_id: String, question: Dictionary)
signal damage_dealt(amount: int, is_weakness: bool)
signal damage_received(amount: int)

func setup(enemy: EnemyData, pack: ContentPackBase) -> void:
	_enemy = enemy
	_pack = pack
	enemy_hp = enemy.max_hp
	state = State.IDLE

func start_player_turn() -> void:
	if state != State.IDLE:
		return
	state = State.PLAYER_TURN

func select_attack(attack_type_id: String) -> void:
	if state != State.PLAYER_TURN:
		return
	current_attack_type = attack_type_id
	state = State.QUESTION
	var question: Dictionary = _pack.get_question(attack_type_id, 1, [])
	attack_selected.emit(attack_type_id, question)

func on_question_answered(correct: bool, question_id: String) -> void:
	if state != State.QUESTION:
		return
	state = State.RESOLVING
	GameState.srs_system.record_answer(question_id, correct)
	if correct:
		_apply_player_attack()
	else:
		_apply_enemy_attack()

func _apply_player_attack() -> void:
	var multiplier: float = _enemy.get_damage_multiplier(current_attack_type)
	var is_weakness: bool = multiplier > 1.0
	var skill_bonus: int = _get_skill_attack_bonus()
	var damage: int = int((base_player_damage + skill_bonus) * multiplier)
	enemy_hp = max(0, enemy_hp - damage)
	damage_dealt.emit(damage, is_weakness)
	GameState.increment_combo()
	_call_skill_hooks_on_correct()
	if enemy_hp == 0:
		state = State.END
		battle_ended.emit(true)
		return
	state = State.IDLE

func _apply_enemy_attack() -> void:
	GameState.combo_count = 0
	GameState.combo_changed.emit(0)
	_call_skill_hooks_on_wrong()
	var damage: int = _enemy.base_attack
	damage_received.emit(damage)
	GameState.take_damage(damage)
	if GameState.player_hp == 0:
		state = State.END
		battle_ended.emit(false)
		return
	state = State.IDLE

func _get_skill_attack_bonus() -> int:
	var bonus: int = 0
	for skill_id in GameState.active_bd_skills:
		# Phase 6 will wire actual skill instances; for now, no bonus
		pass
	return bonus

func _call_skill_hooks_on_correct() -> void:
	pass  # Phase 2 skill tasks will implement this

func _call_skill_hooks_on_wrong() -> void:
	pass  # Phase 2 skill tasks will implement this
```

- [ ] **Step 3: 修复测试中 GameState.player_hp 的初始状态**

`test_wrong_answer_damages_player` 和 `test_player_defeat_emits_signal` 依赖 `GameState.player_hp`。在 `before_each` 中重置：

在 `test_battle_controller.gd` 的 `before_each()` 末尾添加：

```gdscript
	GameState.player_hp = 100
	GameState.player_max_hp = 100
	GameState.combo_count = 0
```

- [ ] **Step 4: 运行测试确认通过**

Expected: 8 tests PASS

- [ ] **Step 5: 提交**

```bash
git add src/battle/battle_controller.gd tests/test_battle_controller.gd
git commit -m "feat: add BattleController state machine with weakness multipliers and GameState integration"
```

---

## Task 5: 战斗主场景 + 攻击选择 UI

**Files:**
- Create: `src/battle/battle_scene.tscn`
- Modify: `src/battle/battle_controller.gd` (add scene wiring)

- [ ] **Step 1: 创建 battle_scene.tscn**

新建 `src/battle/battle_scene.tscn`：

```
[gd_scene load_steps=3 format=3 uid="uid://battle_scene"]

[ext_resource type="Script" path="res://src/battle/battle_controller.gd" id="1_bc"]
[ext_resource type="PackedScene" path="res://src/battle/question_ui.tscn" id="2_qui"]

[node name="BattleScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_bc")

[node name="EnemyArea" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 300.0
offset_top = 80.0
offset_right = 600.0
offset_bottom = 250.0

[node name="EnemyNameLabel" type="Label" parent="EnemyArea"]
text = "敌人名称"

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

[node name="QuestionUIInstance" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
visible = false
```

- [ ] **Step 2: 在 BattleController 添加场景节点引用和 UI 更新**

在 `battle_controller.gd` 顶部 setup() 之前添加节点引用和初始化方法：

```gdscript
# Scene node refs (set by scene, null-safe in unit tests)
var enemy_name_label: Label
var enemy_hp_bar: ProgressBar
var weakness_label: Label
var player_hp_bar: ProgressBar
var combo_label: Label
var attack_buttons_container: HBoxContainer
var question_ui_node: Control

func setup_scene_nodes(
		p_enemy_name: Label,
		p_enemy_hp: ProgressBar,
		p_weakness: Label,
		p_player_hp: ProgressBar,
		p_combo: Label,
		p_attack_buttons: HBoxContainer,
		p_question_ui: Control) -> void:
	enemy_name_label = p_enemy_name
	enemy_hp_bar = p_enemy_hp
	weakness_label = p_weakness
	player_hp_bar = p_player_hp
	combo_label = p_combo
	attack_buttons_container = p_attack_buttons
	question_ui_node = p_question_ui
	# Connect GameState signals for UI refresh
	GameState.hp_changed.connect(_on_player_hp_changed)
	GameState.combo_changed.connect(_on_combo_changed)

func refresh_enemy_ui() -> void:
	if enemy_name_label:
		enemy_name_label.text = _enemy.enemy_name
	if enemy_hp_bar:
		enemy_hp_bar.max_value = _enemy.max_hp
		enemy_hp_bar.value = enemy_hp
	if weakness_label and _pack:
		var types: Array[Dictionary] = _pack.get_attack_types()
		var weak_names: Array[String] = []
		for t in types:
			if t["id"] in _enemy.weaknesses:
				weak_names.append(t["name"])
		weakness_label.text = "弱点: " + ", ".join(weak_names)

func build_attack_buttons() -> void:
	if not attack_buttons_container or not _pack:
		return
	for child in attack_buttons_container.get_children():
		child.queue_free()
	for attack_type in _pack.get_attack_types():
		var btn: Button = Button.new()
		btn.text = attack_type.get("icon", "") + " " + attack_type.get("name", "")
		var type_id: String = attack_type["id"]
		btn.pressed.connect(func(): select_attack(type_id))
		attack_buttons_container.add_child(btn)

func _on_player_hp_changed(new_hp: int, max_hp: int) -> void:
	if player_hp_bar:
		player_hp_bar.max_value = max_hp
		player_hp_bar.value = new_hp

func _on_combo_changed(count: int) -> void:
	if combo_label:
		combo_label.text = "连击: " + str(count)
```

- [ ] **Step 3: 提交**

```bash
git add src/battle/battle_scene.tscn src/battle/battle_controller.gd
git commit -m "feat: add battle scene with attack buttons, HP bars, combo label"
```

---

## Task 6: 燃爆流 BD 技能（3 个）

**Files:**
- Create: `src/battle/skills/blaze/blaze_accelerator.gd`
- Create: `src/battle/skills/blaze/ember.gd`
- Create: `src/battle/skills/blaze/super_combo.gd`
- Modify: `src/battle/battle_controller.gd` (接入技能钩子)

- [ ] **Step 1: BlazeAccelerator（连击加速）**

新建 `src/battle/skills/blaze/blaze_accelerator.gd`：

```gdscript
class_name BlazeAccelerator extends SkillBase

func _init() -> void:
	skill_id = "blaze_accelerator"
	skill_name = "连击加速"
	bd_path = "blaze"
	skill_type = "passive"
	description = "每次连击后，下一题答题时限 +0.5 秒（最多 +5 秒）"

## 被动：答对后通知 QuestionController 延长时限
func on_correct(battle_state: Dictionary) -> void:
	var bonus: float = min(GameState.combo_count * 0.5, 5.0)
	battle_state["time_limit_bonus"] = bonus
```

- [ ] **Step 2: Ember（余烬）**

新建 `src/battle/skills/blaze/ember.gd`：

```gdscript
class_name Ember extends SkillBase

var _ember_stacks: int = 0
const EMBER_DAMAGE: int = 3
const MAX_STACKS: int = 5

func _init() -> void:
	skill_id = "ember"
	skill_name = "余烬"
	bd_path = "blaze"
	skill_type = "passive"
	description = "答对后敌人附加余烬（最多5层），每回合开始时各层造成 3 点伤害"

func on_correct(battle_state: Dictionary) -> void:
	_ember_stacks = min(_ember_stacks + 1, MAX_STACKS)
	battle_state["ember_stacks"] = _ember_stacks

func on_round_start(battle_state: Dictionary) -> void:
	if _ember_stacks > 0:
		battle_state["ember_damage"] = _ember_stacks * EMBER_DAMAGE

func on_wrong(battle_state: Dictionary) -> void:
	_ember_stacks = 0
	battle_state["ember_stacks"] = 0
```

- [ ] **Step 3: SuperCombo（超连击）**

新建 `src/battle/skills/blaze/super_combo.gd`：

```gdscript
class_name SuperCombo extends SkillBase

func _init() -> void:
	skill_id = "super_combo"
	skill_name = "超连击"
	bd_path = "blaze"
	skill_type = "passive"
	description = "连击达到10时，触发范围爆炸，造成额外 50 点伤害"

func on_correct(battle_state: Dictionary) -> void:
	if GameState.combo_count == 10:
		battle_state["super_combo_triggered"] = true
		battle_state["super_combo_damage"] = 50
```

- [ ] **Step 4: 接入 BattleController 技能钩子**

在 `battle_controller.gd` 中替换两个 pass 方法：

```gdscript
func _call_skill_hooks_on_correct() -> void:
	var battle_state: Dictionary = _build_battle_state()
	for skill in _get_active_skill_instances():
		skill.on_correct(battle_state)
	_apply_battle_state_effects(battle_state)

func _call_skill_hooks_on_wrong() -> void:
	var battle_state: Dictionary = _build_battle_state()
	for skill in _get_active_skill_instances():
		skill.on_wrong(battle_state)

func _build_battle_state() -> Dictionary:
	return {
		"player_hp": GameState.player_hp,
		"enemy_hp": enemy_hp,
		"combo": GameState.combo_count,
		"round": 0,
		"sealed_types": [],
		"time_limit_bonus": 0.0,
		"ember_stacks": 0,
		"ember_damage": 0,
		"super_combo_triggered": false,
		"super_combo_damage": 0,
	}

func _get_active_skill_instances() -> Array[SkillBase]:
	# Phase 6 will load from ContentPack; for now return empty
	return []

func _apply_battle_state_effects(battle_state: Dictionary) -> void:
	if battle_state.get("super_combo_triggered", false):
		var extra: int = battle_state.get("super_combo_damage", 0)
		enemy_hp = max(0, enemy_hp - extra)
	if battle_state.get("ember_damage", 0) > 0:
		enemy_hp = max(0, enemy_hp - battle_state["ember_damage"])
```

- [ ] **Step 5: 提交**

```bash
git add src/battle/skills/blaze/ src/battle/battle_controller.gd
git commit -m "feat: add blaze BD skills (accelerator, ember, super_combo) and wire skill hooks"
```

---

## Task 7: 铁壁流 BD 技能（3 个）

**Files:**
- Create: `src/battle/skills/tank/error_shield.gd`
- Create: `src/battle/skills/tank/regeneration.gd`
- Create: `src/battle/skills/tank/unyielding.gd`

- [ ] **Step 1: ErrorShield（错误护盾）**

新建 `src/battle/skills/tank/error_shield.gd`：

```gdscript
class_name ErrorShield extends SkillBase

var _wrong_count: int = 0
const SHIELD_INTERVAL: int = 5

func _init() -> void:
	skill_id = "error_shield"
	skill_name = "错误护盾"
	bd_path = "tank"
	skill_type = "passive"
	description = "每答错 5 次，下一次答错不打断连击"

var _shield_active: bool = false

func on_wrong(battle_state: Dictionary) -> void:
	_wrong_count += 1
	if _wrong_count % SHIELD_INTERVAL == 0:
		_shield_active = true
	if _shield_active:
		battle_state["preserve_combo"] = true
		_shield_active = false
```

- [ ] **Step 2: Regeneration（回血）**

新建 `src/battle/skills/tank/regeneration.gd`：

```gdscript
class_name Regeneration extends SkillBase

const HEAL_AMOUNT: int = 15
const TRIGGER_COMBO: int = 10

func _init() -> void:
	skill_id = "regeneration"
	skill_name = "回血"
	bd_path = "tank"
	skill_type = "passive"
	description = "每达到10连击，回复 15 HP"

func on_correct(battle_state: Dictionary) -> void:
	if GameState.combo_count > 0 and GameState.combo_count % TRIGGER_COMBO == 0:
		var healed: int = min(HEAL_AMOUNT, GameState.player_max_hp - GameState.player_hp)
		GameState.player_hp += healed
		battle_state["healed"] = healed
		GameState.hp_changed.emit(GameState.player_hp, GameState.player_max_hp)
```

- [ ] **Step 3: Unyielding（不屈）**

新建 `src/battle/skills/tank/unyielding.gd`：

```gdscript
class_name Unyielding extends SkillBase

const LOW_HP_THRESHOLD: float = 0.2
const DAMAGE_MULTIPLIER: float = 2.0

func _init() -> void:
	skill_id = "unyielding"
	skill_name = "不屈"
	bd_path = "tank"
	skill_type = "passive"
	description = "HP 低于 20% 时，攻击伤害翻倍"

func on_correct(battle_state: Dictionary) -> void:
	var hp_ratio: float = float(GameState.player_hp) / float(GameState.player_max_hp)
	if hp_ratio < LOW_HP_THRESHOLD:
		battle_state["damage_multiplier"] = DAMAGE_MULTIPLIER
```

- [ ] **Step 4: 在 BattleController._apply_battle_state_effects 接入护盾和伤害倍率**

在 `battle_controller.gd` 的 `_apply_battle_state_effects` 末尾追加：

```gdscript
	# Tank: damage multiplier from Unyielding
	if battle_state.get("damage_multiplier", 1.0) != 1.0:
		# retroactively applied — store for next attack instead
		# (signal already emitted; this is a design note for Phase refinement)
		pass
```

注意：`damage_multiplier` 需要在 `_apply_player_attack()` 中读取，而不是在 aftermath。在 `_apply_player_attack()` 里加入：

```gdscript
	# gather pre-attack battle state for skill effects
	var pre_state: Dictionary = _build_battle_state()
	_call_skill_hooks_pre_attack(pre_state)
	var extra_multiplier: float = pre_state.get("damage_multiplier", 1.0)
	var damage: int = int((base_player_damage + skill_bonus) * multiplier * extra_multiplier)
```

添加新方法：

```gdscript
func _call_skill_hooks_pre_attack(battle_state: Dictionary) -> void:
	for skill in _get_active_skill_instances():
		skill.on_correct(battle_state)
```

- [ ] **Step 5: 提交**

```bash
git add src/battle/skills/tank/ src/battle/battle_controller.gd
git commit -m "feat: add tank BD skills (error_shield, regeneration, unyielding)"
```

---

## Task 8: 远征开始 — 技能选择场景

**Files:**
- Create: `src/battle/expedition_setup.tscn`
- Create: `src/battle/expedition_setup_controller.gd`

- [ ] **Step 1: ExpeditionSetupController**

新建 `src/battle/expedition_setup_controller.gd`：

```gdscript
class_name ExpeditionSetupController extends Control

## 从技能池随机抽 count 个，玩家选1个带入远征
var offered_skills: Array[Dictionary] = []
var selected_skill_id: String = ""

signal skill_chosen(skill_id: String)
signal setup_cancelled()

func offer_skills(all_skills: Array[Dictionary], count: int = 3) -> void:
	all_skills.shuffle()
	offered_skills = all_skills.slice(0, min(count, all_skills.size()))
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	var label: Label = Label.new()
	label.text = "选择本次远征的起始技能"
	add_child(label)
	for skill_dict in offered_skills:
		var btn: Button = Button.new()
		btn.text = skill_dict.get("skill_name", skill_dict.get("skill_id", ""))
		var sid: String = skill_dict.get("skill_id", "")
		btn.pressed.connect(func(): _on_skill_selected(sid))
		add_child(btn)

func _on_skill_selected(skill_id: String) -> void:
	selected_skill_id = skill_id
	GameState.active_bd_skills = [skill_id]
	skill_chosen.emit(skill_id)
```

- [ ] **Step 2: 创建 expedition_setup.tscn**

新建 `src/battle/expedition_setup.tscn`：

```
[gd_scene load_steps=2 format=3 uid="uid://expedition_setup"]

[ext_resource type="Script" path="res://src/battle/expedition_setup_controller.gd" id="1_esc"]

[node name="ExpeditionSetup" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_esc")
```

- [ ] **Step 3: 连接主菜单的"开始冒险"按钮**

修改 `src/ui/main_menu.gd`，在 `_on_start_pressed` 中：

```gdscript
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://src/battle/expedition_setup.tscn")
```

- [ ] **Step 4: 提交**

```bash
git add src/battle/expedition_setup.tscn src/battle/expedition_setup_controller.gd src/ui/main_menu.gd
git commit -m "feat: add expedition setup scene with skill selection and wire start button"
```

---

## Phase 2 完成标准

- [ ] GUT 测试全部通过：ComboSystem 8条 + QuestionController 4条 + BattleController 8条
- [ ] `battle_scene.tscn` 存在，攻击按钮由 ContentPack 动态生成
- [ ] 6 个 BD 技能文件均存在（燃爆流3个，铁壁流3个）
- [ ] 技能通过 SkillBase 接口接入，BattleController 不直接引用具体技能类
- [ ] 远征开始场景存在，主菜单"开始冒险"可跳转

---

## 与其他 Phase 的接口约定

Phase 3（探索）通过以下方式启动战斗：
```gdscript
# 探索场景遭遇怪物时：
get_tree().change_scene_to_file("res://src/battle/battle_scene.tscn")
# BattleController.setup(enemy, GameState.content_loader.get_active_pack()) 由战斗场景 _ready 调用
```

Phase 5（Boss战）复用 BattleController，传入 BossBase 子类作为特殊 enemy，Boss 的 `boss_action()` 在 `_apply_enemy_attack()` 中替代 `enemy.base_attack`。
