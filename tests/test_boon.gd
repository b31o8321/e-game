## test_boon.gd — Boon 系统测试
##
## 覆盖：
##   - BoonRegistry.get_all() = 6
##   - BoonRegistry.get_by_id 已知/未知
##   - apply(heal_now) hp 上升不超 max
##   - apply(max_hp_up) max_hp 和 hp 都涨
##   - apply(crystal_now) crystals_collected 涨
##   - apply(extra_relic) 装备 1 个 relic
##   - apply(deck_polish_dmg) deck 内 damage 卡 base_damage +N
##   - after_each 重置 RunState 关键字段
extends GutTest


# ─── helpers ──────────────────────────────────────────────────────

func _make_boon(id: String, effect_type: String, magnitude: int) -> Boon:
	var b := Boon.new()
	b.id = id
	b.display_name = id
	b.description = ""
	b.effect_type = effect_type
	b.magnitude = magnitude
	return b


func _make_card(base_damage: int) -> Card:
	var c := Card.new()
	c.base_damage = base_damage
	return c


func _rs_available() -> bool:
	return typeof(RunState) != TYPE_NIL and RunState != null


func after_each() -> void:
	if not _rs_available():
		return
	RunState.player_hp = 100
	RunState.player_max_hp = 100
	RunState.crystals_collected = 0
	RunState.equipped_relics = []
	RunState.current_deck = []
	RunState.ap_bonus_next_turn = 0


# ─── BoonRegistry ─────────────────────────────────────────────────

func test_registry_returns_six_boons() -> void:
	var all := BoonRegistry.get_all()
	assert_eq(all.size(), 6, "registry should contain exactly 6 boons")


func test_registry_get_by_id_known() -> void:
	var b := BoonRegistry.get_by_id("boon_hp_potion")
	assert_not_null(b, "known id should return a Boon")
	assert_eq(b.id, "boon_hp_potion")
	assert_eq(b.effect_type, "heal_now")
	assert_eq(b.magnitude, 20)


func test_registry_get_by_id_unknown_returns_null() -> void:
	var b := BoonRegistry.get_by_id("boon_does_not_exist_xyz")
	assert_null(b, "unknown id should return null")


func test_registry_all_have_non_empty_ids() -> void:
	for b in BoonRegistry.get_all():
		assert_ne(b.id, "", "every boon must have a non-empty id")


# ─── apply: heal_now ─────────────────────────────────────────────

func test_apply_heal_now_increases_hp() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.player_max_hp = 100
	RunState.player_hp = 60
	var b := _make_boon("test_heal", "heal_now", 20)
	var ok := BoonRegistry.apply(b)
	assert_true(ok, "apply should return true")
	assert_eq(RunState.player_hp, 80, "hp should increase by 20")


func test_apply_heal_now_does_not_exceed_max() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.player_max_hp = 100
	RunState.player_hp = 95
	var b := _make_boon("test_heal_cap", "heal_now", 20)
	BoonRegistry.apply(b)
	assert_eq(RunState.player_hp, 100, "hp must not exceed max_hp")


# ─── apply: max_hp_up ────────────────────────────────────────────

func test_apply_max_hp_up_raises_both() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.player_max_hp = 100
	RunState.player_hp = 80
	var b := _make_boon("test_maxhp", "max_hp_up", 15)
	var ok := BoonRegistry.apply(b)
	assert_true(ok, "apply should return true")
	assert_eq(RunState.player_max_hp, 115, "max_hp should be 115")
	assert_eq(RunState.player_hp, 95, "hp should also increase by 15")


# ─── apply: crystal_now ──────────────────────────────────────────

func test_apply_crystal_now_increases_crystals() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 10
	var b := _make_boon("test_crystal", "crystal_now", 25)
	var ok := BoonRegistry.apply(b)
	assert_true(ok, "apply should return true")
	assert_eq(RunState.crystals_collected, 35, "crystals_collected should be 35")


# ─── apply: extra_relic ──────────────────────────────────────────

func test_apply_extra_relic_equips_one() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	var b := _make_boon("test_extra_relic", "extra_relic", 1)
	var ok := BoonRegistry.apply(b)
	assert_true(ok, "apply should return true")
	assert_eq(RunState.equipped_relics.size(), 1, "should have 1 relic equipped after boon")


# ─── apply: deck_polish_dmg ──────────────────────────────────────

func test_apply_deck_polish_dmg_increases_base_damage() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	var c1 := _make_card(3)
	var c2 := _make_card(0)   # zero-damage card should NOT be touched
	var c3 := _make_card(5)
	RunState.current_deck = [c1, c2, c3]
	var b := _make_boon("test_polish", "deck_polish_dmg", 1)
	var ok := BoonRegistry.apply(b)
	assert_true(ok, "apply should return true")
	assert_eq(c1.base_damage, 4, "damage card should be +1 → 4")
	assert_eq(c2.base_damage, 0, "zero-damage card should remain 0")
	assert_eq(c3.base_damage, 6, "damage card should be +1 → 6")


# ─── apply: ap_bonus_next_turn ───────────────────────────────────

func test_apply_ap_bonus_next_turn_accumulates() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.ap_bonus_next_turn = 0
	var b := _make_boon("test_ap", "ap_bonus_next_turn", 1)
	BoonRegistry.apply(b)
	assert_eq(RunState.ap_bonus_next_turn, 1, "ap_bonus_next_turn should be 1")
	BoonRegistry.apply(b)
	assert_eq(RunState.ap_bonus_next_turn, 2, "ap_bonus_next_turn should accumulate to 2")


# ─── apply: unknown effect_type ──────────────────────────────────

func test_apply_unknown_effect_returns_false() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	var b := _make_boon("test_unknown", "totally_invalid_type", 99)
	var ok := BoonRegistry.apply(b)
	assert_false(ok, "apply should return false for unknown effect_type")


# ─── apply: null boon ────────────────────────────────────────────

func test_apply_null_boon_returns_false() -> void:
	var ok := BoonRegistry.apply(null)
	assert_false(ok, "apply(null) should return false")
