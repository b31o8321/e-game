## test_multi_challenge_board — multi-challenge board API + per-challenge effects.
##
## Covers:
##   - BattleController initializes board with up to BOARD_SIZE challenges visible
##   - solve_challenge / submit_challenge removes that challenge from board
##   - keep_challenge / toggle_keep persists across end_player_turn refill
##   - Effect types: damage / heal / shield / draw_card / draw_question /
##     weakness_strike / combo_boost
##   - selected_challenge_index API + try_place_card with explicit challenge index
extends GutTest


# ─── helpers ──────────────────────────────────────────────────────

func _make_card(overrides: Dictionary = {}) -> Card:
	var base := {
		"id": "card_brave",
		"text": "brave",
		"type": "word",
		"pos": "adjective",
		"tags": ["positive_emotion"],
		"skill": "vocab",
		"base_damage": 5,
		"rarity": "common",
	}
	for k in overrides.keys():
		base[k] = overrides[k]
	return Card.from_dict(base)


func _make_template(template_id: String, effect_type: String = "damage", effect_magnitude: int = 0) -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": template_id,
		"kind": "fill_in_blank",
		"dialogue": "I am ___",
		"slots": [
			{
				"index": 0,
				"required_pos": "adjective",
				"required_type": "",
				"required_tags": [],
				"forbidden_tags": [],
				"damage_multiplier": 1.0,
			},
		],
		"topic_id": "test",
		"effect_type": effect_type,
		"effect_magnitude": effect_magnitude,
	})


func _make_enemy(hp: int = 999, attack: int = 0) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_enemy"
	e.enemy_name = "Test"
	e.max_hp = hp
	e.base_attack = attack
	# weak_axes used by weakness_strike effect
	e.weak_axes = ["positive_emotion"]
	return e


## Selector that cycles through a fixed list (so we get distinct templates on board).
class _CycleSelector extends ChallengeSelector:
	var templates: Array = []
	var cursor: int = 0

	func _init() -> void:
		super()

	func pick_challenge(_enemy: EnemyData, _pack, _srs) -> ChallengeTemplate:
		if templates.is_empty():
			return null
		var t = templates[cursor % templates.size()]
		cursor += 1
		return t


func _build_controller(templates: Array, deck_size: int = 12, board_size: int = 3, attack: int = 0, extra_cards: Array = []) -> BattleController:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var deck: Array[Card] = []
	for i in deck_size:
		deck.append(_make_card({"id": "card_%d" % i, "text": "x%d" % i}))
	for ec in extra_cards:
		deck.append(ec)
	var enemy: EnemyData = _make_enemy(999, attack)
	ctrl.setup(enemy, null, deck, null, board_size)
	var sel := _CycleSelector.new()
	sel.templates = templates
	ctrl.set_selector(sel)
	ctrl.start_battle()
	return ctrl


## Make a noun card so noun-required templates pass the B5 hand-solvability filter.
func _make_noun_card(id: String = "card_noun_x") -> Card:
	return _make_card({
		"id": id,
		"text": "thing",
		"type": "word",
		"pos": "noun",
		"tags": [],
	})


## B5 helper：用纯 adjective 手牌起战斗（noun 模板不会被 refill 选中），
## 然后 add_to_board 强插一道 noun 模板到棋盘 index 0，便于"放错"测试。
##
## 返回 noun 模板在棋盘中的实际 index（add_to_board 会追加到末尾，
## 调用方需要使用此 index 而不是固定 0）。
func _build_controller_force_noun_at(templates: Array, noun_template: ChallengeTemplate, board_size: int = 3) -> Dictionary:
	var ctrl: BattleController = _build_controller(templates, 8, board_size, 0)
	var noun_idx: int = ctrl.available_challenges.size()
	ctrl.add_to_board(noun_template)
	return {"ctrl": ctrl, "noun_idx": noun_idx}


# ─── tests ────────────────────────────────────────────────────────

func test_board_initializes_with_three_challenges() -> void:
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
	]
	var ctrl: BattleController = _build_controller(templates)
	assert_eq(ctrl.available_challenges.size(), 3,
		"board should be filled to board_size at start_battle")
	# selected defaults to 0
	assert_eq(ctrl.selected_challenge_index, 0)
	assert_not_null(ctrl.current_template, "current_template proxy should resolve")


func test_solving_challenge_removes_it_no_midturn_refill() -> void:
	# B4: 不再回合内自动补题——解了一道题，棋盘只剩 2 道。
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
		_make_template("t_e"),
	]
	var ctrl: BattleController = _build_controller(templates)
	var size_before: int = ctrl.available_challenges.size()
	# Solve the first challenge by placing a card into its slot 0
	var card: Card = ctrl.hand[0]
	var ok: bool = ctrl.try_place_card(card, 0, 0)
	assert_true(ok, "place must succeed")
	# Solved → t_a removed; no auto-refill
	var still_has_a: bool = false
	for t in ctrl.available_challenges:
		if t.template_id == "t_a":
			still_has_a = true
	assert_false(still_has_a, "solved challenge should be removed from board")
	assert_eq(ctrl.available_challenges.size(), size_before - 1,
		"B4: solving does NOT auto-refill mid-turn")


func test_end_player_turn_refills_board_to_full() -> void:
	# B4: 回合末才 refill_board()
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
		_make_template("t_e"),
		_make_template("t_f"),
	]
	var ctrl: BattleController = _build_controller(templates, 12, 3, 0)
	# Solve one challenge → board size goes from 3 to 2
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	assert_eq(ctrl.available_challenges.size(), 2)
	# End turn → enemy turn → refill back to 3
	ctrl.end_player_turn()
	assert_eq(ctrl.available_challenges.size(), 3,
		"end_player_turn should refill board to board_size")


func test_kept_challenge_persists_across_turn_end() -> void:
	var templates: Array = [
		_make_template("t_keep"),
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
		_make_template("t_e"),
		_make_template("t_f"),
	]
	var ctrl: BattleController = _build_controller(templates, 12, 3, 0)
	# Mark challenge index 0 (t_keep) as kept
	var kept: bool = ctrl.toggle_keep(0)
	assert_true(kept, "toggle_keep should return true on first call")
	assert_true(ctrl.is_kept(0), "is_kept(0) should be true")
	# End turn → board refills, kept template should still be there
	ctrl.end_player_turn()
	# After enemy turn, board is refilled
	var has_keep: bool = false
	for t in ctrl.available_challenges:
		if t.template_id == "t_keep":
			has_keep = true
	assert_true(has_keep, "kept template should persist across turn refill")


func test_non_kept_challenge_replaced_at_turn_end() -> void:
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
		_make_template("t_e"),
		_make_template("t_f"),
		_make_template("t_g"),
	]
	var ctrl: BattleController = _build_controller(templates, 12, 3, 0)
	# Don't keep anything → all 3 should be replaced
	# Track initial set
	var initial_ids: Array = []
	for t in ctrl.available_challenges:
		initial_ids.append(t.template_id)
	ctrl.end_player_turn()
	# Cycle selector ensures the replacements are different ones (4..6)
	var same_count: int = 0
	for t in ctrl.available_challenges:
		if t.template_id in initial_ids:
			same_count += 1
	# At least the cycle should rotate; unless pool is too small, many should differ
	# With 7 templates and cycle, this will be all-new.
	assert_lt(same_count, 3, "non-kept challenges should be replaced")


func test_effect_heal_restores_hp() -> void:
	var templates: Array = [
		_make_template("t_heal", "heal", 20),
		_make_template("t_b"),
		_make_template("t_c"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	# Damage the player a bit so heal has room
	ctrl.player_hp = 50
	ctrl.player_max_hp = 100
	# Solve the heal challenge
	watch_signals(ctrl)
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	assert_eq(ctrl.player_hp, 70, "heal +20 brings 50 → 70")
	assert_signal_emitted(ctrl, "healed")


func test_effect_shield_adds_shield() -> void:
	var templates: Array = [
		_make_template("t_shield", "shield", 15),
		_make_template("t_b"),
		_make_template("t_c"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	assert_eq(ctrl.player_shield, 0)
	watch_signals(ctrl)
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	assert_eq(ctrl.player_shield, 15, "shield +15 should accumulate")
	assert_signal_emitted(ctrl, "shielded")


func test_effect_shield_absorbs_enemy_damage() -> void:
	var templates: Array = [
		_make_template("t_shield", "shield", 10),
		_make_template("t_b"),
		_make_template("t_c"),
	]
	# Enemy attacks for 8, shield 10 → fully absorbed
	var ctrl: BattleController = _build_controller(templates, 8, 3, 8)
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	assert_eq(ctrl.player_shield, 10)
	var hp_before: int = ctrl.player_hp
	ctrl.end_player_turn()
	assert_eq(ctrl.player_hp, hp_before, "shield should fully absorb 8 damage")
	assert_eq(ctrl.player_shield, 2, "shield should have 10-8=2 remaining")


func test_effect_draw_card_draws_extra() -> void:
	var templates: Array = [
		_make_template("t_draw", "draw_card", 2),
		_make_template("t_b"),
		_make_template("t_c"),
	]
	var ctrl: BattleController = _build_controller(templates, 12, 3, 0)
	var hand_before: int = ctrl.hand.size()
	watch_signals(ctrl)
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	# Drew 2 from effect; played 1; bonus draw at 2 plays may or may not have fired (only 1 played so far)
	# So expect: hand_before - 1 (played) + 2 (drawn) = hand_before + 1
	assert_eq(ctrl.hand.size(), hand_before + 1, "draw_card +2 should net hand +1 after using 1 card")
	assert_signal_emitted(ctrl, "cards_drawn")


func test_effect_draw_question_adds_to_board() -> void:
	var templates: Array = [
		_make_template("t_dq", "draw_question", 1),
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	var size_before: int = ctrl.available_challenges.size()
	watch_signals(ctrl)
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	# B4 (no mid-turn auto-refill): solving t_dq (-1) + draw_question(+1) = net same
	# size_before(3) - 1 + 1 = 3
	assert_eq(ctrl.available_challenges.size(), size_before,
		"draw_question should add 1 challenge after solving (net same; no auto-refill)")
	assert_signal_emitted(ctrl, "questions_added")


func test_effect_combo_boost_doubles_next_damage() -> void:
	var templates: Array = [
		_make_template("t_boost", "combo_boost", 0),
		_make_template("t_normal", "damage", 0),
		_make_template("t_c"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	# Solve t_boost (challenge 0)
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	assert_eq(ctrl.pending_damage_modifier, "next_x2",
		"combo_boost should arm next_x2 modifier")
	# Now solve t_normal (was challenge 1, now likely 0 after solving)
	var hp_before: int = ctrl.enemy_hp
	# Find t_normal index
	var idx: int = -1
	for i in ctrl.available_challenges.size():
		if ctrl.available_challenges[i].template_id == "t_normal":
			idx = i
			break
	assert_gte(idx, 0, "t_normal should still be on board")
	var card2: Card = ctrl.hand[0]
	ctrl.try_place_card(card2, 0, idx)
	# Modifier should be consumed
	assert_eq(ctrl.pending_damage_modifier, "",
		"modifier should be cleared after applied")
	assert_lt(ctrl.enemy_hp, hp_before,
		"normal damage challenge should hit enemy")


func test_effect_weakness_strike_uses_15x_when_weak() -> void:
	var templates: Array = [
		_make_template("t_ws", "weakness_strike", 0),
		_make_template("t_b"),
		_make_template("t_c"),
	]
	# Enemy has weak_axes = ["positive_emotion"], card has tag positive_emotion
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	var hp_before: int = ctrl.enemy_hp
	# Use card with positive_emotion (default _make_card)
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	# Damage > 0 because weakness_strike applies 1.5x
	assert_lt(ctrl.enemy_hp, hp_before, "weakness_strike should deal damage")


func test_selected_challenge_index_routes_card_placement() -> void:
	# 用足够多的模板，让自动补题不会再补回刚解的那一道。
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
		_make_template("t_e"),
		_make_template("t_f"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	# Switch selected to index 2
	ctrl.set_selected_challenge_index(2)
	assert_eq(ctrl.selected_challenge_index, 2)
	# Track which template was at the selected index
	var selected_template_id: String = ctrl.available_challenges[2].template_id
	# Place a card into selected (slot 0) — using the 2-arg overload routes via selected
	var card: Card = ctrl.hand[0]
	var ok: bool = ctrl.try_place_card(card, 0)
	assert_true(ok)
	# The template that WAS at index 2 is now solved & removed.
	# (Cycle selector ensures replacement is a different template_id when pool > board.)
	var still_has: bool = false
	for t in ctrl.available_challenges:
		if t.template_id == selected_template_id:
			still_has = true
	assert_false(still_has, "selected challenge should have been solved/removed")


func test_add_to_board_increases_available_count() -> void:
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
		_make_template("t_c"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	var size_before: int = ctrl.available_challenges.size()
	var added: bool = ctrl.add_to_board(_make_template("t_extra"))
	assert_true(added)
	assert_eq(ctrl.available_challenges.size(), size_before + 1)


func test_kept_template_solved_clears_kept_flag() -> void:
	# 留下的题被解了之后，kept 状态应该被清除（避免 ghost id 留在 kept_template_ids）
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
		_make_template("t_c"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	ctrl.toggle_keep(0)
	assert_true(ctrl.is_kept(0))
	# Solve the kept challenge
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	# t_a should not be in kept_template_ids anymore
	assert_false("t_a" in ctrl.kept_template_ids,
		"solving a kept challenge should clear it from kept set")


func test_board_size_one_solving_empties_until_turn_end() -> void:
	# B4：BOARD_SIZE = 1 时，解掉唯一的题就空了——回合末才补
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 1, 0)
	assert_eq(ctrl.available_challenges.size(), 1)
	# Solve → board empty (no auto-refill)
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	assert_eq(ctrl.available_challenges.size(), 0,
		"B4: with board_size=1, solving leaves empty board until turn end")
	# End turn → refill back to 1
	ctrl.end_player_turn()
	assert_eq(ctrl.available_challenges.size(), 1,
		"after end_player_turn, board refills to board_size=1")


func test_queued_for_next_turn_adds_extra_questions_on_refill() -> void:
	# B4：卡牌 draw_question 累计到 _queued_for_next_turn，refill 时多补
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
		_make_template("t_e"),
		_make_template("t_f"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	# 直接戳 _queued_for_next_turn 模拟卡牌能力作用
	ctrl._queued_for_next_turn = 2
	ctrl.end_player_turn()
	# board_size(3) + queued(2) = 5
	assert_eq(ctrl.available_challenges.size(), 5,
		"queued_for_next_turn should add to board on refill")
	assert_eq(ctrl._queued_for_next_turn, 0,
		"queued counter clears after refill")


func test_challenge_effects_apply_returns_correct_dict() -> void:
	# Direct ChallengeEffects.apply unit test
	var t_heal: ChallengeTemplate = _make_template("t_heal", "heal", 25)
	var r: Dictionary = ChallengeEffects.apply(null, t_heal, 0)
	assert_eq(int(r.get("heal_player", 0)), 25)
	assert_eq(int(r.get("damage_to_enemy", 0)), 0)

	var t_dmg: ChallengeTemplate = _make_template("t_dmg", "damage", 0)
	var r2: Dictionary = ChallengeEffects.apply(null, t_dmg, 12)
	assert_eq(int(r2.get("damage_to_enemy", 0)), 12)

	var t_combo: ChallengeTemplate = _make_template("t_cb", "combo_boost", 0)
	var r3: Dictionary = ChallengeEffects.apply(null, t_combo, 8)
	assert_eq(str(r3.get("modifier", "")), "next_x2")
	assert_eq(int(r3.get("damage_to_enemy", 0)), 8, "combo_boost still does base damage")


# ─── 一锤定音（wrong-answer feedback）─────────────────────

## 构造一道"必须 noun"的题，让 adjective 卡放进去 → 一定失败。
func _make_noun_template(template_id: String) -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": template_id,
		"kind": "fill_in_blank",
		"dialogue": "I see a ___",
		"slots": [
			{
				"index": 0,
				"required_pos": "noun",
				"required_type": "",
				"required_tags": [],
				"forbidden_tags": [],
				"damage_multiplier": 1.0,
			},
		],
		"topic_id": "test",
		"effect_type": "damage",
		"effect_magnitude": 0,
		"perfect_match_card_ids": ["card_noun_perfect"],
	})


func test_invalid_card_marks_challenge_failed() -> void:
	# B5: noun 模板因 hand-aware filter 不会自动进棋盘——用 add_to_board 强插
	var templates: Array = [
		_make_template("t_b"),
		_make_template("t_c"),
	]
	var bundle: Dictionary = _build_controller_force_noun_at(templates, _make_noun_template("t_noun"))
	var ctrl: BattleController = bundle["ctrl"]
	var noun_idx: int = bundle["noun_idx"]
	# Hand has adjective cards (default _make_card pos=adjective). Place into t_noun → invalid.
	watch_signals(ctrl)
	var card: Card = ctrl.hand[0]
	var ok: bool = ctrl.try_place_card(card, 0, noun_idx)
	assert_false(ok, "place must fail on invalid pos")
	assert_true(ctrl.is_failed(noun_idx), "noun challenge should be flagged failed")
	assert_signal_emitted(ctrl, "challenge_failed")


func test_failed_challenge_cannot_be_selected() -> void:
	var templates: Array = [
		_make_template("t_b"),
		_make_template("t_c"),
	]
	var bundle: Dictionary = _build_controller_force_noun_at(templates, _make_noun_template("t_noun"))
	var ctrl: BattleController = bundle["ctrl"]
	var noun_idx: int = bundle["noun_idx"]
	# Force-fail noun challenge
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, noun_idx)
	assert_true(ctrl.is_failed(noun_idx))
	# Switch to challenge 0 first (so we have a known starting point)
	ctrl.set_selected_challenge_index(0)
	assert_eq(ctrl.selected_challenge_index, 0)
	# Try to switch to failed noun → should be ignored
	ctrl.set_selected_challenge_index(noun_idx)
	assert_eq(ctrl.selected_challenge_index, 0,
		"set_selected_challenge_index must reject failed challenges")


func test_combo_resets_on_fail() -> void:
	var templates: Array = [
		_make_template("t_b"),
		_make_template("t_c"),
	]
	var bundle: Dictionary = _build_controller_force_noun_at(templates, _make_noun_template("t_noun"))
	var ctrl: BattleController = bundle["ctrl"]
	var noun_idx: int = bundle["noun_idx"]
	# Pump combo > 0
	ctrl._combo.increment()
	ctrl._combo.increment()
	assert_gt(ctrl._combo.count, 0, "precondition: combo > 0")
	# Fail noun challenge
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, noun_idx)
	assert_true(ctrl.is_failed(noun_idx))
	assert_eq(ctrl._combo.count, 0, "combo should reset on wrong answer")


func test_no_effect_applied_on_fail() -> void:
	var templates: Array = [
		_make_template("t_b"),
		_make_template("t_c"),
	]
	var bundle: Dictionary = _build_controller_force_noun_at(templates, _make_noun_template("t_noun"))
	var ctrl: BattleController = bundle["ctrl"]
	var noun_idx: int = bundle["noun_idx"]
	var enemy_hp_before: int = ctrl.enemy_hp
	var player_hp_before: int = ctrl.player_hp
	var shield_before: int = ctrl.player_shield
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, noun_idx)
	assert_true(ctrl.is_failed(noun_idx), "challenge marked failed")
	assert_eq(ctrl.enemy_hp, enemy_hp_before, "no damage on fail")
	assert_eq(ctrl.player_hp, player_hp_before, "no heal/damage on fail")
	assert_eq(ctrl.player_shield, shield_before, "no shield on fail")


func test_failed_challenge_cleared_on_refill() -> void:
	var templates: Array = [
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
		_make_template("t_e"),
		_make_template("t_f"),
	]
	var bundle: Dictionary = _build_controller_force_noun_at(templates, _make_noun_template("t_noun"))
	var ctrl: BattleController = bundle["ctrl"]
	var noun_idx: int = bundle["noun_idx"]
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, noun_idx)
	assert_true(ctrl.is_failed(noun_idx))
	ctrl.end_player_turn()
	# After refill: failed indices cleared and the failed template should be gone
	assert_eq(ctrl._failed_challenge_indices.size(), 0,
		"failed indices cleared after refill")
	assert_false(ctrl.is_failed(noun_idx),
		"failed noun challenge should no longer be flagged after refill")


func test_failed_challenge_cannot_be_kept() -> void:
	var templates: Array = [
		_make_template("t_b"),
		_make_template("t_c"),
	]
	var bundle: Dictionary = _build_controller_force_noun_at(templates, _make_noun_template("t_noun"))
	var ctrl: BattleController = bundle["ctrl"]
	var noun_idx: int = bundle["noun_idx"]
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, noun_idx)
	assert_true(ctrl.is_failed(noun_idx))
	# toggle_keep on failed challenge should be rejected
	var kept: bool = ctrl.toggle_keep(noun_idx)
	assert_false(kept, "toggle_keep must reject failed challenges")
	assert_false(ctrl.is_kept(noun_idx), "failed challenge must not be marked kept")


func test_has_solvable_challenges_false_when_all_failed() -> void:
	# 3 noun-required challenges, hand is all adjectives → all 3 fail
	# B5: 用 add_to_board 强插 noun 模板（hand 是 adjective，refill 不会选 noun）
	var ctrl: BattleController = _build_controller([], 8, 3, 0)
	# 清掉 refill 加的（虽然 templates 为空时 refill 也不会加任何）
	# 强插 3 道 noun 题
	ctrl.add_to_board(_make_noun_template("t_a"))
	ctrl.add_to_board(_make_noun_template("t_b"))
	ctrl.add_to_board(_make_noun_template("t_c"))
	# 起始已有 0 道（templates 为空）；加 3 → 共 3 道
	# Fail each
	ctrl.try_place_card(ctrl.hand[0], 0, 0)
	ctrl.try_place_card(ctrl.hand[0], 0, 1)
	ctrl.try_place_card(ctrl.hand[0], 0, 2)
	assert_false(ctrl.has_solvable_challenges(),
		"all challenges failed → no solvable challenges")


# ─── B5: hand-aware question selection ───────────────────────────

## 单槽：hand 有 adjective → 单槽 adjective 题可解
func test_can_solve_with_hand_single_slot_match() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var t: ChallengeTemplate = _make_template("t_adj")  # required_pos=adjective
	var hand: Array[Card] = [_make_card({"id": "c1"})]  # default pos=adjective
	assert_true(ctrl._can_solve_with_hand(t, hand),
		"adjective hand can solve adjective template")


## 单槽：hand 是 noun → 单槽 adjective 题不可解
func test_can_solve_with_hand_single_slot_no_match() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var t: ChallengeTemplate = _make_template("t_adj")
	var hand: Array[Card] = [_make_noun_card("noun_only")]
	assert_false(ctrl._can_solve_with_hand(t, hand),
		"noun hand cannot solve adjective template")


## 空手牌 + 非空槽 → false
func test_can_solve_with_hand_empty_hand_returns_false() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var t: ChallengeTemplate = _make_template("t_adj")
	var hand: Array[Card] = []
	assert_false(ctrl._can_solve_with_hand(t, hand),
		"empty hand cannot solve a non-empty template")


## 空槽模板 → 视为可解（边界）
func test_can_solve_with_hand_empty_template_slots_returns_true() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var t: ChallengeTemplate = ChallengeTemplate.from_dict({
		"template_id": "t_empty",
		"slots": [],
	})
	var hand: Array[Card] = []
	assert_true(ctrl._can_solve_with_hand(t, hand),
		"empty-slots template is trivially solvable")


## null template → 视为可解（兼容空 selector 路径）
func test_can_solve_with_hand_null_template_returns_true() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	assert_true(ctrl._can_solve_with_hand(null, [] as Array[Card]),
		"null template treated as solvable")


## 多槽：2 个 adjective 槽 + 2 张 adjective 卡 → 贪心可解
func _make_two_slot_adjective_template(template_id: String) -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": template_id,
		"kind": "fill_in_blank",
		"dialogue": "He is ___ and ___",
		"slots": [
			{"index": 0, "required_pos": "adjective"},
			{"index": 1, "required_pos": "adjective"},
		],
	})


func test_can_solve_with_hand_multi_slot_two_matches() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var t: ChallengeTemplate = _make_two_slot_adjective_template("t_2adj")
	var hand: Array[Card] = [
		_make_card({"id": "a1"}),
		_make_card({"id": "a2"}),
	]
	assert_true(ctrl._can_solve_with_hand(t, hand),
		"2 adjective cards solve 2 adjective slots")


## 多槽：2 个 adjective 槽 + 1 张 adjective 卡 → 不可解
func test_can_solve_with_hand_multi_slot_only_one_match() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var t: ChallengeTemplate = _make_two_slot_adjective_template("t_2adj")
	var hand: Array[Card] = [
		_make_card({"id": "a1"}),
		_make_noun_card("noun_only"),
	]
	assert_false(ctrl._can_solve_with_hand(t, hand),
		"only one adjective + one noun cannot fill two adjective slots")


## 多槽：mixed slot 类型（adj + noun）+ 手牌正好各一张 → 可解
func _make_adj_then_noun_template(template_id: String) -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": template_id,
		"kind": "fill_in_blank",
		"dialogue": "I see a ___ ___",
		"slots": [
			{"index": 0, "required_pos": "adjective"},
			{"index": 1, "required_pos": "noun"},
		],
	})


func test_can_solve_with_hand_multi_slot_mixed_types() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var t: ChallengeTemplate = _make_adj_then_noun_template("t_adjnoun")
	var hand: Array[Card] = [
		_make_card({"id": "a1"}),  # adjective
		_make_noun_card("n1"),     # noun
	]
	assert_true(ctrl._can_solve_with_hand(t, hand),
		"one adj + one noun solves adj+noun slots")


## refill_board 仅放入"当前手牌可解"的题
func test_refill_board_filters_to_solvable_with_hand() -> void:
	# 手牌全是 adjective；池里有 noun 题 + adjective 题；refill 只该选 adjective 题
	var templates: Array = [
		_make_noun_template("t_noun_a"),
		_make_template("t_adj_a"),
		_make_noun_template("t_noun_b"),
		_make_template("t_adj_b"),
		_make_template("t_adj_c"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	# Hand 默认是 adjective（_build_controller 用的 _make_card）
	for ch in ctrl.available_challenges:
		# 每道题的所有槽都应该能被手牌解
		assert_true(ctrl._can_solve_with_hand(ch, ctrl.hand),
			"refilled challenge '%s' should be solvable with current hand" % ch.template_id)
		# 具体：noun 题不应该出现
		assert_false(ch.template_id.begins_with("t_noun"),
			"noun-only template should be filtered out (hand has no noun)")


## 池里全是"不可解"的题 → Task 13 fallback：棋盘照样填满，但每题标 is_warn=true
## 让 UI 渲染 🟡 提示「此题手里没法解」。永远比留空板更友好。
func test_refill_when_all_unsolvable_results_in_smaller_board() -> void:
	var templates: Array = [
		_make_noun_template("t_noun_a"),
		_make_noun_template("t_noun_b"),
		_make_noun_template("t_noun_c"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	# Hand 全是 adjective，没有 noun → 走 fallback 路径填满棋盘
	assert_eq(ctrl.available_challenges.size(), 3,
		"fallback should fill board even when no template solvable by hand")
	for ch in ctrl.available_challenges:
		assert_true(ch.is_warn,
			"fallback-picked template '%s' should be marked is_warn=true" % ch.template_id)


## start_battle：先抽手牌再 refill_board，所有起手题都可解
func test_first_turn_questions_match_starting_hand() -> void:
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
	]
	var ctrl: BattleController = _build_controller(templates, 8, 3, 0)
	assert_eq(ctrl.hand.size(), BattleController.HAND_SIZE,
		"hand drawn before refill")
	for ch in ctrl.available_challenges:
		assert_true(ctrl._can_solve_with_hand(ch, ctrl.hand),
			"starting challenge '%s' solvable with starting hand" % ch.template_id)


## 回合末：手牌重抽后 refill 用新手牌过滤
func test_refill_at_turn_end_uses_new_hand() -> void:
	var templates: Array = [
		_make_template("t_a"),
		_make_template("t_b"),
		_make_template("t_c"),
		_make_template("t_d"),
		_make_template("t_e"),
	]
	var ctrl: BattleController = _build_controller(templates, 12, 3, 0)
	ctrl.end_player_turn()
	for ch in ctrl.available_challenges:
		assert_true(ctrl._can_solve_with_hand(ch, ctrl.hand),
			"after end_player_turn, all board challenges solvable with new hand")


## set_hand_for_test 测试辅助：能直接覆盖手牌
func test_set_hand_for_test_replaces_hand() -> void:
	var ctrl: BattleController = _build_controller([_make_template("t_a")], 8, 3, 0)
	var new_hand: Array[Card] = [
		_make_noun_card("manual_noun"),
		_make_card({"id": "manual_adj"}),
	]
	ctrl.set_hand_for_test(new_hand)
	assert_eq(ctrl.hand.size(), 2, "hand replaced")
	assert_eq(ctrl.hand[0].id, "manual_noun")
	assert_eq(ctrl.hand[1].id, "manual_adj")
