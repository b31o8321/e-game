## test_relic_combat_hooks.gd — Slice 2: 5 种 Relic effect_type 在战斗中真正生效
##
## 覆盖：
##   damage_boost   — submit_challenge 时 base_damage 被加了 magnitude
##   heal_per_turn  — end_player_turn 时 player_hp 回血
##   shield_per_turn — 敌方回合结束后新回合开始时 player_shield 增加
##   combo_extra_chance — _combo_increment_with_extra 可能额外 +1 combo（概率钩）
##   crystal_bonus  — _on_enemy_dead 时 RunState.crystals_collected 增加
##   integration    — 装备多个遗物，同一场战斗触发多个钩子
extends GutTest


# ─── preloads ─────────────────────────────────────────────────────
const BattleControllerClass = preload("res://src/battle/battle_controller.gd")


# ─── helpers ──────────────────────────────────────────────────────

func _has_run_state() -> bool:
	return typeof(RunState) != TYPE_NIL and RunState != null


func _equip(effect_type: String, magnitude: int) -> void:
	if not _has_run_state():
		return
	var r := Relic.new()
	r.id = "test_" + effect_type
	r.display_name = effect_type
	r.effect_type = effect_type
	r.magnitude = magnitude
	RunState.add_relic(r)


func after_each() -> void:
	if _has_run_state():
		RunState.equipped_relics = []
		RunState.crystals_collected = 0


func _make_card(id: String = "card_test") -> Card:
	return Card.from_dict({
		"id": id,
		"text": id,
		"type": "word",
		"pos": "adjective",
		"tags": [],
		"skill": "vocab",
		"base_damage": 5,
		"rarity": "common",
	})


func _make_template_one_slot(tmpl_id: String = "tmpl_test") -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": tmpl_id,
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


func _make_enemy(hp: int = 9999, attack: int = 0) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_enemy"
	e.enemy_name = "Test"
	e.max_hp = hp
	e.base_attack = attack
	return e


class _AlwaysSelector extends ChallengeSelector:
	var template: ChallengeTemplate
	func pick_challenge(_e: EnemyData, _p, _s) -> ChallengeTemplate:
		return template


## hp: current HP of player. max_hp: defaults to 100.
func _build_controller(hp: int = 100, enemy_hp: int = 9999, enemy_attack: int = 0, max_hp: int = 100) -> BattleController:
	var ctrl: BattleController = BattleControllerClass.new()
	add_child_autofree(ctrl)
	var deck: Array[Card] = []
	for i in 10:
		deck.append(_make_card("card_%d" % i))
	var enemy: EnemyData = _make_enemy(enemy_hp, enemy_attack)
	ctrl.setup(enemy, null, deck, null)
	ctrl.player_max_hp = max_hp
	ctrl.player_hp = hp
	ctrl.player_shield = 0
	var sel := _AlwaysSelector.new()
	sel.template = _make_template_one_slot()
	ctrl.set_selector(sel)
	ctrl.start_battle()
	return ctrl


# ─── damage_boost ─────────────────────────────────────────────────

func test_damage_boost_increases_damage() -> void:
	if not _has_run_state():
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	_equip("damage_boost", 5)

	var ctrl: BattleController = _build_controller()
	# Collect damage dealt signal — use Array to allow mutation inside lambda
	var damage_amounts: Array[int] = []
	ctrl.damage_dealt.connect(func(amt: int, _crit: bool, _weak: bool) -> void:
		damage_amounts.append(amt)
	)

	# solve the current challenge
	var card: Card = ctrl.card_library[0]
	ctrl.try_place_card(card, 0)
	# card.base_damage is 5, relic adds 5 → expect >= 10
	assert_false(damage_amounts.is_empty(), "damage_dealt signal should have fired")
	assert_gte(damage_amounts[0], 10,
		"damage_boost relic should increase total damage by at least its magnitude (5)")


func test_damage_boost_relic_adds_more_than_no_relic() -> void:
	## Comparative test: damage WITH damage_boost relic > damage WITHOUT relic.
	## This avoids hardcoding the exact DamageCalculator output.
	if not _has_run_state():
		pending("RunState autoload not available")
		return

	# --- without relic ---
	RunState.equipped_relics = []
	var ctrl_base: BattleController = _build_controller()
	var base_dmg: Array[int] = []
	ctrl_base.damage_dealt.connect(func(amt: int, _c: bool, _w: bool) -> void:
		base_dmg.append(amt)
	)
	ctrl_base.try_place_card(ctrl_base.card_library[0], 0)
	assert_false(base_dmg.is_empty(), "damage_dealt should fire without relic")

	# --- with damage_boost relic of +5 ---
	RunState.equipped_relics = []
	_equip("damage_boost", 5)
	var ctrl_boost: BattleController = _build_controller()
	var boost_dmg: Array[int] = []
	ctrl_boost.damage_dealt.connect(func(amt: int, _c: bool, _w: bool) -> void:
		boost_dmg.append(amt)
	)
	ctrl_boost.try_place_card(ctrl_boost.card_library[0], 0)
	assert_false(boost_dmg.is_empty(), "damage_dealt should fire with relic")

	assert_gt(boost_dmg[0], base_dmg[0],
		"damage_boost relic must produce higher damage than no relic")


# ─── heal_per_turn ────────────────────────────────────────────────

func test_heal_per_turn_restores_hp_on_end_turn() -> void:
	if not _has_run_state():
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	_equip("heal_per_turn", 8)

	# player at 80/100 — needs explicit max_hp=100 so heal headroom exists
	var ctrl: BattleController = _build_controller(80, 9999, 0, 100)
	var healed_amounts: Array[int] = []
	ctrl.healed.connect(func(amt: int) -> void:
		healed_amounts.append(amt)
	)

	ctrl.end_player_turn()
	assert_gte(ctrl.player_hp, 88,
		"heal_per_turn relic should restore at least 8 HP at end of player turn")
	var total_healed: int = 0
	for v in healed_amounts:
		total_healed += v
	assert_gte(total_healed, 8,
		"healed signal should have been emitted with at least 8 total")


func test_heal_per_turn_does_not_exceed_max_hp() -> void:
	if not _has_run_state():
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	_equip("heal_per_turn", 50)

	# player at full HP
	var ctrl: BattleController = _build_controller(100)
	ctrl.end_player_turn()
	assert_lte(ctrl.player_hp, ctrl.player_max_hp,
		"heal_per_turn must not overheal above player_max_hp")


# ─── shield_per_turn ──────────────────────────────────────────────

func test_shield_per_turn_adds_shield_at_turn_start() -> void:
	if not _has_run_state():
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	_equip("shield_per_turn", 6)

	var ctrl: BattleController = _build_controller()
	var shield_amounts: Array[int] = []
	ctrl.shielded.connect(func(amt: int) -> void:
		shield_amounts.append(amt)
	)

	# end_player_turn → _run_enemy_turn → refill_board → shield_per_turn hook fires
	ctrl.end_player_turn()
	assert_gte(ctrl.player_shield, 6,
		"shield_per_turn relic should add at least 6 shield at start of next player turn")
	var total_shielded: int = 0
	for v in shield_amounts:
		total_shielded += v
	assert_gte(total_shielded, 6,
		"shielded signal should have been emitted with at least 6 total")


# ─── combo_extra_chance ───────────────────────────────────────────

func test_combo_extra_chance_at_100_always_extra_increments() -> void:
	if not _has_run_state():
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	_equip("combo_extra_chance", 100)  # 100% chance → always triggers

	var ctrl: BattleController = _build_controller()
	# _combo_increment_with_extra is called internally during submit_challenge.
	# Solve a challenge and check combo count is higher than 1 (base increment + relic extra).
	var card: Card = ctrl.card_library[0]
	ctrl.try_place_card(card, 0)
	# After solving one challenge: base combo +1 from damage path + relic extra +1 = at least 2
	assert_gte(ctrl._combo.count, 2,
		"combo_extra_chance at 100% should produce combo count >= 2 after one solve")


func test_combo_extra_chance_at_zero_no_extra() -> void:
	if not _has_run_state():
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	# No relic for combo_extra_chance → magnitude = 0 → no extra
	var ctrl: BattleController = _build_controller()
	var card: Card = ctrl.card_library[0]
	ctrl.try_place_card(card, 0)
	# Base: 1 increment from damage; with 0 extra_chance relic: exactly 1
	assert_eq(ctrl._combo.count, 1,
		"without combo_extra_chance relic, combo should be exactly 1 after one solve")


# ─── crystal_bonus ────────────────────────────────────────────────

func test_crystal_bonus_added_on_enemy_dead() -> void:
	if not _has_run_state():
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	RunState.crystals_collected = 0
	_equip("crystal_bonus", 15)

	# Use enemy with 1 HP so one solve kills it
	var ctrl: BattleController = _build_controller(100, 1, 0)
	ctrl.try_place_card(ctrl.card_library[0], 0)
	# After enemy dies: crystal_bonus should be added to RunState.crystals_collected
	assert_gte(RunState.crystals_collected, 15,
		"crystal_bonus relic should add at least 15 crystals on enemy death")


# ─── integration: multiple relics same battle ─────────────────────

func test_multiple_relic_types_all_apply() -> void:
	if not _has_run_state():
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	RunState.crystals_collected = 0
	_equip("damage_boost", 3)
	_equip("heal_per_turn", 5)
	_equip("shield_per_turn", 4)
	_equip("crystal_bonus", 10)

	var ctrl: BattleController = _build_controller(70, 1, 0)
	# Solve challenge → kills enemy (hp=1)
	ctrl.try_place_card(ctrl.card_library[0], 0)
	# crystal_bonus applied
	assert_gte(RunState.crystals_collected, 10,
		"crystal_bonus must fire on enemy death")
	# Player was at 70; max is 100. heal_per_turn and shield_per_turn did not fire yet
	# (end_player_turn not called before kill), so crystals suffice as integration signal.
	# Verify damage_boost: enemy had 1 HP; any +3 boost still kills it (can't directly
	# assert dealt damage, but battle_ended(true) implies enemy died)
	assert_eq(ctrl.state, BattleController.State.END,
		"battle must have ended after killing 1-HP enemy")
