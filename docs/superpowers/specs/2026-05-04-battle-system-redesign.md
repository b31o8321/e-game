# 战斗系统重设计 — 知识神塔

> 状态：v1（已对齐核心机制；卡池 / Boss 多阶段 / 装备词条等细节将在后续 spec 决定）
> 上下文：本 spec 替换原有"问答攻击"战斗（`BattleController` + `QuestionController`），与即将设计的 Roguelite 局结构、永久成长、知识城等模块并列。

---

## 设计目标

- **教育闭环**：玩家学到的知识 = 牌组里能打出去的牌；不学就打不动。
- **教育产出主动化**：除了选题，还能用嘴说、动手拼、心算等"主动输出"机制（Subject Spice）。
- **"解除知识封印"叙事**：敌人不是怪物，是被遗忘扭曲的知识守关者；战斗 = 修复其残缺/错误台词。
- **学科无关**：核心战斗引擎不依赖任何特定学科；学科切换 = 内容包切换。
- **爽感密度**：高频视听反馈（连击 / 暴击 / 全屏特效 / Spice 仪式感）。

非目标（明确不做）：
- 不做小弟/宠物/出战单位（之前已否决"词灵"路线）。
- 不做塔防/弹幕（之前已否决）。
- MVP 不做多技能槽位 + Build 系统（避免一次叠太多复杂度）。

---

## 整体架构

```
战斗系统
├─ 核心引擎层（学科无关）
│   ├─ Card / Hand / Deck / DiscardPile
│   ├─ ChallengeTemplate / ChallengeSlot / Challenge（运行时）
│   ├─ ChallengeValidator（卡片→槽位 匹配判定）
│   ├─ DamageCalculator（基础伤害 + 弱点 + 连击 + 暴击）
│   ├─ ComboSystem（沿用现有）
│   └─ SubjectSpiceBase（接口）
│
├─ UI 层
│   ├─ BattleScene（手牌区 / 敌人区 / Challenge 显示 / HP-MP-连击 / 弃牌堆）
│   ├─ CardView（手牌单卡视图，可拖拽）
│   ├─ ChallengeBoardView（敌人台词带可拖入槽）
│   ├─ EnemyView（立绘 + HP/状态）
│   └─ SpiceModal（Spice 触发时全屏 modal）
│
└─ 内容包层（学科特定）
    └─ EnglishContentPack
        ├─ Cards（cards.json）
        ├─ ChallengeTemplates（challenges.json）
        ├─ Enemies（含台词序列）
        └─ Spices
            ├─ VoiceScrollSpice（口语卷轴）
            └─ DictationSpice（听写法术）
```

---

## 核心数据模型

### Card（4 维度分类）

每张卡有 4 个独立维度，引擎通过这些字段做匹配，**学科切换 = 重新填这些字段**：

```gdscript
class_name Card extends Resource

@export var id: String                  # "card_brave"
@export var text: String                # "brave"

# 维度 1: Type（机制角色，决定能进什么槽）
@export var type: String                # "word" | "phrase" | "pattern" | "rule" | "sound" | "modifier"

# 维度 2: POS（仅 word/phrase 用，决定词性槽匹配）
@export var pos: String                 # "adjective" | "verb" | ... | "" (其他类型空)

# 维度 3: Tags（自由打标，多维过滤）
@export var tags: Array[String]         # ["positive_emotion", "personality", "grade_4"]

# 维度 4: Skill（技能域，决定 Spice 兼容性）
@export var skill: String               # "vocab" | "grammar" | "phonetics" | "spelling" | "speaking" | "listening" | "reading" | "writing"

# 战斗属性
@export var base_damage: int
@export var rarity: String              # "common" | "rare" | "epic" | "legendary"
@export var on_play_effect: String      # 可空，附加效果 ID
@export var icon_path: String

# 听音 / 拼写卡专属
@export var audio_path: String          # type=sound 时使用
```

#### Type 枚举（引擎层定义）

| 类型 | 用途 | MVP 是否实现 |
|------|------|-------------|
| `word` | 单词卡 | ✅ MVP |
| `phrase` | 短语卡（look forward to）| ✅ MVP |
| `pattern` | 句型片段卡（"How do you ___?"）| ✅ MVP |
| `sound` | 发音/听音卡 | ✅ MVP（与 Spice 联动） |
| `rule` | 规则卡（修改其他卡，如 "+ed → 过去式"）| ⏸ Phase 2 |
| `modifier` | 修饰卡（在另一张卡前加 "very" / "not"）| ⏸ Phase 2 |

#### POS 枚举（英语包）

`adjective / noun / verb / adverb / pronoun / preposition / conjunction / article / interjection / numeral / determiner`

#### Tags 命名空间（建议但不强制）

- 主题：`emotion / family / school / food / animal / weather / time / place / body / sport / hobby / shopping / travel / festival / daily / nature / job / color / number`
- 语法：`past_tense / present_simple / present_continuous / future / comparative / superlative / plural / possessive / question / negation / passive`
- 情景：`scenario:restaurant / scenario:airport / scenario:greeting / ...`
- 难度：`grade_4 / grade_5 / grade_6`

### ChallengeTemplate

```gdscript
class_name ChallengeTemplate extends Resource

@export var template_id: String         # "fill_in_blank_v1"
@export var kind: String                # 见下方枚举
@export var dialogue: String            # "I am very ___"，___ 表示槽
@export var slots: Array[ChallengeSlot]
@export var topic_id: String            # "adjectives_basic"（与单元/楼层挂钩）
@export var perfect_match_card_ids: Array[String]   # 暴击卡（最优解）
@export var audio_path: String          # 听力 Challenge 用
```

#### Kind 枚举（MVP 5 种 + Phase 2 扩展）

**MVP 必做（小学阶段重点）：**

| kind | 形式 | 锻炼 |
|------|------|------|
| `fill_in_blank` | "I am very ___" 选词填空 | reading + vocab |
| `error_correct` | "He are happy" 划红 are 选 is 替换 | grammar |
| `listening_fill` | 🔊 听音 → 选拼写 | listening + spelling |
| `pronounce_attack` | 朗读敌人台词触发反伤（Spice 触发）| speaking |
| `sentence_build` | 散乱卡片按正确顺序排列 | writing + grammar |

**Phase 2 推迟：**
- `chain_response`（接龙对话）
- `rule_apply`（规则卡修改其他卡）
- `modifier_stack`（修饰卡叠加）
- `scenario_complete`（情景对话补全）

### ChallengeSlot

```gdscript
class_name ChallengeSlot extends Resource

@export var index: int
@export var required_type: String        # "word" 等；空 = 不限
@export var required_pos: String         # "adjective" 等；空 = 不限
@export var required_tags: Array[String] # any-match 即过；空 = 不限
@export var forbidden_tags: Array[String]# any-match 即拒
@export var damage_multiplier: float = 1.0
```

引擎匹配逻辑：

```gdscript
func can_place(card: Card, slot: ChallengeSlot) -> bool:
    if slot.required_type and card.type != slot.required_type: return false
    if slot.required_pos and card.pos != slot.required_pos: return false
    if not slot.required_tags.is_empty() and card.tags.filter(func(t): return t in slot.required_tags).is_empty():
        return false
    if not slot.forbidden_tags.is_empty() and not card.tags.filter(func(t): return t in slot.forbidden_tags).is_empty():
        return false
    return true
```

### Challenge（运行时实例，不持久化）

```gdscript
var template: ChallengeTemplate
var slots_state: Array        # [Card | null] 每槽当前填的卡
var enemy_id: String
var phase: int
```

---

## 战斗流程

```
A. 战斗初始化
   ├─ 加载 enemy_id 对应的 ChallengeTemplate 序列（多阶段敌人有多组）
   ├─ 玩家牌组 shuffle，抽 5 张
   └─ 渲染当前 Challenge 台词 + 空槽

B. 玩家回合
   ├─ 玩家从手牌拖卡 → Challenge 槽
   │   ├─ Validator.can_place(card, slot) → true/false
   │   └─ 不允许：卡弹回手牌
   ├─ 槽全部填满 → 触发解算
   │   ├─ DamageCalculator(填的卡, 模板, 战斗状态) → 伤害值
   │   ├─ 暴击判定：所有槽都是 perfect_match → 全屏特效 + ×2
   │   ├─ ComboSystem.increment()
   │   ├─ 敌人受伤 → 立绘震动 + 数字飞出
   │   └─ 抽下一组 Challenge（同一敌人下一句台词）
   ├─ 玩家可在任一时刻使用 Spice 物品（卷轴/手牌中的 Spice 卡）
   │   └─ 触发 SpiceModal 流程（见下文）
   └─ 玩家点击"过牌"或槽未填满超时 → 进入敌人回合

C. 敌人回合
   ├─ 若槽未填满（玩家放弃）→ 玩家受伤（轻）+ 当前 Challenge 跳过
   ├─ 敌人攻击：取台词中的"敌方动作"标记 → 玩家受伤
   ├─ 玩家弃手 + 重抽 5 张
   └─ 进入下一玩家回合

D. 结束条件
   ├─ 敌人 HP 归零 → 胜利 → 进入 3 选 1 卡片奖励
   └─ 玩家 HP 归零 → 失败 → 退出当前 Run（roguelite 死局）
```

---

## 解算细节

### Validator.can_place

见上方"ChallengeSlot"小节的伪码（基于 type / pos / tags / forbidden_tags 匹配）。

### DamageCalculator

```
基础伤害 = sum(slot.damage_multiplier × card.base_damage for each filled slot)

熟练度系数 = 各卡 mastery_multiplier 的几何平均（见"反舒适区"小节）
若所有 filled card.id 都在 template.perfect_match_card_ids
  → 暴击系数 ×2（"完美修复"）
弱点系数 = enemy.weakness_factor（card.skill 或 card.tags 命中 enemy.weak_axes ? 1.5 : 1.0）
连击系数 = 1 + 0.05 × combo_count（封顶 2.0）

最终伤害 = round(基础 × 熟练度 × 暴击 × 弱点 × 连击)
```

### 失败/部分通过

- **可放但非最优**：正常伤害（无暴击）
- **不可放**：卡弹回，不消耗回合，但消耗一点点"思考时间"（对玩家来说没惩罚，鼓励试错）
- **超时未填**：进入敌人回合 + 失血（轻）

---

## 学科特色机制（Subject Spice）

### 接口

```gdscript
class_name SubjectSpiceBase extends Resource

func get_id() -> String
func get_display_name() -> String
func get_description() -> String
func get_ui_scene() -> PackedScene       # 战斗中触发的 modal 场景
func evaluate(input_data: Variant) -> SpiceResult
```

```gdscript
class_name SpiceResult
var success: bool
var quality: float                       # 0.0 ~ 1.0
var effect_payload: Dictionary           # {"buff": "atk_up_30", "duration": 3}
```

### 调用链

1. 战斗中玩家点击 Spice 道具（卷轴 / 特殊卡片）
2. `BattleController.invoke_spice(spice_id)`
3. 实例化 `spice.get_ui_scene()` 作为全屏 modal
4. modal 完成后通过 signal 回传 input_data
5. `spice.evaluate(input_data) → SpiceResult`
6. 应用 `effect_payload`（buff、伤害、回血、抽牌等）
7. 关闭 modal，回到战斗主流程

### 英语 Spice：口语卷轴（VoiceScrollSpice）

```gdscript
class_name VoiceScrollSpice extends SubjectSpiceBase

@export var target_phrase: String          # "I'm strong"
@export var buff_id: String                # "atk_up"
@export var buff_value: int                # 30
@export var buff_duration: int             # 3 turns
```

**UI（voice_scroll_ui.tscn）**：
- 大字显示 `target_phrase`（带音标）
- 长按 🎤 按钮 → 录音（最长 5 秒）
- 松开 → 显示"识别中..."
- 调用 STT 后端（见下文）→ 返回 transcript
- 算 quality（编辑距离 + 单词命中比例）
- success 阈值 0.6
- 成功：buff 动画 + 词条飞向角色 + 关闭
- 失败：可重试（最多 2 次），不扣血

**STT 后端（MVP 多策略）**：

| 策略 | 启用条件 | 实现 |
|------|---------|------|
| Whisper API | 有网 + 有 API Key | HTTP POST 至 OpenAI |
| 占位（dev mode）| 没网 / 无 Key | 录音满 1.5 秒即视为通过（占位）|

API Key 配置：`user://config.cfg` 中 `voice_stt_api_key`，设置界面可填。

### 英语 Spice：听写法术（DictationSpice）

```gdscript
class_name DictationSpice extends SubjectSpiceBase

@export var target_word: String           # "brave"
@export var counter_damage: int           # 反伤 25
```

**UI**：
- 播放 `target_word` 的音频（TTS 或预录）
- 显示输入框 + 软键盘（移动端）
- 提交 → 全字符串小写比对
- 成功：counter_damage 反弹给敌人
- 失败：鼓励文案 + 显示正确拼写（教学时刻）

---

## 战斗 UI 布局

```
┌────────────────────────────────────────────┐
│  🌑 楼层 1F · 第 2 战 · 敌人 1/1            │ ← 顶部
├────────────────────────────────────────────┤
│                                            │
│           ┌───────────────────┐            │
│           │   迷雾低吟者立绘    │            │
│           │   HP ▰▰▰▰▰▱▱       │            │
│           │   弱点：positive    │            │
│           └───────────────────┘            │
│                                            │
│   敌人台词（可填空 ChallengeBoard）：         │
│   "I am very [_____] ..."                  │
│                                            │
├────────────────────────────────────────────┤
│  🧙 守护者 HP ▰▰▰▱  MP ▰▰▰▰  连击 4🔥       │
├────────────────────────────────────────────┤
│  手牌（可横滑）：                            │
│  [brave] [happy] [run] [book] [angry]      │
├────────────────────────────────────────────┤
│  [🎤 口语卷轴]  [🎵 听写]  [过牌]            │
└────────────────────────────────────────────┘
```

---

## 现有代码迁移

| 现有 | 处置 |
|------|------|
| `src/battle/battle_controller.gd` | **大改** — 移除问答逻辑，改为卡片解算驱动 |
| `src/battle/battle_scene.tscn` | **重写** — 新 UI 布局 |
| `src/battle/question_controller.gd` | **删除** |
| `src/battle/question_ui.tscn` | **删除** |
| `src/battle/combo_system.gd` | **保留**，接入新流程 |
| `src/battle/enemy_data.gd` | **扩展** — 加 `challenge_template_ids: Array[String]` 和 `weak_categories` |
| `src/content/english/data/questions.json` | **重组** — 拆为 `cards.json` + `challenges.json` + `enemies.json` |
| `src/content/english/english_content_pack.gd` | **扩展** — 加 `load_cards()` / `load_challenges()` / `get_spices()` |
| `src/core/interfaces/content_pack_base.gd` | **扩展** — 加 Card / Challenge / Spice 接口 |
| `src/battle/skills/` 目录 | **保留待用** — 暂不接入 MVP |
| `src/battle/expedition_setup*` | **删除** — Roguelite 不需要远征概念 |

---

## 反"舒适区刷分"机制（教育核心）

为防止小孩只用熟悉卡反复刷会的题，引擎在战斗与奖励两端做正/负向激励。

### 1. 熟练度伤害衰减

每张卡运行时计算 `mastery_level`（基于 `SrsSystem` 答对次数）：

| 等级 | 标志 | 触发条件 | 伤害倍率 |
|------|------|---------|---------|
| 🌱 新 | Fresh | 战斗中从未用对过 | **×1.5** |
| 🌿 学习中 | Learning | 答对 1-3 次 | ×1.3 |
| 🌳 熟练 | Proficient | 答对 4-7 次 | ×1.0 |
| ⭐ 掌握 | Mastered | 答对 8+ 次 | **×0.7** |

**包装为成长，不是惩罚**：
- UI 显示 "🌳 熟练 — 用新卡获得更高伤害!"
- 不显示 "已掌握，伤害降低" 之类负向文案

### 2. 新卡奖励（正向激励）

战后结算自动加：
- 本局首次使用的卡 → 每张 +5 词晶 + 一次性 "🌱 新卡解锁!" 弹窗
- 用新卡击败敌人 → 额外 +10 词晶
- 营地 3 选 1 卡片 — **未学过主题的卡置顶推荐**

### 3. 楼层主题倾斜（结构强制）

`ChallengeTemplate` 的槽位**强制偏向本楼层子主题**：
- 1F「形容词初阶」的所有 Challenge 槽位 `required_pos = "adjective"`
- 即使带满名词卡也填不进去 → 必须学会本层词汇

### 4. SRS 驱动的针对性敌人

战斗 Challenge 选择伪码：
```gdscript
func pick_challenge_for_enemy(enemy, srs):
    if randf() < 0.3 and srs.has_weak_questions():
        return generate_from_weak(srs.get_weakest(3))
    return pick_random(enemy.challenge_pool)
```

→ **30% 概率注入玩家薄弱主题的 Challenge**，无法回避弱点。

### 5. Boss 强制覆盖

Final Boss 的 Challenge 池**必须覆盖该单元所有子主题**（A + B + C）。
- 跳过任意子主题 = 那道 Challenge 没卡填 = 必受伤
- Boss 是真正的"期末考"

### 6. 三星挑战的广度奖（图鉴 100% 必经）

每楼层 3 颗星：
- ⭐ 通关
- ⭐⭐ 不撤退一次通关
- ⭐⭐⭐ **本局使用至少 N 张新卡通关**（N = 楼层卡池 30%）

只刷会的题的玩家拿不到第三颗星。

### 接入点（代码层）

| 模块 | 改动 |
|------|------|
| `SrsSystem` | 已有；新增 `get_mastery_level(card_id)` / `get_weakest_card_ids(count)` |
| `Card` | 加运行时属性 `mastery_level`，每场战斗刷新 |
| `DamageCalculator` | 加 `mastery_multiplier` 系数 |
| `BattleController` | 战后调用 `record_card_usage(...)` + 计算新卡奖励 |
| `ChallengeSelector`（新）| 30% 概率从 SRS 弱点注入 |
| `Boss` 数据 | `requires_topic_coverage: Array[String]` |
| 三星挑战系统 | 由 Run / 永久成长 spec 实现，本 spec 仅声明接口 |

---

## Phase 2 储备（不做但记下）

避免架构改动后无法扩展，下面这些机制**接口预留**：

### 规则卡 + 修饰卡（"卡片升级"思路）

- `rule` 类型卡：拖到其他卡上 → 修改它（如 "+ed" 把 `go` → `went`）
- `modifier` 类型卡：在另一张卡前组合（如 `very` + `happy`）
- 这就是用户提到的"卡片升级"概念，体验是**玩家亲手造词**
- 难度：需要"卡上拖卡"的 UI 交互 + 临时合成卡的状态机
- 教育价值高（亲手做时态/构词），但 MVP 暂不做

### 高级 Challenge 类型

- `chain_response` 接龙
- `scenario_complete` 情景对话
- `rule_apply` / `modifier_stack` 配合 Phase 2 卡型

### 卡片合成 / 永久升级

- 重复卡 ×3 → 升一级
- 升级提升伤害 / 解锁附加效果

### 装备/遗物对卡片的修饰

- 装备词条："所有动词卡 +2 伤害" / "新卡奖励 ×2"
- 遗物："连击 5 时所有形容词暴击"

---

## MVP 范围

### 必做（Phase 1）

| 项 | 数量 / 详情 |
|------|------|
| Card 类 + JSON 加载 | 含 type / pos / tags / skill 4 维 |
| 起始卡池 | 20 张（覆盖 word / phrase / pattern / sound 4 种 type）|
| ChallengeTemplate | **5 种**：`fill_in_blank` + `error_correct` + `listening_fill` + `pronounce_attack` + `sentence_build` |
| Challenge 模板数据 | 15 个（覆盖 1F 三个子主题）|
| 敌人 | 3 种小怪 + 3 个 Boss（配 Run 三幕）|
| BattleController 重写 | 含拖卡/解算/连击/胜负 |
| BattleScene UI | 完整布局 + 拖拽 + 卡片熟练度标识 |
| ComboSystem 接入 | 5 连小招、10 连大招 |
| 反舒适区机制 | 熟练度衰减 + 新卡奖励 + 主题倾斜 + SRS 注入 + Boss 覆盖（三星挑战在外部 spec）|
| 英语 Spice | `VoiceScrollSpice` + `DictationSpice` |
| Spice Modal UI | 2 个 |
| Whisper API 集成 | 含离线占位 |

### 不做（推迟）

- `rule` / `modifier` 卡型（Phase 2 储备）
- `chain_response` / `scenario_complete` Challenge 类型
- 装备词条对卡片的修饰
- 卡片升级 / 卡片合成
- 三星挑战 UI（本 spec 仅声明接口，由后续 spec 落地）
- 多 Spice（仅 voice + dictation）

---

## 测试策略

### 单元测试（GUT）

- `Card.from_dict()` 数据加载边界
- `Validator.can_place()` 多组合（类型不匹配 / tags 包含与不包含）
- `DamageCalculator` 矩阵：含/不含弱点 × 连击 0/3/5/10 × 暴击/普通
- `ComboSystem` 增减边界
- `VoiceScrollSpice.evaluate()` 字符串相似度阈值
- `DictationSpice.evaluate()` 大小写 / 标点边界

### 集成测试

- 完整战斗：3 张卡通关一个简单 Challenge
- 失败路径：HP 归零退出
- Spice 触发：modal 开关 + buff 应用

### 手动测试（必须真机）

- 麦克风录音质量（Mac M 系列、iOS、Android）
- Whisper API 延迟 + 错误降级
- UI 拖拽手感（鼠标 / 触屏）

---

## 未决事项（依赖其他 spec）

这些**不在本 spec 内决定**，但会影响战斗实现细节：

1. **Run 结构 / 路径地图** — 战斗节点频次、难度曲线、奖励分布
2. **永久成长 / 知识城** — 起手卡池如何随永久升级扩展
3. **职业系统** — 不同职业的初始牌组差异
4. **Boss 多阶段模板** — 阶段切换的台词与 Spice 触发
5. **装备 / 遗物** — 战斗中的被动效果接入点
6. **卡片获取节奏** — 每场战后 3 选 1 的池子怎么生成
7. **学科切换** — 数学/科学包的 Card 与 ChallengeTemplate 形态

战斗 spec 留好接口（Card 数据驱动、ChallengeTemplate 可扩展、Spice 可注册），等其他 spec 确定后填入。

---

## 验收标准

- [ ] 玩家可在战斗中拖卡填空，正确卡造成伤害，错误卡退回。
- [ ] 连击 5/10 触发可见的小招/大招特效。
- [ ] 击败一个敌人 → 弹出 3 选 1 卡片奖励 → 加入牌组。
- [ ] 玩家 HP 归零 → 退出战斗，触发 Run 失败流程（暂占位，等 Run spec）。
- [ ] 至少一个 VoiceScrollSpice 道具可在战斗中点击 → 唤起麦克风 modal → Whisper 识别 → buff 应用。
- [ ] 单测覆盖核心解算逻辑 ≥80%。
- [ ] 战斗界面在 1280×720 / 1920×1080 / 移动竖屏均可用（核心元素不裁切）。
