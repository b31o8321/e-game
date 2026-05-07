## test_card_abilities — verify B4 card-ability layer
##
## Covers:
##   1. ability_type / ability_magnitude survive from_dict / to_dict roundtrip
##   2. apply_pre_submit aggregates abilities into modifiers
##   3. chain_bonus = 1.5x when prev card shares any tag, 1.0x otherwise
##   4. double_effect doubles damage AND heal AND shield
##   5. heal_on_use stacks extra healing on top of question heal effect
##   6. draw_card / draw_question on cards add to controller results
##   7. combo_charge advances combo by 2 per hit
##   8. submit_challenge integration: card+question effects stack
extends GutTest


# ─── helpers ──────────────────────────────────────────────────────

func _make_card(overrides: Dictionary = {}) -> Card:
	var base := {
		"id": "card_test",
		"text": "test",
		"type": "word",
		"pos": "adjective",
		"tags": ["positive_emotion"],
		"skill": "vocab",
		"base_damage": 5,
		"rarity": "common",
		"ability_type": "none",
		"ability_magnitude": 0,
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
	e.weak_axes = []
	return e


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


func _build_controller(templates: Array, deck: Array[Card], board_size: int = 3, attack: int = 0) -> BattleController:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var enemy: EnemyData = _make_enemy(999, attack)
	ctrl.setup(enemy, null, deck, null, board_size)
	var sel := _CycleSelector.new()
	sel.templates = templates
	ctrl.set_selector(sel)
	ctrl.start_battle()
	return ctrl


# ─── unit tests: Card.ability_type roundtrip ──────────────────────

func test_card_from_dict_loads_ability_fields() -> void:
	var c := Card.from_dict({
		"id": "card_x",
		"ability_type": "draw_card",
		"ability_magnitude": 2,
		"ability_description": "测试",
	})
	assert_eq(c.ability_type, "draw_card")
	assert_eq(c.ability_magnitude, 2)
	assert_eq(c.ability_description, "测试")


func test_card_to_dict_includes_ability_fields() -> void:
	var c := _make_card({
		"ability_type": "double_effect",
		"ability_magnitude": 0,
		"ability_description": "翻倍",
	})
	var d: Dictionary = c.to_dict()
	assert_true(d.has("ability_type"))
	assert_eq(str(d["ability_type"]), "double_effect")
	assert_eq(int(d["ability_magnitude"]), 0)
	assert_eq(str(d["ability_description"]), "翻倍")


func test_card_default_ability_is_none() -> void:
	var c := Card.from_dict({"id": "c"})
	assert_eq(c.ability_type, "none")
	assert_eq(c.ability_magnitude, 0)


# ─── unit tests: CardAbilities.apply_pre_submit ───────────────────

func test_apply_pre_submit_no_abilities_returns_neutral() -> void:
	var c := _make_card()  # ability_type = none
	var r: Dictionary = CardAbilities.apply_pre_submit(null, [c], 10)
	assert_almost_eq(float(r["damage_modifier"]), 1.0, 0.001)
	assert_almost_eq(float(r["heal_modifier"]), 1.0, 0.001)
	assert_eq(int(r["extra_draw"]), 0)
	assert_eq(int(r["extra_heal"]), 0)
	assert_eq(int(r["queue_questions"]), 0)
	assert_eq(int(r["combo_extra"]), 0)


func test_apply_pre_submit_draw_card_accumulates() -> void:
	var c1 := _make_card({"ability_type": "draw_card", "ability_magnitude": 1})
	var c2 := _make_card({"ability_type": "draw_card", "ability_magnitude": 2})
	var r: Dictionary = CardAbilities.apply_pre_submit(null, [c1, c2], 10)
	assert_eq(int(r["extra_draw"]), 3)


func test_apply_pre_submit_double_effect_doubles_modifiers() -> void:
	var c := _make_card({"ability_type": "double_effect"})
	var r: Dictionary = CardAbilities.apply_pre_submit(null, [c], 10)
	assert_almost_eq(float(r["damage_modifier"]), 2.0, 0.001)
	assert_almost_eq(float(r["heal_modifier"]), 2.0, 0.001)
	assert_almost_eq(float(r["shield_modifier"]), 2.0, 0.001)


func test_apply_pre_submit_heal_on_use_accumulates_extra_heal() -> void:
	var c := _make_card({"ability_type": "heal_on_use", "ability_magnitude": 5})
	var r: Dictionary = CardAbilities.apply_pre_submit(null, [c], 10)
	assert_eq(int(r["extra_heal"]), 5)


func test_apply_pre_submit_draw_question_accumulates() -> void:
	var c := _make_card({"ability_type": "draw_question", "ability_magnitude": 1})
	var r: Dictionary = CardAbilities.apply_pre_submit(null, [c], 10)
	assert_eq(int(r["queue_questions"]), 1)


func test_apply_pre_submit_combo_charge_extra() -> void:
	var c := _make_card({"ability_type": "combo_charge", "ability_magnitude": 1})
	var r: Dictionary = CardAbilities.apply_pre_submit(null, [c], 10)
	assert_eq(int(r["combo_extra"]), 1)


# ─── chain_bonus ───────────────────────────────────────────────────

func test_chain_bonus_with_shared_tag_gives_15x() -> void:
	# prev card has tag "positive_personality"; chain_bonus card also has it
	var prev := _make_card({"tags": ["adjective", "positive_personality"]})
	var cur := _make_card({"ability_type": "chain_bonus", "tags": ["positive_personality"]})
	var r: Dictionary = CardAbilities.apply_pre_submit(null, [prev, cur], 10)
	assert_almost_eq(float(r["damage_modifier"]), 1.5, 0.001)


func test_chain_bonus_without_shared_tag_is_1x() -> void:
	var prev := _make_card({"tags": ["foo"]})
	var cur := _make_card({"ability_type": "chain_bonus", "tags": ["bar"]})
	var r: Dictionary = CardAbilities.apply_pre_submit(null, [prev, cur], 10)
	assert_almost_eq(float(r["damage_modifier"]), 1.0, 0.001)


func test_chain_bonus_first_card_no_prev_is_1x() -> void:
	var cur := _make_card({"ability_type": "chain_bonus", "tags": ["positive_emotion"]})
	var r: Dictionary = CardAbilities.apply_pre_submit(null, [cur], 10)
	assert_almost_eq(float(r["damage_modifier"]), 1.0, 0.001)


# ─── integration: submit_challenge stacks card + question ─────────

func test_submit_card_double_effect_doubles_damage() -> void:
	# Card has double_effect; question is plain damage. base damage should double.
	var deck: Array[Card] = []
	for i in 6:
		deck.append(_make_card({"id": "card_d_%d" % i, "text": "x", "ability_type": "double_effect"}))
	var templates: Array = [
		_make_template("t_a", "damage", 0),
		_make_template("t_b", "damage", 0),
		_make_template("t_c", "damage", 0),
	]
	var ctrl: BattleController = _build_controller(templates, deck, 3, 0)
	var hp_before: int = ctrl.enemy_hp
	# Use a card with double_effect ability
	var card: Card = ctrl.hand[0]
	# Compute base damage manually (no double): for our card base_damage=5 it's at least 5.
	# After double_effect → damage to enemy ≥ 10
	ctrl.try_place_card(card, 0, 0)
	var dmg: int = hp_before - ctrl.enemy_hp
	assert_gte(dmg, 10, "double_effect should at least double base damage of 5 → 10+")


func test_submit_card_heal_on_use_stacks_with_question_heal() -> void:
	# Card heal_on_use=4 + question heal=20 → +24 hp (capped at max)
	var deck: Array[Card] = []
	for i in 6:
		deck.append(_make_card({"id": "card_h_%d" % i, "text": "x", "ability_type": "heal_on_use", "ability_magnitude": 4}))
	var templates: Array = [
		_make_template("t_heal", "heal", 20),
		_make_template("t_b", "damage", 0),
		_make_template("t_c", "damage", 0),
	]
	var ctrl: BattleController = _build_controller(templates, deck, 3, 0)
	ctrl.player_hp = 50
	ctrl.player_max_hp = 100
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	# 50 + 20 (question) + 4 (heal_on_use) = 74
	assert_eq(ctrl.player_hp, 74, "heal stacks: question heal +20 + card heal_on_use +4 = +24")


func test_submit_card_draw_card_extra_draws() -> void:
	# Card with draw_card +1 ability. Question is plain damage.
	# We make ALL cards have draw_card so any hand card works.
	var deck: Array[Card] = []
	for i in 12:
		deck.append(_make_card({"id": "card_dc_%d" % i, "text": "x", "ability_type": "draw_card", "ability_magnitude": 1}))
	var templates: Array = [
		_make_template("t_a", "damage", 0),
		_make_template("t_b", "damage", 0),
		_make_template("t_c", "damage", 0),
	]
	var ctrl: BattleController = _build_controller(templates, deck, 3, 0)
	var hand_size_before: int = ctrl.hand.size()
	# Note: BattleController has DRAW_PER_N_CARDS=2 — every 2 cards played triggers +1 bonus.
	# Playing 1 card with draw_card+1 → -1 (played) + 1 (ability) = net 0
	# (bonus draw triggers at cards_played_this_turn % 2 == 0; 1 play does not trigger)
	ctrl.try_place_card(ctrl.hand[0], 0, 0)
	assert_eq(ctrl.hand.size(), hand_size_before,
		"draw_card +1 ability + 1 played = net same hand size")


func test_submit_card_double_effect_doubles_heal() -> void:
	# heal +20 question + double_effect card → heal +40
	var deck: Array[Card] = []
	for i in 6:
		deck.append(_make_card({"id": "card_de_%d" % i, "text": "x", "ability_type": "double_effect"}))
	var templates: Array = [
		_make_template("t_heal", "heal", 20),
		_make_template("t_b", "damage", 0),
		_make_template("t_c", "damage", 0),
	]
	var ctrl: BattleController = _build_controller(templates, deck, 3, 0)
	ctrl.player_hp = 30
	ctrl.player_max_hp = 100
	var card: Card = ctrl.hand[0]
	ctrl.try_place_card(card, 0, 0)
	# 30 + 40 = 70
	assert_eq(ctrl.player_hp, 70, "double_effect doubles question heal: 20→40")


func test_submit_card_draw_question_queues_for_next_turn() -> void:
	# Card draw_question +1 ability: queued for NEXT turn (not this turn).
	# This is different from question's own draw_question effect, which adds immediately.
	var deck: Array[Card] = []
	for i in 6:
		deck.append(_make_card({"id": "card_dq_%d" % i, "text": "x", "ability_type": "draw_question", "ability_magnitude": 1}))
	var templates: Array = [
		_make_template("t_a", "damage", 0),
		_make_template("t_b", "damage", 0),
		_make_template("t_c", "damage", 0),
		_make_template("t_d", "damage", 0),
		_make_template("t_e", "damage", 0),
		_make_template("t_f", "damage", 0),
		_make_template("t_g", "damage", 0),
	]
	var ctrl: BattleController = _build_controller(templates, deck, 3, 0)
	# Solve one challenge: -1 from board, queue_questions += 1
	ctrl.try_place_card(ctrl.hand[0], 0, 0)
	# Mid-turn: board down to 2 (no auto-refill, no immediate add)
	assert_eq(ctrl.available_challenges.size(), 2,
		"card draw_question doesn't add immediately—it queues")
	assert_eq(ctrl._queued_for_next_turn, 1,
		"queue_for_next_turn should be 1 after using draw_question card")
	# End turn → refill adds queued bonus (target = board_size + queued = 3 + 1 = 4)
	ctrl.end_player_turn()
	assert_eq(ctrl.available_challenges.size(), 4,
		"refill at turn end should add board_size + queued = 4")
	assert_eq(ctrl._queued_for_next_turn, 0,
		"queue should be cleared after refill")
