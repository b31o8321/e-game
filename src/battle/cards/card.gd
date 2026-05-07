## Card resource — 战斗卡片数据模型
##
## 4 个独立维度（type / pos / tags / skill）+ 战斗属性。学科切换 = 重新填字段，
## 引擎层不需要任何改动。详见 docs/superpowers/specs/2026-05-04-battle-system-redesign.md
## 中"核心数据模型 → Card"小节。
class_name Card extends Resource

@export var id: String = ""                 # 唯一 ID, e.g. "card_brave"
@export var text: String = ""               # 显示文本, e.g. "brave"

# === 维度 1：Type（机制角色，决定能进什么槽）===
## "word" | "phrase" | "pattern" | "rule" | "sound" | "modifier"
@export var type: String = ""

# === 维度 2：POS（仅 word/phrase 用，决定词性槽匹配）===
## "adjective" | "noun" | "verb" | "adverb" | ... | ""（其他类型空）
@export var pos: String = ""

# === 维度 3：Tags（自由打标，多维过滤）===
@export var tags: Array[String] = []

# === 维度 4：Skill（技能域，决定 Spice 兼容性）===
## "vocab" | "grammar" | "phonetics" | "spelling" | "speaking" | "listening" | "reading" | "writing"
@export var skill: String = ""

# === 战斗属性 ===
@export var base_damage: int = 0
## "common" | "rare" | "epic" | "legendary"
@export var rarity: String = "common"
## 可空，附加效果 ID
@export var on_play_effect: String = ""
@export var icon_path: String = ""

# === 听音 / 拼写卡专属 ===
## type=sound 时使用；word 卡也可填，作为 TTS 音频
@export var audio_path: String = ""

# === 学习内容（Phase 4.x：让卡牌能教学）===
@export var meaning: String = ""           # 中文含义，e.g. "勇敢的"
@export var example_en: String = ""        # 英文例句（可选，仅实义词）
@export var example_zh: String = ""        # 例句中文翻译
@export var phonetic: String = ""          # IPA 音标，e.g. "[breɪv]"

# === 卡牌能力（B4 — 游戏性优先重构）===
## 能力类型 — 触发后产生额外战斗效果。
## "none"          — 无额外能力（默认）
## "draw_card"     — 此卡填槽时，额外抽 N 张
## "draw_question" — 此卡填槽时，给棋盘加 N 道题
## "double_effect" — 当前题结算的效果 ×2（伤害/回血/护盾）
## "chain_bonus"   — 与上一张卡共享 tag 时，伤害 ×1.5
## "heal_on_use"   — 此卡每次填槽都回血 N
## "combo_charge"  — 命中时连击 +2（而非 +1）
@export var ability_type: String = "none"
@export var ability_magnitude: int = 0
@export var ability_description: String = ""


## 从 Dictionary（来自 JSON）构造一张 Card。
## 缺失字段使用合理默认值；非法类型尽量保留语义而不抛错。
static func from_dict(data: Dictionary) -> Card:
	var card := Card.new()
	card.id = str(data.get("id", ""))
	card.text = str(data.get("text", ""))
	card.type = str(data.get("type", ""))
	card.pos = str(data.get("pos", ""))
	card.skill = str(data.get("skill", ""))
	card.base_damage = int(data.get("base_damage", 0))
	card.rarity = str(data.get("rarity", "common"))
	card.on_play_effect = str(data.get("on_play_effect", ""))
	card.icon_path = str(data.get("icon_path", ""))
	card.audio_path = str(data.get("audio_path", ""))
	card.meaning = str(data.get("meaning", ""))
	card.example_en = str(data.get("example_en", ""))
	card.example_zh = str(data.get("example_zh", ""))
	card.phonetic = str(data.get("phonetic", ""))
	card.ability_type = str(data.get("ability_type", "none"))
	card.ability_magnitude = int(data.get("ability_magnitude", 0))
	card.ability_description = str(data.get("ability_description", ""))

	# Tags 必须是 Array[String]，做一次 str() 转换，把数字等都规范成字符串
	var raw_tags: Array = data.get("tags", [])
	var tags: Array[String] = []
	for t in raw_tags:
		tags.append(str(t))
	card.tags = tags

	return card


## 序列化回 Dictionary（便于调试 / 测试 / 存档）
func to_dict() -> Dictionary:
	return {
		"id": id,
		"text": text,
		"type": type,
		"pos": pos,
		"tags": tags,
		"skill": skill,
		"base_damage": base_damage,
		"rarity": rarity,
		"on_play_effect": on_play_effect,
		"icon_path": icon_path,
		"audio_path": audio_path,
		"meaning": meaning,
		"example_en": example_en,
		"example_zh": example_zh,
		"phonetic": phonetic,
		"ability_type": ability_type,
		"ability_magnitude": ability_magnitude,
		"ability_description": ability_description,
	}
