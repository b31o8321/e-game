## test_entity_ability — verify abstract EntityAbility + AbilitiesRegistry.
##
## Covers:
##   - Each ability type fires correct effect payload
##   - on_hp_threshold triggers once only and only when HP ratio ≤ threshold%
##   - turn_start triggers always (spec says "caller passes correct phase")
##   - reset() clears one-time triggered flag
##   - AbilitiesRegistry.make returns null for unknown id
##   - make_many skips unknowns
##   - All 7 default abilities can be instantiated
extends GutTest


# ─── EntityAbility unit tests ────────────────────────────────────

func test_heal_ability_apply_returns_healed_magnitude() -> void:
	var a := EntityAbility.new()
	a.id = "regen_2"
	a.trigger = "turn_start"
	a.effect_type = "heal"
	a.magnitude = 2
	var result: Dictionary = a.apply({})
	assert_eq(int(result["healed"]), 2, "heal effect returns healed=magnitude")
	assert_eq(int(result["shielded"]), 0)
	assert_eq(int(result["extra_actions"]), 0)


func test_shield_ability_apply_returns_shielded_magnitude() -> void:
	var a := EntityAbility.new()
	a.effect_type = "shield"
	a.magnitude = 5
	var result: Dictionary = a.apply({})
	assert_eq(int(result["shielded"]), 5)


func test_extra_action_ability_apply_returns_extra_actions() -> void:
	var a := EntityAbility.new()
	a.effect_type = "extra_action"
	a.magnitude = 1
	var result: Dictionary = a.apply({})
	assert_eq(int(result["extra_actions"]), 1)


func test_reflect_ability_apply_returns_reflected_damage_pct() -> void:
	var a := EntityAbility.new()
	a.effect_type = "reflect"
	a.magnitude = 25
	var result: Dictionary = a.apply({})
	assert_eq(int(result["reflected_damage"]), 25)


# ─── triggers ─────────────────────────────────────────────────────

func test_turn_start_should_trigger_always() -> void:
	var a := EntityAbility.new()
	a.trigger = "turn_start"
	assert_true(a.should_trigger({"hp": 10, "max_hp": 100}))


func test_turn_end_on_attack_on_damage_taken_trigger_always() -> void:
	for trig in ["turn_end", "on_attack", "on_damage_taken"]:
		var a := EntityAbility.new()
		a.trigger = trig
		assert_true(a.should_trigger({"hp": 10, "max_hp": 100}),
			"trigger %s should fire when phase matches" % trig)


func test_on_hp_threshold_triggers_only_when_below_threshold() -> void:
	var a := EntityAbility.new()
	a.trigger = "on_hp_threshold"
	a.threshold = 50
	# 80% HP → 不触发
	assert_false(a.should_trigger({"hp": 80, "max_hp": 100}))
	# 50% HP → 触发（≤）
	assert_true(a.should_trigger({"hp": 50, "max_hp": 100}))
	# 30% HP → 触发
	assert_true(a.should_trigger({"hp": 30, "max_hp": 100}))


func test_on_hp_threshold_triggers_once_only() -> void:
	var a := EntityAbility.new()
	a.trigger = "on_hp_threshold"
	a.threshold = 50
	assert_true(a.should_trigger({"hp": 30, "max_hp": 100}),
		"first should_trigger call returns true when below threshold")
	a.mark_triggered()
	assert_false(a.should_trigger({"hp": 30, "max_hp": 100}),
		"after mark_triggered, should not fire again even if still below threshold")


func test_reset_clears_triggered_once_flag() -> void:
	var a := EntityAbility.new()
	a.trigger = "on_hp_threshold"
	a.threshold = 50
	a.mark_triggered()
	assert_true(a.is_triggered_once())
	a.reset()
	assert_false(a.is_triggered_once())
	assert_true(a.should_trigger({"hp": 10, "max_hp": 100}),
		"after reset, threshold trigger fires again")


func test_unknown_trigger_never_fires() -> void:
	var a := EntityAbility.new()
	a.trigger = "made_up_phase"
	assert_false(a.should_trigger({"hp": 1, "max_hp": 100}))


# ─── AbilitiesRegistry ────────────────────────────────────────────

func test_registry_make_known_id_returns_instance() -> void:
	var a: EntityAbility = AbilitiesRegistry.make("regen_2")
	assert_not_null(a)
	assert_eq(a.id, "regen_2")
	assert_eq(a.effect_type, "heal")
	assert_eq(a.magnitude, 2)
	assert_eq(a.trigger, "turn_start")
	assert_eq(a.icon, "💚")


func test_registry_make_unknown_id_returns_null() -> void:
	var a: EntityAbility = AbilitiesRegistry.make("does_not_exist_xyz")
	assert_null(a)


func test_registry_known_ids_contains_seven_defaults() -> void:
	var ids: Array[String] = AbilitiesRegistry.known_ids()
	assert_true(ids.size() >= 7,
		"registry should expose ≥7 default abilities (got %d)" % ids.size())
	for required in ["regen_2", "regen_3", "shield_each_turn_5",
			"multi_action_2", "multi_action_3", "shield_at_50", "reflect_25"]:
		assert_true(required in ids, "registry must know %s" % required)


func test_registry_make_many_skips_unknown() -> void:
	var arr: Array[EntityAbility] = AbilitiesRegistry.make_many(
		["regen_2", "ghost", "shield_at_50"])
	assert_eq(arr.size(), 2, "unknown ids dropped silently")
	var got_ids: Array[String] = []
	for a in arr:
		got_ids.append(a.id)
	assert_true("regen_2" in got_ids)
	assert_true("shield_at_50" in got_ids)


func test_shield_at_50_threshold_trigger_correctly_built() -> void:
	var a: EntityAbility = AbilitiesRegistry.make("shield_at_50")
	assert_eq(a.trigger, "on_hp_threshold")
	assert_eq(a.effect_type, "shield")
	assert_eq(a.magnitude, 20)
	assert_eq(a.threshold, 50)
	# 60% → no trigger
	assert_false(a.should_trigger({"hp": 60, "max_hp": 100}))
	# 50% → trigger
	assert_true(a.should_trigger({"hp": 50, "max_hp": 100}))


func test_multi_action_2_grants_one_extra_action() -> void:
	var a: EntityAbility = AbilitiesRegistry.make("multi_action_2")
	assert_eq(a.effect_type, "extra_action")
	assert_eq(a.magnitude, 1, "multi_action_2 = 1 + 1 = 2 actions/turn")
	var result: Dictionary = a.apply({})
	assert_eq(int(result["extra_actions"]), 1)


func test_multi_action_3_grants_two_extra_actions() -> void:
	var a: EntityAbility = AbilitiesRegistry.make("multi_action_3")
	assert_eq(a.magnitude, 2, "multi_action_3 = 1 + 2 = 3 actions/turn")
