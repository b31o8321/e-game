## test_ability_once_per_turn — T2 of card-library redesign.
##
## Verifies that each card's ability triggers at most once per turn:
##   - mark_card_ability_used records the card id
##   - get_used_ability_card_ids returns a duplicate (not a live reference)
##   - mark is idempotent (same id twice → list size still 1)
##   - end_player_turn clears the used list
##   - CardAbilities.apply_pre_submit skips cards already in the used list
##   - Backward compat: null controller → no skip (existing tests rely on this)
extends GutTest

const BattleControllerClass = preload("res://src/battle/battle_controller.gd")
const CardClass = preload("res://src/battle/cards/card.gd")
const CardAbilitiesClass = preload("res://src/battle/card_abilities.gd")


func _make_card(id: String, ability_type: String = "draw_card", magnitude: int = 1) -> Card:
	var c := CardClass.new()
	c.id = id
	c.text = id
	c.type = "word"
	c.pos = "adjective"
	var tags: Array[String] = ["positive_emotion"]
	c.tags = tags
	c.base_damage = 5
	c.ability_type = ability_type
	c.ability_magnitude = magnitude
	return c


func test_ability_marks_card_used() -> void:
	var c: BattleController = BattleControllerClass.new()
	add_child_autofree(c)
	c.mark_card_ability_used("card_a")
	assert_true("card_a" in c.get_used_ability_card_ids())


func test_get_used_returns_duplicate_not_reference() -> void:
	var c: BattleController = BattleControllerClass.new()
	add_child_autofree(c)
	c.mark_card_ability_used("card_a")
	var list: Array[String] = c.get_used_ability_card_ids()
	list.append("card_b")
	assert_false("card_b" in c.get_used_ability_card_ids(),
		"mutating returned list must not leak into controller state")


func test_mark_idempotent() -> void:
	var c: BattleController = BattleControllerClass.new()
	add_child_autofree(c)
	c.mark_card_ability_used("card_a")
	c.mark_card_ability_used("card_a")
	assert_eq(c.get_used_ability_card_ids().size(), 1)


func test_mark_empty_id_noop() -> void:
	var c: BattleController = BattleControllerClass.new()
	add_child_autofree(c)
	c.mark_card_ability_used("")
	assert_eq(c.get_used_ability_card_ids().size(), 0,
		"empty id should be ignored, not appended")


func test_end_turn_clears_used_ids() -> void:
	var c: BattleController = BattleControllerClass.new()
	add_child_autofree(c)
	c.mark_card_ability_used("card_a")
	c.mark_card_ability_used("card_b")
	assert_eq(c.get_used_ability_card_ids().size(), 2)
	c.end_player_turn()
	assert_eq(c.get_used_ability_card_ids().size(), 0,
		"end_player_turn must clear used-ability list so abilities re-trigger next turn")


func test_card_abilities_skip_used() -> void:
	# Verify CardAbilities.apply_pre_submit respects used list
	var c: BattleController = BattleControllerClass.new()
	add_child_autofree(c)
	c.mark_card_ability_used("card_used")
	var card_used: Card = _make_card("card_used", "draw_card", 2)
	var card_fresh: Card = _make_card("card_fresh", "draw_card", 3)
	var result: Dictionary = CardAbilitiesClass.apply_pre_submit(c, [card_used, card_fresh], 10)
	# card_used skipped; card_fresh contributes 3
	assert_eq(int(result.get("extra_draw", -1)), 3,
		"used card's ability should be skipped; only fresh card contributes")


func test_card_abilities_no_used_list_no_skip() -> void:
	# Backward compat: if controller has no list (null), all abilities trigger.
	# This protects all existing CardAbilities tests that pass null as controller.
	var card_a: Card = _make_card("card_a", "draw_card", 1)
	var card_b: Card = _make_card("card_b", "draw_card", 1)
	var result: Dictionary = CardAbilitiesClass.apply_pre_submit(null, [card_a, card_b], 10)
	assert_eq(int(result.get("extra_draw", -1)), 2,
		"null controller = no gating; both cards contribute their abilities")
