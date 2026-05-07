## APConnection — 玩家在 AP 队列里的一条连线
##
## 字段：
##   slot_index           队列位置（0-based）
##   card                 出的卡
##   challenge_index      题板上的题索引
##   question_slot_index  题里的具体槽
##   preview              结算前预估 {damage, heal, ...}
class_name APConnection extends RefCounted

var slot_index: int = 0
var card: Card = null
var challenge_index: int = -1
var question_slot_index: int = 0
var preview: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"slot_index": slot_index,
		"card_id": card.id if card else "",
		"challenge_index": challenge_index,
		"question_slot_index": question_slot_index,
		"preview": preview.duplicate(),
	}
