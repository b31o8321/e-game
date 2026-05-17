## test_equipment.gd — Equipment 数据 + 注册表 + RunState 集成测试
##
## 覆盖（≥8 个 assert）：
##   1. EquipmentRegistry.get_all 返回 12
##   2. get_for_slot("weapon") 返回 4
##   3. RunState.equip(weapon) 装到 equipped_weapon
##   4. 装新 weapon 替换旧 weapon（返回 true）
##   5. equip(shield) 不动 weapon 字段
##   6. get_equipment_total_magnitude 合计正确
##   7. get_combined_magnitude（relic + equipment）合计正确
##   8. start_floor 重置三槽 null
extends GutTest


# ─── helpers ──────────────────────────────────────────────────────

func _make_equipment(id: String, slot: String, effect_type: String, magnitude: int) -> Equipment:
	var eq := Equipment.new()
	eq.id = id
	eq.display_name = id
	eq.slot = slot
	eq.effect_type = effect_type
	eq.magnitude = magnitude
	eq.icon = "⚔"
	eq.rarity = "common"
	return eq


func _make_relic(id: String, effect_type: String, magnitude: int) -> Relic:
	var r := Relic.new()
	r.id = id
	r.display_name = id
	r.effect_type = effect_type
	r.magnitude = magnitude
	r.rarity = "common"
	return r


# ─── 1. EquipmentRegistry.get_all 返回 12 ─────────────────────────

func test_registry_returns_twelve_equipment() -> void:
	var all := EquipmentRegistry.get_all()
	assert_eq(all.size(), 12, "registry should contain exactly 12 starter equipment items")


# ─── 2. get_for_slot("weapon") 返回 4 ────────────────────────────

func test_get_for_slot_weapon_returns_four() -> void:
	var weapons := EquipmentRegistry.get_for_slot("weapon")
	assert_eq(weapons.size(), 4, "get_for_slot('weapon') should return 4 items")


func test_get_for_slot_shield_returns_four() -> void:
	var shields := EquipmentRegistry.get_for_slot("shield")
	assert_eq(shields.size(), 4, "get_for_slot('shield') should return 4 items")


func test_get_for_slot_ring_returns_four() -> void:
	var rings := EquipmentRegistry.get_for_slot("ring")
	assert_eq(rings.size(), 4, "get_for_slot('ring') should return 4 items")


# ─── 3. RunState.equip(weapon) 装到 equipped_weapon ──────────────

func test_equip_weapon_sets_equipped_weapon() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	RunState.equipped_weapon = null
	RunState.equipped_shield = null
	RunState.equipped_ring = null
	var w := _make_equipment("test_w", "weapon", "damage_boost", 2)
	RunState.equip(w)
	assert_eq(RunState.equipped_weapon, w, "equipped_weapon should be set")
	assert_null(RunState.equipped_shield, "equipped_shield should remain null")
	assert_null(RunState.equipped_ring, "equipped_ring should remain null")


# ─── 4. 装新 weapon 替换旧 weapon（返回 true）───────────────────

func test_equip_weapon_replaces_and_returns_true() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	var w1 := _make_equipment("old_w", "weapon", "damage_boost", 1)
	var w2 := _make_equipment("new_w", "weapon", "damage_boost", 3)
	RunState.equipped_weapon = w1
	var replaced: bool = RunState.equip(w2)
	assert_true(replaced, "equip should return true when replacing an existing weapon")
	assert_eq(RunState.equipped_weapon, w2, "equipped_weapon should be the new item")


# ─── 5. equip(shield) 不动 weapon 字段 ───────────────────────────

func test_equip_shield_does_not_affect_weapon() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	var w := _make_equipment("my_w", "weapon", "damage_boost", 2)
	var s := _make_equipment("my_s", "shield", "shield_per_turn", 3)
	RunState.equipped_weapon = w
	RunState.equip(s)
	assert_eq(RunState.equipped_weapon, w, "equipped_weapon must not be changed when equipping a shield")
	assert_eq(RunState.equipped_shield, s, "equipped_shield should be set")


# ─── 6. get_equipment_total_magnitude 合计正确 ───────────────────

func test_get_equipment_total_magnitude() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	RunState.equipped_weapon = _make_equipment("eq_w", "weapon", "damage_boost", 3)
	RunState.equipped_shield = _make_equipment("eq_s", "shield", "damage_boost", 1)
	RunState.equipped_ring = _make_equipment("eq_r", "ring", "crystal_bonus", 5)
	var dmg_total: int = RunState.get_equipment_total_magnitude("damage_boost")
	assert_eq(dmg_total, 4, "damage_boost should sum weapon(3)+shield(1)=4")
	var crystal_total: int = RunState.get_equipment_total_magnitude("crystal_bonus")
	assert_eq(crystal_total, 5, "crystal_bonus should sum ring(5)=5")
	var missing: int = RunState.get_equipment_total_magnitude("heal_per_turn")
	assert_eq(missing, 0, "unequipped effect_type should return 0")


# ─── 7. get_combined_magnitude（relic + equipment）合计正确 ──────

func test_get_combined_magnitude_sums_relic_and_equipment() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	RunState.add_relic(_make_relic("r_dmg", "damage_boost", 4))
	RunState.equipped_weapon = _make_equipment("eq_dmg_w", "weapon", "damage_boost", 2)
	RunState.equipped_shield = null
	RunState.equipped_ring = null
	var combined: int = RunState.get_combined_magnitude("damage_boost")
	assert_eq(combined, 6, "combined damage_boost: relic(4)+weapon(2) = 6")


# ─── 8. start_floor 重置三槽 null ────────────────────────────────

func test_start_floor_resets_equipment_slots() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	RunState.equipped_weapon = _make_equipment("pre_w", "weapon", "damage_boost", 1)
	RunState.equipped_shield = _make_equipment("pre_s", "shield", "shield_per_turn", 1)
	RunState.equipped_ring = _make_equipment("pre_r", "ring", "crystal_bonus", 1)
	# start_floor without pack will reset slots
	RunState.start_floor("test_floor", null)
	assert_null(RunState.equipped_weapon, "equipped_weapon should be null after start_floor")
	assert_null(RunState.equipped_shield, "equipped_shield should be null after start_floor")
	assert_null(RunState.equipped_ring, "equipped_ring should be null after start_floor")
