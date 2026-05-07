## CardValidator — 引擎层的"卡片→槽位"匹配判定
##
## 完全学科无关：只看 type / pos / tags / forbidden_tags / accept_card_ids 字段。
## 详见 docs/superpowers/specs/2026-05-04-battle-system-redesign.md
## 中"解算细节 → Validator.can_place"小节。
class_name CardValidator extends RefCounted


## 判断一张卡能否放进某个槽。
## 任一约束不满足返回 false；全部满足返回 true。
##
## 优先级：
##   1. accept_card_ids（白名单，最高优先级；命中即过、不过即拒）
##   2. required_type
##   3. required_pos
##   4. required_tags（默认 any-match；tag_match_mode="all" 时要求全部命中）
##   5. forbidden_tags（任一命中即拒）
static func can_place(card: Card, slot: ChallengeSlot) -> bool:
	if card == null or slot == null:
		return false

	# 1. accept_card_ids 白名单：非空时强制只放白名单内的卡
	if not slot.accept_card_ids.is_empty():
		return card.id in slot.accept_card_ids

	# 2. type 约束
	if slot.required_type != "" and card.type != slot.required_type:
		return false

	# 3. pos 约束
	if slot.required_pos != "" and card.pos != slot.required_pos:
		return false

	# 4. required_tags
	if not slot.required_tags.is_empty():
		if slot.tag_match_mode == "all":
			# 卡必须包含全部 required_tag
			for required_tag in slot.required_tags:
				if not (required_tag in card.tags):
					return false
		else:
			# "any"（默认）：任一命中即过
			var has_any_required := false
			for t in card.tags:
				if t in slot.required_tags:
					has_any_required = true
					break
			if not has_any_required:
				return false

	# 5. forbidden_tags：any-match 即拒
	if not slot.forbidden_tags.is_empty():
		for t in card.tags:
			if t in slot.forbidden_tags:
				return false

	return true
