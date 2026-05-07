# 内容包接口设计 — 知识神塔

> 状态：v1（接口定型，包目录约定，存档隔离方案，含 Math 最小骨架作为接口验证样例）
> 上下文：本 spec 与战斗 / Run / 知识城三 spec 并列。定义"学科切换零侵入"的全套约定——引擎层和内容包层的责任划分、ContentPackBase 完整接口、数据文件目录规范、跨包验证机制。

---

## 设计目标

- **学科切换零引擎改动**：新学科 = 在 `src/content/<subject>/` 下新建包目录 + 实现 `ContentPackBase`，引擎层一行不动。
- **数据维度同构 + 数据值各包自定义**：所有包共享同一组抽象（Card / Challenge / Spice），但 `card_types / pos / tags / spices` 的具体值由包自定。
- **存档按学科隔离**：每学科独立存档文件，切换学科不丢进度。
- **MVP 仅英语，但接口完整**：现在只有英语包跑，但 Math/Chinese/Science 接进来时不需要回头改架构。
- **启动时自动验证**：内容包数据错误（空引用、缺方法）在启动时报告，不让游戏运行中崩溃。

---

## 责任划分

### 🔧 引擎层（学科无关）

永远不动的部分：

| 系统 | 内容 |
|------|------|
| 数据结构 | `Card` / `ChallengeTemplate` / `ChallengeSlot` / `EnemyData` / `BossBase` / `SubjectSpiceBase` / `Equipment` |
| 战斗机制 | 拖卡 / 槽位匹配 / 伤害计算 / 连击 / Spice 调用 / 熟练度 |
| Run 结构 | 三幕路径 / 节点解析 / 中场营地 / 结算 |
| 资源经济 | 双货币、撤退/通关分配、商店购买框架 |
| 城市框架 | 6 建筑布局、图鉴、商店、备战、训练场 |
| SRS / 存档 / 设置 | 全部通用 |
| 反舒适区机制 | 熟练度衰减 / 新卡奖励 / SRS 注入 / Boss 覆盖 |

### 📦 内容包层（学科特定）

每包自己定义：

| 系统 | 内容 |
|------|------|
| 卡片数据 | `cards.json` |
| Challenge 模板 | `challenges.json` |
| 敌人数据 | `enemies.json` |
| Boss 脚本 | `bosses/*.gd`（多阶段逻辑）|
| 楼层配置 | `floors.json`（每楼层 3 act + 子主题）|
| 卡类型词汇表 | 这个包用 `word/phrase/...` 还是 `number/operator/...` |
| POS 词汇表 | 英语有 `adjective/noun/...`；数学包返回空数组 |
| Tag 命名空间 | 各包定义自己的 topic / grammar / scenario |
| Spice 实现 | 各包写自己的 GDScript 类 + UI 场景 |
| 视觉主题 | 主色 / 背景图 / 字体（资源文件）|
| BGM / SFX | 各楼层音乐 / 战斗音效 |
| 剧情文本 | 开篇 / 楼层介绍 / 结局 |

---

## ContentPackBase — 完整接口

```gdscript
class_name ContentPackBase extends Node

# === 身份 ===
func get_id() -> String                          # "english_grade46"
func get_display_name() -> String                # "英语 4-6 年级"
func get_subject_category() -> String            # "english" | "math" | "science" | "chinese" | ...
func get_grade_range() -> Array[int]             # [4, 5, 6]
func get_version() -> String                     # "0.1.0"

# === 主题 ===
func get_theme_colors() -> Dictionary            # {"primary": Color, "accent": Color, "danger": Color}
func get_main_menu_bg_path() -> String
func get_city_bg_path() -> String
func get_floor_bg_path(floor_id: String) -> String
func get_battle_bgm_path(floor_id: String) -> String
func get_main_menu_bgm_path() -> String
func get_city_bgm_path() -> String

# === Card 类型词汇表 ===
func get_card_types() -> Array[Dictionary]
# [{id: "word", display: "词卡", icon: "res://..."}, ...]

func get_pos_values() -> Array[Dictionary]
# 英语: [{id: "adjective", display: "形容词"}, ...]
# 数学: []  ← 这个包不用 POS

func get_tag_namespaces() -> Array[Dictionary]
# [
#   {id: "topic", display: "主题", values: ["emotion", ...]},
#   {id: "grammar", display: "语法特征", values: [...]}
# ]

# === Cards ===
func get_card(card_id: String) -> Card
func get_all_cards() -> Array[Card]
func get_starting_deck_card_ids() -> Array[String]  # 起手 12 张 ID
func get_card_pool_for_floor(floor_id: String) -> Array[Card]   # 该层战利品池

# === Challenges ===
func get_challenge_template(template_id: String) -> ChallengeTemplate
func get_challenges_for_topic(topic_id: String) -> Array[ChallengeTemplate]
func get_supported_challenge_kinds() -> Array[String]
# 英语: ["fill_in_blank", "error_correct", "listening_fill", "pronounce_attack", "sentence_build"]
# 数学: ["fill_in_blank", "equation_solve", "shape_identify"]

# === Enemies / Bosses ===
func get_enemy(enemy_id: String) -> EnemyData
func get_boss(boss_id: String) -> BossBase
func get_enemy_pool_for_floor(floor_id: String) -> Array[EnemyData]

# === Floors（单元配置）===
func get_floor_config(floor_id: String) -> Dictionary
# {
#   floor_id: "1F",
#   unit_name: "形容词初阶",
#   recommended_run_minutes: 18,
#   acts: [
#     {sub_topic_id: "emotion_adjectives", node_count: 6, node_distribution: {...}, boss_id: "...", review_cards: [...]},
#     ...
#   ]
# }

func get_all_floor_ids() -> Array[String]        # ["1F", "2F", "3F", ...] 解锁顺序
func get_floor_unlock_chain() -> Array[Dictionary]
# [{floor_id: "1F", unlocks: ["2F"]}, ...]

# === Spices ===
func get_available_spices() -> Array[SubjectSpiceBase]
func get_spice(spice_id: String) -> SubjectSpiceBase

# === Equipment / Loot（Phase 2 接口预留）===
func get_equipment_pool() -> Array[Equipment]
func get_loot_table_for_floor(floor_id: String) -> Dictionary

# === 剧情文本 ===
func get_intro_story_panels() -> Array[Dictionary]
# [{image_path: "...", text: "...", bgm: "..."}, ...]

func get_floor_intro_dialogue(floor_id: String) -> Array[Dictionary]
func get_ending_panels() -> Array[Dictionary]

# === 验证 ===
func validate() -> Array[String]
# 返回错误信息列表，空数组 = 验证通过
```

**所有方法都是 abstract**，子类必须实现。引擎调用前 ContentLoader 调用 `validate()`，失败则不切换。

---

## 包目录结构（强制约定）

```
src/content/<subject>/
├─ <subject>_content_pack.gd          # 实现 ContentPackBase（必需）
├─ data/
│   ├─ pack_meta.json                 # 主题色、版本、显示名、grade_range
│   ├─ cards.json                     # 所有卡片
│   ├─ challenges.json                # 所有 ChallengeTemplate
│   ├─ enemies.json                   # 所有敌人
│   ├─ bosses.json                    # Boss 元数据（具体逻辑在 bosses/*.gd）
│   ├─ floors.json                    # 楼层 + 三幕配置
│   ├─ equipment.json                 # Phase 2
│   └─ lore.json                      # 剧情面板（开篇/楼层介绍/结局）
├─ spices/
│   ├─ <spice>.gd                     # 各 Spice 类
│   └─ <spice>_ui.tscn                # 各 Spice 的全屏 modal 场景
├─ bosses/
│   └─ <boss>.gd                      # 各 Boss 自定义脚本（继承 BossBase）
├─ assets/
│   ├─ enemies/                       # 敌人立绘
│   ├─ bosses/                        # Boss 立绘
│   ├─ floors/                        # 楼层背景
│   ├─ cards/                         # 卡片图标
│   └─ ui/                            # UI 装饰素材
└─ audio/
    ├─ bgm/
    │   ├─ main_menu.ogg
    │   ├─ city.ogg
    │   └─ floor_<n>.ogg
    └─ sfx/
        └─ <attack_type>_*.ogg
```

**约定即代码**：`ContentLoader` 自动扫描 `res://src/content/*/`，对每个子目录尝试加载 `<dir>_content_pack.gd`。**新增学科 = 新建目录**。

---

## ContentLoader 职责

```gdscript
class_name ContentLoader extends Node

var packs: Dictionary = {}             # id → ContentPackBase
var active_pack_id: String = ""

func _ready() -> void:
    _auto_discover()

func _auto_discover() -> void:
    var content_root = "res://src/content/"
    var dir = DirAccess.open(content_root)
    if not dir: return
    
    dir.list_dir_begin()
    while true:
        var subdir = dir.get_next()
        if subdir == "": break
        if subdir.begins_with("_") or not dir.current_is_dir(): continue
        
        var script_path = content_root + subdir + "/" + subdir + "_content_pack.gd"
        var pack_class = load(script_path)
        if pack_class:
            var pack: ContentPackBase = pack_class.new()
            register_pack(pack)
    dir.list_dir_end()

func register_pack(pack: ContentPackBase) -> void:
    packs[pack.get_id()] = pack

func set_active_pack(pack_id: String) -> bool:
    if not packs.has(pack_id):
        push_error("Pack not found: " + pack_id)
        return false
    
    var pack: ContentPackBase = packs[pack_id]
    var errors = pack.validate()
    if not errors.is_empty():
        push_error("Pack validation failed: " + str(errors))
        return false
    
    active_pack_id = pack_id
    SaveSystem.set_active_pack_id(pack_id)
    GameState.notify_pack_changed(pack)
    return true

func get_active_pack() -> ContentPackBase:
    return packs.get(active_pack_id) if active_pack_id else null

func get_available_packs() -> Array[ContentPackBase]:
    return packs.values()
```

---

## 验证机制

每包必须在 `validate()` 里至少检查：

```gdscript
func validate() -> Array[String]:
    var errors: Array[String] = []
    
    # 1. 元数据完整性
    if get_id().is_empty(): errors.append("get_id() returned empty")
    if get_display_name().is_empty(): errors.append("get_display_name() returned empty")
    
    # 2. 卡片引用完整
    var all_card_ids = get_all_cards().map(func(c): return c.id)
    for cid in get_starting_deck_card_ids():
        if cid not in all_card_ids:
            errors.append("starting deck references missing card: " + cid)
    
    # 3. 楼层引用完整
    var floor_ids = get_all_floor_ids()
    for fid in floor_ids:
        var cfg = get_floor_config(fid)
        for act in cfg.get("acts", []):
            var bid = act.get("boss_id", "")
            if bid and not get_boss(bid):
                errors.append("floor %s act references missing boss: %s" % [fid, bid])
    
    # 4. Challenge 槽位类型在 card_types 中
    var valid_types = get_card_types().map(func(t): return t.id)
    for tmpl in _all_challenge_templates():
        for slot in tmpl.slots:
            if slot.required_type and slot.required_type not in valid_types:
                errors.append("challenge %s slot has invalid type: %s" % [tmpl.template_id, slot.required_type])
    
    # 5. Spice 实现
    for spice in get_available_spices():
        if not spice.has_method("evaluate"):
            errors.append("spice missing evaluate(): " + spice.get_id())
    
    return errors
```

启动时 `ContentLoader.set_active_pack(id)` 调验证；失败则保持原 pack，控制台报错。开发期容易发现数据问题。

---

## 三个学科示例（验证接口够用）

### 📘 English Pack（参考实现）

```gdscript
extends ContentPackBase

func get_id() -> String: return "english_grade46"
func get_display_name() -> String: return "英语 4-6 年级"
func get_subject_category() -> String: return "english"

func get_card_types() -> Array[Dictionary]:
    return [
        {id = "word",    display = "词卡",   icon = "res://src/content/english/assets/ui/icon_word.png"},
        {id = "phrase",  display = "短语卡", icon = "res://src/content/english/assets/ui/icon_phrase.png"},
        {id = "pattern", display = "句型卡", icon = "res://src/content/english/assets/ui/icon_pattern.png"},
        {id = "sound",   display = "音卡",   icon = "res://src/content/english/assets/ui/icon_sound.png"},
    ]

func get_pos_values() -> Array[Dictionary]:
    return [
        {id = "adjective",   display = "形容词"},
        {id = "noun",        display = "名词"},
        {id = "verb",        display = "动词"},
        {id = "adverb",      display = "副词"},
        {id = "pronoun",     display = "代词"},
        {id = "preposition", display = "介词"},
        # ...
    ]

func get_tag_namespaces() -> Array[Dictionary]:
    return [
        {
            id = "topic", display = "主题",
            values = ["emotion", "family", "school", "food", "animal", "weather", ...]
        },
        {
            id = "grammar", display = "语法特征",
            values = ["past_tense", "present_simple", "comparative", ...]
        }
    ]

func get_supported_challenge_kinds() -> Array[String]:
    return ["fill_in_blank", "error_correct", "listening_fill", "pronounce_attack", "sentence_build"]

func get_available_spices() -> Array[SubjectSpiceBase]:
    return [VoiceScrollSpice.new(), DictationSpice.new()]

# ... 其他从 JSON 加载
```

### 📗 Math Pack — 最小骨架（接口验证用）

**目标**：仅作为 spec 一部分，**不实现真做**，但证明接口能容纳数学。

```gdscript
extends ContentPackBase

func get_id() -> String: return "math_grade46"
func get_display_name() -> String: return "数学 4-6 年级"
func get_subject_category() -> String: return "math"

func get_card_types() -> Array[Dictionary]:
    return [
        {id = "number",   display = "数字卡",   icon = "..."},
        {id = "operator", display = "运算符卡", icon = "..."},
        {id = "formula",  display = "公式卡",   icon = "..."},
        {id = "shape",    display = "几何卡",   icon = "..."},
        {id = "unit",     display = "单位卡",   icon = "..."},
    ]

func get_pos_values() -> Array[Dictionary]:
    return []   # 数学没有词性概念

func get_tag_namespaces() -> Array[Dictionary]:
    return [
        {id = "topic",    display = "主题",   values = ["addition", "subtraction", "multiplication", "geometry", "fractions"]},
        {id = "property", display = "数学性质", values = ["commutative", "associative", "distributive"]},
    ]

func get_supported_challenge_kinds() -> Array[String]:
    return ["fill_in_blank", "equation_solve", "shape_identify", "error_correct"]

func get_available_spices() -> Array[SubjectSpiceBase]:
    return [MentalArithmeticSpice.new()]   # 心算闪电
```

**最小数据样例**（cards.json 节选）：
```jsonc
[
  { "id": "card_num_3", "type": "number", "text": "3", "tags": ["small_number", "addition"], "skill": "vocab", "base_damage": 5, "rarity": "common" },
  { "id": "card_num_7", "type": "number", "text": "7", "tags": ["small_number", "addition"], "skill": "vocab", "base_damage": 7, "rarity": "common" },
  { "id": "card_op_plus", "type": "operator", "text": "+", "tags": ["addition"], "skill": "vocab", "base_damage": 0, "rarity": "common" },
  { "id": "card_formula_triangle_area", "type": "formula", "text": "1/2 × 底 × 高", "tags": ["geometry"], "skill": "grammar", "base_damage": 15, "rarity": "rare" }
]
```

**最小 Challenge 样例**：
```jsonc
[
  {
    "template_id": "math_eq_1",
    "kind": "equation_solve",
    "dialogue": "3 + ___ = 10",
    "topic_id": "addition_basic",
    "slots": [
      {"required_type": "number", "required_tags": ["small_number"]}
    ],
    "perfect_match_card_ids": ["card_num_7"]
  }
]
```

**核心证明**：引擎 `Validator.can_place(card, slot)` 不区分英语数学——它只看 `card.type == slot.required_type` 和 tag 交集。**同一个引擎能跑英语也能跑数学**。

### 📒 Chinese Pack — 接口验证（更不一样）

```gdscript
func get_card_types() -> Array[Dictionary]:
    return [
        {id = "character",  display = "字卡"},
        {id = "word",       display = "词卡"},
        {id = "poem_line",  display = "诗句卡"},
        {id = "rhetoric",   display = "修辞卡"},
    ]

func get_supported_challenge_kinds() -> Array[String]:
    return ["fill_in_blank", "poem_complete", "character_match"]

func get_available_spices() -> Array[SubjectSpiceBase]:
    return [PoemRecitationSpice.new(), StrokeOrderSpice.new()]
```

→ 同一个引擎，同一个接口。

---

## 学科切换交互（MVP 隐藏，框架预留）

### 设置界面（最终形态，MVP 隐藏）

```
[设置]
学习内容：[英语 4-6] ▾
  ├─ 英语 4-6        ✓ (当前)
  ├─ 英语 7-9        🔓
  ├─ 数学 4-6        🔓
  ├─ 科学 4-6        🔒 (即将推出)
  └─ 语文 4-6        🔒 (即将推出)

[切换需要回主菜单。当前进度按学科保存，切回不会丢失。]
```

### MVP 阶段

- 设置中**不显示**"学习内容"切换项（仅英语，避免选项困惑）
- 内部仍按学科分文件存档（架构就位，UI 隐藏）
- Math 包目录可以**存在但空**（仅一个 stub 类），不向用户暴露

### 切换流程

```
玩家点击切换 →
  弹窗"切换学科会回到主菜单，确定？"  →
  确定 →
  ContentLoader.set_active_pack(new_id) →
  SaveSystem.load_per_pack_save(new_id) →
  GameState 重置（保留全局设置）→
  跳转主菜单
```

---

## 存档隔离

### 文件结构

```
user://saves/
├─ active.cfg                # 当前激活的 pack_id
├─ english_grade46.json
├─ math_grade46.json
└─ ...
```

### SaveSystem 改造

```gdscript
class_name SaveSystem extends Node

var _active_pack_id: String = ""

func set_active_pack_id(pack_id: String) -> void:
    _active_pack_id = pack_id
    var cfg = ConfigFile.new()
    cfg.set_value("meta", "active_pack_id", pack_id)
    cfg.save("user://saves/active.cfg")

func get_save_path() -> String:
    return "user://saves/" + _active_pack_id + ".json"

func save_game_state(state: Dictionary) -> void:
    var path = get_save_path()
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    var f = FileAccess.open(path, FileAccess.WRITE)
    f.store_string(JSON.stringify(state))

func load_game_state() -> Dictionary:
    var path = get_save_path()
    if not FileAccess.file_exists(path):
        return {}
    var f = FileAccess.open(path, FileAccess.READ)
    return JSON.parse_string(f.get_as_text()) or {}

# 旧存档迁移
func migrate_legacy() -> void:
    if FileAccess.file_exists("user://save.json"):
        var data = JSON.parse_string(FileAccess.open("user://save.json", FileAccess.READ).get_as_text())
        var path = "user://saves/english_grade46.json"
        DirAccess.make_dir_recursive_absolute(path.get_base_dir())
        var f = FileAccess.open(path, FileAccess.WRITE)
        f.store_string(JSON.stringify(data))
        DirAccess.remove_absolute("user://save.json")  # 清理旧文件
```

启动时检测旧 `save.json`，自动迁移到 `saves/english_grade46.json`。

---

## 现有代码处置

| 现有 | 处置 |
|------|------|
| `src/core/interfaces/content_pack_base.gd` | **大改** — 实现完整 25 方法接口 |
| `src/core/systems/content_loader.gd` | **改** — 自动扫描 + 验证机制 |
| `src/core/systems/save_system.gd` | **改** — per-pack 存档 + 旧档迁移 |
| `src/content/english/english_content_pack.gd` | **大改** — 实现新接口 |
| `src/content/english/data/questions.json` | **拆** — `cards.json` + `challenges.json` + `enemies.json` |
| `src/content/english/data/gates.json` | **重组** — 改为 `floors.json`（带三幕） |
| `src/content/english/bosses/librarian_boss.gd` | **适配** — 实现新 BossBase 接口 |
| `src/core/interfaces/boss_base.gd` | **扩展** — 加 phase / dialogue / spice_trigger 接口 |

新增：
- `src/content/_template/` — 内容包脚手架模板（README + 空骨架文件）
- `src/content/_validator/pack_validator.gd` — 跨包验证工具（命令行可调）

---

## MVP 范围

### 必做
- ContentPackBase 完整接口（25 个方法）
- ContentLoader 自动扫描 + `validate()` 验证
- 英语包按新接口完整重写
- 英语 JSON 数据拆分（cards / challenges / enemies / floors / lore）
- SaveSystem 按学科分文件 + 旧档自动迁移
- 启动时验证报告（控制台）
- 设置中"学习内容"切换 UI 框架（MVP 阶段隐藏）

### 不做（推迟）
- Math / Chinese / Science 包真实做（仅作 spec 样例）
- 内容包脚手架生成器
- 内容包热重载
- 跨包数据共享（每包数据独立）

---

## 测试策略

### 单元测试（GUT）
- `ContentPackBase.validate()` 各种数据缺失场景
- `ContentLoader._auto_discover()` 含/不含子目录的健壮性
- `ContentLoader.set_active_pack()` 验证失败回退
- `SaveSystem.migrate_legacy()` 旧档迁移
- Card / ChallengeTemplate JSON 加载边界

### 集成测试
- 启动 → 自动扫描包 → 加载英语 → 验证通过 → 进游戏
- 切换学科（mock 第二个 stub 包）→ 存档隔离验证
- 旧 save.json 存在 → 启动后自动迁移到 saves/<id>.json

### 手动测试
- 改 cards.json 中故意写错 type → 启动报告错误，不崩溃
- 删除一个 enemy_id → 启动报告引用错误
- 全新用户 → 没旧档 → 直接走新格式

---

## 验收标准

- [ ] `src/content/english/` 完整重写，目录结构符合约定
- [ ] `ContentPackBase` 完整 25 方法接口
- [ ] `ContentLoader` 启动自动扫描 + 调用 `validate()`
- [ ] 启动时控制台输出 "[ContentLoader] 加载 1 个内容包: english_grade46 ✓"
- [ ] 故意制造 cards.json 错误 → 启动控制台报错且游戏继续可用
- [ ] save.json 旧档自动迁移到 saves/english_grade46.json
- [ ] 设置界面有"学习内容"区域（MVP 隐藏，但代码就位）
- [ ] 跨学科切换流程通（含 mock 第二个 stub 包）
- [ ] 单测覆盖 ContentLoader / SaveSystem 迁移 ≥80%

---

## 设计取舍说明

### Q: 为什么 Spice 是包级，不是引擎级抽象？

A: 各学科特色机制差异太大（口语 vs 心算 vs 笔顺）。强行抽象到引擎层会变成"什么都不像"的接口。让每个包写自己 Spice 类，引擎只调通用 `evaluate(input)`。

### Q: Card 的 4 维分类够吗？

A: **够了**。type / pos / tags / skill 已覆盖：
- 机制角色（type）
- 语法/数学结构角色（pos，可空）
- 自由打标签（tags，无限扩展）
- 技能域（skill，决定 Spice 兼容）

任何学科都能映射。

### Q: 为什么 25 方法的单一接口，不拆？

A: 简单直白，少跳转。25 方法看似多，但概念清晰（身份 / 主题 / 卡 / Challenge / 敌人 / 楼层 / Spice / 装备 / 剧情 / 验证 = 10 类）。拆成多接口反而增加心智负担。

### Q: 为什么 MVP 隐藏学科切换 UI？

A: 现在只有英语一包；显示一个空选择项会让玩家困惑。架构就位，UI 隐藏，等 Math 真做完再开放。

---

## 未决事项（依赖其他 spec）

- **Boss spec**：`BossBase` 的多阶段接口最终形态
- **故事 / 剧情 spec**：剧情面板格式（image_path + text + bgm + transition）
- **职业系统 spec**：内容包是否要为各职业配不同起手卡组（接口已留 `get_starting_deck_card_ids()`，但没参数化职业）
- **美术清单 spec**：每包需要的视觉资产 + Kenney/AI 来源
