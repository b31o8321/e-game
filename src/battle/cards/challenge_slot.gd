## ChallengeSlot resource — Challenge 模板中的一个填空槽
##
## 引擎通过 type / pos / tags / forbidden_tags 约束哪些卡可以放进来。
## 详见 docs/superpowers/specs/2026-05-04-battle-system-redesign.md
## 中"核心数据模型 → ChallengeSlot"小节。
class_name ChallengeSlot extends Resource

@export var index: int = 0
## 必需的 Card.type；空字符串 = 不限
@export var required_type: String = ""
## 必需的 Card.pos；空字符串 = 不限
@export var required_pos: String = ""
## 必需 tags（默认 any-match 即过；tag_match_mode="all" 时要求全部命中）
@export var required_tags: Array[String] = []
## 禁用 tags（any-match 即拒）
@export var forbidden_tags: Array[String] = []
## 该槽伤害倍率
@export var damage_multiplier: float = 1.0
## 严格白名单：只允许这些 card_id 放入；为空时回退到 type/pos/tags 匹配。
## 用途：当一句对话只有 1-3 张卡在语义上真正合理时，
## 用 accept_card_ids 锁死，避免"词性对就能放进来"的误导。
@export var accept_card_ids: Array[String] = []
## required_tags 匹配模式："any"（默认）或 "all"。
## - "any"：卡只要有任一 required_tag 即过（旧行为）
## - "all"：卡必须含全部 required_tag 才过（用于精确语义槽）
@export var tag_match_mode: String = "any"


## 从 Dictionary 构造 ChallengeSlot
static func from_dict(data: Dictionary) -> ChallengeSlot:
	var slot := ChallengeSlot.new()
	slot.index = int(data.get("index", 0))
	slot.required_type = str(data.get("required_type", ""))
	slot.required_pos = str(data.get("required_pos", ""))
	slot.damage_multiplier = float(data.get("damage_multiplier", 1.0))
	slot.tag_match_mode = str(data.get("tag_match_mode", "any"))

	var raw_required: Array = data.get("required_tags", [])
	var required: Array[String] = []
	for t in raw_required:
		required.append(str(t))
	slot.required_tags = required

	var raw_forbidden: Array = data.get("forbidden_tags", [])
	var forbidden: Array[String] = []
	for t in raw_forbidden:
		forbidden.append(str(t))
	slot.forbidden_tags = forbidden

	var raw_accept: Array = data.get("accept_card_ids", [])
	var accept: Array[String] = []
	for cid in raw_accept:
		accept.append(str(cid))
	slot.accept_card_ids = accept

	return slot


func to_dict() -> Dictionary:
	return {
		"index": index,
		"required_type": required_type,
		"required_pos": required_pos,
		"required_tags": required_tags,
		"forbidden_tags": forbidden_tags,
		"damage_multiplier": damage_multiplier,
		"accept_card_ids": accept_card_ids,
		"tag_match_mode": tag_match_mode,
	}
