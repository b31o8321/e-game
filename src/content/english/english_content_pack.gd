## EnglishContentPack — 英语 4-6 年级内容包
##
## Phase 3：从 JSON 数据文件加载完整的卡片 / Challenge / 敌人 / Boss / 楼层 /
## 装备 / Spice 数据。实现 ContentPackBase 25 方法接口。
##
## 同时保留旧接口（get_question / get_gates / get_buildings / get_attack_types ...）
## 以便 BattleController / CityController / PracticeArenaController 等现有调用方
## 在 Phase 2 迁移完成前继续工作。
##
## 详见: docs/superpowers/specs/2026-05-04-content-pack-interface-design.md
## 详见: docs/superpowers/specs/2026-05-04-english-pack-mvp-content.md
class_name EnglishContentPack extends ContentPackBase

const VoiceScrollSpice = preload("res://src/content/english/spices/voice_scroll_spice.gd")
const DictationSpice = preload("res://src/content/english/spices/dictation_spice.gd")
const WordChoiceSpice = preload("res://src/content/english/spices/word_choice_spice.gd")

const _DATA_DIR := "res://src/content/english/data/"

# ─── Phase 3 数据缓存 ───────────────────────────────────────────────
var _cards: Dictionary = {}                # id → Card
var _challenges: Dictionary = {}            # template_id → ChallengeTemplate
var _enemies: Dictionary = {}               # id → EnemyData
var _bosses: Dictionary = {}                # id → Dictionary（原始 Boss 元数据）
var _floors: Dictionary = {}                # floor_id → Dictionary
var _equipment_pool: Array = []             # Array of equipment Dictionaries
var _spices_cache: Array = []               # Array of SubjectSpiceBase 实例
var _lore_titles: Dictionary = {}           # lore_id → 友好名称
var _lore_id_to_path: Dictionary = {}       # lore_id → 包含它的 JSON 文件路径
var _pack_meta: Dictionary = {}             # pack_meta.json 全部元数据

# ─── 旧数据缓存（@deprecated，Phase 2 迁移后删除）─────────────────
var _questions: Array[Dictionary] = []
var _gates: Array[Dictionary] = []


func _init() -> void:
	# 旧字段保留兼容（GameState 等调用方还在读取）
	pack_id = "english_grade46"
	pack_name = "英语 4-6 年级"
	subject = "english"
	grades = [4, 5, 6]


func _ready() -> void:
	# 旧接口
	_load_questions()
	_load_gates()
	# Phase 3 新数据
	_load_pack_meta()
	_load_cards()
	_load_challenges()
	_load_enemies()
	_load_bosses()
	_load_floors()
	_load_equipment()
	_load_spices()
	_load_lore_titles()
	_build_lore_path_index()


# 读取 pack_meta.json：游戏标题、主题色、主菜单/知识城背景与 BGM 路径
func _load_pack_meta() -> void:
	var path := _DATA_DIR + "pack_meta.json"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_pack_meta = parsed


# ═══════════════════════════════════════════════════════════════════
# 新接口实现
# ═══════════════════════════════════════════════════════════════════

# ─── 身份 ──────────────────────────────────────────────────────────

func get_id() -> String:
	return "english_grade46"

func get_display_name() -> String:
	return "英语 4-6 年级"

func get_subject_category() -> String:
	return "english"

func get_grade_range() -> Array[int]:
	return [4, 5, 6]

func get_version() -> String:
	return "0.1.0"


# ─── 主题与资产路径（pack_meta.json 提供，未配置 → 空串）─────────────

func get_theme_colors() -> Dictionary:
	var raw: Variant = _pack_meta.get("theme_colors", null)
	if not (raw is Dictionary):
		return {}
	# 把十六进制字符串解析为 Color；未识别值跳过
	var out: Dictionary = {}
	for k in raw.keys():
		var v: Variant = raw[k]
		if v is String and v.begins_with("#"):
			out[str(k)] = Color(v)
		elif v is Color:
			out[str(k)] = v
	return out


func get_main_menu_bg_path() -> String:
	return str(_pack_meta.get("main_menu_bg_path", ""))


func get_city_bg_path() -> String:
	return str(_pack_meta.get("city_bg_path", ""))


func get_floor_bg_path(floor_id: String) -> String:
	var cfg: Dictionary = _floors.get(floor_id, {})
	return str(cfg.get("background_path", ""))


func get_battle_bgm_path(floor_id: String) -> String:
	var cfg: Dictionary = _floors.get(floor_id, {})
	return str(cfg.get("bgm_path", ""))


func get_main_menu_bgm_path() -> String:
	return str(_pack_meta.get("main_menu_bgm_path", ""))


func get_city_bgm_path() -> String:
	return str(_pack_meta.get("city_bgm_path", ""))


func get_game_title() -> String:
	return str(_pack_meta.get("game_title", "知识神塔"))


func get_game_subtitle() -> String:
	return str(_pack_meta.get("game_subtitle", "Tower of Knowledge"))


## 通用 pack_meta 字符串读取（供其他控制器在不扩展接口的情况下取额外资产路径）
func get_pack_meta_string(key: String) -> String:
	return str(_pack_meta.get(key, ""))


# ─── Card 类型词汇表 ───────────────────────────────────────────────

func get_card_types() -> Array[Dictionary]:
	return [
		{"id": "word",     "display": "词卡",   "icon": "res://src/content/english/assets/ui/icon_word.png"},
		{"id": "phrase",   "display": "短语卡", "icon": "res://src/content/english/assets/ui/icon_phrase.png"},
		{"id": "pattern",  "display": "句型卡", "icon": "res://src/content/english/assets/ui/icon_pattern.png"},
		{"id": "sound",    "display": "音卡",   "icon": "res://src/content/english/assets/ui/icon_sound.png"},
		{"id": "rule",     "display": "规则卡", "icon": "res://src/content/english/assets/ui/icon_rule.png"},
		{"id": "modifier", "display": "修饰卡", "icon": "res://src/content/english/assets/ui/icon_modifier.png"},
	]

func get_pos_values() -> Array[Dictionary]:
	return [
		{"id": "adjective",   "display": "形容词"},
		{"id": "noun",        "display": "名词"},
		{"id": "verb",        "display": "动词"},
		{"id": "verb_be",     "display": "系动词"},
		{"id": "adverb",      "display": "副词"},
		{"id": "pronoun",     "display": "代词"},
		{"id": "preposition", "display": "介词"},
		{"id": "conjunction", "display": "连词"},
		{"id": "article",     "display": "冠词"},
		{"id": "letter",      "display": "字母"},
		{"id": "syllable",    "display": "音节"},
		{"id": "sight_word",  "display": "高频词"},
		{"id": "number",      "display": "数词"},
	]

func get_tag_namespaces() -> Array[Dictionary]:
	return [
		{
			"id": "topic", "display": "主题",
			"values": ["emotion", "family", "school", "food", "animal", "weather", "color", "number", "body", "clothing"]
		},
		{
			"id": "grammar", "display": "语法特征",
			"values": ["past_tense", "present_simple", "present_continuous", "future", "comparative", "superlative", "plural", "singular"]
		},
		{
			"id": "scenario", "display": "场景",
			"values": ["greeting", "shopping", "travel", "classroom", "home"]
		},
	]


# ─── Challenges ───────────────────────────────────────────────────

func get_supported_challenge_kinds() -> Array[String]:
	return ["fill_in_blank", "error_correct", "listening_fill", "pronounce_attack", "sentence_build"]


# ═══════════════════════════════════════════════════════════════════
# Phase 3 — JSON 加载实现
# ═══════════════════════════════════════════════════════════════════

func _load_cards() -> void:
	var path := _DATA_DIR + "cards.json"
	var arr: Array[Card] = CardLoader.load_cards_from_json(path)
	for card in arr:
		if card and card.id != "":
			_cards[card.id] = card

func _load_challenges() -> void:
	var path := _DATA_DIR + "challenges.json"
	var arr: Array[ChallengeTemplate] = CardLoader.load_challenges_from_json(path)
	for tmpl in arr:
		if tmpl and tmpl.template_id != "":
			_challenges[tmpl.template_id] = tmpl

func _load_enemies() -> void:
	var path := _DATA_DIR + "enemies.json"
	var raw: Variant = _read_json(path, "enemies")
	if not (raw is Array):
		return
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var e := EnemyData.new()
		e.enemy_id = str(entry.get("id", ""))
		e.enemy_name = str(entry.get("display_name", ""))
		e.max_hp = int(entry.get("max_hp", 100))
		e.base_attack = int(entry.get("base_attack", 10))
		e.sprite_path = str(entry.get("portrait_path", ""))
		e.topic_id = str(entry.get("topic_id", ""))

		var raw_axes: Array = entry.get("weak_axes", [])
		var axes: Array[String] = []
		for v in raw_axes:
			axes.append(str(v))
		e.weak_axes = axes

		var raw_ids: Array = entry.get("challenge_template_ids", [])
		var ids: Array[String] = []
		for v in raw_ids:
			ids.append(str(v))
		e.challenge_template_ids = ids

		var raw_abilities: Array = entry.get("ability_ids", [])
		var abilities: Array[String] = []
		for v in raw_abilities:
			abilities.append(str(v))
		e.ability_ids = abilities

		if e.enemy_id != "":
			_enemies[e.enemy_id] = e

func _load_bosses() -> void:
	var path := _DATA_DIR + "bosses.json"
	var raw: Variant = _read_json(path, "bosses")
	if not (raw is Array):
		return
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var bid := str(entry.get("id", ""))
		if bid == "":
			continue
		_bosses[bid] = entry

func _load_floors() -> void:
	var path := _DATA_DIR + "floors.json"
	var raw: Variant = _read_json(path, "floors")
	if not (raw is Array):
		return
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var fid := str(entry.get("floor_id", ""))
		if fid == "":
			continue
		_floors[fid] = entry

func _load_equipment() -> void:
	var path := _DATA_DIR + "equipment.json"
	var raw: Variant = _read_json(path, "equipment")
	if not (raw is Array):
		return
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_equipment_pool.append(entry)

func _load_spices() -> void:
	var path := _DATA_DIR + "spices.json"
	var raw: Variant = _read_json(path, "spices")
	if not (raw is Array):
		# 数据文件不可用 → 回退到默认硬编码 spice
		_spices_cache = _build_default_spices()
		return
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var spice = _build_spice_from_entry(entry)
		if spice != null:
			_spices_cache.append(spice)
	# 若 JSON 解析后一个都没构造出来，仍回退默认
	if _spices_cache.is_empty():
		_spices_cache = _build_default_spices()


func _build_spice_from_entry(entry: Dictionary):
	var kind := str(entry.get("kind", ""))
	match kind:
		"voice_scroll":
			var v: VoiceScrollSpice = VoiceScrollSpice.new()
			v.target_phrase = str(entry.get("target_phrase", ""))
			v.buff_id = str(entry.get("buff_id", "atk_up"))
			v.buff_value = int(entry.get("buff_value", 30))
			v.buff_duration = int(entry.get("buff_duration", 3))
			v.set_meta("spice_id_override", str(entry.get("id", "")))
			v.set_meta("display_name_override", str(entry.get("display_name", "")))
			return v
		"dictation":
			var d: DictationSpice = DictationSpice.new()
			d.target_word = str(entry.get("target_word", ""))
			d.counter_damage = int(entry.get("counter_damage", 25))
			d.audio_path = str(entry.get("audio_path", ""))
			d.set_meta("spice_id_override", str(entry.get("id", "")))
			d.set_meta("display_name_override", str(entry.get("display_name", "")))
			return d
		"word_choice":
			var w: WordChoiceSpice = WordChoiceSpice.new()
			w.target_word = str(entry.get("target_word", ""))
			w.prompt_meaning = str(entry.get("prompt_meaning", ""))
			var choices_raw: Variant = entry.get("choices", [])
			if choices_raw is Array:
				var typed_choices: Array[String] = []
				for v in choices_raw:
					typed_choices.append(str(v))
				w.choices = typed_choices
			w.damage_bonus = int(entry.get("damage_bonus", 20))
			w.set_meta("spice_id_override", str(entry.get("id", "")))
			w.set_meta("display_name_override", str(entry.get("display_name", "")))
			return w
	push_error("[EnglishContentPack] 未知 spice kind: %s" % kind)
	return null


# ─── Cards 接口实现 ────────────────────────────────────────────────

func get_card(card_id: String) -> Card:
	return _cards.get(card_id, null)

func get_all_cards() -> Array[Card]:
	var out: Array[Card] = []
	for v in _cards.values():
		out.append(v)
	return out

## MVP 起手卡组：5 形容词（含 1 非正面） + 3 系动词 + 2 代词 + 1 句型 + 1 高频词 = 13 张
## 含 1 张非正面性格（lazy），让 1F 精英对偶题（She is X and he is Y）可解。
func get_starting_deck_card_ids() -> Array[String]:
	return [
		"card_happy",
		"card_brave",
		"card_big",
		"card_kind",
		"card_smart",
		"card_lazy",
		"card_be_am",
		"card_be_is",
		"card_be_are",
		"card_pronoun_i",
		"card_pronoun_you",
		"card_pattern_i_am_blank",
		"card_word_a",
	]


## 按楼层定制的起手卡组（解决"题目和手卡对不上"问题）。
## 0F 字母拼读 → 字母 + 高频词 + 音节
## 1F 形容词初阶 → 形容词 + 系动词 + 句型
## 2F 名词与代词 → 名词（家庭+身体）+ 代词 + 形容词承接
func get_starting_deck_for_floor(floor_id: String) -> Array[String]:
	match floor_id:
		"0F":
			# 8 字母 + 3 高频词 + 2 音节 = 13 张（含 t/i 以应对精英拼读题）
			return [
				"card_letter_a",
				"card_letter_b",
				"card_letter_c",
				"card_letter_d",
				"card_letter_g",
				"card_letter_i",
				"card_letter_o",
				"card_letter_t",
				"card_word_am",
				"card_word_this",
				"card_word_that",
				"card_syllable_at",
				"card_syllable_un",
			]
		"1F":
			# 沿用通用 12 张：5 形容词 + 3 系动词 + 2 代词 + 1 句型 + 1 高频词
			return get_starting_deck_card_ids()
		"2F":
			# 4 家庭名词 + 4 身体名词 + 3 代词 + 1 系动词 + 1 形容词 = 13 张
			# (含 are 以应对 2F 精英 "She and he are my ___" 题)
			return [
				"card_noun_mother",
				"card_noun_father",
				"card_noun_sister",
				"card_noun_brother",
				"card_noun_eye",
				"card_noun_hand",
				"card_noun_head",
				"card_noun_foot",
				"card_pronoun_he",
				"card_pronoun_she",
				"card_pronoun_we",
				"card_be_are",
				"card_kind",
			]
		"3F":
			# 8 动词 + 4 代词/系动词 = 12 张（匹配 3F 动词题）
			return [
				"card_verb_run",
				"card_verb_eat",
				"card_verb_play",
				"card_verb_swim",
				"card_verb_read",
				"card_verb_write",
				"card_verb_go",
				"card_verb_like",
				"card_pronoun_i",
				"card_pronoun_you",
				"card_pronoun_he",
				"card_pronoun_she",
			]
		"4F":
			# 10 数字 + 2 时间词 = 12 张（匹配 4F 数字时间题）
			return [
				"card_num_one",
				"card_num_two",
				"card_num_three",
				"card_num_four",
				"card_num_five",
				"card_num_six",
				"card_num_seven",
				"card_num_eight",
				"card_num_nine",
				"card_num_ten",
				"card_time_morning",
				"card_time_afternoon",
			]
		"5F":
			# 综合复习：3 代词 + 3 动词 + 2 数字 + 2 系动词 + 2 形容词 = 12 张
			return [
				"card_pronoun_i",
				"card_pronoun_she",
				"card_pronoun_he",
				"card_verb_go",
				"card_verb_eat",
				"card_verb_play",
				"card_num_three",
				"card_num_five",
				"card_be_am",
				"card_be_is",
				"card_happy",
				"card_kind",
			]
	# 未识别楼层 → 回退默认
	return get_starting_deck_card_ids()

## 楼层卡池：按楼层 sub_topic_id 与卡片 tags 交集过滤
func get_card_pool_for_floor(floor_id: String) -> Array[Card]:
	var out: Array[Card] = []
	var cfg: Dictionary = _floors.get(floor_id, {})
	if cfg.is_empty():
		return out
	var topic_set: Dictionary = {}
	for act in cfg.get("acts", []):
		var sub_topic := str(act.get("sub_topic_id", ""))
		if sub_topic != "":
			topic_set[sub_topic] = true
	if topic_set.is_empty():
		return out
	for card in _cards.values():
		for t in card.tags:
			if topic_set.has(t):
				out.append(card)
				break
	return out


# ─── Challenges 接口实现 ──────────────────────────────────────────

func get_challenge_template(template_id: String) -> ChallengeTemplate:
	return _challenges.get(template_id, null)

func get_challenges_for_topic(topic_id: String) -> Array[ChallengeTemplate]:
	var out: Array[ChallengeTemplate] = []
	for tmpl in _challenges.values():
		if tmpl != null and tmpl.topic_id == topic_id:
			out.append(tmpl)
	return out


# ─── Enemies / Bosses 接口实现 ────────────────────────────────────

func get_enemy(enemy_id: String) -> EnemyData:
	return _enemies.get(enemy_id, null)

## get_boss 返回 BossBase（接口约定）；当前 JSON 仅记录元数据，包装到 BossBase。
func get_boss(boss_id: String) -> BossBase:
	var data: Dictionary = _bosses.get(boss_id, {})
	if data.is_empty():
		return null
	var b: BossBase = BossBase.new()
	b.boss_id = str(data.get("id", boss_id))
	b.max_hp = int(data.get("max_hp", 500))
	# gate_id 旧字段，暂用 topic_id 兜底
	b.gate_id = str(data.get("topic_id", ""))
	return b

## 返回原始 Boss 数据 Dictionary（drops / phases / weak_axes / dialogue 等）
func get_boss_data(boss_id: String) -> Dictionary:
	return _bosses.get(boss_id, {})

func get_enemy_pool_for_floor(floor_id: String) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	var cfg: Dictionary = _floors.get(floor_id, {})
	if cfg.is_empty():
		return out
	var topic_set: Dictionary = {}
	for act in cfg.get("acts", []):
		var sub_topic := str(act.get("sub_topic_id", ""))
		if sub_topic != "":
			topic_set[sub_topic] = true
	for e in _enemies.values():
		if topic_set.has(e.topic_id):
			out.append(e)
	return out


# ─── Floors 接口实现 ──────────────────────────────────────────────

func get_floor_config(floor_id: String) -> Dictionary:
	return _floors.get(floor_id, {})

func get_all_floor_ids() -> Array[String]:
	# 维持 JSON 顺序（_floors 是 Dictionary，Godot 4 保留插入顺序）
	var out: Array[String] = []
	for k in _floors.keys():
		out.append(str(k))
	return out

func get_floor_unlock_chain() -> Array[Dictionary]:
	var chain: Array[Dictionary] = []
	var ids := get_all_floor_ids()
	for i in ids.size():
		var fid := ids[i]
		var unlocks: Array[String] = []
		if i + 1 < ids.size():
			unlocks.append(ids[i + 1])
		chain.append({"floor_id": fid, "unlocks": unlocks})
	return chain


# ─── Spices ──────────────────────────────────────────────────────

func get_available_spices() -> Array:
	if _spices_cache.is_empty():
		_spices_cache = _build_default_spices()
	return _spices_cache

func get_spice(spice_id: String) -> Resource:
	for s in get_available_spices():
		if s == null:
			continue
		# 优先比对 meta（来自 JSON 的实例 ID），再退到类自身的 get_id()
		if s.has_meta("spice_id_override"):
			var override := str(s.get_meta("spice_id_override"))
			if override == spice_id:
				return s
		if s.has_method("get_id") and s.get_id() == spice_id:
			return s
	return null

func _build_default_spices() -> Array:
	var out: Array = []

	var voice: VoiceScrollSpice = VoiceScrollSpice.new()
	voice.target_phrase = "I am strong"
	voice.buff_id = "atk_up"
	voice.buff_value = 30
	voice.buff_duration = 3
	out.append(voice)

	var dict: DictationSpice = DictationSpice.new()
	dict.target_word = "brave"
	dict.counter_damage = 25
	dict.audio_path = ""
	out.append(dict)

	var wc: WordChoiceSpice = WordChoiceSpice.new()
	wc.target_word = "happy"
	wc.prompt_meaning = "高兴的"
	wc.choices = ["happy", "sad", "angry", "tired"]
	wc.damage_bonus = 20
	out.append(wc)

	return out


# ─── Equipment / Loot ────────────────────────────────────────────

func get_equipment_pool() -> Array:
	return _equipment_pool

func get_loot_table_for_floor(floor_id: String) -> Dictionary:
	# 简单战利品表：列出该楼层 boss 的固定掉落
	var out: Dictionary = {"common": [], "rare": [], "epic": []}
	var cfg: Dictionary = _floors.get(floor_id, {})
	if cfg.is_empty():
		return out
	for act in cfg.get("acts", []):
		var bid := str(act.get("boss_id", ""))
		var bdata: Dictionary = _bosses.get(bid, {})
		if bdata.is_empty():
			continue
		var drops: Dictionary = bdata.get("drops", {})
		var eq_id := str(drops.get("equipment_id", ""))
		if eq_id == "":
			continue
		# 找到 equipment 条目
		for eq in _equipment_pool:
			if str(eq.get("id", "")) == eq_id:
				var rarity := str(eq.get("rarity", "common"))
				if not out.has(rarity):
					out[rarity] = []
				out[rarity].append(eq)
				break
	return out


# ─── 剧情面板（Cutscene 系统消费）──────────────────────────────────

const _LORE_DIR: String = "res://src/content/english/data/lore"


func get_intro_panels() -> Array[CutscenePanel]:
	return CutsceneLoader.load_panels_from_json(_LORE_DIR + "/intro.json")


func get_floor_intro_panels(floor_id: String) -> Array[CutscenePanel]:
	var path: String = "%s/floor_intros/%s.json" % [_LORE_DIR, floor_id]
	return CutsceneLoader.load_panels_from_json(path)


func get_floor_complete_panels(floor_id: String) -> Array[CutscenePanel]:
	var path: String = "%s/floor_completes/%s.json" % [_LORE_DIR, floor_id]
	return CutsceneLoader.load_panels_from_json(path)


func get_boss_pre_panels(boss_id: String) -> Array[CutscenePanel]:
	var path: String = "%s/boss_dialogues/%s_pre.json" % [_LORE_DIR, boss_id]
	return CutsceneLoader.load_panels_from_json(path)


func get_boss_post_panels(boss_id: String) -> Array[CutscenePanel]:
	var path: String = "%s/boss_dialogues/%s_post.json" % [_LORE_DIR, boss_id]
	return CutsceneLoader.load_panels_from_json(path)


func get_ending_panels() -> Array[CutscenePanel]:
	return CutsceneLoader.load_panels_from_json(_LORE_DIR + "/ending.json")


func get_lore_title(lore_id: String) -> String:
	if lore_id == "":
		return ""
	if _lore_titles.has(lore_id):
		return str(_lore_titles[lore_id])
	# 兜底：直接返回 ID（图鉴馆能至少显示一个"标识"）
	return lore_id


## 找到包含 lore_id 的 JSON 文件，重播整段面板序列。
## 这避免了"按 panel_index 跳到中间"的复杂度——MVP 阶段重播整段更自然。
func get_panels_containing_lore(lore_id: String) -> Array[CutscenePanel]:
	if lore_id == "":
		return []
	var path: String = str(_lore_id_to_path.get(lore_id, ""))
	if path == "":
		# 索引未命中：尝试懒重建一次
		_build_lore_path_index()
		path = str(_lore_id_to_path.get(lore_id, ""))
	if path == "":
		return []
	return CutsceneLoader.load_panels_from_json(path)


func _load_lore_titles() -> void:
	var path: String = _LORE_DIR + "/lore_titles.json"
	if not FileAccess.file_exists(path):
		# 文件缺失也无所谓：get_lore_title 会回退到 ID
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_lore_titles = parsed


## 扫描所有 lore JSON 文件，建立 lore_codex_id → 文件路径 的反向索引，
## 便于图鉴馆点击重播。
func _build_lore_path_index() -> void:
	_lore_id_to_path.clear()
	var roots: Array[String] = [
		_LORE_DIR + "/intro.json",
		_LORE_DIR + "/ending.json",
	]
	for p in roots:
		_index_lore_file(p)
	for sub in ["floor_intros", "floor_completes", "boss_dialogues"]:
		var dir_path: String = _LORE_DIR + "/" + sub
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".json"):
				_index_lore_file(dir_path + "/" + fname)
			fname = dir.get_next()
		dir.list_dir_end()


func _index_lore_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Array):
		return
	for entry in parsed:
		if not (entry is Dictionary):
			continue
		var lid: String = str(entry.get("lore_codex_id", ""))
		if lid != "":
			_lore_id_to_path[lid] = path


# ─── 验证 ──────────────────────────────────────────────────────────

func validate() -> Array[String]:
	var errors: Array[String] = []
	if get_id().is_empty():
		errors.append("english_pack: get_id() returned empty")
	if get_display_name().is_empty():
		errors.append("english_pack: get_display_name() returned empty")
	if get_subject_category() != "english":
		errors.append("english_pack: subject_category must be 'english'")
	if get_card_types().is_empty():
		errors.append("english_pack: get_card_types() returned empty")
	if get_supported_challenge_kinds().is_empty():
		errors.append("english_pack: get_supported_challenge_kinds() returned empty")

	# 1. 起手卡组每张 ID 都在卡池里
	for cid in get_starting_deck_card_ids():
		if not _cards.has(cid):
			errors.append("english_pack: starting deck references missing card_id: %s" % cid)

	# 2. 楼层引用的 boss_id 必须存在
	for fid in get_all_floor_ids():
		var cfg: Dictionary = _floors.get(fid, {})
		for act in cfg.get("acts", []):
			var bid := str(act.get("boss_id", ""))
			if bid != "" and not _bosses.has(bid):
				errors.append("english_pack: floor %s act %s references missing boss: %s" % [fid, str(act.get("act_index", "?")), bid])

	# 3. Boss / Enemy 引用的 challenge_template_ids 必须存在
	for bid in _bosses.keys():
		var bdata: Dictionary = _bosses[bid]
		for tid in bdata.get("challenge_template_ids", []):
			if not _challenges.has(str(tid)):
				errors.append("english_pack: boss %s references missing challenge: %s" % [bid, tid])
	for eid in _enemies.keys():
		var e: EnemyData = _enemies[eid]
		for tid in e.challenge_template_ids:
			if not _challenges.has(str(tid)):
				errors.append("english_pack: enemy %s references missing challenge: %s" % [eid, tid])

	# 4. Challenge slot 的 required_type / required_pos 必须在词汇表内
	var valid_types: Array[String] = []
	for t in get_card_types():
		valid_types.append(str(t.get("id", "")))
	var valid_pos: Array[String] = []
	for p in get_pos_values():
		valid_pos.append(str(p.get("id", "")))
	for tid in _challenges.keys():
		var tmpl: ChallengeTemplate = _challenges[tid]
		for slot in tmpl.slots:
			if slot.required_type != "" and not (slot.required_type in valid_types):
				errors.append("english_pack: challenge %s slot has invalid required_type: %s" % [tid, slot.required_type])
			if slot.required_pos != "" and not (slot.required_pos in valid_pos):
				errors.append("english_pack: challenge %s slot has invalid required_pos: %s" % [tid, slot.required_pos])
		# perfect_match_card_ids 必须存在
		for cid in tmpl.perfect_match_card_ids:
			if not _cards.has(cid):
				errors.append("english_pack: challenge %s perfect_match references missing card: %s" % [tid, cid])
		# accept_card_ids 必须引用真实存在的卡（否则该槽永远无法被填）
		for slot in tmpl.slots:
			for cid in slot.accept_card_ids:
				if not _cards.has(cid):
					errors.append("english_pack: challenge %s slot %d accept_card_ids references missing card: %s" % [tid, slot.index, cid])
			# required_tags：必须有至少一张卡满足，否则该挑战无解
			if not slot.required_tags.is_empty() and slot.accept_card_ids.is_empty():
				var any_card_matches: bool = false
				for c in _cards.values():
					if not (c is Card):
						continue
					if slot.tag_match_mode == "all":
						var all_hit: bool = true
						for rt in slot.required_tags:
							if not (rt in c.tags):
								all_hit = false
								break
						if all_hit:
							any_card_matches = true
							break
					else:
						var has_any: bool = false
						for ct in c.tags:
							if ct in slot.required_tags:
								has_any = true
								break
						if has_any:
							any_card_matches = true
							break
				if not any_card_matches:
					errors.append("english_pack: challenge %s slot %d required_tags %s (mode=%s) not satisfiable by any card" % [tid, slot.index, str(slot.required_tags), slot.tag_match_mode])

	# 5. Spice 实现了 evaluate
	for spice in get_available_spices():
		if spice == null or not spice.has_method("evaluate"):
			errors.append("english_pack: spice missing evaluate(): %s" % str(spice))

	return errors


# ═══════════════════════════════════════════════════════════════════
# 内部辅助
# ═══════════════════════════════════════════════════════════════════

## 读 JSON 文件并取顶层 key 对应的数组（{"key": [...]}）
static func _read_json(path: String, key: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[EnglishContentPack] 文件不存在: %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[EnglishContentPack] 无法打开文件: %s" % path)
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("[EnglishContentPack] JSON 解析失败 %s: %s (line %d)" % [path, json.get_error_message(), json.get_error_line()])
		return null
	var data: Variant = json.data
	if typeof(data) == TYPE_DICTIONARY and data.has(key):
		return data[key]
	if typeof(data) == TYPE_ARRAY:
		return data
	push_error("[EnglishContentPack] JSON 顶层缺少键 \"%s\": %s" % [key, path])
	return null


# ═══════════════════════════════════════════════════════════════════
# 旧接口保留（@deprecated — Phase 2 BattleController 等迁移后移除）
# ═══════════════════════════════════════════════════════════════════

func _load_questions() -> void:
	var path := "res://src/content/english/data/questions.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("EnglishContentPack: failed to open " + path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary) or not parsed.has("questions"):
		push_error("EnglishContentPack: invalid JSON at " + path)
		return
	_questions.assign(parsed["questions"])

func _load_gates() -> void:
	var path := "res://src/content/english/data/gates.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("EnglishContentPack: failed to open " + path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary) or not parsed.has("gates"):
		push_error("EnglishContentPack: invalid JSON at " + path)
		return
	_gates.assign(parsed["gates"])

## @deprecated Phase 2: 题目检索改走 Card / ChallengeTemplate
func get_question(attack_type_id: String, _difficulty: int, exclude_ids: Array[String]) -> Dictionary:
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

## @deprecated Phase 2
func get_question_by_id(question_id: String) -> Dictionary:
	for q in _questions:
		if q.get("id", "") == question_id:
			return q
	return {}

## @deprecated Phase 2
func get_gate_questions(_gate_id: String, count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for q in _questions:
		if q.get("grade", 99) <= GameState.player_grade:
			pool.append(q)
	pool.shuffle()
	var result: Array[Dictionary] = []
	result.assign(pool.slice(0, min(count, pool.size())))
	return result

## @deprecated Phase 2
func get_gates() -> Array[Dictionary]:
	return _gates

## @deprecated Phase 2: 攻击类型概念被 Card.type / Card.skill 取代
func get_attack_types() -> Array[Dictionary]:
	return [
		{"id": "vocabulary", "name": "词灵", "icon": "📚", "color": "#667eea", "element": "fire"},
		{"id": "grammar",    "name": "法则", "icon": "📝", "color": "#f5576c", "element": "ice"},
	]

## @deprecated Phase 2: 知识城建筑改由专属 city_config.json 提供
func get_buildings() -> Array[Dictionary]:
	return [
		{"id": "vocabulary_library", "name": "词汇图书馆", "attack_type_id": "vocabulary", "base_damage": 10, "levels": [1, 2, 3]},
		{"id": "grammar_academy",    "name": "语法学院",   "attack_type_id": "grammar",    "base_damage": 10, "levels": [1, 2, 3]},
	]

## @deprecated Phase 2
func on_question_answered(_question_id: String, _correct: bool) -> void:
	pass

## @deprecated Phase 2
func get_skills(_bd_path: String) -> Array[Dictionary]:
	return []

## @deprecated Phase 2
func get_equipment() -> Array[Dictionary]:
	return []

## @deprecated Phase 2
func get_puzzle_scene_path(_knowledge_id: String) -> String:
	return ""

## @deprecated Phase 2
func get_audio(_text: String) -> AudioStream:
	return null
