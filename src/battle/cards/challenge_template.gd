## ChallengeTemplate resource — 一句敌人台词 + 槽位序列
##
## 详见 docs/superpowers/specs/2026-05-04-battle-system-redesign.md
## 中"核心数据模型 → ChallengeTemplate"小节。
class_name ChallengeTemplate extends Resource

@export var template_id: String = ""
## "fill_in_blank" | "error_correct" | "listening_fill" | "pronounce_attack" | "sentence_build" | ...
@export var kind: String = ""
## 敌人台词，___ 表示槽位
@export var dialogue: String = ""
@export var slots: Array[ChallengeSlot] = []
## 单元/楼层主题 ID，e.g. "adjectives_basic"
@export var topic_id: String = ""
## 暴击卡（最优解）ID 列表
@export var perfect_match_card_ids: Array[String] = []
## 听力 Challenge 用
@export var audio_path: String = ""
## 中文语义提示，强制玩家理解词义（e.g. "积极情绪"、"形容身材"）。
## 留空 = 无提示。BattleScene 会以淡色 inline label 渲染在槽位旁。
@export var topic_hint: String = ""
## 战略效果类型——决定解题后产生的效果。详见 ChallengeEffects。
## 取值：
##   "damage"          (默认) 用基础伤害公式打敌人
##   "heal"            回血 effect_magnitude HP
##   "shield"          加临时护盾 effect_magnitude
##   "draw_card"       立即抽 effect_magnitude 张牌
##   "draw_question"   下回合棋盘多 effect_magnitude 个题
##   "weakness_strike" 命中弱点时额外 ×1.5 伤害
##   "combo_boost"     下一题伤害 ×2
@export var effect_type: String = "damage"
## effect_type 对应的数值（HP / 护盾 / 抽牌数 等）。
## "damage" 类型时：0 = 走基础伤害公式；>0 = 用此值替代基础伤害（少用）。
@export var effect_magnitude: int = 0

## Runtime-only 标记，NOT serialized in from_dict/to_dict。
## refill_board 在「手牌无法解任何 preferred 题、走 fallback 不过滤池」时
## 把入选的题标 is_warn = true，让 UI 可渲染 🟡 提示，告诉玩家这题手里没法解。
var is_warn: bool = false


## 从 Dictionary 构造（嵌套 slots 数组也会递归构造）
static func from_dict(data: Dictionary) -> ChallengeTemplate:
	var tmpl := ChallengeTemplate.new()
	tmpl.template_id = str(data.get("template_id", ""))
	tmpl.kind = str(data.get("kind", ""))
	tmpl.dialogue = str(data.get("dialogue", ""))
	tmpl.topic_id = str(data.get("topic_id", ""))
	tmpl.audio_path = str(data.get("audio_path", ""))
	tmpl.topic_hint = str(data.get("topic_hint", ""))
	tmpl.effect_type = str(data.get("effect_type", "damage"))
	tmpl.effect_magnitude = int(data.get("effect_magnitude", 0))

	# perfect_match_card_ids
	var raw_perfect: Array = data.get("perfect_match_card_ids", [])
	var perfect: Array[String] = []
	for s in raw_perfect:
		perfect.append(str(s))
	tmpl.perfect_match_card_ids = perfect

	# slots
	var raw_slots: Array = data.get("slots", [])
	var slots: Array[ChallengeSlot] = []
	for i in raw_slots.size():
		var raw = raw_slots[i]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var slot := ChallengeSlot.from_dict(raw)
		# 若 slot 没显式 index，用数组下标兜底
		if not raw.has("index"):
			slot.index = i
		slots.append(slot)
	tmpl.slots = slots

	return tmpl


func to_dict() -> Dictionary:
	var slot_dicts: Array = []
	for slot in slots:
		slot_dicts.append(slot.to_dict())
	return {
		"template_id": template_id,
		"kind": kind,
		"dialogue": dialogue,
		"slots": slot_dicts,
		"topic_id": topic_id,
		"perfect_match_card_ids": perfect_match_card_ids,
		"audio_path": audio_path,
		"topic_hint": topic_hint,
		"effect_type": effect_type,
		"effect_magnitude": effect_magnitude,
	}
