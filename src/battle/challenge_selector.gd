## ChallengeSelector — 为敌人挑选 ChallengeTemplate
##
## 30% 概率从 SRS 弱点主题挑选；70% 概率从敌人主题随机挑。
## 详见 docs/superpowers/specs/2026-05-04-battle-system-redesign.md
## 中"反舒适区刷分机制 → SRS 驱动的针对性敌人"小节。
##
## 注：此类持有一个 RNG，便于测试时注入种子。生产环境用默认随机化。
class_name ChallengeSelector extends RefCounted


const WEAK_TOPIC_CHANCE: float = 0.3
const WEAK_TOP_K: int = 3


var _rng: RandomNumberGenerator
## 反舒适区：Boss 战时，BattleController 调 set_required_coverage(boss.requires_topic_coverage)
## 让 selector 按子主题轮询，确保整场战斗覆盖所有子主题。空数组 = 不强制。
var _required_coverage: Array[String] = []
var _coverage_cursor: int = 0


func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()


## 测试用：注入固定种子的 RNG
func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Boss 战开始时由 BattleController 调用：设定本场必须轮询的子主题。
## 之后每次 pick_challenge 会按 cursor 推进，确保 Boss 覆盖每个子主题至少一次。
func set_required_coverage(sub_topic_ids: Array) -> void:
	_required_coverage = []
	for v in sub_topic_ids:
		var s: String = str(v)
		if s != "":
			_required_coverage.append(s)
	_coverage_cursor = 0


## 挑选 ChallengeTemplate；任一依赖缺失或没合适模板时返回 null。
func pick_challenge(
		enemy: EnemyData,
		pack: ContentPackBase,
		srs: SRSSystem) -> ChallengeTemplate:
	if enemy == null or pack == null:
		return null

	# Boss 强制覆盖优先：按 cursor 轮询 _required_coverage 中的子主题，
	# 漏一个 = 那道题没卡填 = 必受伤。
	if not _required_coverage.is_empty():
		var topic: String = _required_coverage[_coverage_cursor % _required_coverage.size()]
		_coverage_cursor += 1
		var t: ChallengeTemplate = _pick_from_topic(pack, topic)
		if t != null:
			return t
		# 找不到该子主题模板时降级到敌人主题池

	var roll: float = _rng.randf()

	if roll < WEAK_TOPIC_CHANCE and srs != null and srs.has_weak_questions():
		var weak_ids: Array[String] = srs.get_weakest_card_ids(WEAK_TOP_K)
		var weak_pick: ChallengeTemplate = _find_template_using_cards(pack, weak_ids)
		if weak_pick != null:
			return weak_pick
		# 无法用弱点卡找到模板时降级到主题池

	return _pick_from_topic(pack, enemy.topic_id)


# ─── 私有 ─────────────────────────────────────────────────────────

## 在主题池里随机选一个
func _pick_from_topic(pack: ContentPackBase, topic_id: String) -> ChallengeTemplate:
	if topic_id == "":
		return null
	var pool: Array[ChallengeTemplate] = pack.get_challenges_for_topic(topic_id)
	if pool.is_empty():
		return null
	var idx: int = _rng.randi_range(0, pool.size() - 1)
	return pool[idx]


## 在 pack 中找一个 perfect_match 包含 weak_card_ids 的模板。
## 仅遍历 pack.get_challenges_for_topic 是有限的；MVP 实现：
## 通过尝试每个 weak_card_id 当作 topic_id（若同名）+ 无法直接列出全模板时返回 null。
## Phase 2 待 ContentPackBase 提供 get_all_challenge_templates() 后改实现。
func _find_template_using_cards(
		pack: ContentPackBase,
		weak_card_ids: Array[String]) -> ChallengeTemplate:
	# 现阶段无 get_all_challenges() 接口，先按规则：
	# 把 weak_card_ids 第一个 id 当 hint topic 试着抓主题；找不到返回 null。
	# 在 BattleController 中 30% 几率走到这里失败时会降级到主题池。
	for card_id in weak_card_ids:
		var pool: Array[ChallengeTemplate] = pack.get_challenges_for_topic(card_id)
		for tmpl in pool:
			if tmpl == null:
				continue
			if card_id in tmpl.perfect_match_card_ids:
				return tmpl
	return null
