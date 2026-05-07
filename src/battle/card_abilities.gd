## CardAbilities — 卡片能力计算器（B4：游戏性优先重构）
##
## 卡片现在带 ability_type / ability_magnitude，结算 challenge 时与
## 题目效果（ChallengeEffects）叠加产生最终伤害 / 治疗 / 抽牌。
##
## 各能力类型语义：
##   "none"          — 无额外能力（默认）
##   "draw_card"     — 此卡填槽 → 提交时额外抽 N 张
##   "draw_question" — 此卡填槽 → 提交时给棋盘加 N 道题
##   "double_effect" — 当前题结算的效果 ×2（damage_modifier）
##   "chain_bonus"   — 与上一张已填卡共享 tag 时，伤害 ×1.5
##   "heal_on_use"   — 此卡每次填槽都回血 N
##   "combo_charge"  — 命中时连击 +2（额外加 1）
##
## 用法：BattleController.submit_challenge 在 ChallengeEffects.apply 之前
## 调用 apply_pre_submit() 拿到累积修饰；然后把 damage_modifier 应用到
## base_damage，再调 ChallengeEffects.apply 拿到 effects；最后把
## extra_heal / extra_draw / queue_questions 等卡专属字段加到结果上。
class_name CardAbilities extends RefCounted


## 累积一组卡（一道题里所有已填的卡）的能力作用。返回一个 Dictionary：
##   damage_modifier: float    — 整体伤害倍率（用于 double_effect / chain_bonus）
##   heal_modifier:   float    — 整体回血倍率（double_effect 也作用于 heal）
##   shield_modifier: float    — 整体护盾倍率（double_effect 也作用于 shield）
##   extra_draw:      int      — 额外抽牌数（draw_card 累加）
##   extra_heal:      int      — 额外回血数（heal_on_use 累加）
##   queue_questions: int      — 加题数（draw_question 累加）
##   combo_extra:     int      — 命中时额外连击数（combo_charge 累加）
static func apply_pre_submit(_controller, cards: Array, _base: int) -> Dictionary:
	var result := {
		"damage_modifier": 1.0,
		"heal_modifier": 1.0,
		"shield_modifier": 1.0,
		"extra_draw": 0,
		"extra_heal": 0,
		"queue_questions": 0,
		"combo_extra": 0,
	}
	# chain_bonus 需要"上一张已填卡"的引用——按填槽顺序处理
	for i in cards.size():
		var c = cards[i]
		if not (c is Card):
			continue
		var card := c as Card
		var atype: String = card.ability_type
		var mag: int = max(0, card.ability_magnitude)
		match atype:
			"draw_card":
				result["extra_draw"] = int(result["extra_draw"]) + max(1, mag)
			"draw_question":
				result["queue_questions"] = int(result["queue_questions"]) + max(1, mag)
			"double_effect":
				result["damage_modifier"] = float(result["damage_modifier"]) * 2.0
				result["heal_modifier"] = float(result["heal_modifier"]) * 2.0
				result["shield_modifier"] = float(result["shield_modifier"]) * 2.0
			"heal_on_use":
				result["extra_heal"] = int(result["extra_heal"]) + max(1, mag)
			"chain_bonus":
				# 找前面任意一张共享 tag 的卡 → 整体 ×1.5
				var multiplier: float = _chain_bonus_multiplier(cards, i)
				result["damage_modifier"] = float(result["damage_modifier"]) * multiplier
			"combo_charge":
				result["combo_extra"] = int(result["combo_extra"]) + max(1, mag)
			_:
				pass
	return result


## 给定 cards[idx]（chain_bonus 卡），找前面任意位置的卡共享至少 1 个 tag，
## 共享则返回 1.5；否则 1.0。
static func _chain_bonus_multiplier(cards: Array, idx: int) -> float:
	if idx <= 0:
		return 1.0
	var cur = cards[idx]
	if not (cur is Card):
		return 1.0
	var cur_card := cur as Card
	if cur_card.tags.is_empty():
		return 1.0
	for j in idx:
		var prev = cards[j]
		if not (prev is Card):
			continue
		var prev_card := prev as Card
		for tag in cur_card.tags:
			if tag in prev_card.tags:
				return 1.5
	return 1.0


## 友好显示名（UI 标签 / 调试用）
static func display_name(ability_type: String) -> String:
	match ability_type:
		"none", "":
			return ""
		"draw_card":
			return "抽牌"
		"draw_question":
			return "加题"
		"double_effect":
			return "效果翻倍"
		"chain_bonus":
			return "连锁"
		"heal_on_use":
			return "回血"
		"combo_charge":
			return "连击充能"
	return ability_type


## 友好图标（emoji）— 用于卡牌右下角徽章。
static func icon(ability_type: String) -> String:
	match ability_type:
		"draw_card":
			return "🎴"
		"draw_question":
			return "📚"
		"double_effect":
			return "⚡"
		"chain_bonus":
			return "🔗"
		"heal_on_use":
			return "💚"
		"combo_charge":
			return "🔥"
	return ""


## 是否有非 none 能力
static func has_ability(card: Card) -> bool:
	if card == null:
		return false
	return card.ability_type != "" and card.ability_type != "none"
