# 知识神塔 — 架构文档

## 整体架构

```
知识神塔
├── 核心 (src/core)          — 全局状态、内容系统、存档、SRS
├── UI (src/ui)              — 主菜单、设置、撤退报告
├── 探索 (src/exploration)   — 世界地图、资源节点、敌人、大关入口
├── 战斗 (src/battle)        — 战斗控制器、题目 UI、远征设置
├── 大关 (src/gate)          — 大关介绍→波次→Boss→通关
├── 城市 (src/city)          — 建筑升级、练习场
└── 内容包 (src/content)     — 题目数据、大关配置、Boss 脚本
```

---

## 核心模块

### GameState（全局单例自动加载）
`src/core/autoloads/game_state.gd`

所有场景共享的全局状态，挂载在 AutoLoad 节点树上。

**玩家状态：**
| 字段 | 类型 | 说明 |
|------|------|------|
| `player_hp` | int | 当前血量（默认 100） |
| `player_max_hp` | int | 最大血量（默认 100） |
| `player_grade` | int | 年级 4/5/6，控制题目难度池 |
| `combo_count` | int | 当前连击数 |
| `knowledge_level` | int | 知识层级，解锁大关用 |
| `inventory_resources` | Dictionary | 背包资源 `{type: amount}` |
| `equipment_slots` | Dictionary | 装备栏 |
| `player_grade` | int | 年级 4/5/6（影响题目过滤） |

**远征状态（开始冒险时激活）：**
| 字段 | 类型 | 说明 |
|------|------|------|
| `expedition_active` | bool | 是否在远征中 |
| `expedition_return_scene` | String | 战斗结束后返回的场景路径 |
| `pending_enemy` | EnemyData | 即将进入战斗的敌人数据 |
| `active_bd_skills` | Array | 本次远征携带的技能 ID 列表 |

**大关状态（进入大关时激活）：**
| 字段 | 类型 | 说明 |
|------|------|------|
| `is_gate_active` | bool | 是否在大关中 |
| `pending_gate_id` | String | 当前大关 ID |
| `pending_gate_config` | Dictionary | 大关完整配置（来自 gates.json） |
| `gate_questions_pool` | Array | 当前大关的题目池 |
| `gate_wave_index` | int | 当前波次（0 开始） |
| `gate_wave_count` | int | 总波次数 |
| `gate_boss_defeat_lines` | Array | Boss 击败后的台词 |

**信号：**
| 信号 | 触发时机 |
|------|--------|
| `hp_changed(new_hp, max_hp)` | 玩家血量变化时 |
| `combo_changed(count)` | 连击数变化时 |
| `gate_completed(gate_id)` | 大关完成时 |

**关键方法：**
- `start_expedition()` / `end_expedition(victory)`
- `start_gate(cfg, questions)` / `complete_gate()` / `fail_gate()`
- `take_damage(amount)` / `increment_combo()` / `reset_combo()`

---

### ContentLoader
`src/core/systems/content_loader.gd`

管理内容包注册和切换。当前注册了 `EnglishContentPack`（ID: `english_grade46`）。

```
GameState._ready()
  └─ content_loader.register_pack(EnglishContentPack)
  └─ content_loader.set_active_pack("english_grade46")

其他场景调用:
  GameState.content_loader.get_active_pack()  → EnglishContentPack
```

### EnglishContentPack
`src/content/english/english_content_pack.gd`

实现 `ContentPackBase` 接口，从 JSON 加载题目和大关配置。

- 题目文件：`src/content/english/data/questions.json`（80 道题，含 grade 字段）
- 大关文件：`src/content/english/data/gates.json`（遗忘图书馆）
- 按 `grade ≤ player_grade` 累进过滤题目

---

## 玩法流程链路

### 流程 1：开始冒险

```
主菜单 [开始冒险]
  → expedition_setup.tscn
      _ready(): 从内容包取技能列表
      若无技能 → 直接跳转探索场景 ✓
      若有技能 → 展示选择 → 选择后跳转
  → exploration_scene.tscn
```

### 流程 2：探索场景（核心 Hub）

```
exploration_scene.tscn
  ├─ 词灵结晶 / 法则矿石 节点（ResourceNode）
  │   → 答对题目 → 获得资源
  │
  ├─ 敌人遭遇节点（EnemyEncounterNode）
  │   → 设置 GameState.pending_enemy
  │   → 设置 expedition_return_scene = exploration_scene
  │   → battle_scene.tscn
  │       → 胜利 → exploration_scene.tscn
  │       → 失败 → retreat_report_scene.tscn
  │
  ├─ 知识大关节点（KnowledgeGateNode）
  │   → GameState.start_gate(cfg, questions)
  │   → gate_intro_scene.tscn
  │       → [大关流程，见流程 4]
  │
  └─ 返回按钮
      → 远征中 → retreat_report_scene.tscn
      → 非远征 → city_scene.tscn
```

### 流程 3：战斗（探索中遭遇敌人）

```
battle_scene.tscn  (BattleController)
  _ready():
    1. 从场景树获取 UI 节点
    2. _setup_question_ui() — 动态加载 question_ui.tscn
    3. 读取 GameState.pending_enemy + get_active_pack()
    4. build_attack_buttons() — 按攻击类型（词灵/法则）生成按钮
    5. start_player_turn()

  玩家选择攻击类型
    → select_attack(attack_type_id)
    → 从内容包取一道题
    → 显示 question_ui
    → 答对 → _apply_player_attack() → 伤害敌人
    → 答错 → _apply_enemy_attack() → 扣玩家血
    → 循环直到 enemy_hp == 0 或 player_hp == 0

  battle_ended(victory)
    → 胜利 → expedition_return_scene（探索）
    → 失败 → retreat_report_scene.tscn
```

### 流程 4：知识大关

```
gate_intro_scene.tscn  (GateIntroController)
  _ready():
    1. 加载 Boss 脚本（boss_script_path）
    2. 展示 Boss 介绍台词
    3. 预加载题目池 (get_gate_questions)

  [继续] → _start_wave() 或 _go_to_boss()
  [放弃] → exploration_scene.tscn

wave 循环（gate_wave_index < gate_wave_count）:
  gate_wave_scene.tscn  (GateWaveController)
    → 每道题从 gate_questions_pool 取（pop_front）
    → 胜利 → gate_wave_index++
    → 还有波次 → 下一个 gate_wave_scene
    → 波次打完 → boss_battle_scene.tscn
    → 失败 → gate_intro_scene.tscn（可重试）

boss_battle_scene.tscn  (BossBattleController)
  → 加载 LibrarianBoss（两阶段 Boss）
  → 阶段 1：血量 >50% — 攻击 + 连击≥3时乱序选项
  → 阶段 2：血量 ≤50% — 封印词灵攻击 + 加强伤害
  → 胜利 → gate_complete_scene.tscn
  → 失败 → gate_intro_scene.tscn

gate_complete_scene.tscn
  → 展示 Boss 败北台词
  → 返回 → exploration_scene.tscn
      (GameState.complete_gate() 已在 BossBattleController 调用)
```

### 流程 5：城市

```
city_scene.tscn  (CityController / CitySceneController)
  ├─ 建筑槽（BuildingSlot）— 升级建筑增强战斗能力
  ├─ 练习场 → practice_arena_scene.tscn
  │     → 从 SRS 系统取错误率高的题目
  │     → 答完 10 题 → 奖励词灵结晶
  │     → 返回 city_scene
  └─ 开始冒险 → expedition_setup.tscn
```

### 流程 6：设置

```
settings_scene.tscn
  → 选择年级（4/5/6）
  → 立即更新 GameState.player_grade
  → save_system.save_game_state()（持久化）
  → 返回主菜单
```

---

## 存档系统

`src/core/systems/save_system.gd` — 保存到 `user://save.json`

**存储的字段：**
`player_hp`, `player_max_hp`, `knowledge_level`, `unlocked_knowledge_ids`,
`completed_gate_ids`, `city_building_levels`, `inventory_resources`,
`equipment_slots`, `player_grade`, `saved_at`

---

## SRS 系统（间隔重复）

`src/core/systems/srs_system.gd`

- 每道题答对/答错后调用 `record_answer(question_id, correct)`
- 练习场用 `get_weakest_questions(count)` 取错误率最高的题
- 供未来家长看板（Phase 9）读取学习数据

---

## 内容包接口（ContentPackBase）

所有内容包必须实现：

| 方法 | 说明 |
|------|------|
| `get_question(type, difficulty, exclude_ids)` | 返回一道随机题 |
| `get_question_by_id(id)` | 按 ID 精确查题 |
| `get_gate_questions(gate_id, count)` | 返回大关题目池 |
| `get_gates()` | 返回大关配置列表 |
| `get_attack_types()` | 返回攻击类型（词灵/法则） |
| `get_buildings()` | 返回城市建筑定义 |
| `get_skills(bd_path)` | 返回技能列表（当前为空） |

---

## 已知限制 / 待实现

| 项目 | 状态 |
|------|------|
| 美术资源（背景、角色图） | 待实现 |
| 技能系统（远征技能选择） | 接口已留，当前 get_skills() 返回空 |
| 装备系统 | 接口已留，当前无内容 |
| 音效 / BGM | 未实现 |
| TTS 语音（audio_text 字段已备） | Phase 8 |
| Supabase 云存档 | Phase 7 |
| 家长看板 | Phase 9 |
