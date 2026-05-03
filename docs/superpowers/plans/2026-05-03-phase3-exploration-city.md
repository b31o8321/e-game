# 知识神塔 Phase 3 — 野外探索 + 城市建设

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现野外探索场景（点击资源节点触发 SRS 答题采集）、敌人遭遇节点（跳入战斗）、城市建设场景（升级4座建筑消耗资源），并串联所有场景跳转。

**Architecture:** 探索场景由 `ExplorationController` 管理，资源节点 (`ResourceNode extends Button`) 通过 signal 触发嵌入的 `QuestionController`；敌人节点 (`EnemyEncounterNode extends Button`) 将 EnemyData 写入 `GameState.pending_enemy` 后跳转战斗；`BattleController._ready()` 自动从 `GameState.pending_enemy` 初始化；城市建设由 `CityController.upgrade_building()` 纯逻辑处理，UI 由 `BuildingSlot` 响应。

**Tech Stack:** Godot 4 · GDScript · GUT · Phase 1 GameState · Phase 2 QuestionController / BattleController

**依赖 Phase 1–2：**
- `GameState` autoload（`inventory_resources`, `city_building_levels`, `srs_system`）
- `ContentPackBase.get_question()` / `get_buildings()`
- `QuestionController`（`question_ui.tscn` 已存在）
- `BattleController.setup()` / `setup_scene_nodes()`
- `EnemyData` Resource

---

## 文件结构

```
src/exploration/
├── exploration_scene.tscn        # 探索主场景
├── exploration_controller.gd     # 管理资源/敌人节点、题目弹出、返回
├── resource_node.gd              # extends Button: 点击→答题→采集
├── resource_node.tscn            # Button 根节点
├── enemy_encounter_node.gd       # extends Button: 点击→写入pending_enemy→战斗
└── enemy_encounter_node.tscn     # Button 根节点

src/city/
├── city_scene.tscn               # 城市主场景
├── city_controller.gd            # 升级逻辑、资源检查
├── building_slot.gd              # 单个建筑槽 UI（等级/升级按钮）
└── building_slot.tscn            # Control 根节点

tests/
├── test_resource_node.gd
└── test_city_controller.gd
```

**修改已有文件：**
- `src/core/autoloads/game_state.gd` — 新增 `pending_enemy`, `expedition_return_scene`
- `src/battle/battle_controller.gd` — 新增 `_ready()` 自动初始化 + 战后导航
- `tests/mock_content_pack.gd` — `get_buildings()` 返回真实 mock 数据
- `src/ui/main_menu.gd` — `_on_city_pressed()` 跳转城市场景

---

## Task 1: 基础准备 — GameState 新字段 + MockContentPack 建筑数据

**Files:**
- Modify: `src/core/autoloads/game_state.gd`
- Modify: `tests/mock_content_pack.gd`

- [ ] **Step 1: 在 GameState 添加两个新字段**

在 `src/core/autoloads/game_state.gd` 的 `# 当前远征状态` 块下方（`expedition_loot` 之后）追加：

```gdscript
## 待进入战斗的敌人，ExplorationController 写入，BattleController 读取后置 null
var pending_enemy: EnemyData = null
## 战斗结束后返回的场景路径；空字符串 = 不跳转（单元测试场景）
var expedition_return_scene: String = ""
```

- [ ] **Step 2: 更新 MockContentPack.get_buildings() 返回 mock 建筑**

将 `tests/mock_content_pack.gd` 中的 `get_buildings()` 替换为：

```gdscript
func get_buildings() -> Array[Dictionary]:
	return [
		{
			"id": "vocabulary_library",
			"name": "词汇图书馆",
			"max_level": 3,
			"upgrade_costs": {
				1: { "vocabulary_crystal": 3 },
				2: { "vocabulary_crystal": 8 },
				3: { "vocabulary_crystal": 15 },
			}
		},
		{
			"id": "grammar_academy",
			"name": "语法学院",
			"max_level": 3,
			"upgrade_costs": {
				1: { "grammar_ore": 3 },
				2: { "grammar_ore": 8 },
				3: { "grammar_ore": 15 },
			}
		}
	]
```

- [ ] **Step 3: 提交**

```bash
git add src/core/autoloads/game_state.gd tests/mock_content_pack.gd
git commit -m "feat: add GameState.pending_enemy/expedition_return_scene and mock buildings"
```

---

## Task 2: ResourceNode — 资源节点 TDD

**Files:**
- Create: `src/exploration/resource_node.gd`
- Create: `src/exploration/resource_node.tscn`
- Create: `tests/test_resource_node.gd`

- [ ] **Step 1: 写失败测试**

新建 `tests/test_resource_node.gd`：

```gdscript
extends GutTest

var node_: ResourceNode
var mock_pack: MockContentPack

func before_each() -> void:
	node_ = ResourceNode.new()
	add_child_autofree(node_)
	node_.resource_type_id = "vocabulary_crystal"
	node_.resource_amount = 3
	node_.attack_type_id = "vocabulary"
	mock_pack = MockContentPack.new()
	GameState.inventory_resources = {}

func test_initial_state_is_available() -> void:
	assert_eq(node_.node_state, ResourceNode.NodeState.AVAILABLE)

func test_try_collect_changes_state_to_pending() -> void:
	node_.try_collect(mock_pack)
	assert_eq(node_.node_state, ResourceNode.NodeState.PENDING_ANSWER)

func test_try_collect_emits_question_requested() -> void:
	watch_signals(node_)
	node_.try_collect(mock_pack)
	assert_signal_emitted(node_, "question_requested")

func test_correct_answer_adds_resource_to_game_state() -> void:
	node_.try_collect(mock_pack)
	node_.on_question_answered(true)
	assert_eq(GameState.inventory_resources.get("vocabulary_crystal", 0), 3)

func test_correct_answer_marks_collected() -> void:
	node_.try_collect(mock_pack)
	node_.on_question_answered(true)
	assert_eq(node_.node_state, ResourceNode.NodeState.COLLECTED)

func test_wrong_answer_resets_to_available() -> void:
	node_.try_collect(mock_pack)
	node_.on_question_answered(false)
	assert_eq(node_.node_state, ResourceNode.NodeState.AVAILABLE)
	assert_eq(GameState.inventory_resources.get("vocabulary_crystal", 0), 0)

func test_try_collect_ignored_when_pending() -> void:
	node_.try_collect(mock_pack)
	node_.try_collect(mock_pack)  # 第二次应忽略
	assert_eq(node_.node_state, ResourceNode.NodeState.PENDING_ANSWER)
```

- [ ] **Step 2: 实现 ResourceNode**

新建 `src/exploration/resource_node.gd`：

```gdscript
class_name ResourceNode extends Button

@export var resource_type_id: String = "vocabulary_crystal"
@export var resource_amount: int = 1
@export var attack_type_id: String = "vocabulary"

enum NodeState { AVAILABLE, PENDING_ANSWER, COLLECTED }
var node_state: NodeState = NodeState.AVAILABLE

signal question_requested(node: ResourceNode, question: Dictionary)
signal collected(resource_type_id: String, amount: int)

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	if pack:
		try_collect(pack)

func try_collect(pack: ContentPackBase) -> void:
	if node_state != NodeState.AVAILABLE:
		return
	node_state = NodeState.PENDING_ANSWER
	disabled = true
	var question: Dictionary = pack.get_question(attack_type_id, 1, [])
	question_requested.emit(self, question)

func on_question_answered(correct: bool) -> void:
	if correct:
		node_state = NodeState.COLLECTED
		modulate = Color(0.5, 0.5, 0.5)
		GameState.inventory_resources[resource_type_id] = \
			GameState.inventory_resources.get(resource_type_id, 0) + resource_amount
		collected.emit(resource_type_id, resource_amount)
	else:
		node_state = NodeState.AVAILABLE
		disabled = false
```

- [ ] **Step 3: 创建 resource_node.tscn**

新建 `src/exploration/resource_node.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/exploration/resource_node.gd" id="1_rn"]

[node name="ResourceNode" type="Button"]
script = ExtResource("1_rn")
text = "💎 资源"
```

- [ ] **Step 4: 提交**

```bash
git add src/exploration/resource_node.gd src/exploration/resource_node.tscn tests/test_resource_node.gd
git commit -m "feat: add ResourceNode with question-gated collection and SRS recording"
```

---

## Task 3: ExplorationController + 探索场景

**Files:**
- Create: `src/exploration/exploration_controller.gd`
- Create: `src/exploration/exploration_scene.tscn`

- [ ] **Step 1: 实现 ExplorationController**

新建 `src/exploration/exploration_controller.gd`：

```gdscript
class_name ExplorationController extends Control

## 资源节点配置：[{resource_type, attack_type, amount, label}]
const RESOURCE_NODE_CONFIGS: Array[Dictionary] = [
	{ "resource_type": "vocabulary_crystal", "attack_type": "vocabulary", "amount": 2, "label": "📚 词汇结晶 ×2" },
	{ "resource_type": "vocabulary_crystal", "attack_type": "vocabulary", "amount": 1, "label": "📚 词汇结晶 ×1" },
	{ "resource_type": "grammar_ore",        "attack_type": "grammar",    "amount": 2, "label": "📝 语法矿石 ×2" },
	{ "resource_type": "grammar_ore",        "attack_type": "grammar",    "amount": 1, "label": "📝 语法矿石 ×1" },
]

var _pending_node: ResourceNode = null
var _question_controller: QuestionController = null
var _question_ui: Control = null

@onready var _node_area: VBoxContainer = $NodeArea
@onready var _resource_bar: Label = $ResourceBar
@onready var _return_button: Button = $ReturnButton

func _ready() -> void:
	_spawn_resource_nodes()
	_setup_question_ui()
	_return_button.pressed.connect(_on_return_pressed)
	_update_resource_bar()
	GameState.inventory_resources  # 初始化触发

func _spawn_resource_nodes() -> void:
	var scene: PackedScene = load("res://src/exploration/resource_node.tscn")
	for cfg in RESOURCE_NODE_CONFIGS:
		var rn: ResourceNode = scene.instantiate() as ResourceNode
		rn.resource_type_id = cfg["resource_type"]
		rn.attack_type_id = cfg["attack_type"]
		rn.resource_amount = cfg["amount"]
		rn.text = cfg["label"]
		rn.question_requested.connect(_on_node_question_requested)
		rn.collected.connect(_on_resource_collected)
		_node_area.add_child(rn)

func _setup_question_ui() -> void:
	var scene: PackedScene = load("res://src/battle/question_ui.tscn")
	_question_ui = scene.instantiate() as Control
	_question_ui.visible = false
	add_child(_question_ui)
	_question_controller = _question_ui as QuestionController
	_question_controller.answered.connect(_on_question_answered)

func _on_node_question_requested(node: ResourceNode, question: Dictionary) -> void:
	_pending_node = node
	_question_controller.load_question(question)
	_question_ui.visible = true

func _on_question_answered(correct: bool, question_id: String) -> void:
	_question_ui.visible = false
	GameState.srs_system.record_answer(question_id, correct)
	if _pending_node:
		_pending_node.on_question_answered(correct)
		_pending_node = null
	_update_resource_bar()

func _on_resource_collected(_type: String, _amount: int) -> void:
	_update_resource_bar()

func _update_resource_bar() -> void:
	if not _resource_bar:
		return
	var parts: Array[String] = []
	for k in GameState.inventory_resources:
		parts.append("%s: %d" % [k, GameState.inventory_resources[k]])
	_resource_bar.text = "背包: " + (", ".join(parts) if not parts.is_empty() else "空")

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://src/city/city_scene.tscn")
```

- [ ] **Step 2: 创建 exploration_scene.tscn**

新建 `src/exploration/exploration_scene.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/exploration/exploration_controller.gd" id="1_ec"]

[node name="ExplorationScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_ec")

[node name="ResourceBar" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 10.0
offset_right = 700.0
offset_bottom = 40.0
text = "背包: 空"

[node name="NodeArea" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 50.0
offset_top = 60.0
offset_right = 400.0
offset_bottom = 500.0

[node name="EnemyArea" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 450.0
offset_top = 60.0
offset_right = 750.0
offset_bottom = 300.0

[node name="ReturnButton" type="Button" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 520.0
offset_right = 200.0
offset_bottom = 560.0
text = "返回城市"
```

- [ ] **Step 3: 提交**

```bash
git add src/exploration/exploration_controller.gd src/exploration/exploration_scene.tscn
git commit -m "feat: add exploration scene with resource node spawning and question flow"
```

---

## Task 4: EnemyEncounterNode + BattleController 自动初始化

**Files:**
- Create: `src/exploration/enemy_encounter_node.gd`
- Create: `src/exploration/enemy_encounter_node.tscn`
- Modify: `src/battle/battle_controller.gd` (add `_ready()` + `_on_battle_ended()`)
- Modify: `src/exploration/exploration_controller.gd` (spawn enemy nodes)

- [ ] **Step 1: 创建 EnemyEncounterNode**

新建 `src/exploration/enemy_encounter_node.gd`：

```gdscript
class_name EnemyEncounterNode extends Button

## 遭遇的敌人数据，由场景控制器在 spawn 时设置
var enemy_data: EnemyData = null

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if enemy_data == null:
		push_error("EnemyEncounterNode: enemy_data not set")
		return
	GameState.pending_enemy = enemy_data
	GameState.expedition_return_scene = "res://src/exploration/exploration_scene.tscn"
	get_tree().change_scene_to_file("res://src/battle/battle_scene.tscn")
```

新建 `src/exploration/enemy_encounter_node.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/exploration/enemy_encounter_node.gd" id="1_een"]

[node name="EnemyEncounterNode" type="Button"]
script = ExtResource("1_een")
text = "⚔️ 遭遇怪物"
```

- [ ] **Step 2: 在 ExplorationController 中增加敌人节点生成配置**

在 `src/exploration/exploration_controller.gd` 的 `RESOURCE_NODE_CONFIGS` 常量下方追加：

```gdscript
## 敌人节点配置：[{enemy_id, enemy_name, max_hp, base_attack, weaknesses, multipliers, label}]
const ENEMY_CONFIGS: Array[Dictionary] = [
	{
		"enemy_id": "forest_goblin",
		"enemy_name": "森林哥布林",
		"max_hp": 40,
		"base_attack": 6,
		"weaknesses": ["vocabulary"],
		"multipliers": { "vocabulary": 1.5 },
		"label": "⚔️ 森林哥布林 (弱点: 词汇)",
	},
	{
		"enemy_id": "stone_golem",
		"enemy_name": "石头傀儡",
		"max_hp": 60,
		"base_attack": 8,
		"weaknesses": ["grammar"],
		"multipliers": { "grammar": 2.0 },
		"label": "⚔️ 石头傀儡 (弱点: 语法)",
	},
]
```

在 `_ready()` 末尾追加（在 `_update_resource_bar()` 之前）：

```gdscript
	_spawn_enemy_nodes()
```

在类末尾添加新方法：

```gdscript
func _spawn_enemy_nodes() -> void:
	var scene: PackedScene = load("res://src/exploration/enemy_encounter_node.tscn")
	var area: VBoxContainer = $EnemyArea
	for cfg in ENEMY_CONFIGS:
		var een: EnemyEncounterNode = scene.instantiate() as EnemyEncounterNode
		var ed: EnemyData = EnemyData.new()
		ed.enemy_id = cfg["enemy_id"]
		ed.enemy_name = cfg["enemy_name"]
		ed.max_hp = cfg["max_hp"]
		ed.base_attack = cfg["base_attack"]
		ed.weaknesses = cfg["weaknesses"]
		ed.weakness_multipliers = cfg["multipliers"]
		een.enemy_data = ed
		een.text = cfg["label"]
		area.add_child(een)
```

- [ ] **Step 3: 在 BattleController 末尾添加 `_ready()` 和战后导航**

在 `src/battle/battle_controller.gd` 末尾追加：

```gdscript
func _ready() -> void:
	# 连接节点引用（单元测试中无子节点，get_node_or_null 返回 null 则跳过）
	var enemy_name_lbl := get_node_or_null("EnemyArea/EnemyNameLabel") as Label
	var enemy_hp_bar_node := get_node_or_null("EnemyArea/EnemyHpBar") as ProgressBar
	var weakness_lbl := get_node_or_null("EnemyArea/WeaknessLabel") as Label
	var player_hp_bar_node := get_node_or_null("PlayerArea/PlayerHpBar") as ProgressBar
	var combo_lbl := get_node_or_null("PlayerArea/ComboLabel") as Label
	var attack_btns := get_node_or_null("AttackButtons") as HBoxContainer
	var question_ui := get_node_or_null("QuestionUIInstance") as Control
	if enemy_name_lbl:
		setup_scene_nodes(enemy_name_lbl, enemy_hp_bar_node, weakness_lbl,
			player_hp_bar_node, combo_lbl, attack_btns, question_ui)
	# 从 GameState 自动拾取待战敌人
	if GameState.pending_enemy != null:
		setup(GameState.pending_enemy, GameState.content_loader.get_active_pack())
		refresh_enemy_ui()
		build_attack_buttons()
		start_player_turn()
	battle_ended.connect(_on_battle_ended)

func _on_battle_ended(victory: bool) -> void:
	GameState.pending_enemy = null
	var return_scene: String = GameState.expedition_return_scene
	GameState.expedition_return_scene = ""
	if return_scene.is_empty():
		return  # 单元测试场景：不跳转
	get_tree().change_scene_to_file(return_scene)
```

注意：失败时（`!victory`）`_on_battle_ended` 回到 `expedition_return_scene`（探索场景），玩家可选择返回城市。胜利和失败均回到同一场景，符合"HP 归零自动撤退"设计。

- [ ] **Step 4: 提交**

```bash
git add src/exploration/enemy_encounter_node.gd src/exploration/enemy_encounter_node.tscn \
    src/exploration/exploration_controller.gd src/battle/battle_controller.gd
git commit -m "feat: add EnemyEncounterNode and BattleController auto-setup with scene navigation"
```

---

## Task 5: CityController — 建筑升级 TDD

**Files:**
- Create: `src/city/city_controller.gd`
- Create: `src/city/building_slot.gd`
- Create: `tests/test_city_controller.gd`

- [ ] **Step 1: 写失败测试**

新建 `tests/test_city_controller.gd`：

```gdscript
extends GutTest

var controller: CityController
var mock_pack: MockContentPack

func before_each() -> void:
	controller = CityController.new()
	add_child_autofree(controller)
	mock_pack = MockContentPack.new()
	controller.setup(mock_pack)
	GameState.city_building_levels = {}
	GameState.inventory_resources = {}

func test_upgrade_increases_building_level() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 10 }
	controller.upgrade_building("vocabulary_library")
	assert_eq(GameState.city_building_levels.get("vocabulary_library", 0), 1)

func test_upgrade_deducts_resources() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 10 }
	controller.upgrade_building("vocabulary_library")
	assert_eq(GameState.inventory_resources.get("vocabulary_crystal", 0), 7)

func test_upgrade_returns_true_on_success() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 10 }
	var result: bool = controller.upgrade_building("vocabulary_library")
	assert_true(result)

func test_upgrade_fails_insufficient_resources() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 1 }  # need 3
	var result: bool = controller.upgrade_building("vocabulary_library")
	assert_false(result)
	assert_eq(GameState.city_building_levels.get("vocabulary_library", 0), 0)

func test_upgrade_fails_at_max_level() -> void:
	GameState.city_building_levels = { "vocabulary_library": 3 }
	GameState.inventory_resources = { "vocabulary_crystal": 100 }
	var result: bool = controller.upgrade_building("vocabulary_library")
	assert_false(result)
	assert_eq(GameState.city_building_levels.get("vocabulary_library"), 3)

func test_can_afford_returns_true_when_affordable() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 5 }
	assert_true(controller.can_afford_upgrade("vocabulary_library"))

func test_can_afford_returns_false_when_not_affordable() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 2 }
	assert_false(controller.can_afford_upgrade("vocabulary_library"))

func test_get_buildings_returns_pack_data() -> void:
	var buildings: Array[Dictionary] = controller.get_buildings()
	assert_eq(buildings.size(), 2)
```

- [ ] **Step 2: 实现 CityController**

新建 `src/city/city_controller.gd`：

```gdscript
class_name CityController extends Node

var _pack: ContentPackBase = null
var _buildings_cache: Array[Dictionary] = []

signal building_upgraded(building_id: String, new_level: int)

func setup(pack: ContentPackBase) -> void:
	_pack = pack
	_buildings_cache = _pack.get_buildings()

func get_buildings() -> Array[Dictionary]:
	return _buildings_cache

func get_current_level(building_id: String) -> int:
	return GameState.city_building_levels.get(building_id, 0)

## 升级建筑。返回 true = 成功，false = 资源不足或已满级
func upgrade_building(building_id: String) -> bool:
	var building: Dictionary = _get_building_def(building_id)
	if building.is_empty():
		return false
	var current_level: int = get_current_level(building_id)
	var max_level: int = building.get("max_level", 3)
	if current_level >= max_level:
		return false
	var next_level: int = current_level + 1
	var cost: Dictionary = _get_upgrade_cost(building, next_level)
	if not _has_resources(cost):
		return false
	_deduct_resources(cost)
	GameState.city_building_levels[building_id] = next_level
	building_upgraded.emit(building_id, next_level)
	return true

## 检查是否能负担下一级升级费用
func can_afford_upgrade(building_id: String) -> bool:
	var building: Dictionary = _get_building_def(building_id)
	if building.is_empty():
		return false
	var current_level: int = get_current_level(building_id)
	var max_level: int = building.get("max_level", 3)
	if current_level >= max_level:
		return false
	var next_level: int = current_level + 1
	var cost: Dictionary = _get_upgrade_cost(building, next_level)
	return _has_resources(cost)

func _get_building_def(building_id: String) -> Dictionary:
	for b in _buildings_cache:
		if b.get("id", "") == building_id:
			return b
	return {}

func _get_upgrade_cost(building: Dictionary, level: int) -> Dictionary:
	var costs: Dictionary = building.get("upgrade_costs", {})
	return costs.get(level, {})

func _has_resources(cost: Dictionary) -> bool:
	for resource_id in cost:
		if GameState.inventory_resources.get(resource_id, 0) < cost[resource_id]:
			return false
	return true

func _deduct_resources(cost: Dictionary) -> void:
	for resource_id in cost:
		GameState.inventory_resources[resource_id] = \
			GameState.inventory_resources.get(resource_id, 0) - cost[resource_id]
```

- [ ] **Step 3: 实现 BuildingSlot（响应式 UI 槽）**

新建 `src/city/building_slot.gd`：

```gdscript
class_name BuildingSlot extends Control

var _controller: CityController = null
var _building_id: String = ""
var _building_def: Dictionary = {}

@onready var _name_label: Label = $NameLabel
@onready var _level_label: Label = $LevelLabel
@onready var _upgrade_button: Button = $UpgradeButton

signal upgrade_requested(building_id: String)

func setup(controller: CityController, building_def: Dictionary) -> void:
	_controller = controller
	_building_id = building_def.get("id", "")
	_building_def = building_def
	_controller.building_upgraded.connect(_on_building_upgraded)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	refresh()

func refresh() -> void:
	if not _name_label:
		return
	var current_level: int = _controller.get_current_level(_building_id)
	var max_level: int = _building_def.get("max_level", 3)
	_name_label.text = _building_def.get("name", _building_id)
	_level_label.text = "Lv %d / %d" % [current_level, max_level]
	_upgrade_button.disabled = not _controller.can_afford_upgrade(_building_id)
	if current_level >= max_level:
		_upgrade_button.text = "已满级"
		_upgrade_button.disabled = true
	else:
		var next: int = current_level + 1
		var cost_dict: Dictionary = _building_def.get("upgrade_costs", {}).get(next, {})
		var cost_str: String = _format_cost(cost_dict)
		_upgrade_button.text = "升级 (%s)" % cost_str

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k in cost:
		parts.append("%s×%d" % [k, cost[k]])
	return ", ".join(parts)

func _on_upgrade_pressed() -> void:
	upgrade_requested.emit(_building_id)

func _on_building_upgraded(building_id: String, _new_level: int) -> void:
	if building_id == _building_id:
		refresh()
```

- [ ] **Step 4: 提交**

```bash
git add src/city/city_controller.gd src/city/building_slot.gd tests/test_city_controller.gd
git commit -m "feat: add CityController upgrade logic and BuildingSlot UI component"
```

---

## Task 6: 城市场景 + 场景导航串联

**Files:**
- Create: `src/city/city_scene.tscn`
- Create: `src/city/building_slot.tscn`
- Modify: `src/ui/main_menu.gd`

- [ ] **Step 1: 创建 building_slot.tscn**

新建 `src/city/building_slot.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/city/building_slot.gd" id="1_bs"]

[node name="BuildingSlot" type="Control"]
script = ExtResource("1_bs")
custom_minimum_size = Vector2(0, 80)

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="NameLabel" type="Label" parent="VBoxContainer"]
text = "建筑名称"

[node name="LevelLabel" type="Label" parent="VBoxContainer"]
text = "Lv 0 / 3"

[node name="UpgradeButton" type="Button" parent="VBoxContainer"]
text = "升级"
```

- [ ] **Step 2: 创建 city_scene.tscn**

新建 `src/city/city_scene.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/city/city_scene_controller.gd" id="1_csc"]

[node name="CityScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_csc")

[node name="TitleLabel" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 10.0
offset_right = 300.0
offset_bottom = 40.0
text = "知识神塔 · 城市"

[node name="ResourceBar" type="Label" parent="."]
layout_mode = 1
offset_left = 10.0
offset_top = 45.0
offset_right = 700.0
offset_bottom = 75.0
text = "背包: 空"

[node name="BuildingContainer" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 50.0
offset_top = 90.0
offset_right = 500.0
offset_bottom = 500.0

[node name="StartExpeditionButton" type="Button" parent="."]
layout_mode = 1
offset_left = 50.0
offset_top = 520.0
offset_right = 280.0
offset_bottom = 560.0
text = "出发探索"

[node name="BackToMenuButton" type="Button" parent="."]
layout_mode = 1
offset_left = 300.0
offset_top = 520.0
offset_right = 500.0
offset_bottom = 560.0
text = "返回主菜单"
```

- [ ] **Step 3: 创建 city_scene_controller.gd**

新建 `src/city/city_scene_controller.gd`：

```gdscript
extends Control

var _city_controller: CityController = CityController.new()

@onready var _resource_bar: Label = $ResourceBar
@onready var _building_container: VBoxContainer = $BuildingContainer
@onready var _start_button: Button = $StartExpeditionButton
@onready var _back_button: Button = $BackToMenuButton

func _ready() -> void:
	add_child(_city_controller)
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	if pack:
		_city_controller.setup(pack)
		_build_building_slots()
	_start_button.pressed.connect(_on_start_expedition)
	_back_button.pressed.connect(_on_back_to_menu)
	_city_controller.building_upgraded.connect(_on_any_building_upgraded)
	_update_resource_bar()

func _build_building_slots() -> void:
	var slot_scene: PackedScene = load("res://src/city/building_slot.tscn")
	for building_def in _city_controller.get_buildings():
		var slot: BuildingSlot = slot_scene.instantiate() as BuildingSlot
		slot.upgrade_requested.connect(_on_upgrade_requested)
		_building_container.add_child(slot)
		slot.setup(_city_controller, building_def)

func _on_upgrade_requested(building_id: String) -> void:
	_city_controller.upgrade_building(building_id)
	_update_resource_bar()

func _on_any_building_upgraded(_building_id: String, _level: int) -> void:
	_update_resource_bar()

func _update_resource_bar() -> void:
	var parts: Array[String] = []
	for k in GameState.inventory_resources:
		parts.append("%s: %d" % [k, GameState.inventory_resources[k]])
	_resource_bar.text = "背包: " + (", ".join(parts) if not parts.is_empty() else "空")

func _on_start_expedition() -> void:
	get_tree().change_scene_to_file("res://src/battle/expedition_setup.tscn")

func _on_back_to_menu() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
```

- [ ] **Step 4: 修改 main_menu.gd 接入城市场景**

将 `src/ui/main_menu.gd` 中的 `_on_city_pressed()` 替换为：

```gdscript
func _on_city_pressed() -> void:
	get_tree().change_scene_to_file("res://src/city/city_scene.tscn")
```

- [ ] **Step 5: 提交**

```bash
git add src/city/city_scene.tscn src/city/building_slot.tscn \
    src/city/city_scene_controller.gd src/ui/main_menu.gd
git commit -m "feat: add city scene with building slots, resource display, and full scene navigation"
```

---

## Phase 3 完成标准

- [ ] `tests/test_resource_node.gd` — 7 条 GUT 测试全部通过
- [ ] `tests/test_city_controller.gd` — 8 条 GUT 测试全部通过
- [ ] `exploration_scene.tscn` 存在，ResourceNode 通过 MockContentPack 验证可答题采集
- [ ] `enemy_encounter_node.tscn` 存在，点击后设置 `GameState.pending_enemy`
- [ ] `BattleController._ready()` 在非测试场景自动初始化战斗
- [ ] `city_scene.tscn` 存在，升级按钮在资源不足时禁用
- [ ] 主菜单"我的城市"可跳转城市场景，城市"出发探索"跳转 expedition_setup

---

## 与其他 Phase 的接口约定

Phase 4（撤退报告 + 专项练习）通过 `GameState.expedition_ended` 信号获取战斗统计数据。

Phase 5（大关 + Boss）复用 `BattleController` 和 `EnemyEncounterNode` 架构，通过 `BossBase extends EnemyData`（或组合模式）注入 Boss 行为。

Phase 6（英语内容包）替换 `MockContentPack`，`RESOURCE_NODE_CONFIGS` 中的 `resource_type` 和 `attack_type` 由 ContentPack 驱动。
