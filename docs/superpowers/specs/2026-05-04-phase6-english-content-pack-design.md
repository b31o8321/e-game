# Phase 6 — 英语内容包 设计文档

## Goal

实现可试玩的真实英语内容包（小学4-6年级），包含80道题目、年级难度设置界面、以及完整大关配置。玩家可从主菜单进入设置选择年级，影响题目难度池。

## Architecture

采用**单 JSON + 代码过滤**方案：所有题目存放在 `questions.json`，每题含 `grade` 字段。`EnglishContentPack` 在 `_ready()` 时加载 JSON，`get_question()` 根据 `GameState.player_grade` 筛选可用题目（grade ≤ player_grade）。年级设置独立场景，主菜单入口，修改立即生效并存档。

---

## 文件结构

| 路径 | 动作 | 职责 |
|------|------|------|
| `src/content/english/english_content_pack.gd` | 新建 | 实现 ContentPackBase 全部接口 |
| `src/content/english/data/questions.json` | 新建 | 80 道题目（词汇50 + 语法30） |
| `src/content/english/data/gates.json` | 新建 | 大关配置（遗忘图书馆） |
| `src/ui/settings_scene.gd` | 新建 | 年级选择控制器 |
| `src/ui/settings_scene.tscn` | 新建 | 设置界面场景 |
| `src/core/autoloads/game_state.gd` | 修改 | 新增 `player_grade: int = 5` 字段 |
| `src/core/systems/save_system.gd` | 修改 | 存读 `player_grade` |
| `src/ui/main_menu.gd` (或 tscn) | 修改 | 新增"设置"按钮入口 |

---

## JSON 数据格式

### questions.json

顶层结构：`{ "questions": [ ... ] }`

每题格式：
```json
{
  "id": "q_vocab_001",
  "type": "vocabulary",
  "grade": 4,
  "question": "What does 'brave' mean?",
  "options": ["勇敢的", "聪明的", "安静的", "友善的"],
  "correct_index": 0,
  "explanation": "brave [breɪv] · 勇敢的  例：The brave knight saved the village.",
  "audio_text": "brave"
}
```

字段说明：
- `id`: 唯一标识，格式 `q_vocab_NNN` / `q_grammar_NNN`
- `type`: `"vocabulary"` | `"grammar"`（对应 attack_type_id）
- `grade`: 4 | 5 | 6
- `options`: 4个选项
- `correct_index`: 0-based
- `explanation`: 显示给玩家的解析（含音标、中文释义、例句）
- `audio_text`: 用于 Phase 8 TTS 的朗读文本

**题目数量分布：**
- 4年级词汇：20题（高频基础词：brave, kind, fast, quiet, strong...）
- 5年级词汇：20题（中级词：curious, patient, enormous, ancient...）
- 6年级词汇：10题（进阶词：mischievous, determined, genuine...）
- 4年级语法：10题（be动词、简单现在时、There is/are）
- 5年级语法：12题（一般过去时、可数/不可数名词、形容词比较级）
- 6年级语法：8题（现在完成时、被动语态基础、定语从句引导词）

### gates.json

顶层结构：`{ "gates": [ ... ] }`

```json
{
  "gate_id": "gate_en_librarian",
  "gate_name": "遗忘图书馆",
  "required_knowledge_level": 1,
  "wave_count": 2,
  "questions_per_wave": 4,
  "wave_enemy": {
    "enemy_name": "遗忘幽灵",
    "max_hp": 40,
    "base_attack": 6,
    "weaknesses": ["vocabulary"],
    "multipliers": { "vocabulary": 1.5 }
  },
  "boss_script_path": "res://src/content/english/bosses/librarian_boss.gd",
  "boss_enemy": {
    "enemy_name": "遗忘图书管理员",
    "max_hp": 150,
    "base_attack": 10,
    "weaknesses": [],
    "multipliers": {}
  },
  "unlock_knowledge_level": 2,
  "unlock_area_ids": []
}
```

---

## EnglishContentPack 实现

```gdscript
class_name EnglishContentPack extends ContentPackBase

var _questions: Array[Dictionary] = []
var _gates: Array[Dictionary] = []

func _init() -> void:
    pack_id = "english_grade46"
    pack_name = "小学英语 4-6年级"
    subject = "english"
    grades = [4, 5, 6]

func _ready() -> void:
    _load_questions()
    _load_gates()
```

**`get_question(attack_type_id, difficulty, exclude_ids)`**：
- 筛选条件：`type == attack_type_id`（若非空）且 `grade <= GameState.player_grade`
- 排除 `exclude_ids`
- 从候选中随机取一道

**`get_question_by_id(id)`**：直接查 `_questions` 数组

**`get_gate_questions(gate_id, count)`**：
- 返回专为大关设计的题目子集（高错误率、高考点题）
- 实现：从 `_questions` 中过滤出 `grade <= player_grade` 的题，随机取 `count` 道（去重）

**`get_gates()`**：返回 `_gates`

**`get_attack_types()`**：
```gdscript
return [
    { "id": "vocabulary", "name": "词汇", "icon": "📚", "color": "#667eea", "element": "fire" },
    { "id": "grammar",    "name": "语法", "icon": "📝", "color": "#f5576c", "element": "ice" },
]
```

**`get_buildings()`**：与 MockContentPack 相同（词汇图书馆 + 语法学院）

---

## GameState 变更

新增字段：
```gdscript
var player_grade: int = 5   # 4 | 5 | 6
```

SaveSystem 同步存读此字段：`save_game_state()` 写入 `"player_grade": GameState.player_grade`，`load_game_state()` 读取 `data.get("player_grade", 5)`。

---

## 设置界面

**`settings_scene.tscn`** 节点结构：
- `TitleLabel`（"游戏设置"）
- `GradeLabel`（"年级选择"）
- `Grade4Button` / `Grade5Button` / `Grade6Button`（三个 Button，互斥选中）
- `BackButton`（"返回"）

**逻辑：**
- `_ready()`：根据 `GameState.player_grade` 高亮当前按钮
- 点击年级按钮：更新 `GameState.player_grade`，调用 `GameState.save_system.save_game_state()`
- 返回：`change_scene_to_file("res://src/ui/main_menu.tscn")`

**主菜单修改：** 新增"⚙️ 设置"按钮，跳转 `settings_scene.tscn`。

---

## ContentLoader 连接

`ContentLoader` 通过 `register_pack()` + `set_active_pack()` 注册内容包。目前主菜单未注册任何包，`get_active_pack()` 返回 null。

修改 `src/core/autoloads/game_state.gd` 的 `_ready()`，在创建 `content_loader` 后追加：

```gdscript
var english_pack := EnglishContentPack.new()
content_loader.add_child(english_pack)
content_loader.register_pack(english_pack)
content_loader.set_active_pack("english_grade46")
```

这样全局所有场景调用 `GameState.content_loader.get_active_pack()` 都能拿到真实内容包。

---

## 测试覆盖

`tests/test_english_content_pack.gd`（GUT）：
1. `get_question("vocabulary", 1, [])` 返回 grade ≤ player_grade 的词汇题
2. `get_question` 排除 exclude_ids 中的题目
3. `player_grade=4` 时不返回 grade 5/6 的题
4. `get_gate_questions("gate_en_librarian", 8)` 返回 8 道不重复题
5. `get_gates()` 返回至少 1 个大关，gate_id == "gate_en_librarian"
6. `get_question_by_id("q_vocab_001")` 返回正确题目

---

## 年级难度说明

| 年级 | 词汇范围 | 语法范围 |
|------|----------|----------|
| 4年级 | 基础高频词（200词内） | be动词、简单现在时、There is/are |
| 5年级 | 中级词（延伸到500词） | 一般过去时、比较级、可数/不可数 |
| 6年级 | 进阶词、短语动词 | 现在完成时、被动语态、定语从句 |

玩家选择年级后，题目池包含该年级及以下所有题目（累进制）。

---

## 与其他 Phase 的接口约定

- **Phase 7（Supabase）**：`save_system.save_game_state()` 已预留云端同步位置，`player_grade` 随其他字段一并同步
- **Phase 8（语音）**：每题 `audio_text` 字段已备好，TTS 直接读取
- **Phase 9（家长看板）**：答题记录已通过 SRS 系统存储，`player_grade` 可供家长看板展示

---

## Phase 6 完成标准

- [ ] `EnglishContentPack` 加载 JSON 成功，6条 GUT 测试全部通过
- [ ] 80道题目覆盖词汇+语法，grade 字段正确
- [ ] 年级设置界面可访问，切换立即生效，重启后保持
- [ ] ContentLoader 使用 EnglishContentPack 替代 MockContentPack
- [ ] 遗忘图书馆大关可从探索场景进入，wave 战斗出真实题目
- [ ] 整体试玩流程通畅：城市 → 探索 → 打怪（真实题） → 大关 → Boss → 通关
