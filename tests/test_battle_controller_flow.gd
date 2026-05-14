## test_battle_controller_flow — verify post-redesign turn-flow features.
##
## Covers:
##   1. cards_played_this_turn counter increments on placement
##   2. _maybe_draw_bonus_card draws +1 every 2 cards
##   3. Multi-challenge per turn (after submit, advance happens, counter persists)
##   4. challenges_solved_this_turn increments per submit, resets on end_player_turn
##   5. end_player_turn resets per-turn counters
extends GutTest


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
	})


func _make_enemy(hp: int = 999) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_enemy"
	e.enemy_name = "Test"
	e.max_hp = hp
	e.base_attack = 0   # never kill the player so we can do many turns
	return e


class _AlwaysSelector extends ChallengeSelector:
	var template: ChallengeTemplate
	func _init() -> void:
		super()
	func pick_challenge(_enemy: EnemyData, _pack, _srs) -> ChallengeTemplate:
		return template


func _build_controller(deck_size: int = 10) -> BattleController:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var deck: Array[Card] = []
	for i in deck_size:
		deck.append(_make_card({"id": "card_%d" % i, "text": "x%d" % i}))
	var enemy: EnemyData = _make_enemy()
	ctrl.setup(enemy, null, deck, null)
	var sel := _AlwaysSelector.new()
	sel.template = _make_template_one_slot()
	ctrl.set_selector(sel)
	ctrl.start_battle()
	return ctrl


# ─── tests ────────────────────────────────────────────────────────

func test_cards_played_counter_increments_on_place() -> void:
	var ctrl: BattleController = _build_controller(8)
	assert_eq(ctrl.cards_played_this_turn, 0)
	# Submit one challenge → counter +1; advance to next challenge auto-loads
	var card: Card = ctrl.hand[0]
	var ok: bool = ctrl.try_place_card(card, 0)
	assert_true(ok)
	# After submit (single-slot challenge), counter should be 1
	assert_eq(ctrl.cards_played_this_turn, 1, "counter increments after card placement")


## 2026-05-08 静态卡库改造：每打两张卡奖励抽 1 张 (DRAW_PER_N_CARDS) 已移除
## ——库内卡始终可见，没有"抽牌"概念。本测试改为空 pass 保留为占位，
## 真正的"过两张牌奖励"机制将由 T2/T3 重设计（譬如 AP 容量奖励）。
func test_bonus_draw_every_two_cards() -> void:
	pass


func test_challenges_solved_per_turn_counter() -> void:
	var ctrl: BattleController = _build_controller(20)
	assert_eq(ctrl.challenges_solved_this_turn, 0)
	# Play one card → submit → counter becomes 1
	ctrl.try_place_card(ctrl.hand[0], 0)
	assert_eq(ctrl.challenges_solved_this_turn, 1, "counter goes up after submit")
	# Play another card in same turn → counter becomes 2
	ctrl.try_place_card(ctrl.hand[0], 0)
	assert_eq(ctrl.challenges_solved_this_turn, 2, "counter persists within a turn")


func test_end_player_turn_resets_per_turn_counters() -> void:
	var ctrl: BattleController = _build_controller(20)
	ctrl.try_place_card(ctrl.hand[0], 0)
	ctrl.try_place_card(ctrl.hand[0], 0)
	assert_gt(ctrl.cards_played_this_turn, 0)
	assert_gt(ctrl.challenges_solved_this_turn, 0)
	ctrl.end_player_turn()
	# After enemy turn finishes, state returns to PLAYER_TURN
	assert_eq(ctrl.cards_played_this_turn, 0,
		"cards_played_this_turn resets on turn end")
	assert_eq(ctrl.challenges_solved_this_turn, 0,
		"challenges_solved_this_turn resets on turn end")


func test_multi_challenge_per_turn_advances_without_ending_turn() -> void:
	# Verify that after submitting a challenge, the controller stays in PLAYER_TURN
	# and advances to next challenge (rather than ending the turn).
	var ctrl: BattleController = _build_controller(20)
	var state_before: int = ctrl.state
	assert_eq(state_before, BattleController.State.PLAYER_TURN)
	ctrl.try_place_card(ctrl.hand[0], 0)
	assert_eq(ctrl.state, BattleController.State.PLAYER_TURN,
		"after submitting a challenge, state should remain PLAYER_TURN (not ENEMY_TURN)")
	assert_not_null(ctrl.current_template,
		"a fresh challenge should be loaded for the same turn")


func test_turn_combo_signal_fires_at_two_solved() -> void:
	var ctrl: BattleController = _build_controller(20)
	watch_signals(ctrl)
	# 1st submit: counter=1, no signal
	ctrl.try_place_card(ctrl.hand[0], 0)
	# 2nd submit: counter=2 → turn_combo_advanced signal fires
	ctrl.try_place_card(ctrl.hand[0], 0)
	assert_signal_emitted(ctrl, "turn_combo_advanced",
		"second consecutive submit in a turn fires turn_combo_advanced")
