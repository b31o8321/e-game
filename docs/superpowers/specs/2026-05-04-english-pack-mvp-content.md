# 英语包 MVP 内容设计 (0F / 1F / 2F)

> 状态：v1（详细到卡片/Challenge/敌人/Boss 数据）
> 上下文：本 spec 配合 narrative spec 使用，是英语包数据文件的内容指南。Phase 1 MVP 三层完整数据。

---

## MVP 总量

| 项 | 0F | 1F | 2F | 合计 |
|----|----|----|----|------|
| 卡片数 | 50 | 25 | 35 | 110 |
| Challenge 模板 | 10 | 12 | 12 | 34 |
| 普通敌人 | 2 | 3 | 3 | 8 |
| Boss | 3 | 3 | 3 | 9 |
| 楼层背景 | 2（明/暗）| 2 | 2 | 6 |

---

## 0F · 字母与拼读

### 单元设定
- **目标人群**：英语零基础（小学一二年级或刚开始学）
- **学习要点**：26 字母认识 / 自然拼读 / 高频词
- **推荐 Run 时长**：12 分钟
- **可跳过**：进游戏时有"我已经认识字母"选项

### 子主题与三幕

```
[0F 楼层简介]
词语之师："这一层是字母厅。曾经字母们排列整齐..."
词语之师："现在它们打散了。来帮我把它们找回来。"

ACT 1 · 字母认识（5 节点）
   └─ Boss A: 字母混乱者
ACT 2 · 自然拼读（5 节点）
   └─ Boss B: 发音之灵
ACT 3 · 高频词（6 节点）
   └─ Boss Final: 字母守关者
```

### 卡池（50 张）

#### 字母卡（26 张，type=word, pos=letter）
A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
- 每张：base_damage 4-6，rarity common
- tags: ["letter", "grade_3"]

#### 拼读音节卡（10 张，type=phrase, pos=syllable）
-at, -an, -in, -ig, -un, -et, -op, -ut, -ed, -ay
- 每张：base_damage 6-8，rarity common
- tags: ["phonics", "grade_3"]

#### 高频词卡（14 张，type=word, pos=sight_word）
a, the, I, am, is, are, you, he, she, it, this, that, my, no
- 每张：base_damage 5-7，rarity common
- tags: ["sight_word", "grade_3"]

### Challenge 模板（10 个）

```jsonc
[
  {
    "template_id": "0F_alphabet_next",
    "kind": "fill_in_blank",
    "dialogue": "A, B, C, ___, E",
    "topic_id": "0F_alphabet",
    "slots": [{"required_type": "word", "required_pos": "letter"}],
    "perfect_match_card_ids": ["card_letter_d"]
  },
  {
    "template_id": "0F_phonics_cat",
    "kind": "listening_fill",
    "dialogue": "🔊 Listen: cat",
    "audio_path": "res://content/english/audio/words/cat.ogg",
    "topic_id": "0F_phonics",
    "slots": [
      {"required_type": "word", "required_pos": "letter"},
      {"required_type": "phrase", "required_pos": "syllable"}
    ],
    "perfect_match_card_ids": ["card_letter_c", "card_syllable_at"]
  },
  {
    "template_id": "0F_sight_iam",
    "kind": "fill_in_blank",
    "dialogue": "I ___ a boy.",
    "topic_id": "0F_sight_words",
    "slots": [{"required_type": "word", "required_pos": "sight_word", "required_tags": ["be_verb"]}],
    "perfect_match_card_ids": ["card_word_am"]
  }
  // ... 7 more
]
```

### 敌人

| ID | 名字 | HP | 攻击 | 弱点 |
|----|-----|----|----|------|
| `letter_wisp` | 字母游魂 | 30 | 5 | letter |
| `phonics_phantom` | 音节幻影 | 40 | 7 | syllable |

### Bosses

| ID | 名字 | HP | 阶段 | 弱点 | 战利品 |
|----|------|----|----|------|-------|
| `letter_chaos` | 字母混乱者 | 60 | 1 | letter | 词晶 +30 / 1 蓝图碎片 |
| `phonics_spirit` | 发音之灵 | 70 | 1 | syllable | 词晶 +30 / 1 蓝图碎片 |
| `letter_warden` | 字母守关者 | 120 | 2 | mixed | 词晶 +50 / 3 蓝图碎片 / 装备「初学者徽章」|

---

## 1F · 形容词初阶

### 单元设定
- **目标年级**：3 年级（小学英语起步）
- **学习要点**：基础形容词 / 系动词 / 形容词在句中位置
- **推荐 Run 时长**：18 分钟

### 子主题与三幕

```
[1F 楼层简介]
词语之师："1F 是图书馆。曾经，它陈列着世界上所有美好的形容词。"
词语之师："去唤醒他们吧。"

ACT 1 · 情绪形容词（6 节点）
   └─ Boss A: 迷雾低吟者
ACT 2 · 性格形容词（7 节点）
   └─ Boss B: 静默叹息者
ACT 3 · 形容词语法（8 节点）
   └─ Boss Final: 图书管理员（双阶段）
```

### 卡池（25 张）

#### 形容词词卡（15 张，type=word, pos=adjective）

情绪类（5）：happy, sad, angry, tired, excited
性格类（5）：brave, kind, lazy, smart, quiet
描述类（5）：big, small, beautiful, strong, fast

每张：
- base_damage 8-10
- rarity 1× rare（excited/beautiful），其余 common
- tags 例：`["adjective", "emotion", "positive", "grade_3"]`

#### 系动词卡（4 张，type=word, pos=verb_be）
am, is, are, was

每张：base_damage 5，common
tags: `["be_verb", "grade_3"]`

#### 句型卡（3 张，type=pattern）
- "I am ___" → 槽位要 adjective
- "He is ___" → 同
- "It is ___" → 同

每张：base_damage 10，rare
tags: `["sentence_pattern", "grade_3"]`

#### 修饰副词卡（3 张，type=word, pos=adverb）
very, so, too

每张：base_damage 4，common
tags: `["intensifier", "grade_3"]`

### Challenge 模板（12 个）

```jsonc
[
  {
    "template_id": "1F_emotion_blank",
    "kind": "fill_in_blank",
    "dialogue": "I am very ___",
    "topic_id": "1F_emotion",
    "slots": [{
      "required_type": "word",
      "required_pos": "adjective",
      "required_tags": ["emotion"]
    }],
    "perfect_match_card_ids": ["card_happy", "card_sad", "card_angry"]
  },
  {
    "template_id": "1F_personality_blank",
    "kind": "fill_in_blank",
    "dialogue": "She is so ___",
    "topic_id": "1F_personality",
    "slots": [{
      "required_type": "word",
      "required_pos": "adjective",
      "required_tags": ["personality"]
    }]
  },
  {
    "template_id": "1F_be_correct",
    "kind": "error_correct",
    "dialogue": "He [are] happy.",
    "topic_id": "1F_grammar",
    "slots": [{"required_type": "word", "required_pos": "verb_be", "forbidden_tags": ["plural_subject"]}],
    "perfect_match_card_ids": ["card_word_is"]
  }
  // ... 9 more
]
```

### 敌人

| ID | 名字 | HP | 攻击 | 弱点 |
|----|-----|----|----|------|
| `library_dust` | 书页尘灵 | 35 | 6 | emotion |
| `wandering_word` | 游荡词魂 | 50 | 8 | personality |
| `bookworm` | 书虫 | 60 | 10 | grammar |

### Bosses

| ID | 名字 | HP | 阶段 | 弱点 | 战利品 |
|----|------|----|----|------|-------|
| `fog_whisperer` | 迷雾低吟者 | 80 | 1 | emotion | 词晶 +40 / 1 碎片 |
| `silent_sigher` | 静默叹息者 | 90 | 1 | personality | 词晶 +40 / 1 碎片 |
| `librarian` | 图书管理员 | 180 | 2 | mixed_adjective | 词晶 +80 / 3 碎片 / 「沉默之书」|

---

## 2F · 名词与代词

### 单元设定
- **目标年级**：3 年级下 / 4 年级
- **学习要点**：家庭/身体名词 / 人称代词 / 指示代词

### 子主题与三幕

```
[2F 楼层简介]
词语之师："2F 是家庭与身体之厅。"
词语之师："这里的名词们在混乱中失去了归属。"

ACT 1 · 家庭称谓（6 节点）
   └─ Boss A: 家族散乱者
ACT 2 · 身体物品（7 节点）
   └─ Boss B: 形体迷失者
ACT 3 · 代词运用（8 节点）
   └─ Boss Final: 家庭守护者
```

### 卡池（35 张）

#### 家庭名词（10）
mother, father, sister, brother, grandma, grandpa, son, daughter, family, baby
- type=word, pos=noun
- tags: `["family", "grade_3"]`
- base_damage 8-10

#### 身体名词（10）
head, hand, eye, foot, hair, ear, nose, mouth, arm, leg
- type=word, pos=noun
- tags: `["body", "grade_3"]`
- base_damage 7-9

#### 物品名词（5）
book, pen, bag, desk, chair
- type=word, pos=noun
- tags: `["object", "school", "grade_3"]`
- base_damage 6-8

#### 人称代词（8）
I, you, he, she, it, we, they, me
- type=word, pos=pronoun
- tags: `["pronoun", "grade_4"]`
- base_damage 6-8

#### 指示代词 + 句型（2）
- 卡片：this, that
- 句型卡：[This is ___], [That is ___]
- type=word/pattern
- base_damage 7-9

### Challenge 模板（12 个）

```jsonc
[
  {
    "template_id": "2F_family_blank",
    "kind": "fill_in_blank",
    "dialogue": "My ___ is kind.",
    "topic_id": "2F_family",
    "slots": [{"required_type": "word", "required_pos": "noun", "required_tags": ["family"]}]
  },
  {
    "template_id": "2F_body_blank",
    "kind": "fill_in_blank",
    "dialogue": "I have two ___.",
    "topic_id": "2F_body",
    "slots": [{"required_type": "word", "required_pos": "noun", "required_tags": ["body"]}]
  },
  {
    "template_id": "2F_pronoun_correct",
    "kind": "error_correct",
    "dialogue": "[Him] is my brother.",
    "topic_id": "2F_pronoun",
    "slots": [{"required_type": "word", "required_pos": "pronoun", "required_tags": ["subject_form"]}],
    "perfect_match_card_ids": ["card_pronoun_he"]
  },
  {
    "template_id": "2F_this_that",
    "kind": "fill_in_blank",
    "dialogue": "___ is my book.",
    "topic_id": "2F_demonstrative",
    "slots": [{"required_type": "word", "required_pos": "pronoun", "required_tags": ["demonstrative"]}]
  }
  // ... 8 more
]
```

### 敌人

| ID | 名字 | HP | 攻击 | 弱点 |
|----|-----|----|----|------|
| `home_haunter` | 家屋萦绕者 | 45 | 7 | family |
| `body_blur` | 形影模糊 | 55 | 9 | body |
| `pronoun_pest` | 代词捣蛋鬼 | 70 | 11 | pronoun |

### Bosses

| ID | 名字 | HP | 阶段 | 弱点 | 战利品 |
|----|------|----|----|------|-------|
| `family_scatter` | 家族散乱者 | 90 | 1 | family | 词晶 +50 / 1 碎片 |
| `body_lost` | 形体迷失者 | 100 | 1 | body | 词晶 +50 / 1 碎片 |
| `family_guardian` | 家庭守护者 | 200 | 2 | mixed | 词晶 +100 / 3 碎片 / 「血缘之环」|

---

## Spice 整合（MVP）

### VoiceScrollSpice 道具

3 张卷轴（Boss 战利品池）：
- 「战吼卷轴」: 喊 "I'm strong" → ATK +30% / 3 回合（0F-A 掉）
- 「勇气咒」: 喊 "I'm brave" → 反伤 25（1F-A 掉）
- 「家人守护」: 喊 "My family" → 回 30 HP（2F-A 掉）

### DictationSpice 道具

2 张：
- 「听写之刃」: 听音写词 → 对应词卡造成暴击（每楼层一种）
- 「记忆之钟」: 听音写词 → 抽 2 张卡

---

## 装备（MVP，最小）

| ID | 名字 | 来源 | 词条 |
|----|------|-----|------|
| `equip_starter_badge` | 初学者徽章 | 0F Final 必掉 | 起手 HP +10 |
| `equip_silent_book` | 沉默之书 | 1F Final 必掉 | 形容词卡伤害 +3 |
| `equip_blood_ring` | 血缘之环 | 2F Final 必掉 | 名词/代词卡伤害 +3 |
| `equip_wood_sword` | 木剑 | 起手 | 普通伤害 +2 |

---

## 数据文件结构

```
src/content/english/data/
├─ pack_meta.json
├─ cards.json                  # 110 张卡片合集
├─ challenges.json             # 34 个 Challenge 模板
├─ enemies.json                # 8 普通敌人
├─ bosses.json                 # 9 Boss 元数据
├─ floors.json                 # 0F/1F/2F 楼层配置
├─ equipment.json              # 4 件装备
├─ spices.json                 # 5 个 Spice 道具
└─ lore/                       # 剧情面板（narrative spec 中详细）
    ├─ intro.json
    ├─ floor_intros/...
    ├─ boss_dialogues/...
    └─ ...
```

---

## floors.json 结构示例

```jsonc
[
  {
    "floor_id": "1F",
    "unit_name": "形容词初阶",
    "recommended_run_minutes": 18,
    "unlock_after": "0F",
    "background_path": "res://content/english/assets/floors/1f_library.png",
    "background_dim_path": "res://content/english/assets/floors/1f_library_dim.png",
    "bgm_path": "res://content/english/audio/bgm/1f_library.ogg",
    "acts": [
      {
        "act_index": 1,
        "sub_topic_id": "1F_emotion",
        "node_count": 6,
        "node_distribution": {"battle": 3, "elite": 1, "shop": 1, "puzzle": 1},
        "boss_id": "fog_whisperer",
        "review_card_ids": ["card_happy", "card_sad", "card_angry"]
      },
      {
        "act_index": 2,
        "sub_topic_id": "1F_personality",
        "node_count": 7,
        "node_distribution": {"battle": 3, "elite": 1, "shop": 1, "rest": 1, "mystery": 1},
        "boss_id": "silent_sigher",
        "review_card_ids": ["card_brave", "card_kind", "card_lazy"]
      },
      {
        "act_index": 3,
        "sub_topic_id": "1F_grammar",
        "node_count": 8,
        "node_distribution": {"battle": 4, "elite": 1, "shop": 1, "rest": 1, "puzzle": 1},
        "boss_id": "librarian",
        "review_card_ids": []
      }
    ]
  }
]
```

---

## MVP 起手卡组（玩家初次启动）

12 张：
- 5 张基础形容词：happy, brave, big, kind, smart
- 3 张系动词：am, is, are
- 2 张代词：I, you
- 1 张句型：[I am ___]
- 1 张高频词：a

→ 通过 0F 教程 → 解锁更多卡 → 进 1F → 战利品扩展

---

## 验收标准

- [ ] 110 张卡片完整加载，所有 type/pos/tags 字段合法
- [ ] 34 个 Challenge 模板加载，所有 slot 引用的 card_id 存在
- [ ] 9 个 Boss 加载，HP/阶段/弱点完整
- [ ] 8 个普通敌人加载
- [ ] 0F-2F 的 floors.json 配置完整
- [ ] 5 件 Spice 道具可用
- [ ] 4 件装备可掉落和装备
- [ ] `validate()` 检查通过
- [ ] 单测覆盖卡片/Challenge/敌人 JSON 加载 ≥80%

---

## Phase 2 / 3 内容

不在 MVP 范围，但记一笔确保架构兼容：

**Phase 2**：3F-5F（一般现在时 / 一般过去时 / 现在进行时）
**Phase 3**：6F-10F（比较级 / 将来时 / 疑问句 / 阅读 / 期末）

每楼层添加 = 加 cards.json 行 + 加 challenges.json 行 + 加 enemies.json 行 + 加 bosses.json 行 + 在 floors.json 加楼层 + 在 lore/ 加面板。**架构零改动**。
