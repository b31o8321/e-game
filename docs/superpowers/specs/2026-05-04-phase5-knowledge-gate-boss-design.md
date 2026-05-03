# Phase 5 — 知识大关框架 + Boss系统 设计文档

## Goal

实现完整的里程碑大关（Knowledge Gate）框架：从探索场景入口、多波次敌人、Boss战（4种特殊机制、多阶段）、到通关解锁。提供一个具体 Boss（遗忘图书管理员）作为首发内容验证框架。

## Architecture

采用**分场景导航**方式，与 Phase 1–4 模式一致。每个场景职责单一，GameState 携带轻量 gate 状态跨场景传递。波次战斗复用已测试的 `BattleController`（via `GateWaveController` 子类），Boss战使用新的 `BossBattleController` 子类。

---

## 完整流程

```
探索场景
  └─ KnowledgeGateNode 点击（需 knowledge_level 满足 required_knowledge_level）
       ↓ 设置 pending_gate_id, is_gate_active=true, 预加载 gate_questions_pool
  gate_intro_scene     — 逐句展示 Boss 入场台词，"开始挑战"按钮
       ↓
  gate_wave_scene × N  — GateWaveController（无技能加成，从 pool 取题）
       ↓ 全波通过
  boss_battle_scene    — BossBattleController（4种机制，多阶段）
       ↓ 胜利
  gate_complete_scene  — 播放胜利台词，写入解锁，返回探索
       ↓
  探索场景（knowledge_level++，新区域节点出现）

  任意失败 → gate_intro_scene（可重试，但重新来过）
```

---

## GameState 新增字段

```gdscript
var pending_gate_id: String = ""
var gate_wave_index: int = 0              # 当前第几波（0-based）
var gate_wave_count: int = 0              # 总波数（从关卡配置读）
var gate_questions_pool: Array[Dictionary] = []  # 预加载关卡题目
var is_gate_active: bool = false          # true 时抑制 expedition 逻辑
```

`is_gate_active` 保护开关：gate 内战斗不调用 `end_expedition()`，胜负走独立路径。

新增方法：
```gdscript
func start_gate(gate_id: String, wave_count: int, questions: Array[Dictionary]) -> void
func complete_gate(gate_id: String, unlock_knowledge_level: int, unlock_area_ids: Array[String]) -> void
func fail_gate() -> void
```

---

## 文件结构

### 新建文件

| 文件 | 职责 |
|------|------|
| `src/exploration/knowledge_gate_node.gd` | extends Button；点击后初始化 gate 状态并跳转 intro |
| `src/gate/gate_intro_controller.gd` | 逐句展示 intro dialogue；"开始"→ wave_scene |
| `src/gate/gate_intro_scene.tscn` | gate intro 场景 |
| `src/gate/gate_wave_controller.gd` | extends BattleController；从 pool 取题；无技能；波次衔接 |
| `src/gate/gate_wave_scene.tscn` | 波次战斗场景 |
| `src/gate/boss_battle_controller.gd` | extends BattleController；4种 boss action；阶段切换 |
| `src/gate/boss_battle_scene.tscn` | Boss 战场景 |
| `src/gate/gate_complete_controller.gd` | 展示胜利台词；调用 `complete_gate()`；返回探索 |
| `src/gate/gate_complete_scene.tscn` | 通关场景 |
| `src/content/english/bosses/librarian_boss.gd` | 遗忘图书管理员（2阶段，seal+shuffle） |
| `tests/test_boss_battle_controller.gd` | Boss战控制器单元测试 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/core/autoloads/game_state.gd` | 新增 5 个 gate 字段 + 3 个方法 |
| `src/core/interfaces/content_pack_base.gd` | 新增 `get_gates() -> Array[Dictionary]` |
| `tests/mock_content_pack.gd` | 实现 `get_gates()`（1个 mock 关卡） |
| `src/exploration/exploration_controller.gd` | 生成 KnowledgeGateNode；监听 `gate_completed` 刷新 |
| `src/battle/battle_controller.gd` | `select_attack()` 检查 `gate_questions_pool`；`_on_battle_ended()` 检查 `is_gate_active` |

---

## ContentPackBase 大关配置格式

```gdscript
func get_gates() -> Array[Dictionary]:
    return []
    # 每项格式：
    # {
    #   "gate_id": String,
    #   "gate_name": String,
    #   "required_knowledge_level": int,
    #   "wave_count": int,               # Boss 前的普通敌人波数
    #   "questions_per_wave": int,        # 每波敌人答题数
    #   "wave_enemy": Dictionary,         # { enemy_name, max_hp, base_attack, weaknesses, multipliers }
    #   "boss_script_path": String,       # res:// 路径
    #   "boss_enemy": Dictionary,         # { enemy_name, max_hp, base_attack }
    #   "unlock_knowledge_level": int,
    #   "unlock_area_ids": Array[String]
    # }
```

---

## GateWaveController

`extends BattleController`，重写：

```gdscript
func select_attack(attack_type_id: String) -> void:
    # 从 GameState.gate_questions_pool 取题，而非随机
    if state != State.PLAYER_TURN: return
    current_attack_type = attack_type_id
    state = State.QUESTION
    var question: Dictionary = _pop_gate_question()
    attack_selected.emit(attack_type_id, question)

func _get_active_skill_instances() -> Array[SkillBase]:
    return []   # 大关内无技能加成

func _on_battle_ended(victory: bool) -> void:
    if return_scene.is_empty(): return
    GameState.pending_enemy = null
    if not victory:
        GameState.fail_gate()
        get_tree().change_scene_to_file("res://src/gate/gate_intro_scene.tscn")
        return
    GameState.gate_wave_index += 1
    if GameState.gate_wave_index < GameState.gate_wave_count:
        get_tree().change_scene_to_file("res://src/gate/gate_wave_scene.tscn")
    else:
        get_tree().change_scene_to_file("res://src/gate/boss_battle_scene.tscn")
```

---

## BossBattleController

`extends BattleController`，在波次控制器基础上增加：

### 状态
```gdscript
var _boss: BossBase
var _current_phase: int = 1
var _sealed_types: Array[String] = []
var _pending_shuffle: bool = false
var _timer_reduction: float = 0.0
```

### Boss Action 处理

每次玩家答题（正确或错误）后调用 `_execute_boss_action()`：

```gdscript
func _execute_boss_action() -> void:
    var bs := _build_battle_state()
    bs["phase"] = _current_phase
    bs["sealed_types"] = _sealed_types
    var action: Dictionary = _boss.boss_action(bs)
    match action.get("type", "none"):
        "damage":
            GameState.take_damage(action.get("value", 0))
        "seal_attack":
            var type_id: String = action.get("value", "")
            if type_id and type_id not in _sealed_types:
                _sealed_types.append(type_id)
            build_attack_buttons()   # 刷新按钮隐藏封印类型
        "shuffle_options":
            _pending_shuffle = true
        "shorten_timer":
            _timer_reduction = min(_timer_reduction + action.get("value", 0.0), 7.0)
```

### 阶段切换

每次造成伤害后检查：
- 2阶段：50% HP 触发 phase 2
- 3阶段：66% 和 33% 分别触发 phase 2、3

```gdscript
func _check_phase_transition() -> void:
    var phase_count := _boss.get_phase_count()
    var hp_pct := float(enemy_hp) / float(_enemy.max_hp)
    var new_phase := 1
    if phase_count == 2 and hp_pct <= 0.5:
        new_phase = 2
    elif phase_count == 3:
        if hp_pct <= 0.33: new_phase = 3
        elif hp_pct <= 0.66: new_phase = 2
    if new_phase > _current_phase:
        _current_phase = new_phase
        var bs := _build_battle_state()
        _boss.on_phase_start(_current_phase, bs)
        # 读取 phase start 可能新增的封印类型
        var new_seals: Array = bs.get("seal_types", [])
        for t in new_seals:
            if t not in _sealed_types:
                _sealed_types.append(t)
        build_attack_buttons()
```

### 封印类型 + 打乱选项

`build_attack_buttons()` 重写：跳过 `_sealed_types` 中的类型。

`select_attack()` 中，若 `_pending_shuffle`，则取出题目后打乱 `options` 顺序并映射 `correct_index`。

### Timer

`select_attack()` 加载题目后，设置 `_question_controller.time_limit = max(3.0, base_time - _timer_reduction)`。

---

## 遗忘图书管理员（LibrarianBoss）

```gdscript
阶段1（HP 100%→50%）：
  - 连击≥3：shuffle_options（"图书管理员打乱了选项！"）
  - 否则：damage 8（"遗忘之力侵蚀你的记忆…"）

阶段2（HP 50%→0%）：
  - 第一次进入：seal_attack "vocabulary"（通过 on_phase_start 设置）
  - 连击≥3：shuffle_options
  - 否则：damage 12

入场台词：
  "这里是遗忘之渊的最后屏障。"
  "你以为凭一点记忆就能通过？"
  "让我来测试你——真的记住了吗？"

胜利台词：
  "…不可思议。记忆…竟然如此顽强。"
  "大关已解封。更深处的知识，等待你去发现。"
```

---

## 探索场景变化

`ExplorationController._ready()` 从 `pack.get_gates()` 读取大关列表，为每个大关生成一个 `KnowledgeGateNode`：
- `required_knowledge_level > GameState.knowledge_level`：按钮置灰，显示"需要知识层级 N"
- 已完成（在 `completed_gate_ids` 中）：显示"✅ 已通关"，仍可重入但不再给奖励
- 可挑战：正常按钮

监听 `GameState.gate_completed` 信号：刷新所有大关节点状态。

---

## 测试覆盖

`test_boss_battle_controller.gd`（GUT）：
1. `boss_action "damage"` → 玩家 HP 正确减少
2. `boss_action "seal_attack"` → `_sealed_types` 包含该类型
3. 同一类型不重复封印
4. `boss_action "shorten_timer"` → `time_limit` 不低于 3.0
5. `boss_action "shuffle_options"` → `_pending_shuffle = true`
6. 阶段2在50% HP触发（2阶段Boss）
7. gate_questions_pool 用完时 `_pop_gate_question()` 返回空 Dictionary 不崩溃
8. 胜利时调用 `get_tree().change_scene_to_file(gate_complete_scene_path)`（mock验证）

---

## Phase 5 完成标准

- [ ] `GateWaveController` 和 `BossBattleController` 单元测试全部通过
- [ ] 探索场景显示大关入口，knowledge_level 不足时置灰
- [ ] 完整流程可跑通：intro → wave × N → boss → complete
- [ ] 4种 boss action 全部生效（封印按钮消失、选项乱序、计时缩短、直接伤害）
- [ ] 2阶段阶段切换触发 on_phase_start，封印新类型
- [ ] 通关后 knowledge_level 增加，gate_completed 信号触发，completed_gate_ids 写入
- [ ] 重试流程：失败后回 gate_intro，重新开始
- [ ] LibrarianBoss 两阶段行为符合设计

---

## 与其他 Phase 的接口约定

- Phase 6（完整英语内容包）：实现真实的 `get_gates()` 和 `get_gate_questions()`，提供多个大关定义和真实题目池
- Phase 7（Supabase）：`complete_gate()` 在云端同步 `completed_gate_ids` 和 `knowledge_level`
- Phase 8（语音）：`gate_intro_controller` 和 `gate_complete_controller` 预留 `audio_text` 字段供 TTS 播放台词
