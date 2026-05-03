# Phase 6 — 英语内容包 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现可试玩的真实英语内容包（小学4-6年级），含80道题目、年级设置界面、遗忘图书馆大关配置，替换 MockContentPack 后全流程可试玩。

**Architecture:** JSON 数据文件 + `EnglishContentPack extends ContentPackBase` 运行时加载；`GameState.player_grade` 字段控制题目难度池（grade ≤ player_grade）；年级可在设置界面随时更改并存档。

**Tech Stack:** Godot 4 · GDScript · GUT · JSON（FileAccess 加载）

---

## 文件结构

| 路径 | 动作 | 职责 |
|------|------|------|
| `src/core/autoloads/game_state.gd` | 修改 | 新增 `player_grade` 字段 + 注册 EnglishContentPack |
| `src/core/systems/save_system.gd` | 修改 | 存读 `player_grade` |
| `src/content/english/data/questions.json` | 新建 | 80道题目 |
| `src/content/english/data/gates.json` | 新建 | 遗忘图书馆大关配置 |
| `src/content/english/english_content_pack.gd` | 新建 | ContentPackBase 实现 |
| `tests/test_english_content_pack.gd` | 新建 | 6条 GUT 测试 |
| `src/ui/settings_scene.gd` | 新建 | 年级选择控制器 |
| `src/ui/settings_scene.tscn` | 新建 | 设置场景 |
| `src/ui/main_menu.gd` | 修改 | 新增设置按钮；gate_button → 探索场景 |
| `src/ui/main_menu.tscn` | 修改 | 新增 SettingsButton 节点 |

---

## Task 1: GameState.player_grade + SaveSystem

**Files:**
- Modify: `src/core/autoloads/game_state.gd`
- Modify: `src/core/systems/save_system.gd`

- [ ] **Step 1: 读取 game_state.gd 当前内容**

读取 `src/core/autoloads/game_state.gd`，确认现有字段位置。

- [ ] **Step 2: 在 game_state.gd 添加 player_grade 字段**

在 `# 玩家核心状态` 区块（`player_hp` 那一组字段）末尾追加：

```gdscript
var player_grade: int = 5       # 4 | 5 | 6，影响题目难度池
```

- [ ] **Step 3: 读取 save_system.gd 当前内容**

读取 `src/core/systems/save_system.gd`，确认 `save_game_state()` 和 `load_game_state()` 的结构。

- [ ] **Step 4: 在 save_game_state() 写入 player_grade**

在 `save_game_state()` 的 data 字典中追加：

```gdscript
		"player_grade": GameState.player_grade,
```

完整修改后的 `save_game_state()` 方法：

```gdscript
func save_game_state() -> void:
	var data: Dictionary = {
		"player_hp": GameState.player_hp,
		"player_max_hp": GameState.player_max_hp,
		"knowledge_level": GameState.knowledge_level,
		"unlocked_knowledge_ids": GameState.unlocked_knowledge_ids,
		"completed_gate_ids": GameState.completed_gate_ids,
		"city_building_levels": GameState.city_building_levels,
		"inventory_resources": GameState.inventory_resources,
		"equipment_slots": GameState.equipment_slots,
		"player_grade": GameState.player_grade,
		"saved_at": Time.get_unix_time_from_system()
	}
	save(data)
```

- [ ] **Step 5: 在 load_game_state() 读取 player_grade**

在 `load_game_state()` 末尾追加：

```gdscript
	GameState.player_grade = data.get("player_grade", 5)
```

- [ ] **Step 6: 提交**

```bash
git add src/core/autoloads/game_state.gd src/core/systems/save_system.gd
git commit -m "feat: add player_grade field to GameState and SaveSystem"
```

---

## Task 2: JSON 数据文件

**Files:**
- Create: `src/content/english/data/questions.json`
- Create: `src/content/english/data/gates.json`

注意：`src/content/english/data/` 目录不存在，写文件时会自动创建。

- [ ] **Step 1: 创建 questions.json**

新建 `src/content/english/data/questions.json`，写入以下完整内容（80道题）：

```json
{
  "questions": [
    { "id": "q_vocab_001", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'brave' mean?", "options": ["勇敢的", "聪明的", "安静的", "友善的"], "correct_index": 0, "explanation": "brave [breɪv] · 形容词 · 勇敢的\n例句：The brave knight saved the village.", "audio_text": "brave" },
    { "id": "q_vocab_002", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'kind' mean?", "options": ["快速的", "善良的", "嘈杂的", "懒惰的"], "correct_index": 1, "explanation": "kind [kaɪnd] · 形容词 · 善良的\n例句：She is very kind to animals.", "audio_text": "kind" },
    { "id": "q_vocab_003", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'fast' mean?", "options": ["慢的", "强壮的", "快速的", "安静的"], "correct_index": 2, "explanation": "fast [fæst] · 形容词 · 快速的\n例句：The cheetah is a fast animal.", "audio_text": "fast" },
    { "id": "q_vocab_004", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'quiet' mean?", "options": ["忙碌的", "嘈杂的", "疲惫的", "安静的"], "correct_index": 3, "explanation": "quiet [ˈkwaɪət] · 形容词 · 安静的\n例句：Please be quiet in the library.", "audio_text": "quiet" },
    { "id": "q_vocab_005", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'strong' mean?", "options": ["强壮的", "柔软的", "小的", "轻的"], "correct_index": 0, "explanation": "strong [strɒŋ] · 形容词 · 强壮的\n例句：He is strong enough to lift the box.", "audio_text": "strong" },
    { "id": "q_vocab_006", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'happy' mean?", "options": ["悲伤的", "生气的", "快乐的", "害怕的"], "correct_index": 2, "explanation": "happy [ˈhæpi] · 形容词 · 快乐的\n例句：She felt happy when she got the gift.", "audio_text": "happy" },
    { "id": "q_vocab_007", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'hungry' mean?", "options": ["口渴的", "饥饿的", "疲倦的", "寒冷的"], "correct_index": 1, "explanation": "hungry [ˈhʌŋɡri] · 形容词 · 饥饿的\n例句：I am hungry. Let's eat lunch.", "audio_text": "hungry" },
    { "id": "q_vocab_008", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'tired' mean?", "options": ["精力充沛的", "高兴的", "疲惫的", "好奇的"], "correct_index": 2, "explanation": "tired [ˈtaɪəd] · 形容词 · 疲惫的\n例句：After the long walk, she felt very tired.", "audio_text": "tired" },
    { "id": "q_vocab_009", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'beautiful' mean?", "options": ["丑陋的", "美丽的", "普通的", "古老的"], "correct_index": 1, "explanation": "beautiful [ˈbjuːtɪfl] · 形容词 · 美丽的\n例句：What a beautiful sunset!", "audio_text": "beautiful" },
    { "id": "q_vocab_010", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'clean' mean?", "options": ["肮脏的", "湿的", "干净的", "破旧的"], "correct_index": 2, "explanation": "clean [kliːn] · 形容词 · 干净的\n例句：Keep your room clean and tidy.", "audio_text": "clean" },
    { "id": "q_vocab_011", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'careful' mean?", "options": ["粗心的", "小心的", "勇敢的", "懒惰的"], "correct_index": 1, "explanation": "careful [ˈkeəfl] · 形容词 · 小心的\n例句：Be careful when you cross the road.", "audio_text": "careful" },
    { "id": "q_vocab_012", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'friendly' mean?", "options": ["陌生的", "粗鲁的", "友好的", "害羞的"], "correct_index": 2, "explanation": "friendly [ˈfrendli] · 形容词 · 友好的\n例句：My new classmates are very friendly.", "audio_text": "friendly" },
    { "id": "q_vocab_013", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'funny' mean?", "options": ["无聊的", "悲伤的", "有趣的", "严肃的"], "correct_index": 2, "explanation": "funny [ˈfʌni] · 形容词 · 有趣的/好笑的\n例句：He told a very funny joke.", "audio_text": "funny" },
    { "id": "q_vocab_014", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'lazy' mean?", "options": ["勤劳的", "懒惰的", "活泼的", "温柔的"], "correct_index": 1, "explanation": "lazy [ˈleɪzi] · 形容词 · 懒惰的\n例句：Don't be lazy. Finish your homework!", "audio_text": "lazy" },
    { "id": "q_vocab_015", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'noisy' mean?", "options": ["安静的", "平和的", "嘈杂的", "轻柔的"], "correct_index": 2, "explanation": "noisy [ˈnɔɪzi] · 形容词 · 嘈杂的\n例句：The street was very noisy during the parade.", "audio_text": "noisy" },
    { "id": "q_vocab_016", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'polite' mean?", "options": ["粗鲁的", "礼貌的", "害羞的", "自私的"], "correct_index": 1, "explanation": "polite [pəˈlaɪt] · 形容词 · 礼貌的\n例句：It is polite to say 'thank you'.", "audio_text": "polite" },
    { "id": "q_vocab_017", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'angry' mean?", "options": ["快乐的", "担心的", "生气的", "惊讶的"], "correct_index": 2, "explanation": "angry [ˈæŋɡri] · 形容词 · 生气的\n例句：He was angry when he lost his keys.", "audio_text": "angry" },
    { "id": "q_vocab_018", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'busy' mean?", "options": ["空闲的", "忙碌的", "无聊的", "懒散的"], "correct_index": 1, "explanation": "busy [ˈbɪzi] · 形容词 · 忙碌的\n例句：Mom is busy cooking dinner.", "audio_text": "busy" },
    { "id": "q_vocab_019", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'lucky' mean?", "options": ["倒霉的", "努力的", "幸运的", "勇敢的"], "correct_index": 2, "explanation": "lucky [ˈlʌki] · 形容词 · 幸运的\n例句：I was lucky to find my lost cat.", "audio_text": "lucky" },
    { "id": "q_vocab_020", "attack_type_id": "vocabulary", "grade": 4, "question": "What does 'smart' mean?", "options": ["愚蠢的", "聪明的", "懒惰的", "粗心的"], "correct_index": 1, "explanation": "smart [smɑːt] · 形容词 · 聪明的\n例句：She is a smart student who always gets good grades.", "audio_text": "smart" },

    { "id": "q_vocab_021", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'curious' mean?", "options": ["无聊的", "害怕的", "好奇的", "满足的"], "correct_index": 2, "explanation": "curious [ˈkjʊəriəs] · 形容词 · 好奇的\n例句：The curious cat looked into every corner.", "audio_text": "curious" },
    { "id": "q_vocab_022", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'patient' mean?", "options": ["急躁的", "耐心的", "好奇的", "粗鲁的"], "correct_index": 1, "explanation": "patient [ˈpeɪʃnt] · 形容词 · 耐心的\n例句：A good teacher is patient with students.", "audio_text": "patient" },
    { "id": "q_vocab_023", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'enormous' mean?", "options": ["微小的", "巨大的", "普通的", "轻薄的"], "correct_index": 1, "explanation": "enormous [ɪˈnɔːməs] · 形容词 · 巨大的\n例句：The elephant is an enormous animal.", "audio_text": "enormous" },
    { "id": "q_vocab_024", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'ancient' mean?", "options": ["现代的", "未来的", "古老的", "崭新的"], "correct_index": 2, "explanation": "ancient [ˈeɪnʃənt] · 形容词 · 古老的\n例句：The ancient temple was built 2000 years ago.", "audio_text": "ancient" },
    { "id": "q_vocab_025", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'mysterious' mean?", "options": ["明显的", "神秘的", "普通的", "简单的"], "correct_index": 1, "explanation": "mysterious [mɪˈstɪəriəs] · 形容词 · 神秘的\n例句：There was a mysterious noise in the night.", "audio_text": "mysterious" },
    { "id": "q_vocab_026", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'delicious' mean?", "options": ["难吃的", "普通的", "美味的", "苦涩的"], "correct_index": 2, "explanation": "delicious [dɪˈlɪʃəs] · 形容词 · 美味的\n例句：The pizza smells delicious.", "audio_text": "delicious" },
    { "id": "q_vocab_027", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'excellent' mean?", "options": ["普通的", "差劲的", "一般的", "优秀的"], "correct_index": 3, "explanation": "excellent [ˈeksələnt] · 形容词 · 优秀的\n例句：She got an excellent score on the exam.", "audio_text": "excellent" },
    { "id": "q_vocab_028", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'famous' mean?", "options": ["无名的", "著名的", "普通的", "神秘的"], "correct_index": 1, "explanation": "famous [ˈfeɪməs] · 形容词 · 著名的\n例句：The Great Wall is a famous landmark.", "audio_text": "famous" },
    { "id": "q_vocab_029", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'frightened' mean?", "options": ["勇敢的", "兴奋的", "害怕的", "快乐的"], "correct_index": 2, "explanation": "frightened [ˈfraɪtnd] · 形容词 · 害怕的\n例句：The child was frightened by the loud thunder.", "audio_text": "frightened" },
    { "id": "q_vocab_030", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'generous' mean?", "options": ["自私的", "吝啬的", "慷慨的", "贪婪的"], "correct_index": 2, "explanation": "generous [ˈdʒenərəs] · 形容词 · 慷慨的\n例句：She was generous enough to share her food.", "audio_text": "generous" },
    { "id": "q_vocab_031", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'grateful' mean?", "options": ["抱怨的", "感激的", "冷漠的", "嫉妒的"], "correct_index": 1, "explanation": "grateful [ˈɡreɪtfl] · 形容词 · 感激的\n例句：I am grateful for your help.", "audio_text": "grateful" },
    { "id": "q_vocab_032", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'helpful' mean?", "options": ["有害的", "无用的", "乐于助人的", "自私的"], "correct_index": 2, "explanation": "helpful [ˈhelpfl] · 形容词 · 乐于助人的\n例句：My classmates are very helpful.", "audio_text": "helpful" },
    { "id": "q_vocab_033", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'independent' mean?", "options": ["依赖的", "独立的", "合作的", "孤独的"], "correct_index": 1, "explanation": "independent [ˌɪndɪˈpendənt] · 形容词 · 独立的\n例句：She is independent and can solve problems on her own.", "audio_text": "independent" },
    { "id": "q_vocab_034", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'nervous' mean?", "options": ["放松的", "平静的", "紧张的", "快乐的"], "correct_index": 2, "explanation": "nervous [ˈnɜːvəs] · 形容词 · 紧张的\n例句：She felt nervous before the speech.", "audio_text": "nervous" },
    { "id": "q_vocab_035", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'ordinary' mean?", "options": ["特别的", "普通的", "神奇的", "罕见的"], "correct_index": 1, "explanation": "ordinary [ˈɔːdɪnri] · 形容词 · 普通的\n例句：It was just an ordinary day at school.", "audio_text": "ordinary" },
    { "id": "q_vocab_036", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'precious' mean?", "options": ["廉价的", "普通的", "珍贵的", "沉重的"], "correct_index": 2, "explanation": "precious [ˈpreʃəs] · 形容词 · 珍贵的\n例句：Time is precious. Don't waste it.", "audio_text": "precious" },
    { "id": "q_vocab_037", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'serious' mean?", "options": ["轻松的", "严肃的", "幽默的", "随意的"], "correct_index": 1, "explanation": "serious [ˈsɪəriəs] · 形容词 · 严肃的\n例句：This is a serious matter.", "audio_text": "serious" },
    { "id": "q_vocab_038", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'unusual' mean?", "options": ["常见的", "普通的", "不寻常的", "传统的"], "correct_index": 2, "explanation": "unusual [ʌnˈjuːʒuəl] · 形容词 · 不寻常的\n例句：It was unusual to see snow in April.", "audio_text": "unusual" },
    { "id": "q_vocab_039", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'wonderful' mean?", "options": ["糟糕的", "普通的", "精彩的", "无聊的"], "correct_index": 2, "explanation": "wonderful [ˈwʌndəfl] · 形容词 · 精彩的/极好的\n例句：We had a wonderful time at the beach.", "audio_text": "wonderful" },
    { "id": "q_vocab_040", "attack_type_id": "vocabulary", "grade": 5, "question": "What does 'adventurous' mean?", "options": ["胆小的", "保守的", "爱冒险的", "谨慎的"], "correct_index": 2, "explanation": "adventurous [ədˈventʃərəs] · 形容词 · 爱冒险的\n例句：She is adventurous and loves to explore new places.", "audio_text": "adventurous" },

    { "id": "q_vocab_041", "attack_type_id": "vocabulary", "grade": 6, "question": "What does 'determined' mean?", "options": ["犹豫的", "坚定的", "动摇的", "懒散的"], "correct_index": 1, "explanation": "determined [dɪˈtɜːmɪnd] · 形容词 · 坚定的\n例句：She was determined to finish the race.", "audio_text": "determined" },
    { "id": "q_vocab_042", "attack_type_id": "vocabulary", "grade": 6, "question": "What does 'genuine' mean?", "options": ["虚假的", "表面的", "真诚的", "造作的"], "correct_index": 2, "explanation": "genuine [ˈdʒenjuɪn] · 形容词 · 真诚的/真实的\n例句：Her smile was genuine and warm.", "audio_text": "genuine" },
    { "id": "q_vocab_043", "attack_type_id": "vocabulary", "grade": 6, "question": "What does 'mischievous' mean?", "options": ["乖巧的", "害羞的", "淘气的", "严肃的"], "correct_index": 2, "explanation": "mischievous [ˈmɪstʃɪvəs] · 形容词 · 淘气的\n例句：The mischievous boy hid his sister's toy.", "audio_text": "mischievous" },
    { "id": "q_vocab_044", "attack_type_id": "vocabulary", "grade": 6, "question": "What does 'compassionate' mean?", "options": ["冷漠的", "富有同情心的", "自私的", "严厉的"], "correct_index": 1, "explanation": "compassionate [kəmˈpæʃənət] · 形容词 · 富有同情心的\n例句：The compassionate nurse cared for the patients.", "audio_text": "compassionate" },
    { "id": "q_vocab_045", "attack_type_id": "vocabulary", "grade": 6, "question": "What does 'ambitious' mean?", "options": ["满足的", "懒惰的", "雄心勃勃的", "保守的"], "correct_index": 2, "explanation": "ambitious [æmˈbɪʃəs] · 形容词 · 雄心勃勃的\n例句：He is ambitious and wants to become a scientist.", "audio_text": "ambitious" },
    { "id": "q_vocab_046", "attack_type_id": "vocabulary", "grade": 6, "question": "What does 'persistent' mean?", "options": ["轻易放弃的", "随意的", "坚持不懈的", "犹豫的"], "correct_index": 2, "explanation": "persistent [pəˈsɪstənt] · 形容词 · 坚持不懈的\n例句：She was persistent in learning English.", "audio_text": "persistent" },
    { "id": "q_vocab_047", "attack_type_id": "vocabulary", "grade": 6, "question": "What does 'tremendous' mean?", "options": ["微小的", "一般的", "巨大的/惊人的", "细微的"], "correct_index": 2, "explanation": "tremendous [trɪˈmendəs] · 形容词 · 巨大的/惊人的\n例句：She made a tremendous effort to win.", "audio_text": "tremendous" },
    { "id": "q_vocab_048", "attack_type_id": "vocabulary", "grade": 6, "question": "What does 'vulnerable' mean?", "options": ["坚强的", "安全的", "脆弱的", "强大的"], "correct_index": 2, "explanation": "vulnerable [ˈvʌlnərəbl] · 形容词 · 脆弱的\n例句：Young children are vulnerable to illness.", "audio_text": "vulnerable" },
    { "id": "q_vocab_049", "attack_type_id": "vocabulary", "grade": 6, "question": "What does 'enthusiastic' mean?", "options": ["冷淡的", "勉强的", "热情洋溢的", "懒散的"], "correct_index": 2, "explanation": "enthusiastic [ɪnˌθjuːziˈæstɪk] · 形容词 · 热情洋溢的\n例句：She is enthusiastic about learning new things.", "audio_text": "enthusiastic" },
    { "id": "q_vocab_050", "attack_type_id": "vocabulary", "grade": 6, "question": "What does 'sophisticated' mean?", "options": ["简单的", "幼稚的", "精致的/复杂的", "粗糙的"], "correct_index": 2, "explanation": "sophisticated [səˈfɪstɪkeɪtɪd] · 形容词 · 精致的/复杂的\n例句：The design is sophisticated and elegant.", "audio_text": "sophisticated" },

    { "id": "q_grammar_001", "attack_type_id": "grammar", "grade": 4, "question": "She ___ a student.", "options": ["is", "am", "are", "was"], "correct_index": 0, "explanation": "第三人称单数主语（she/he/it）搭配 is。\nShe is a student. 她是一名学生。", "audio_text": "She is a student" },
    { "id": "q_grammar_002", "attack_type_id": "grammar", "grade": 4, "question": "There ___ a book on the table.", "options": ["is", "are", "am", "be"], "correct_index": 0, "explanation": "There is + 单数名词。There is a book = 桌上有一本书。", "audio_text": "There is a book on the table" },
    { "id": "q_grammar_003", "attack_type_id": "grammar", "grade": 4, "question": "We ___ happy today.", "options": ["is", "am", "are", "were"], "correct_index": 2, "explanation": "复数主语（we/you/they）搭配 are。We are happy. 我们今天很开心。", "audio_text": "We are happy today" },
    { "id": "q_grammar_004", "attack_type_id": "grammar", "grade": 4, "question": "I ___ eight years old.", "options": ["is", "am", "are", "be"], "correct_index": 1, "explanation": "第一人称单数 I 搭配 am。I am eight years old. 我八岁。", "audio_text": "I am eight years old" },
    { "id": "q_grammar_005", "attack_type_id": "grammar", "grade": 4, "question": "There ___ three cats in the garden.", "options": ["is", "are", "am", "was"], "correct_index": 1, "explanation": "There are + 复数名词。three cats 是复数，用 are。", "audio_text": "There are three cats in the garden" },
    { "id": "q_grammar_006", "attack_type_id": "grammar", "grade": 4, "question": "He ___ to school every day.", "options": ["go", "goes", "going", "gone"], "correct_index": 1, "explanation": "第三人称单数主语（he）在一般现在时中，动词加 -s/es。go → goes。", "audio_text": "He goes to school every day" },
    { "id": "q_grammar_007", "attack_type_id": "grammar", "grade": 4, "question": "They ___ lunch at noon.", "options": ["eat", "eats", "eating", "ate"], "correct_index": 0, "explanation": "复数主语 they 在一般现在时中，动词不加 -s。They eat lunch. 他们中午吃午饭。", "audio_text": "They eat lunch at noon" },
    { "id": "q_grammar_008", "attack_type_id": "grammar", "grade": 4, "question": "The dog ___ very fast.", "options": ["run", "runs", "running", "ran"], "correct_index": 1, "explanation": "第三人称单数主语（the dog）在一般现在时中，run → runs。", "audio_text": "The dog runs very fast" },
    { "id": "q_grammar_009", "attack_type_id": "grammar", "grade": 4, "question": "___ there a library near your home?", "options": ["Is", "Are", "Am", "Do"], "correct_index": 0, "explanation": "There is 的疑问形式：Is there a...? (单数名词用 Is)", "audio_text": "Is there a library near your home" },
    { "id": "q_grammar_010", "attack_type_id": "grammar", "grade": 4, "question": "My sister and I ___ best friends.", "options": ["is", "am", "are", "was"], "correct_index": 2, "explanation": "My sister and I = 两个人，是复数主语，用 are。", "audio_text": "My sister and I are best friends" },

    { "id": "q_grammar_011", "attack_type_id": "grammar", "grade": 5, "question": "She ___ a book yesterday.", "options": ["read", "reads", "reading", "readed"], "correct_index": 0, "explanation": "read 的过去式仍是 read（不规则动词，发音变化 [red]）。yesterday 表明是过去时。", "audio_text": "She read a book yesterday" },
    { "id": "q_grammar_012", "attack_type_id": "grammar", "grade": 5, "question": "We ___ to the park last weekend.", "options": ["go", "goes", "went", "gone"], "correct_index": 2, "explanation": "go 的过去式是 went（不规则动词）。last weekend 表明是一般过去时。", "audio_text": "We went to the park last weekend" },
    { "id": "q_grammar_013", "attack_type_id": "grammar", "grade": 5, "question": "An elephant is ___ than a horse.", "options": ["big", "bigger", "biggest", "more big"], "correct_index": 1, "explanation": "两个事物比较用比较级：big → bigger（双写结尾辅音+er）。", "audio_text": "An elephant is bigger than a horse" },
    { "id": "q_grammar_014", "attack_type_id": "grammar", "grade": 5, "question": "This is the ___ mountain in the world.", "options": ["tall", "taller", "tallest", "most tall"], "correct_index": 2, "explanation": "最高级表示在所有事物中最...：tall → tallest（加est）。the + 最高级。", "audio_text": "This is the tallest mountain in the world" },
    { "id": "q_grammar_015", "attack_type_id": "grammar", "grade": 5, "question": "How ___ water do you drink each day?", "options": ["many", "much", "some", "any"], "correct_index": 1, "explanation": "water 是不可数名词，用 how much 询问数量。how many 用于可数名词。", "audio_text": "How much water do you drink each day" },
    { "id": "q_grammar_016", "attack_type_id": "grammar", "grade": 5, "question": "There are ___ apples in the basket.", "options": ["much", "a little", "many", "a few of"], "correct_index": 2, "explanation": "apples 是可数名词复数，用 many（许多）。much 修饰不可数名词。", "audio_text": "There are many apples in the basket" },
    { "id": "q_grammar_017", "attack_type_id": "grammar", "grade": 5, "question": "He ___ his homework two hours ago.", "options": ["finish", "finishes", "finished", "finishing"], "correct_index": 2, "explanation": "two hours ago 表明是一般过去时。finish → finished（规则动词加ed）。", "audio_text": "He finished his homework two hours ago" },
    { "id": "q_grammar_018", "attack_type_id": "grammar", "grade": 5, "question": "My bag is ___ than yours.", "options": ["heavy", "heavier", "heaviest", "more heavier"], "correct_index": 1, "explanation": "两者比较用比较级：heavy → heavier（去y加ier）。", "audio_text": "My bag is heavier than yours" },
    { "id": "q_grammar_019", "attack_type_id": "grammar", "grade": 5, "question": "I can't find ___ sugar in the kitchen.", "options": ["many", "some", "any", "few"], "correct_index": 2, "explanation": "否定句中用 any 表示\"一点也没有\"。sugar 是不可数名词。", "audio_text": "I can't find any sugar in the kitchen" },
    { "id": "q_grammar_020", "attack_type_id": "grammar", "grade": 5, "question": "She ___ a beautiful song at the concert.", "options": ["sing", "sings", "sang", "singed"], "correct_index": 2, "explanation": "sing 的过去式是 sang（不规则动词）。at the concert 说明是过去的事。", "audio_text": "She sang a beautiful song at the concert" },
    { "id": "q_grammar_021", "attack_type_id": "grammar", "grade": 5, "question": "Which is ___: winter or summer in Beijing?", "options": ["cold", "colder", "coldest", "more cold"], "correct_index": 1, "explanation": "两者比较（winter or summer）用比较级：cold → colder。", "audio_text": "Which is colder, winter or summer in Beijing" },
    { "id": "q_grammar_022", "attack_type_id": "grammar", "grade": 5, "question": "How ___ students are in your class?", "options": ["much", "many", "some", "any"], "correct_index": 1, "explanation": "students 是可数名词，用 how many 询问数量。", "audio_text": "How many students are in your class" },

    { "id": "q_grammar_023", "attack_type_id": "grammar", "grade": 6, "question": "She ___ already eaten dinner.", "options": ["have", "has", "had", "is"], "correct_index": 1, "explanation": "现在完成时：have/has + 过去分词。she 是第三人称单数，用 has。", "audio_text": "She has already eaten dinner" },
    { "id": "q_grammar_024", "attack_type_id": "grammar", "grade": 6, "question": "I ___ never been to Paris.", "options": ["have", "has", "had", "am"], "correct_index": 0, "explanation": "现在完成时：I have + 过去分词。never been = 从未去过。", "audio_text": "I have never been to Paris" },
    { "id": "q_grammar_025", "attack_type_id": "grammar", "grade": 6, "question": "The letter ___ written by Tom.", "options": ["was", "were", "is", "be"], "correct_index": 0, "explanation": "被动语态一般过去时：was/were + 过去分词。the letter 是单数，用 was。", "audio_text": "The letter was written by Tom" },
    { "id": "q_grammar_026", "attack_type_id": "grammar", "grade": 6, "question": "English ___ spoken in many countries.", "options": ["is", "are", "was", "be"], "correct_index": 0, "explanation": "被动语态一般现在时：is/are + 过去分词。English 是单数，用 is。", "audio_text": "English is spoken in many countries" },
    { "id": "q_grammar_027", "attack_type_id": "grammar", "grade": 6, "question": "The boy ___ won the race is my brother.", "options": ["who", "which", "where", "when"], "correct_index": 0, "explanation": "定语从句：先行词是人（the boy）用关系代词 who。", "audio_text": "The boy who won the race is my brother" },
    { "id": "q_grammar_028", "attack_type_id": "grammar", "grade": 6, "question": "This is the book ___ I borrowed from the library.", "options": ["who", "which", "where", "when"], "correct_index": 1, "explanation": "定语从句：先行词是物（the book）用关系代词 which 或 that。", "audio_text": "This is the book which I borrowed from the library" },
    { "id": "q_grammar_029", "attack_type_id": "grammar", "grade": 6, "question": "They ___ been friends for ten years.", "options": ["have", "has", "had", "are"], "correct_index": 0, "explanation": "现在完成时：they have + 过去分词。for ten years 表示持续时间。", "audio_text": "They have been friends for ten years" },
    { "id": "q_grammar_030", "attack_type_id": "grammar", "grade": 6, "question": "The flowers ___ planted by my mother look beautiful.", "options": ["was", "were", "is", "are"], "correct_index": 1, "explanation": "被动语态：flowers 是复数，用 were + 过去分词。", "audio_text": "The flowers were planted by my mother" }
  ]
}
```

- [ ] **Step 2: 创建 gates.json**

新建 `src/content/english/data/gates.json`：

```json
{
  "gates": [
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
  ]
}
```

- [ ] **Step 3: 提交**

```bash
git add src/content/english/data/questions.json src/content/english/data/gates.json
git commit -m "feat: add English content pack JSON data (80 questions + gate config)"
```

---

## Task 3: EnglishContentPack TDD

**Files:**
- Create: `src/content/english/english_content_pack.gd`
- Create: `tests/test_english_content_pack.gd`

- [ ] **Step 1: 写失败测试**

新建 `tests/test_english_content_pack.gd`：

```gdscript
extends GutTest

var pack: EnglishContentPack

func before_each() -> void:
	pack = EnglishContentPack.new()
	add_child_autofree(pack)
	GameState.player_grade = 5

func test_get_question_returns_vocabulary_question() -> void:
	var q: Dictionary = pack.get_question("vocabulary", 1, [])
	assert_false(q.is_empty())
	assert_eq(q.get("attack_type_id", ""), "vocabulary")

func test_get_question_respects_grade_filter() -> void:
	GameState.player_grade = 4
	for i in range(20):
		var q: Dictionary = pack.get_question("vocabulary", 1, [])
		assert_true(q.get("grade", 99) <= 4, "Grade 4 player should not get grade 5/6 questions")

func test_get_question_excludes_ids() -> void:
	GameState.player_grade = 6
	var all_ids: Array[String] = []
	for q in pack._questions:
		if q.get("attack_type_id") == "vocabulary" and q.get("grade", 0) <= 6:
			all_ids.append(q["id"])
	var all_but_one: Array[String] = all_ids.slice(1)
	var result: Dictionary = pack.get_question("vocabulary", 1, all_but_one)
	if not result.is_empty():
		assert_eq(result["id"], all_ids[0])

func test_get_gate_questions_returns_correct_count() -> void:
	var questions: Array[Dictionary] = pack.get_gate_questions("gate_en_librarian", 8)
	assert_eq(questions.size(), 8)

func test_get_gate_questions_no_duplicates() -> void:
	var questions: Array[Dictionary] = pack.get_gate_questions("gate_en_librarian", 10)
	var ids: Array[String] = []
	for q in questions:
		assert_false(q["id"] in ids, "Duplicate question: " + q["id"])
		ids.append(q["id"])

func test_get_gates_returns_librarian_gate() -> void:
	var gates: Array[Dictionary] = pack.get_gates()
	assert_true(gates.size() >= 1)
	assert_eq(gates[0].get("gate_id", ""), "gate_en_librarian")

func test_get_question_by_id_returns_correct_question() -> void:
	var q: Dictionary = pack.get_question_by_id("q_vocab_001")
	assert_false(q.is_empty())
	assert_eq(q.get("id", ""), "q_vocab_001")
```

- [ ] **Step 2: 实现 EnglishContentPack**

新建 `src/content/english/english_content_pack.gd`：

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

func _load_questions() -> void:
	var path: String = "res://src/content/english/data/questions.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("EnglishContentPack: Cannot open " + path)
		return
	var text: String = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null or not data.has("questions"):
		push_error("EnglishContentPack: Invalid questions.json format")
		return
	_questions.assign(data["questions"])

func _load_gates() -> void:
	var path: String = "res://src/content/english/data/gates.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("EnglishContentPack: Cannot open " + path)
		return
	var text: String = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null or not data.has("gates"):
		push_error("EnglishContentPack: Invalid gates.json format")
		return
	_gates.assign(data["gates"])

func get_attack_types() -> Array[Dictionary]:
	return [
		{ "id": "vocabulary", "name": "词汇", "icon": "📚", "color": "#667eea", "element": "fire" },
		{ "id": "grammar",    "name": "语法", "icon": "📝", "color": "#f5576c", "element": "ice" },
	]

func get_question(attack_type_id: String, difficulty: int, exclude_ids: Array[String]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for q in _questions:
		if q.get("grade", 99) > GameState.player_grade:
			continue
		if not attack_type_id.is_empty() and q.get("attack_type_id", "") != attack_type_id:
			continue
		if q.get("id", "") in exclude_ids:
			continue
		candidates.append(q)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]

func get_question_by_id(question_id: String) -> Dictionary:
	for q in _questions:
		if q.get("id", "") == question_id:
			return q
	return {}

func get_gate_questions(gate_id: String, count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for q in _questions:
		if q.get("grade", 99) <= GameState.player_grade:
			pool.append(q)
	pool.shuffle()
	var result: Array[Dictionary] = []
	result.assign(pool.slice(0, min(count, pool.size())))
	return result

func get_gates() -> Array[Dictionary]:
	return _gates

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
			},
		},
		{
			"id": "grammar_academy",
			"name": "语法学院",
			"max_level": 3,
			"upgrade_costs": {
				1: { "grammar_ore": 3 },
				2: { "grammar_ore": 8 },
				3: { "grammar_ore": 15 },
			},
		},
	]

func get_skills(bd_path: String) -> Array[Dictionary]:
	return []

func get_equipment() -> Array[Dictionary]:
	return []

func get_puzzle_scene_path(knowledge_id: String) -> String:
	return ""

func get_audio(text: String) -> AudioStream:
	return null
```

- [ ] **Step 3: 提交**

```bash
git add src/content/english/english_content_pack.gd tests/test_english_content_pack.gd
git commit -m "feat: add EnglishContentPack with JSON-based question loading"
```

---

## Task 4: ContentLoader 注册 EnglishContentPack

**Files:**
- Modify: `src/core/autoloads/game_state.gd`

- [ ] **Step 1: 读取 game_state.gd 的 _ready() 方法**

读取 `src/core/autoloads/game_state.gd`，找到 `_ready()` 方法（当前注册 content_loader、srs_system、expedition_tracker、save_system）。

- [ ] **Step 2: 在 _ready() 中注册 EnglishContentPack**

在 `content_loader = ContentLoader.new()` 和 `add_child(content_loader)` 之后，追加：

```gdscript
	var english_pack := EnglishContentPack.new()
	content_loader.add_child(english_pack)
	content_loader.register_pack(english_pack)
	content_loader.set_active_pack("english_grade46")
```

完整修改后的 `_ready()` 方法：

```gdscript
func _ready() -> void:
	content_loader = ContentLoader.new()
	add_child(content_loader)
	var english_pack := EnglishContentPack.new()
	content_loader.add_child(english_pack)
	content_loader.register_pack(english_pack)
	content_loader.set_active_pack("english_grade46")
	srs_system = SRSSystem.new()
	add_child(srs_system)
	expedition_tracker = ExpeditionTracker.new()
	add_child(expedition_tracker)
	save_system = SaveSystem.new()
	add_child(save_system)
	save_system.load_game_state()
```

- [ ] **Step 3: 提交**

```bash
git add src/core/autoloads/game_state.gd
git commit -m "feat: register EnglishContentPack as active content pack in GameState"
```

---

## Task 5: 年级设置界面

**Files:**
- Create: `src/ui/settings_scene.gd`
- Create: `src/ui/settings_scene.tscn`

- [ ] **Step 1: 实现 settings_scene.gd**

新建 `src/ui/settings_scene.gd`：

```gdscript
extends Control

@onready var _grade4_btn: Button = $VBoxContainer/GradeButtons/Grade4Button
@onready var _grade5_btn: Button = $VBoxContainer/GradeButtons/Grade5Button
@onready var _grade6_btn: Button = $VBoxContainer/GradeButtons/Grade6Button
@onready var _back_btn: Button = $VBoxContainer/BackButton

func _ready() -> void:
	_grade4_btn.pressed.connect(func(): _set_grade(4))
	_grade5_btn.pressed.connect(func(): _set_grade(5))
	_grade6_btn.pressed.connect(func(): _set_grade(6))
	_back_btn.pressed.connect(_on_back_pressed)
	_refresh_buttons()

func _set_grade(grade: int) -> void:
	GameState.player_grade = grade
	GameState.save_system.save_game_state()
	_refresh_buttons()

func _refresh_buttons() -> void:
	_grade4_btn.disabled = GameState.player_grade == 4
	_grade5_btn.disabled = GameState.player_grade == 5
	_grade6_btn.disabled = GameState.player_grade == 6

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
```

- [ ] **Step 2: 创建 settings_scene.tscn**

新建 `src/ui/settings_scene.tscn`：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/settings_scene.gd" id="1_ss"]

[node name="SettingsScene" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_ss")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
offset_left = 200.0
offset_top = 100.0
offset_right = 600.0
offset_bottom = 500.0

[node name="TitleLabel" type="Label" parent="VBoxContainer"]
text = "游戏设置"

[node name="GradeLabel" type="Label" parent="VBoxContainer"]
text = "选择年级（影响题目难度）"

[node name="GradeButtons" type="HBoxContainer" parent="VBoxContainer"]

[node name="Grade4Button" type="Button" parent="VBoxContainer/GradeButtons"]
text = "四年级"

[node name="Grade5Button" type="Button" parent="VBoxContainer/GradeButtons"]
text = "五年级"

[node name="Grade6Button" type="Button" parent="VBoxContainer/GradeButtons"]
text = "六年级"

[node name="BackButton" type="Button" parent="VBoxContainer"]
text = "返回主菜单"
```

- [ ] **Step 3: 提交**

```bash
git add src/ui/settings_scene.gd src/ui/settings_scene.tscn
git commit -m "feat: add grade selection settings scene"
```

---

## Task 6: 主菜单更新

**Files:**
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/main_menu.tscn`

- [ ] **Step 1: 读取 main_menu.tscn 和 main_menu.gd**

读取两个文件，了解当前节点结构（VBoxContainer 下有 StartButton、CityButton、GateButton）。

- [ ] **Step 2: 修改 main_menu.gd**

将 `src/ui/main_menu.gd` 替换为以下内容：

```gdscript
extends Control

@onready var _start_button: Button = $VBoxContainer/StartButton
@onready var _city_button: Button = $VBoxContainer/CityButton
@onready var _explore_button: Button = $VBoxContainer/ExploreButton
@onready var _settings_button: Button = $VBoxContainer/SettingsButton

func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_city_button.pressed.connect(_on_city_pressed)
	_explore_button.pressed.connect(_on_explore_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://src/battle/expedition_setup.tscn")

func _on_city_pressed() -> void:
	get_tree().change_scene_to_file("res://src/city/city_scene.tscn")

func _on_explore_pressed() -> void:
	get_tree().change_scene_to_file("res://src/exploration/exploration_scene.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/settings_scene.tscn")
```

- [ ] **Step 3: 用完整更新后的 main_menu.tscn 替换原文件**

将 `src/ui/main_menu.tscn` 替换为以下完整内容（GateButton 改为 ExploreButton，新增 SettingsButton）：

```
[gd_scene load_steps=2 format=3 uid="uid://main_menu"]

[ext_resource type="Script" path="res://src/ui/main_menu.gd" id="1_main_menu"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1_main_menu")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -75.0
offset_right = 100.0
offset_bottom = 75.0

[node name="Title" type="Label" parent="VBoxContainer"]
text = "知识神塔"

[node name="StartButton" type="Button" parent="VBoxContainer"]
text = "开始冒险"

[node name="CityButton" type="Button" parent="VBoxContainer"]
text = "我的城市"

[node name="ExploreButton" type="Button" parent="VBoxContainer"]
text = "探索野外"

[node name="SettingsButton" type="Button" parent="VBoxContainer"]
text = "⚙ 设置"
```

- [ ] **Step 4: 提交**

```bash
git add src/ui/main_menu.gd src/ui/main_menu.tscn
git commit -m "feat: update main menu - add explore and settings buttons"
```

---

## Phase 6 完成标准检查

- [ ] `EnglishContentPack` 7条 GUT 测试全部通过
- [ ] `player_grade=4` 时 `get_question` 不返回 grade 5/6 的题
- [ ] ContentLoader 注册后，`GameState.content_loader.get_active_pack()` 不为 null
- [ ] 设置界面：切换年级后重进设置页，按钮状态反映当前年级
- [ ] 重启游戏后年级设置保持
- [ ] 主菜单"探索野外"→ 探索场景，题目为真实英语题
- [ ] 主菜单"探索野外"→ 点击大关按钮 → 遗忘图书馆 → 完整流程通关
