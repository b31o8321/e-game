## DamageCalculator — 卡片战斗的伤害解算
##
## 公式：
##   base = sum(slot.damage_multiplier * card.base_damage)
##   mastery = 几何平均(各卡 mastery_multiplier)
##   crit = 2.0 if 全部填的卡 id 都在 template.perfect_match_card_ids else 1.0
##   weakness = 1.5 if 任意填的卡命中 enemy.weak_axes else 1.0
##   combo = clamp(1 + 0.05*combo_count, 1.0, 2.0)
##   final = round(base * mastery * crit * weakness * combo)
##
## 详见 docs/superpowers/specs/2026-05-04-battle-system-redesign.md
## 中"解算细节 → DamageCalculator"小节。
class_name DamageCalculator extends RefCounted


const COMBO_PER_STACK: float = 0.05
const COMBO_CAP: float = 2.0
const CRIT_MULTIPLIER: float = 2.0
const WEAKNESS_MULTIPLIER: float = 1.5


## 计算总伤害。filled_cards 顺序对应 template.slots 顺序；null 视为空槽（不计伤害）。
## 任一参数缺失返回 0。
static func calculate(
		filled_cards: Array,
		template: ChallengeTemplate,
		enemy: EnemyData,
		combo_count: int,
		srs: SRSSystem) -> int:
	if template == null or enemy == null:
		return 0
	if filled_cards.is_empty():
		return 0

	var base: float = _compute_base(filled_cards, template)
	if base <= 0.0:
		return 0

	var mastery: float = _compute_mastery_geomean(filled_cards, srs)
	var crit: float = _compute_crit(filled_cards, template)
	var weakness: float = _compute_weakness(filled_cards, enemy)
	var combo: float = compute_combo_multiplier(combo_count)

	var final: float = base * mastery * crit * weakness * combo
	return int(round(final))


## 提取连击倍率单独暴露（UI / 测试用）
static func compute_combo_multiplier(combo_count: int) -> float:
	if combo_count <= 0:
		return 1.0
	return min(COMBO_CAP, 1.0 + COMBO_PER_STACK * float(combo_count))


## 是否本次解算判定为暴击（所有非空槽的卡都在 perfect_match）
static func is_crit(filled_cards: Array, template: ChallengeTemplate) -> bool:
	return _compute_crit(filled_cards, template) > 1.0


## 是否本次解算命中弱点
static func is_weakness(filled_cards: Array, enemy: EnemyData) -> bool:
	return _compute_weakness(filled_cards, enemy) > 1.0


# ─── 私有 ─────────────────────────────────────────────────────────

static func _compute_base(filled_cards: Array, template: ChallengeTemplate) -> float:
	var sum: float = 0.0
	var slots: Array[ChallengeSlot] = template.slots
	for i in filled_cards.size():
		var card = filled_cards[i]
		if card == null or not (card is Card):
			continue
		var mul: float = 1.0
		if i < slots.size() and slots[i] != null:
			mul = slots[i].damage_multiplier
		sum += mul * float(card.base_damage)
	return sum


static func _compute_mastery_geomean(filled_cards: Array, srs: SRSSystem) -> float:
	# 几何平均 = (∏ x_i)^(1/n)；空集合返回 1.0
	var product: float = 1.0
	var n: int = 0
	for card in filled_cards:
		if card == null or not (card is Card):
			continue
		var lvl: int = MasterySystem.get_level(card.id, srs)
		var m: float = MasterySystem.get_multiplier(lvl)
		product *= m
		n += 1
	if n == 0:
		return 1.0
	return pow(product, 1.0 / float(n))


static func _compute_crit(filled_cards: Array, template: ChallengeTemplate) -> float:
	if template.perfect_match_card_ids.is_empty():
		return 1.0
	var has_filled: bool = false
	for card in filled_cards:
		if card == null or not (card is Card):
			continue
		has_filled = true
		if not (card.id in template.perfect_match_card_ids):
			return 1.0
	return CRIT_MULTIPLIER if has_filled else 1.0


static func _compute_weakness(filled_cards: Array, enemy: EnemyData) -> float:
	for card in filled_cards:
		if card == null or not (card is Card):
			continue
		if enemy.is_weakness_hit(card):
			return WEAKNESS_MULTIPLIER
	return 1.0
