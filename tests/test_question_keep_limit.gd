## test_question_keep_limit — toggle_keep enforces question_keep_max.
##
## Covers:
##   - QUESTION_KEEP_MAX_DEFAULT == 1, controller defaults to it
##   - toggle_keep at limit refuses additional keeps (returns false, state unchanged)
##   - toggle_keep on already-kept question removes it (returns false but state changed)
##   - get_kept_count tracks current size
##   - Raising question_keep_max allows more keeps (future skill / item)
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


func _make_template(template_id: String) -> ChallengeTemplate:
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
	})


func _make_enemy() -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_enemy"
	e.enemy_name = "Test"
	e.max_hp = 9999
	e.base_attack = 0
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


func _build_controller(template_ids: Array, board_size: int = 3) -> BattleController:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var deck: Array[Card] = []
	for i in 12:
		deck.append(_make_card({"id": "card_%d" % i, "text": "x%d" % i}))
	ctrl.setup(_make_enemy(), null, deck, null, board_size)
	var sel := _CycleSelector.new()
	for tid in template_ids:
		sel.templates.append(_make_template(tid))
	ctrl.set_selector(sel)
	ctrl.start_battle()
	return ctrl


# ─── constants / defaults ─────────────────────────────────────────

func test_default_question_keep_max_is_one() -> void:
	assert_eq(BattleController.QUESTION_KEEP_MAX_DEFAULT, 1,
		"QUESTION_KEEP_MAX_DEFAULT should be 1")
	var ctrl := _build_controller(["t_a", "t_b", "t_c"])
	assert_eq(ctrl.question_keep_max, 1,
		"controller.question_keep_max should default to 1")


# ─── cap enforcement ──────────────────────────────────────────────

func test_toggle_keep_first_question_succeeds() -> void:
	var ctrl := _build_controller(["t_a", "t_b", "t_c"])
	var kept: bool = ctrl.toggle_keep(0)
	assert_true(kept, "first toggle_keep should succeed")
	assert_true(ctrl.is_kept(0))
	assert_eq(ctrl.get_kept_count(), 1)


func test_toggle_keep_at_cap_refuses_second() -> void:
	var ctrl := _build_controller(["t_a", "t_b", "t_c"])
	# Cap = 1 by default
	assert_true(ctrl.toggle_keep(0), "first kept")
	assert_eq(ctrl.get_kept_count(), 1)
	# Second keep on a different question should be refused
	var ok: bool = ctrl.toggle_keep(1)
	assert_false(ok, "second toggle_keep at cap=1 must be refused")
	assert_false(ctrl.is_kept(1), "second question must NOT be marked kept")
	assert_eq(ctrl.get_kept_count(), 1, "kept set unchanged after refusal")


func test_toggle_keep_removes_kept_even_at_cap() -> void:
	var ctrl := _build_controller(["t_a", "t_b", "t_c"])
	ctrl.toggle_keep(0)
	assert_true(ctrl.is_kept(0))
	# Toggling kept off must always work — even when at cap
	var ok: bool = ctrl.toggle_keep(0)
	assert_false(ok, "removing kept returns false (state changed but no-longer-kept)")
	assert_false(ctrl.is_kept(0), "kept cleared")
	assert_eq(ctrl.get_kept_count(), 0)


func test_toggle_keep_after_clearing_can_keep_different() -> void:
	var ctrl := _build_controller(["t_a", "t_b", "t_c"])
	ctrl.toggle_keep(0)
	ctrl.toggle_keep(0)  # remove
	# Now re-keep a different question
	var ok: bool = ctrl.toggle_keep(2)
	assert_true(ok, "after clearing, can keep a different question")
	assert_true(ctrl.is_kept(2))


func test_raised_question_keep_max_allows_two() -> void:
	# Simulate a future skill / item raising the cap to 2
	var ctrl := _build_controller(["t_a", "t_b", "t_c"])
	ctrl.question_keep_max = 2
	assert_true(ctrl.toggle_keep(0), "first keep")
	assert_true(ctrl.toggle_keep(1), "second keep (cap=2)")
	assert_eq(ctrl.get_kept_count(), 2)
	# Third still refused
	assert_false(ctrl.toggle_keep(2), "third refused at cap=2")
	assert_eq(ctrl.get_kept_count(), 2)


# ─── interaction with existing flow ──────────────────────────────

func test_kept_question_persists_through_turn_with_cap() -> void:
	var ctrl := _build_controller(
		["t_a", "t_b", "t_c", "t_d", "t_e", "t_f"])
	# Keep 1 (default cap)
	ctrl.toggle_keep(0)
	var kept_id: String = ctrl.available_challenges[0].template_id
	ctrl.end_player_turn()
	# Kept template should still appear on the refilled board
	var found: bool = false
	for t in ctrl.available_challenges:
		if t.template_id == kept_id:
			found = true
	assert_true(found, "kept template should survive turn refill under cap=1")
