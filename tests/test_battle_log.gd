## test_battle_log — verify B6 战斗日志.
##
## Covers:
##   1. _log() appends to battle_log and emits log_appended
##   2. battle_log trims to LOG_MAX_ENTRIES
##   3. start_battle logs an "进入战斗" entry
##   4. submit_challenge (success path) logs a "解决" entry with summary
##   5. challenge_failed (wrong card) logs a "答错 → 正确答案" entry
##   6. enemy attack logs a "敌人: 攻击" entry
##   7. setup() clears battle_log between battles
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


func _make_template_adjective() -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": "tmpl_adj",
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


func _make_template_noun() -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": "tmpl_noun",
		"kind": "fill_in_blank",
		"dialogue": "I see a ___",
		"slots": [{
			"index": 0,
			"required_pos": "noun",
			"required_type": "",
			"required_tags": [],
			"forbidden_tags": [],
			"damage_multiplier": 1.0,
		}],
		"topic_id": "test",
		"perfect_match_card_ids": ["correct_noun"],
	})


func _make_enemy(hp: int = 999, atk: int = 0) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_enemy"
	e.enemy_name = "测试假人"
	e.max_hp = hp
	e.base_attack = atk
	return e


class _AlwaysSelector extends ChallengeSelector:
	var template: ChallengeTemplate
	func _init() -> void:
		super()
	func pick_challenge(_enemy: EnemyData, _pack, _srs) -> ChallengeTemplate:
		return template


func _build_controller(template: ChallengeTemplate = null,
		atk: int = 0,
		deck_size: int = 10) -> BattleController:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var deck: Array[Card] = []
	for i in deck_size:
		deck.append(_make_card({"id": "card_%d" % i, "text": "x%d" % i}))
	ctrl.setup(_make_enemy(999, atk), null, deck, null)
	var sel := _AlwaysSelector.new()
	sel.template = template if template != null else _make_template_adjective()
	ctrl.set_selector(sel)
	ctrl.start_battle()
	return ctrl


# ─── tests ────────────────────────────────────────────────────────

func test_log_appends_and_emits_signal() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	watch_signals(ctrl)
	ctrl._log("hello world")
	assert_eq(ctrl.battle_log.size(), 1, "_log appends one entry")
	assert_eq(ctrl.battle_log[0], "hello world")
	assert_signal_emitted(ctrl, "log_appended",
		"_log emits log_appended signal")


func test_log_empty_message_ignored() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	ctrl._log("")
	assert_eq(ctrl.battle_log.size(), 0,
		"empty messages are not appended")


func test_log_trims_to_max_entries() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	# Push 35 entries; only the last LOG_MAX_ENTRIES (=30) should remain.
	for i in 35:
		ctrl._log("entry %d" % i)
	assert_eq(ctrl.battle_log.size(), BattleController.LOG_MAX_ENTRIES,
		"battle_log capped at LOG_MAX_ENTRIES")
	# Earliest 5 should have been popped — first remaining = "entry 5".
	assert_eq(ctrl.battle_log[0], "entry 5",
		"earliest entries dropped from front when over cap")


func test_start_battle_logs_enemy_name() -> void:
	var ctrl: BattleController = _build_controller()
	# At least the "进入战斗" entry should be present.
	var matched: bool = false
	for line in ctrl.battle_log:
		if "测试假人" in line:
			matched = true
			break
	assert_true(matched,
		"start_battle should log an entry naming the enemy")


func test_submit_challenge_logs_success_summary() -> void:
	var ctrl: BattleController = _build_controller()
	var initial_log_size: int = ctrl.battle_log.size()
	ctrl.try_place_card(ctrl.hand[0], 0)
	# At least one new entry should mention the dialogue or 解决.
	assert_gt(ctrl.battle_log.size(), initial_log_size,
		"submit_challenge appends to log")
	var last: String = ctrl.battle_log[ctrl.battle_log.size() - 1]
	assert_true("解决" in last or "I am" in last,
		"success log mentions resolution or dialogue snippet, got: %s" % last)


func test_failed_challenge_logs_correct_answer() -> void:
	# Force a noun-required template to fail with adjective hand
	var ctrl: BattleController = _build_controller(_make_template_noun())
	# Manually inject the noun template since _can_solve_with_hand may have rejected it
	ctrl.available_challenges.clear()
	ctrl.available_filled_slots.clear()
	ctrl.add_to_board(_make_template_noun())
	ctrl.selected_challenge_index = 0
	var initial_size: int = ctrl.battle_log.size()
	# adjective card → fail
	ctrl.try_place_card(ctrl.hand[0], 0, 0)
	assert_gt(ctrl.battle_log.size(), initial_size,
		"failed challenge appends a log entry")
	var found_fail: bool = false
	for line in ctrl.battle_log:
		if "答错" in line and "correct_noun" in line:
			found_fail = true
			break
	assert_true(found_fail,
		"failed log should mention the correct answer card id")


func test_enemy_attack_logs_damage() -> void:
	var ctrl: BattleController = _build_controller(null, 7)
	# Solve one challenge so end_player_turn doesn't end with 0 enemy turn dmg
	ctrl.try_place_card(ctrl.hand[0], 0)
	var before_size: int = ctrl.battle_log.size()
	ctrl.end_player_turn()
	# Enemy attacked → at least one new log entry.
	assert_gt(ctrl.battle_log.size(), before_size,
		"end_player_turn (enemy attack) appends to log")
	var found_atk: bool = false
	for line in ctrl.battle_log:
		if "敌人" in line and ("攻击" in line or "伤害" in line):
			found_atk = true
			break
	assert_true(found_atk,
		"enemy attack log entry should mention 敌人 + damage")


func test_setup_clears_log() -> void:
	var ctrl: BattleController = _build_controller()
	assert_gt(ctrl.battle_log.size(), 0)
	# Re-setup with a fresh enemy → log should clear.
	var deck: Array[Card] = [_make_card()]
	ctrl.setup(_make_enemy(), null, deck, null)
	assert_eq(ctrl.battle_log.size(), 0,
		"setup() clears battle_log for the new battle")


func test_log_appended_signal_payload_matches_message() -> void:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var captured: Array[String] = []
	ctrl.log_appended.connect(func(m: String) -> void:
		captured.append(m))
	ctrl._log("alpha")
	ctrl._log("beta")
	assert_eq(captured.size(), 2)
	assert_eq(captured[0], "alpha")
	assert_eq(captured[1], "beta")
