## test_spice_battle_trigger — spice invoke mechanism in BattleController.
##
## Covers:
##   1. enemy ability_ids with invoke_spice_X prefix → _pending_spices contains X
##   2. start_battle() calls _maybe_emit_next_spice → spice_invoked signal emits
##   3. _pending_spices is empty after emit (no double-fire)
##   4. WordChoiceSpice.evaluate returns extra_damage payload on correct answer
extends GutTest


# ─── helpers ──────────────────────────────────────────────────────

func _make_enemy_with_spice(spice_id: String) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_spice_enemy"
	e.enemy_name = "Spice Test"
	e.max_hp = 100
	e.base_attack = 0
	e.ability_ids = ["invoke_spice_" + spice_id]
	return e


func _make_enemy_no_spice() -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "plain_enemy"
	e.enemy_name = "Plain"
	e.max_hp = 50
	e.base_attack = 0
	return e


func _make_card() -> Card:
	return Card.from_dict({
		"id": "card_test",
		"text": "test",
		"type": "word",
		"pos": "adjective",
		"tags": [],
		"skill": "vocab",
		"base_damage": 5,
		"rarity": "common",
	})


class _AlwaysSelector extends ChallengeSelector:
	var template: ChallengeTemplate
	func _init() -> void:
		super()
	func pick_challenge(_e: EnemyData, _p, _s) -> ChallengeTemplate:
		return template


func _make_template() -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": "tmpl_spice_test",
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


func _build_controller(enemy: EnemyData) -> BattleController:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var deck: Array[Card] = [_make_card()]
	ctrl.setup(enemy, null, deck, null)
	var sel := _AlwaysSelector.new()
	sel.template = _make_template()
	ctrl.set_selector(sel)
	return ctrl


# ─── tests ────────────────────────────────────────────────────────

## Test 1: invoke_spice_ prefix in ability_ids → _pending_spices populated after setup().
func test_pending_spices_populated_from_ability_ids() -> void:
	var enemy := _make_enemy_with_spice("voice_battle_cry")
	var ctrl := _build_controller(enemy)
	# setup() already called in _build_controller; check _pending_spices
	assert_eq(ctrl._pending_spices.size(), 1, "_pending_spices should have 1 entry")
	assert_eq(ctrl._pending_spices[0], "voice_battle_cry", "spice id extracted correctly")


## Test 2: start_battle() emits spice_invoked signal with correct spice_id.
func test_start_battle_emits_spice_invoked() -> void:
	var enemy := _make_enemy_with_spice("word_choice_happy")
	var ctrl := _build_controller(enemy)
	watch_signals(ctrl)
	ctrl.start_battle()
	assert_signal_emitted_with_parameters(ctrl, "spice_invoked", ["word_choice_happy"])


## Test 3: after _maybe_emit_next_spice fires, _pending_spices is empty (no re-fire).
func test_pending_spices_empty_after_emit() -> void:
	var enemy := _make_enemy_with_spice("dictation_blade")
	var ctrl := _build_controller(enemy)
	ctrl.start_battle()
	assert_eq(ctrl._pending_spices.size(), 0, "_pending_spices should be empty after emit")


## Test 4: WordChoiceSpice.evaluate returns extra_damage on correct choice.
func test_word_choice_evaluate_correct_answer() -> void:
	var WordChoiceSpiceScript: GDScript = load("res://src/content/english/spices/word_choice_spice.gd")
	var spice: Resource = WordChoiceSpiceScript.new()
	spice.set("target_word", "happy")
	spice.set("prompt_meaning", "高兴的")
	spice.set("choices", ["happy", "sad", "angry", "tired"])
	spice.set("damage_bonus", 20)

	var result = spice.call("evaluate", "happy")
	assert_true(result.success, "correct answer should succeed")
	assert_true(result.effect_payload.has("extra_damage"), "payload should have extra_damage")
	assert_eq(int(result.effect_payload["extra_damage"]), 20, "extra_damage should be 20")


## Bonus: WordChoiceSpice.evaluate returns failure on wrong answer.
func test_word_choice_evaluate_wrong_answer() -> void:
	var WordChoiceSpiceScript: GDScript = load("res://src/content/english/spices/word_choice_spice.gd")
	var spice: Resource = WordChoiceSpiceScript.new()
	spice.set("target_word", "happy")
	spice.set("choices", ["happy", "sad", "angry", "tired"])
	spice.set("damage_bonus", 20)

	var result = spice.call("evaluate", "sad")
	assert_false(result.success, "wrong answer should fail")
	assert_false(result.effect_payload.has("extra_damage"), "failed result should not have extra_damage")


## Bonus: enemy without invoke_spice_ ability → _pending_spices empty, no signal.
func test_no_spice_ability_no_signal() -> void:
	var enemy := _make_enemy_no_spice()
	var ctrl := _build_controller(enemy)
	watch_signals(ctrl)
	ctrl.start_battle()
	assert_signal_not_emitted(ctrl, "spice_invoked")
	assert_eq(ctrl._pending_spices.size(), 0, "_pending_spices should stay empty")
