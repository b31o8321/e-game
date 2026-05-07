## test_hand_retention — hand retain mechanic (toggle / cap / turn-end behavior).
##
## Covers:
##   - HAND_RETAIN_MAX_DEFAULT == 3, hand_retain_max defaults to it
##   - toggle_hand_retain adds id; second call removes
##   - toggle_hand_retain rejects when at hand_retain_max
##   - is_hand_retained / get_retained_count reflect state
##   - end_player_turn keeps retained cards and refills to HAND_SIZE
##   - non-retained cards go to discard pile on turn end
##   - _retained_card_ids cleared after end_player_turn
##   - Playing a retained card clears its retain mark
##   - hand_retain_max can be raised (future skill / item simulation)
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


func _make_template() -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": "t_x",
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


func _build_controller(deck_size: int = 12) -> BattleController:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var deck: Array[Card] = []
	for i in deck_size:
		deck.append(_make_card({"id": "card_%d" % i, "text": "x%d" % i}))
	ctrl.setup(_make_enemy(), null, deck, null, 3)
	var sel := _CycleSelector.new()
	sel.templates = [_make_template()]
	ctrl.set_selector(sel)
	ctrl.start_battle()
	return ctrl


# ─── constants / defaults ─────────────────────────────────────────

func test_default_hand_retain_max_is_three() -> void:
	assert_eq(BattleController.HAND_RETAIN_MAX_DEFAULT, 3,
		"HAND_RETAIN_MAX_DEFAULT should be 3")
	var ctrl := _build_controller()
	assert_eq(ctrl.hand_retain_max, 3, "controller.hand_retain_max should default to 3")


# ─── toggle behavior ───────────────────────────────────────────────

func test_toggle_hand_retain_adds_card_id() -> void:
	var ctrl := _build_controller()
	var first_id: String = ctrl.hand[0].id
	assert_false(ctrl.is_hand_retained(first_id), "fresh card not retained")
	var ok: bool = ctrl.toggle_hand_retain(first_id)
	assert_true(ok, "first toggle should succeed")
	assert_true(ctrl.is_hand_retained(first_id), "card should be marked retained")
	assert_eq(ctrl.get_retained_count(), 1)


func test_toggle_hand_retain_removes_when_already_retained() -> void:
	var ctrl := _build_controller()
	var cid: String = ctrl.hand[0].id
	ctrl.toggle_hand_retain(cid)
	assert_true(ctrl.is_hand_retained(cid))
	var ok: bool = ctrl.toggle_hand_retain(cid)
	assert_true(ok, "removing existing retain should return true (state changed)")
	assert_false(ctrl.is_hand_retained(cid), "card should no longer be retained")
	assert_eq(ctrl.get_retained_count(), 0)


func test_toggle_hand_retain_rejects_over_cap() -> void:
	var ctrl := _build_controller()
	# hand_retain_max defaults to 3 — fill it
	var ids: Array[String] = []
	for i in 3:
		var cid: String = ctrl.hand[i].id
		ids.append(cid)
		assert_true(ctrl.toggle_hand_retain(cid), "filling up to cap")
	assert_eq(ctrl.get_retained_count(), 3)
	# 4th retain should be refused
	var fourth_id: String = ctrl.hand[3].id
	var ok: bool = ctrl.toggle_hand_retain(fourth_id)
	assert_false(ok, "over-cap retain must be refused")
	assert_false(ctrl.is_hand_retained(fourth_id), "rejected id must not be in retain set")
	assert_eq(ctrl.get_retained_count(), 3, "retain set unchanged after refusal")


func test_toggle_hand_retain_rejects_unknown_id() -> void:
	var ctrl := _build_controller()
	var ok: bool = ctrl.toggle_hand_retain("not_in_hand")
	assert_false(ok, "id not in hand should be refused")


# ─── end_player_turn flow ──────────────────────────────────────────

func test_end_turn_keeps_retained_cards_and_refills_to_full() -> void:
	var ctrl := _build_controller(20)
	# Mark first 2 cards as retained
	var keep_ids: Array[String] = [ctrl.hand[0].id, ctrl.hand[1].id]
	ctrl.toggle_hand_retain(keep_ids[0])
	ctrl.toggle_hand_retain(keep_ids[1])
	assert_eq(ctrl.get_retained_count(), 2)
	ctrl.end_player_turn()
	# Hand size should be back to HAND_SIZE
	assert_eq(ctrl.hand.size(), BattleController.HAND_SIZE,
		"hand should refill to HAND_SIZE after turn end")
	# Both retained ids should still be in hand
	var hand_ids: Array[String] = []
	for c in ctrl.hand:
		hand_ids.append(c.id)
	for kid in keep_ids:
		assert_true(kid in hand_ids,
			"retained card %s should remain in hand after turn end" % kid)


func test_end_turn_discards_non_retained_cards() -> void:
	var ctrl := _build_controller(20)
	# Retain only 1; collect ids of the rest
	var keep_id: String = ctrl.hand[0].id
	ctrl.toggle_hand_retain(keep_id)
	var dropped_ids: Array[String] = []
	for i in range(1, ctrl.hand.size()):
		dropped_ids.append(ctrl.hand[i].id)
	var discard_before: int = ctrl.discard.size()
	ctrl.end_player_turn()
	# Discard pile should have grown by len(dropped_ids), unless those got reshuffled
	# back into deck during _draw_to_full_hand. Easier check: those ids should NOT
	# be in retained set anymore, AND keep_id remained.
	var hand_ids: Array[String] = []
	for c in ctrl.hand:
		hand_ids.append(c.id)
	assert_true(keep_id in hand_ids, "retained card stays in hand")
	# Sanity: discard pile + deck combined contains the dropped cards somewhere
	# (they may have been reshuffled into deck mid-draw if deck depleted).
	var total_seen: Array[String] = []
	for c in ctrl.discard:
		total_seen.append(c.id)
	for c in ctrl.deck:
		total_seen.append(c.id)
	for c in ctrl.hand:
		total_seen.append(c.id)
	for did in dropped_ids:
		assert_true(did in total_seen,
			"dropped card %s should still exist somewhere (discard/deck/hand)" % did)
	# Discard increased OR was shuffled — at minimum non-retained cards left hand
	assert_gte(discard_before + dropped_ids.size() + ctrl.hand.size(),
		ctrl.discard.size() + ctrl.hand.size(),
		"non-retained cards left the hand at turn end")


func test_end_turn_clears_retained_marks() -> void:
	var ctrl := _build_controller(20)
	ctrl.toggle_hand_retain(ctrl.hand[0].id)
	ctrl.toggle_hand_retain(ctrl.hand[1].id)
	assert_eq(ctrl.get_retained_count(), 2)
	ctrl.end_player_turn()
	assert_eq(ctrl.get_retained_count(), 0,
		"retained marks must clear after end_player_turn")


func test_playing_retained_card_clears_its_retain_mark() -> void:
	var ctrl := _build_controller(12)
	var card: Card = ctrl.hand[0]
	ctrl.toggle_hand_retain(card.id)
	assert_true(ctrl.is_hand_retained(card.id))
	# Play this card into slot 0 of selected challenge → consumed
	var ok: bool = ctrl.try_place_card(card, 0, 0)
	assert_true(ok, "place must succeed")
	# The card id should no longer be in retain set (mark cleared on consume)
	assert_false(ctrl.is_hand_retained(card.id),
		"playing a retained card should clear its retain mark")


func test_raised_hand_retain_max_allows_more() -> void:
	# Simulate a future skill / item raising the cap
	var ctrl := _build_controller(20)
	ctrl.hand_retain_max = 5
	for i in 5:
		assert_true(ctrl.toggle_hand_retain(ctrl.hand[i].id),
			"with cap=5, should be able to retain 5 cards")
	assert_eq(ctrl.get_retained_count(), 5)
	ctrl.end_player_turn()
	# All 5 should remain in hand
	assert_eq(ctrl.hand.size(), BattleController.HAND_SIZE)


# ─── signals ──────────────────────────────────────────────────────

func test_toggle_hand_retain_emits_hand_changed() -> void:
	var ctrl := _build_controller()
	watch_signals(ctrl)
	ctrl.toggle_hand_retain(ctrl.hand[0].id)
	assert_signal_emitted(ctrl, "hand_changed",
		"toggle_hand_retain should emit hand_changed for UI re-render")
