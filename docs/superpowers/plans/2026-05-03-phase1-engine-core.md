# 知识神塔 Phase 1 — 引擎核心 + 扩展接口

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建 Godot 4 项目骨架，定义所有扩展钩子接口（ContentPack、Boss、Skill、Equipment、Puzzle、Building），实现 GameState 全局状态管理、存档/读档、SRS 算法核心，使后续各系统可独立开发而不相互阻塞。

**Architecture:** 所有可扩展点定义为 GDScript `class_name` 基类，子类覆盖虚方法即可接入引擎。系统间通过 `GameState` autoload 和 Godot 信号通信，不直接相互引用。ContentPack 以 `Resource` 子类形式加载，运行时动态注册到引擎。

**Tech Stack:** Godot 4.3 · GDScript · GUT（单元测试）· Supabase REST API · JSON 存档

---

## 后续计划索引

| Phase | 文件 | 内容 |
|-------|------|------|
| Phase 1 | 本文件 | 引擎核心 + 所有接口定义 |
| Phase 2 | `2026-05-03-phase2-battle.md` | 战斗场景、连击、题目 UI、BD技能（燃爆/铁壁） |
| Phase 3 | `2026-05-03-phase3-exploration-city.md` | 野外探索、资源节点、城市建设 |
| Phase 4 | `2026-05-03-phase4-loop-integration.md` | 谜题场景、撤退报告、专项练习、主循环串联 |
| Phase 5 | `2026-05-03-phase5-knowledge-gate.md` | 里程碑大关、Boss系统实现、样例Boss |
| Phase 6 | `2026-05-03-phase6-english-pack.md` | 英语ContentPack完整内容（4-6年级） |
| Phase 7 | `2026-05-03-phase7-persistence.md` | Supabase Auth + 进度云同步、离线缓存 |
| Phase 8 | `2026-05-03-phase8-whisper-stt.md` | whisper.cpp GDExtension 集成、口语跟读评分 |
| Phase 9 | `2026-05-03-phase9-parent-dashboard.md` | 家长看板（独立 Web 页面） |
| Phase 10 | `2026-05-03-phase10-export.md` | macOS / Windows / Android 打包配置 |

---

## 项目文件结构

```
e-game/
├── project.godot
├── addons/
│   └── gut/                         # GUT 测试框架（安装后）
├── src/
│   ├── core/
│   │   ├── interfaces/
│   │   │   ├── content_pack_base.gd     # ContentPack 基类
│   │   │   ├── boss_base.gd             # Boss 基类
│   │   │   ├── skill_base.gd            # BD技能基类
│   │   │   ├── equipment_base.gd        # 装备基类
│   │   │   ├── puzzle_base.gd           # 谜题场景基类
│   │   │   └── building_base.gd         # 城市建筑基类
│   │   ├── systems/
│   │   │   ├── content_loader.gd        # ContentPack 注册/查询
│   │   │   ├── srs_system.gd            # 间隔重复算法
│   │   │   └── save_system.gd           # 本地存档读写
│   │   └── autoloads/
│   │       └── game_state.gd            # 全局状态 autoload
│   ├── battle/                          # Phase 2
│   ├── exploration/                     # Phase 3
│   ├── city/                            # Phase 3
│   ├── knowledge_gate/                  # Phase 5
│   ├── puzzle/                          # Phase 4
│   ├── ui/                              # Phase 4
│   └── content_packs/
│       └── english_grade4_6/            # Phase 6
│           ├── english_pack.gd          # ContentPackBase 子类
│           ├── knowledge/               # JSON 题库
│           ├── skills/                  # 技能定义
│           ├── equipment/               # 装备定义
│           ├── buildings/               # 建筑定义
│           └── audio/                   # 发音音频
├── assets/
└── tests/
    ├── test_srs_system.gd
    ├── test_save_system.gd
    └── test_content_loader.gd
```

---

## Task 1: Godot 项目初始化

**Files:**
- Create: `project.godot`
- Create: `src/core/autoloads/game_state.gd`

- [ ] **Step 1: 新建 Godot 4 项目**

在 Godot 4.3 编辑器中：File → New Project，项目名 `e-game`，路径 `/Users/norman/development/e-game`，渲染器选 **Forward+**。

- [ ] **Step 2: 建立目录结构**

```bash
mkdir -p src/core/interfaces src/core/systems src/core/autoloads
mkdir -p src/battle src/exploration src/city src/knowledge_gate src/puzzle src/ui
mkdir -p src/content_packs/english_grade4_6/{knowledge,skills,equipment,buildings,audio}
mkdir -p assets tests
```

- [ ] **Step 3: 安装 GUT 测试框架**

在 Godot 编辑器中：AssetLib → 搜索 "GUT" → 安装 Gut-Godot Unit Testing。
或直接下载 https://github.com/bitwes/Gut/releases 解压到 `addons/gut/`。
Project → Project Settings → Plugins → 勾选 GUT 启用。

- [ ] **Step 4: 创建 GameState autoload**

新建文件 `src/core/autoloads/game_state.gd`：

```gdscript
extends Node

# 玩家核心状态
var player_hp: int = 100
var player_max_hp: int = 100
var combo_count: int = 0
var knowledge_level: int = 1        # 当前知识层级，决定怪物难度
var active_bd_skills: Array[String] = []
var inventory_resources: Dictionary = {}  # resource_id -> count
var equipment_slots: Dictionary = {
    "weapon": "",
    "armor": "",
    "accessory": "",
    "mount": ""
}

# 进度状态
var unlocked_knowledge_ids: Array[String] = []
var completed_gate_ids: Array[String] = []
var city_building_levels: Dictionary = {}  # building_id -> level

# 当前远征状态
var expedition_active: bool = false
var expedition_loot: Dictionary = {}

# 信号
signal hp_changed(new_hp: int, max_hp: int)
signal combo_changed(count: int)
signal knowledge_unlocked(knowledge_id: String)
signal gate_completed(gate_id: String)
signal expedition_ended(report: Dictionary)

func reset_expedition() -> void:
    expedition_active = false
    expedition_loot = {}
    combo_count = 0
    player_hp = player_max_hp
    active_bd_skills.clear()

func take_damage(amount: int) -> void:
    player_hp = max(0, player_hp - amount)
    combo_count = 0
    emit_signal("combo_changed", combo_count)
    emit_signal("hp_changed", player_hp, player_max_hp)
    if player_hp == 0:
        end_expedition(false)

func increment_combo() -> void:
    combo_count += 1
    emit_signal("combo_changed", combo_count)

func end_expedition(victory: bool) -> void:
    var report = {
        "victory": victory,
        "loot": expedition_loot.duplicate(),
        "peak_combo": combo_count
    }
    reset_expedition()
    emit_signal("expedition_ended", report)
```

- [ ] **Step 5: 注册 autoload**

Project → Project Settings → Autoload → 添加 `src/core/autoloads/game_state.gd`，名称 `GameState`。

- [ ] **Step 6: 初始提交**

```bash
git init
git add .
git commit -m "feat: initialize godot project with GameState autoload"
```

---

## Task 2: ContentPack 基类接口

**Files:**
- Create: `src/core/interfaces/content_pack_base.gd`
- Create: `tests/test_content_loader.gd`

- [ ] **Step 1: 编写 ContentPackBase**

新建 `src/core/interfaces/content_pack_base.gd`：

```gdscript
class_name ContentPackBase extends Resource

## 学科包唯一标识，如 "english_grade4_6"
@export var pack_id: String = ""
## 显示名称
@export var pack_name: String = ""
## 学科类型 "english" | "math" | "chinese"
@export var subject: String = ""
## 支持年级列表 [4, 5, 6]
@export var grades: Array[int] = []

# ── 攻击类型 ────────────────────────────────────────────────────
## 返回该学科支持的攻击类型列表
## 每项格式: { id, name, icon, color, element }
func get_attack_types() -> Array[Dictionary]:
    return []

# ── 知识点 / 题目 ────────────────────────────────────────────────
## 返回已解锁的随机题目（用于战斗/探索）
## attack_type_id: 限定题目类型，"" 表示不限
## difficulty: 1-3
## exclude_ids: 排除题目ID（避免重复）
func get_question(attack_type_id: String, difficulty: int, exclude_ids: Array[String]) -> Dictionary:
    return {}

## 返回大关精选题目池（陷阱题/考点题）
## gate_id: 大关标识
func get_gate_questions(gate_id: String, count: int) -> Array[Dictionary]:
    return []

## 记录答题结果（供 SRS 系统调用）
func on_question_answered(question_id: String, correct: bool) -> void:
    pass

# ── 建筑 ─────────────────────────────────────────────────────────
## 返回城市建筑定义列表
## 每项格式: { id, name, max_level, upgrades: [{level, cost, effects}] }
func get_buildings() -> Array[Dictionary]:
    return []

# ── 技能 ─────────────────────────────────────────────────────────
## 返回可用技能定义列表（进入技能随机池）
## bd_path: "blaze" | "tank" | "element" | "summon" | "" 表示全部
func get_skills(bd_path: String) -> Array[Dictionary]:
    return []

# ── 装备 ─────────────────────────────────────────────────────────
## 返回装备定义列表
func get_equipment() -> Array[Dictionary]:
    return []

# ── 谜题 ─────────────────────────────────────────────────────────
## 返回对应知识点的解锁谜题场景路径
## knowledge_id: 如 "past_tense", "vocabulary_brave"
func get_puzzle_scene_path(knowledge_id: String) -> String:
    return ""

# ── 音频 ─────────────────────────────────────────────────────────
## 返回单词/句子的发音音频流
func get_audio(text: String) -> AudioStream:
    return null
```

- [ ] **Step 2: 编写失败测试**

新建 `tests/test_content_loader.gd`：

```gdscript
extends GutTest

var loader: ContentLoader

func before_each():
    loader = ContentLoader.new()
    add_child_autofree(loader)

func test_register_and_get_pack():
    var pack = ContentPackBase.new()
    pack.pack_id = "test_pack"
    pack.subject = "english"
    loader.register_pack(pack)
    assert_eq(loader.get_pack("test_pack"), pack)

func test_get_unknown_pack_returns_null():
    assert_null(loader.get_pack("nonexistent"))

func test_active_pack_set_and_retrieved():
    var pack = ContentPackBase.new()
    pack.pack_id = "english_grade4_6"
    loader.register_pack(pack)
    loader.set_active_pack("english_grade4_6")
    assert_eq(loader.get_active_pack().pack_id, "english_grade4_6")
```

- [ ] **Step 3: 运行测试，确认失败**

在 Godot 编辑器中运行 GUT 面板，或：
Project → Tools → GUT → Run All Tests
Expected: FAIL（ContentLoader 未定义）

- [ ] **Step 4: 实现 ContentLoader**

新建 `src/core/systems/content_loader.gd`：

```gdscript
class_name ContentLoader extends Node

var _packs: Dictionary = {}      # pack_id -> ContentPackBase
var _active_pack_id: String = ""

func register_pack(pack: ContentPackBase) -> void:
    _packs[pack.pack_id] = pack

func get_pack(pack_id: String) -> ContentPackBase:
    return _packs.get(pack_id, null)

func set_active_pack(pack_id: String) -> void:
    assert(_packs.has(pack_id), "Pack not registered: " + pack_id)
    _active_pack_id = pack_id

func get_active_pack() -> ContentPackBase:
    return _packs.get(_active_pack_id, null)
```

- [ ] **Step 5: 运行测试，确认通过**

Expected: 3 tests PASS

- [ ] **Step 6: 提交**

```bash
git add src/core/interfaces/content_pack_base.gd src/core/systems/content_loader.gd tests/test_content_loader.gd
git commit -m "feat: add ContentPackBase interface and ContentLoader"
```

---

## Task 3: BossBase 接口

**Files:**
- Create: `src/core/interfaces/boss_base.gd`

- [ ] **Step 1: 定义 BossBase**

新建 `src/core/interfaces/boss_base.gd`：

```gdscript
class_name BossBase extends Node

## Boss 唯一标识
@export var boss_id: String = ""
## 最大HP
@export var max_hp: int = 500
## 所属大关
@export var gate_id: String = ""

# ── 通关流程钩子（引擎调用）────────────────────────────────────

## 入场台词（引擎逐句展示）
func get_intro_dialogue() -> Array[String]:
    return []

## 阶段数（1-3），HP阶段触发：2阶段在50% HP，3阶段在66%和33%
func get_phase_count() -> int:
    return 1

## 每阶段开始时调用，可修改 battle_state 中的规则
## phase: 1-based
func on_phase_start(phase: int, battle_state: Dictionary) -> void:
    pass

## 玩家答对时回调
## attack_type: 攻击类型ID
## combo: 当前连击数
## 返回 Boss 的即时反应（空 = 无反应）
func on_player_correct(attack_type: String, combo: int) -> Dictionary:
    return {}

## 玩家答错时回调
## 返回 Boss 的即时反应
func on_player_wrong(attack_type: String) -> Dictionary:
    return {}

## Boss 回合行动（每轮玩家行动后调用）
## battle_state: { player_hp, boss_hp, combo, round, sealed_types }
## 返回 BossAction: { type, value, message }
## type: "damage" | "seal_attack" | "shuffle_options" | "shorten_timer" | "none"
func boss_action(battle_state: Dictionary) -> Dictionary:
    return { "type": "damage", "value": 10, "message": "" }

## 死亡台词
func get_defeat_dialogue() -> Array[String]:
    return []
```

- [ ] **Step 2: 提交**

```bash
git add src/core/interfaces/boss_base.gd
git commit -m "feat: add BossBase interface with phase and action hooks"
```

---

## Task 4: SkillBase / EquipmentBase / BuildingBase / PuzzleBase 接口

**Files:**
- Create: `src/core/interfaces/skill_base.gd`
- Create: `src/core/interfaces/equipment_base.gd`
- Create: `src/core/interfaces/building_base.gd`
- Create: `src/core/interfaces/puzzle_base.gd`

- [ ] **Step 1: SkillBase**

新建 `src/core/interfaces/skill_base.gd`：

```gdscript
class_name SkillBase extends Resource

@export var skill_id: String = ""
@export var skill_name: String = ""
@export var bd_path: String = ""        # "blaze" | "tank" | "element" | "summon"
@export var skill_type: String = ""     # "active" | "passive" | "legendary"
@export var description: String = ""
@export var icon_path: String = ""

## 被动技能：每回合开始时调用，可修改 battle_state
func on_round_start(battle_state: Dictionary) -> void:
    pass

## 主动技能：玩家手动触发，返回技能效果
func activate(battle_state: Dictionary) -> Dictionary:
    return {}

## 协同检查：传入当前持有的所有技能ID，返回是否触发协同及效果
func check_synergy(held_skill_ids: Array[String]) -> Dictionary:
    return { "triggered": false }

## 答对时触发（被动）
func on_correct(battle_state: Dictionary) -> void:
    pass

## 答错时触发（被动）
func on_wrong(battle_state: Dictionary) -> void:
    pass
```

- [ ] **Step 2: EquipmentBase**

新建 `src/core/interfaces/equipment_base.gd`：

```gdscript
class_name EquipmentBase extends Resource

@export var equipment_id: String = ""
@export var equipment_name: String = ""
@export var slot: String = ""   # "weapon" | "armor" | "accessory" | "mount"
@export var description: String = ""
@export var icon_path: String = ""

## 装备时应用效果到 battle_state
func on_equip(battle_state: Dictionary) -> void:
    pass

## 卸下时移除效果
func on_unequip(battle_state: Dictionary) -> void:
    pass

## 答对时触发
func on_correct(battle_state: Dictionary) -> void:
    pass

## 答错时触发
func on_wrong(battle_state: Dictionary) -> void:
    pass
```

- [ ] **Step 3: BuildingBase**

新建 `src/core/interfaces/building_base.gd`：

```gdscript
class_name BuildingBase extends Resource

@export var building_id: String = ""
@export var building_name: String = ""
@export var max_level: int = 5
@export var attack_type_id: String = ""  # 对应的攻击类型

## 返回升级到 level 需要的资源
## 格式: { resource_id: count }
func get_upgrade_cost(level: int) -> Dictionary:
    return {}

## 返回 level 级别的战斗效果
## 格式: { attack_bonus, special_effect_id, special_effect_value }
func get_effects(level: int) -> Dictionary:
    return {}

## 返回 level 级别解锁的技能ID列表
func get_unlocked_skills(level: int) -> Array[String]:
    return []
```

- [ ] **Step 4: PuzzleBase**

新建 `src/core/interfaces/puzzle_base.gd`：

```gdscript
class_name PuzzleBase extends Node

## 对应的知识点ID
@export var knowledge_id: String = ""
## 谜题名称
@export var puzzle_name: String = ""

## 信号：谜题通关
signal puzzle_completed(knowledge_id: String)
## 信号：玩家退出谜题（未完成）
signal puzzle_exited()

## 谜题初始化（引擎调用）
func setup(pack: ContentPackBase) -> void:
    pass

## 检查通关条件（子类实现具体逻辑）
func _check_completion() -> void:
    pass
```

- [ ] **Step 5: 提交**

```bash
git add src/core/interfaces/
git commit -m "feat: add SkillBase, EquipmentBase, BuildingBase, PuzzleBase interfaces"
```

---

## Task 5: SRS 系统

**Files:**
- Create: `src/core/systems/srs_system.gd`
- Create: `tests/test_srs_system.gd`

- [ ] **Step 1: 编写失败测试**

新建 `tests/test_srs_system.gd`：

```gdscript
extends GutTest

var srs: SRSSystem

func before_each():
    srs = SRSSystem.new()
    add_child_autofree(srs)

func test_new_question_has_default_priority():
    var priority = srs.get_priority("q_001")
    assert_eq(priority, 0)

func test_wrong_answer_increases_priority():
    srs.record_answer("q_001", false)
    assert_gt(srs.get_priority("q_001"), 0)

func test_correct_answer_decreases_priority():
    srs.record_answer("q_001", false)
    srs.record_answer("q_001", false)
    var priority_before = srs.get_priority("q_001")
    srs.record_answer("q_001", true)
    assert_lt(srs.get_priority("q_001"), priority_before)

func test_next_question_prefers_high_priority():
    srs.record_answer("q_low", true)
    srs.record_answer("q_low", true)
    srs.record_answer("q_high", false)
    srs.record_answer("q_high", false)
    srs.record_answer("q_high", false)
    var candidates = ["q_low", "q_high"]
    var picked = srs.pick_question(candidates)
    assert_eq(picked, "q_high")

func test_save_and_load():
    srs.record_answer("q_001", false)
    var data = srs.serialize()
    var srs2 = SRSSystem.new()
    add_child_autofree(srs2)
    srs2.deserialize(data)
    assert_eq(srs2.get_priority("q_001"), srs.get_priority("q_001"))
```

- [ ] **Step 2: 运行测试，确认失败**

Expected: FAIL（SRSSystem 未定义）

- [ ] **Step 3: 实现 SRS 系统**

新建 `src/core/systems/srs_system.gd`：

```gdscript
class_name SRSSystem extends Node

# question_id -> { correct: int, wrong: int, last_wrong_time: float }
var _records: Dictionary = {}

func record_answer(question_id: String, correct: bool) -> void:
    if not _records.has(question_id):
        _records[question_id] = { "correct": 0, "wrong": 0, "last_wrong_time": 0.0 }
    if correct:
        _records[question_id]["correct"] += 1
    else:
        _records[question_id]["wrong"] += 1
        _records[question_id]["last_wrong_time"] = Time.get_unix_time_from_system()

## 优先级：错误次数权重高，时间衰减（越久没错优先级越低）
func get_priority(question_id: String) -> float:
    if not _records.has(question_id):
        return 0.0
    var r = _records[question_id]
    var wrong_weight = r["wrong"] * 3.0
    var correct_discount = r["correct"] * 1.0
    var time_decay = 0.0
    if r["last_wrong_time"] > 0:
        var hours_since = (Time.get_unix_time_from_system() - r["last_wrong_time"]) / 3600.0
        time_decay = min(hours_since * 0.5, wrong_weight * 0.8)
    return max(0.0, wrong_weight - correct_discount - time_decay)

## 从候选ID列表中选出优先级最高的
func pick_question(candidate_ids: Array[String]) -> String:
    if candidate_ids.is_empty():
        return ""
    var best_id = candidate_ids[0]
    var best_priority = get_priority(best_id)
    for id in candidate_ids:
        var p = get_priority(id)
        if p > best_priority:
            best_priority = p
            best_id = id
    return best_id

func serialize() -> Dictionary:
    return _records.duplicate(true)

func deserialize(data: Dictionary) -> void:
    _records = data.duplicate(true)
```

- [ ] **Step 4: 运行测试，确认通过**

Expected: 5 tests PASS

- [ ] **Step 5: 提交**

```bash
git add src/core/systems/srs_system.gd tests/test_srs_system.gd
git commit -m "feat: add SRS system with priority-based question selection"
```

---

## Task 6: 本地存档系统

**Files:**
- Create: `src/core/systems/save_system.gd`
- Create: `tests/test_save_system.gd`

- [ ] **Step 1: 编写失败测试**

新建 `tests/test_save_system.gd`：

```gdscript
extends GutTest

var save_sys: SaveSystem

func before_each():
    save_sys = SaveSystem.new()
    add_child_autofree(save_sys)
    # 使用临时路径避免污染真实存档
    save_sys.save_path = "user://test_save.json"

func after_each():
    if FileAccess.file_exists("user://test_save.json"):
        DirAccess.remove_absolute("user://test_save.json")

func test_save_and_load_roundtrip():
    var data = { "player_hp": 80, "combo": 5, "unlocked": ["past_tense"] }
    save_sys.save(data)
    var loaded = save_sys.load_save()
    assert_eq(loaded["player_hp"], 80)
    assert_eq(loaded["unlocked"][0], "past_tense")

func test_load_returns_empty_when_no_file():
    var loaded = save_sys.load_save()
    assert_eq(loaded, {})
```

- [ ] **Step 2: 运行测试，确认失败**

Expected: FAIL（SaveSystem 未定义）

- [ ] **Step 3: 实现存档系统**

新建 `src/core/systems/save_system.gd`：

```gdscript
class_name SaveSystem extends Node

var save_path: String = "user://save.json"

func save(data: Dictionary) -> void:
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()

func load_save() -> Dictionary:
    if not FileAccess.file_exists(save_path):
        return {}
    var file = FileAccess.open(save_path, FileAccess.READ)
    var text = file.get_as_text()
    file.close()
    var result = JSON.parse_string(text)
    if result == null:
        return {}
    return result

func save_game_state() -> void:
    var data = {
        "player_hp": GameState.player_hp,
        "player_max_hp": GameState.player_max_hp,
        "knowledge_level": GameState.knowledge_level,
        "unlocked_knowledge_ids": GameState.unlocked_knowledge_ids,
        "completed_gate_ids": GameState.completed_gate_ids,
        "city_building_levels": GameState.city_building_levels,
        "inventory_resources": GameState.inventory_resources,
        "equipment_slots": GameState.equipment_slots,
        "saved_at": Time.get_unix_time_from_system()
    }
    save(data)

func load_game_state() -> void:
    var data = load_save()
    if data.is_empty():
        return
    GameState.player_hp = data.get("player_hp", 100)
    GameState.player_max_hp = data.get("player_max_hp", 100)
    GameState.knowledge_level = data.get("knowledge_level", 1)
    GameState.unlocked_knowledge_ids = data.get("unlocked_knowledge_ids", [])
    GameState.completed_gate_ids = data.get("completed_gate_ids", [])
    GameState.city_building_levels = data.get("city_building_levels", {})
    GameState.inventory_resources = data.get("inventory_resources", {})
    GameState.equipment_slots = data.get("equipment_slots", {
        "weapon": "", "armor": "", "accessory": "", "mount": ""
    })
```

- [ ] **Step 4: 运行测试，确认通过**

Expected: 2 tests PASS

- [ ] **Step 5: 提交**

```bash
git add src/core/systems/save_system.gd tests/test_save_system.gd
git commit -m "feat: add local save/load system with GameState serialization"
```

---

## Task 7: GameState 扩展 + 注册 ContentLoader 和 SaveSystem

**Files:**
- Modify: `src/core/autoloads/game_state.gd`

- [ ] **Step 1: 在 GameState 中持有系统引用**

在 `game_state.gd` 顶部添加：

```gdscript
# 在 extends Node 后添加
var content_loader: ContentLoader
var srs_system: SRSSystem
var save_system: SaveSystem

func _ready() -> void:
    content_loader = ContentLoader.new()
    add_child(content_loader)
    srs_system = SRSSystem.new()
    add_child(srs_system)
    save_system = SaveSystem.new()
    add_child(save_system)
    save_system.load_game_state()
```

- [ ] **Step 2: 在 expedition_ended 信号处理中自动存档**

在 `game_state.gd` 的 `end_expedition` 函数末尾添加：

```gdscript
    # end_expedition 最后一行
    save_system.save_game_state()
```

- [ ] **Step 3: 提交**

```bash
git add src/core/autoloads/game_state.gd
git commit -m "feat: wire ContentLoader, SRSSystem, SaveSystem into GameState"
```

---

## Task 8: 主菜单场景骨架

**Files:**
- Create: `src/ui/main_menu.tscn`
- Create: `src/ui/main_menu.gd`

- [ ] **Step 1: 创建主菜单场景**

在 Godot 编辑器中：Scene → New Scene，根节点选 `Control`，保存为 `src/ui/main_menu.tscn`。

添加子节点：
- `VBoxContainer`
  - `Label` (text: "知识神塔")
  - `Button` (name: "StartButton", text: "开始冒险")
  - `Button` (name: "CityButton", text: "我的城市")
  - `Button` (name: "GateButton", text: "里程碑大关")

- [ ] **Step 2: 编写主菜单控制器**

新建 `src/ui/main_menu.gd`，挂载到根节点：

```gdscript
extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var city_button: Button = $VBoxContainer/CityButton
@onready var gate_button: Button = $VBoxContainer/GateButton

func _ready() -> void:
    start_button.pressed.connect(_on_start_pressed)
    city_button.pressed.connect(_on_city_pressed)
    gate_button.pressed.connect(_on_gate_pressed)
    # 大关按钮仅在有已注册Pack时可用
    gate_button.disabled = GameState.content_loader.get_active_pack() == null

func _on_start_pressed() -> void:
    # Phase 3: 切换到探索场景
    pass

func _on_city_pressed() -> void:
    # Phase 3: 切换到城市场景
    pass

func _on_gate_pressed() -> void:
    # Phase 5: 切换到大关场景
    pass
```

- [ ] **Step 3: 设置主场景**

Project → Project Settings → Application → Run → Main Scene → 选择 `src/ui/main_menu.tscn`。

运行项目，确认主菜单显示正常（三个按钮均可见）。

- [ ] **Step 4: 提交**

```bash
git add src/ui/main_menu.tscn src/ui/main_menu.gd
git commit -m "feat: add main menu scene skeleton with scene transition hooks"
```

---

## Phase 1 完成标准

- [ ] `gut` 所有测试通过（ContentLoader 3条 + SRS 5条 + SaveSystem 2条）
- [ ] 项目启动无报错，主菜单正常显示
- [ ] 所有接口文件已创建（6个 `*_base.gd`）
- [ ] GameState autoload 正常注册并在启动时加载存档

---

## 后续 Phase 说明

Phase 1 完成后，Phase 2–10 可**并行推进**部分内容：

- Phase 2（战斗）和 Phase 3（探索/城市）互不依赖，可同时开始
- Phase 6（英语ContentPack）可在 Phase 2 开始后同步编写内容
- Phase 5（Boss）依赖 Phase 2 的战斗系统，需 Phase 2 完成后开始
- Phase 7（Supabase同步）可在任何阶段独立接入，不阻塞游戏开发
