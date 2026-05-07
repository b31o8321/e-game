## test_elite_enemy — elite enemies + ability wiring in BattleController.
##
## Covers:
##   - Elite enemies (elite_letter_master / elite_book_keeper / elite_family_keeper)
##     loaded from enemies.json with HP > base + at least 1 ability
##   - Elite challenges referenced exist and are findable by their topic
##   - "敌人正在准备..." case (enemy with no topic_id / no challenges) is no longer
##     possible for elites — they have valid topic_id + challenge_template_ids
##   - BattleController.setup() instantiates _enemy_abilities from ability_ids
##   - turn_start ability (regen_2) heals enemy on enemy turn
##   - shield_each_turn_5 grants enemy_shield each turn
##   - shield_at_50 fires once when enemy HP drops below 50%
##   - multi_action_2 makes enemy attack twice per turn
##   - reflect_25 reflects 25% of damage back at player
##   - Elite enemy challenges solvable with floor starter deck (B5 hand-aware ok)
##   - Player-ability hook is initialized empty
extends GutTest


var loader: ContentLoader

func before_each() -> void:
	loader = ContentLoader.new()
	add_child_autofree(loader)
	await get_tree().process_frame
	loader.set_active_pack("english_grade46")


# ─── elite enemies in JSON ────────────────────────────────────────

func test_elite_letter_master_loaded() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var e: EnemyData = pack.get_enemy("elite_letter_master")
	assert_not_null(e, "elite_letter_master should exist in enemies.json")
	assert_gt(e.max_hp, 30, "elite HP > base normal letter_wisp HP (30)")
	assert_gt(e.ability_ids.size(), 0, "elite must have ≥1 ability")
	assert_ne(e.topic_id, "", "elite must have topic_id (else 敌人正在准备... appears)")
	assert_gt(e.challenge_template_ids.size(), 0,
		"elite must reference challenge_template_ids (else selector returns null)")


func test_elite_book_keeper_loaded() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var e: EnemyData = pack.get_enemy("elite_book_keeper")
	assert_not_null(e, "elite_book_keeper should exist")
	assert_gt(e.max_hp, 60, "elite HP > base bookworm")
	assert_gt(e.ability_ids.size(), 0)
	assert_ne(e.topic_id, "")


func test_elite_family_keeper_loaded() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var e: EnemyData = pack.get_enemy("elite_family_keeper")
	assert_not_null(e, "elite_family_keeper should exist")
	assert_gt(e.max_hp, 70)
	assert_gt(e.ability_ids.size(), 0)
	assert_ne(e.topic_id, "")


func test_all_elite_challenge_template_ids_exist() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	for elite_id in ["elite_letter_master", "elite_book_keeper", "elite_family_keeper"]:
		var e: EnemyData = pack.get_enemy(elite_id)
		assert_not_null(e, "elite enemy %s exists" % elite_id)
		for tid in e.challenge_template_ids:
			var tmpl: ChallengeTemplate = pack.get_challenge_template(tid)
			assert_not_null(tmpl,
				"elite %s references challenge %s — must exist" % [elite_id, tid])


func test_elite_topic_pool_non_empty() -> void:
	# 关键：精英 topic_id 对应的题池必须非空，否则 ChallengeSelector 返回 null
	# 触发 "敌人正在准备..." 的根因。
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	for elite_id in ["elite_letter_master", "elite_book_keeper", "elite_family_keeper"]:
		var e: EnemyData = pack.get_enemy(elite_id)
		var pool: Array[ChallengeTemplate] = pack.get_challenges_for_topic(e.topic_id)
		assert_gt(pool.size(), 0,
			"elite %s topic_id=%s topic pool must be non-empty" % [elite_id, e.topic_id])


# ─── BattleController wires enemy abilities ───────────────────────

func _make_card(overrides: Dictionary = {}) -> Card:
	var base := {
		"id": "card_test",
		"text": "test",
		"type": "word",
		"pos": "adjective",
		"tags": [],
		"skill": "vocab",
		"base_damage": 5,
		"rarity": "common",
	}
	for k in overrides.keys():
		base[k] = overrides[k]
	return Card.from_dict(base)


func _make_template_one_slot() -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": "tmpl_test",
		"kind": "fill_in_blank",
		"dialogue": "I am ___",
		"slots": [{
			"index": 0,
			"required_pos": "adjective",
			"required_type": "",
			"required_tags": [],
			"forbidden_tags": [],
			"damage_multiplier": 1.0,
		}],
		"topic_id": "test",
	})


func _make_enemy_with_abilities(ability_ids: Array, hp: int = 100, atk: int = 5) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_elite"
	e.enemy_name = "Test Elite"
	e.max_hp = hp
	e.base_attack = atk
	var arr: Array[String] = []
	for v in ability_ids:
		arr.append(str(v))
	e.ability_ids = arr
	return e


class _AlwaysSelector extends ChallengeSelector:
	var template: ChallengeTemplate
	func _init() -> void:
		super()
	func pick_challenge(_enemy, _pack, _srs) -> ChallengeTemplate:
		return template


func _build_controller_with_enemy(enemy: EnemyData, deck_size: int = 12) -> BattleController:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var deck: Array[Card] = []
	for i in deck_size:
		deck.append(_make_card({"id": "card_%d" % i, "text": "x%d" % i}))
	ctrl.setup(enemy, null, deck, null)
	var sel := _AlwaysSelector.new()
	sel.template = _make_template_one_slot()
	ctrl.set_selector(sel)
	ctrl.start_battle()
	return ctrl


func test_setup_instantiates_enemy_abilities_from_ids() -> void:
	var enemy := _make_enemy_with_abilities(["regen_2", "shield_at_50"])
	var ctrl := _build_controller_with_enemy(enemy)
	assert_eq(ctrl._enemy_abilities.size(), 2)


func test_setup_skips_unknown_ability_ids() -> void:
	var enemy := _make_enemy_with_abilities(["regen_2", "totally_fake"])
	var ctrl := _build_controller_with_enemy(enemy)
	assert_eq(ctrl._enemy_abilities.size(), 1, "unknown id silently dropped")


func test_player_abilities_initially_empty() -> void:
	var enemy := _make_enemy_with_abilities([])
	var ctrl := _build_controller_with_enemy(enemy)
	assert_eq(ctrl._player_abilities.size(), 0,
		"player abilities are empty stub (装备 / 技能后续填充)")


# ─── turn_start abilities ────────────────────────────────────────

func test_regen_2_heals_enemy_on_enemy_turn() -> void:
	var enemy := _make_enemy_with_abilities(["regen_2"], 100, 0)
	var ctrl := _build_controller_with_enemy(enemy)
	# 用一张卡掉敌人 HP（damage 走 placeholder slot/template，但我们
	# 直接让它通过 try_place_card → submit）。简便：直接修改 enemy_hp。
	ctrl.enemy_hp = 50
	# 触发敌人回合（通过 end_player_turn）
	ctrl.end_player_turn()
	assert_eq(ctrl.enemy_hp, 52,
		"regen_2 ability heals enemy +2 HP at turn start (50 → 52)")


func test_regen_does_not_overheal_above_max_hp() -> void:
	var enemy := _make_enemy_with_abilities(["regen_3"], 50, 0)
	var ctrl := _build_controller_with_enemy(enemy)
	ctrl.enemy_hp = 49
	ctrl.end_player_turn()
	assert_eq(ctrl.enemy_hp, 50, "regen capped at max_hp (49+3 → 50, not 52)")


func test_shield_each_turn_grants_enemy_shield() -> void:
	var enemy := _make_enemy_with_abilities(["shield_each_turn_5"], 100, 0)
	var ctrl := _build_controller_with_enemy(enemy)
	assert_eq(ctrl.enemy_shield, 0)
	ctrl.end_player_turn()
	assert_eq(ctrl.enemy_shield, 5,
		"shield_each_turn_5 adds +5 enemy_shield at enemy turn start")
	# 多回合累加
	ctrl.end_player_turn()
	assert_eq(ctrl.enemy_shield, 10, "shield accumulates across turns")


func test_multi_action_2_makes_enemy_attack_twice() -> void:
	var enemy := _make_enemy_with_abilities(["multi_action_2"], 100, 5)
	var ctrl := _build_controller_with_enemy(enemy)
	var before_hp: int = ctrl.player_hp
	ctrl.player_shield = 0
	ctrl.end_player_turn()
	# 一次基础攻击 + 一次额外攻击 = 2 × 5 = 10 伤害
	assert_eq(before_hp - ctrl.player_hp, 10,
		"multi_action_2 → enemy attacks twice (10 damage total, not 5)")


# ─── on_hp_threshold ──────────────────────────────────────────────

func test_shield_at_50_fires_once_when_hp_below_threshold() -> void:
	var enemy := _make_enemy_with_abilities(["shield_at_50"], 100, 0)
	var ctrl := _build_controller_with_enemy(enemy)
	# 用卡攻击让 enemy_hp 降低（直接调用内部 damage 路径 — submit_challenge
	# 走 ChallengeEffects → damage_to_enemy）。简便：直接调 enemy_hp 然后
	# 通过 try_place_card 模拟一次伤害事件以触发 _apply_enemy_abilities("on_hp_threshold")。
	#
	# 实际上 `_apply_enemy_abilities("on_hp_threshold")` 是在 submit_challenge
	# 的 damage 分支里手动调用，所以我们用一张卡命中模板。
	ctrl.enemy_hp = 100
	# 直接降到 49（≤50%）然后在下次伤害事件触发能力
	ctrl.enemy_hp = 49
	# 模拟一次伤害事件触发能力（即使伤害=1，只要进入 damage 分支）
	# 通过 try_place_card：放一张匹配 adjective 的卡——但 _make_card 默认
	# 已经是 adjective + skill=vocab + base_damage=5，模板要求 pos=adjective 即可放置。
	# 第一次玩家攻击后 _apply_enemy_abilities("on_hp_threshold") 应触发 shield_at_50。
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0)
	assert_gt(ctrl.enemy_shield, 0,
		"shield_at_50 fires when HP ≤ 50%, granting +20 enemy_shield")


func test_shield_at_50_does_not_re_fire() -> void:
	var enemy := _make_enemy_with_abilities(["shield_at_50"], 100, 0)
	var ctrl := _build_controller_with_enemy(enemy)
	ctrl.enemy_hp = 49
	ctrl.try_place_card(ctrl.hand[0], 0)
	var first_shield: int = ctrl.enemy_shield
	assert_gt(first_shield, 0, "first hit triggers")
	# Re-trigger another hit while still under 50% — should not stack.
	# Shield may go DOWN as 2nd attack consumes it, but should not increase by another +20.
	ctrl.enemy_hp = 30
	ctrl.try_place_card(ctrl.hand[0], 0)
	# enemy_shield should NOT have grown beyond first_shield (one-time trigger)
	assert_lte(ctrl.enemy_shield, first_shield,
		"shield_at_50 is one-time; second hit must not add another +20 (got %d, was %d)" % [
			ctrl.enemy_shield, first_shield])


# ─── enemy_shield absorbs damage ──────────────────────────────────

func test_enemy_shield_absorbs_damage_before_hp() -> void:
	var enemy := _make_enemy_with_abilities([], 100, 0)
	var ctrl := _build_controller_with_enemy(enemy)
	ctrl.enemy_shield = 10
	ctrl.enemy_hp = 100
	# 玩家攻击；damage 应先扣 enemy_shield
	ctrl.try_place_card(ctrl.hand[0], 0)
	# 即使伤害 ≥ 1 只要 ≤ 10 应该全被盾抵掉，HP 保持 100
	# 默认 base_damage=5 + 模板 base_damage 倍率，按 DamageCalculator 算结果
	# 这里我们只断言：enemy_shield 减少了或 enemy_hp 没掉成 0
	assert_lt(ctrl.enemy_shield, 10,
		"enemy_shield should absorb damage")


# ─── reflect ──────────────────────────────────────────────────────

func test_reflect_25_returns_damage_to_player() -> void:
	var enemy := _make_enemy_with_abilities(["reflect_25"], 1000, 0)
	var ctrl := _build_controller_with_enemy(enemy)
	ctrl.player_hp = 100
	ctrl.player_shield = 0
	var before_player: int = ctrl.player_hp
	# 打一次——应有反伤
	ctrl.try_place_card(ctrl.hand[0], 0)
	# 玩家 HP 应有损失（25% × 伤害 ≥ 1）
	assert_lt(ctrl.player_hp, before_player,
		"reflect_25 damages player when player attacks enemy")


# ─── elite challenges solvable with floor starter deck ──────────

func test_0F_elite_challenges_solvable_with_0F_starter_deck() -> void:
	# 验证 0F 起手牌组对至少一道精英题可解（B5 hand-aware filter 不会全跳过）
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var deck_ids: Array = pack.get_starting_deck_for_floor("0F")
	var hand: Array[Card] = []
	for cid in deck_ids:
		var c: Card = pack.get_card(cid)
		if c != null:
			hand.append(c)
	# 至少一道 0F 精英题用 hand 可解
	var any_solvable: bool = false
	for tid in ["0F_elite_phonics_cat_full", "0F_elite_phonics_dog_full",
			"0F_elite_alphabet_seq"]:
		var tmpl: ChallengeTemplate = pack.get_challenge_template(tid)
		if tmpl == null:
			continue
		if _hand_can_solve(hand, tmpl):
			any_solvable = true
			break
	assert_true(any_solvable,
		"0F starter deck must be able to solve ≥1 elite challenge")


func test_1F_elite_challenges_solvable_with_1F_starter_deck() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var deck_ids: Array = pack.get_starting_deck_for_floor("1F")
	var hand: Array[Card] = []
	for cid in deck_ids:
		var c: Card = pack.get_card(cid)
		if c != null:
			hand.append(c)
	var any_solvable: bool = false
	for tid in ["1F_elite_personality_pair", "1F_elite_be_pattern_pair",
			"1F_elite_emotion_listen"]:
		var tmpl: ChallengeTemplate = pack.get_challenge_template(tid)
		if tmpl == null:
			continue
		if _hand_can_solve(hand, tmpl):
			any_solvable = true
			break
	assert_true(any_solvable,
		"1F starter deck must be able to solve ≥1 elite challenge")


func test_2F_elite_challenges_solvable_with_2F_starter_deck() -> void:
	var pack: ContentPackBase = loader.get_pack("english_grade46")
	var deck_ids: Array = pack.get_starting_deck_for_floor("2F")
	var hand: Array[Card] = []
	for cid in deck_ids:
		var c: Card = pack.get_card(cid)
		if c != null:
			hand.append(c)
	var any_solvable: bool = false
	for tid in ["2F_elite_family_body", "2F_elite_pronoun_be",
			"2F_elite_pronoun_object"]:
		var tmpl: ChallengeTemplate = pack.get_challenge_template(tid)
		if tmpl == null:
			continue
		if _hand_can_solve(hand, tmpl):
			any_solvable = true
			break
	assert_true(any_solvable,
		"2F starter deck must be able to solve ≥1 elite challenge")


## Greedy hand-can-solve check (mirrors BattleController._can_solve_with_hand).
func _hand_can_solve(hand: Array[Card], template: ChallengeTemplate) -> bool:
	if template == null:
		return true
	var slots: Array = template.slots
	if slots.is_empty():
		return true
	var used: Array[int] = []
	for slot in slots:
		var found: int = -1
		for i in hand.size():
			if i in used:
				continue
			if CardValidator.can_place(hand[i], slot):
				found = i
				break
		if found == -1:
			return false
		used.append(found)
	return true
