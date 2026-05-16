## test_relic_core.gd — Relic 数据 + 注册表 + RunState 集成测试
##
## 覆盖：
##   - RelicRegistry.get_all() 返回 10 个
##   - RelicRegistry.get_by_id 已知/未知 id
##   - RunState.add_relic 成功 / 重复返 false
##   - RunState.has_relic
##   - RunState.get_relic_total_magnitude 累加
##   - start_floor 重置 equipped_relics
extends GutTest


# ─── helpers ──────────────────────────────────────────────────────

func _make_relic(id: String, effect_type: String, magnitude: int) -> Relic:
	var r := Relic.new()
	r.id = id
	r.display_name = id
	r.effect_type = effect_type
	r.magnitude = magnitude
	r.rarity = "common"
	return r


# ─── RelicRegistry ────────────────────────────────────────────────

func test_registry_returns_ten_relics() -> void:
	var all := RelicRegistry.get_all()
	assert_eq(all.size(), 10, "registry should contain exactly 10 starter relics")


func test_registry_get_by_id_known() -> void:
	var r := RelicRegistry.get_by_id("relic_word_amulet")
	assert_not_null(r, "known id should return a Relic")
	assert_eq(r.id, "relic_word_amulet", "id should match")
	assert_eq(r.effect_type, "damage_boost", "effect_type should be damage_boost")
	assert_eq(r.magnitude, 2, "magnitude should be 2")


func test_registry_get_by_id_unknown_returns_null() -> void:
	var r := RelicRegistry.get_by_id("relic_does_not_exist_xyz")
	assert_null(r, "unknown id should return null")


func test_registry_all_have_non_empty_ids() -> void:
	var all := RelicRegistry.get_all()
	for r in all:
		assert_ne(r.id, "", "every relic must have a non-empty id")


# ─── RunState.add_relic / has_relic ──────────────────────────────

func test_add_relic_success() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available in this test context")
		return
	RunState.equipped_relics = []
	var r := _make_relic("test_relic_a", "damage_boost", 3)
	var ok := RunState.add_relic(r)
	assert_true(ok, "add_relic should return true on first add")
	assert_eq(RunState.equipped_relics.size(), 1, "equipped_relics should have 1 entry")


func test_add_relic_duplicate_returns_false() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	var r := _make_relic("test_relic_b", "heal_per_turn", 2)
	RunState.add_relic(r)
	var second := RunState.add_relic(r)
	assert_false(second, "add_relic should return false when relic already equipped")
	assert_eq(RunState.equipped_relics.size(), 1, "no duplicate should be stored")


func test_has_relic_true_and_false() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	var r := _make_relic("test_relic_c", "shield_per_turn", 3)
	RunState.add_relic(r)
	assert_true(RunState.has_relic("test_relic_c"), "has_relic should be true after add")
	assert_false(RunState.has_relic("nonexistent_relic"), "has_relic should be false for unknown id")


# ─── RunState.get_relic_total_magnitude ──────────────────────────

func test_get_relic_total_magnitude_cumulates() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	RunState.add_relic(_make_relic("dmg_1", "damage_boost", 2))
	RunState.add_relic(_make_relic("dmg_2", "damage_boost", 4))
	RunState.add_relic(_make_relic("heal_1", "heal_per_turn", 3))
	var dmg_total := RunState.get_relic_total_magnitude("damage_boost")
	assert_eq(dmg_total, 6, "damage_boost magnitudes should sum to 6")
	var heal_total := RunState.get_relic_total_magnitude("heal_per_turn")
	assert_eq(heal_total, 3, "heal_per_turn magnitude should be 3")
	var missing := RunState.get_relic_total_magnitude("crystal_bonus")
	assert_eq(missing, 0, "unequipped effect_type should sum to 0")


# ─── start_floor 重置 equipped_relics ────────────────────────────

func test_start_floor_resets_equipped_relics() -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	RunState.equipped_relics = []
	RunState.add_relic(_make_relic("pre_floor_relic", "damage_boost", 5))
	assert_eq(RunState.equipped_relics.size(), 1, "precondition: one relic equipped")

	# start_floor 需要 pack；传 null 会走 warning 分支但仍会 reset
	RunState.start_floor("test_floor_relic_reset", null)
	assert_eq(RunState.equipped_relics.size(), 0,
		"start_floor must clear equipped_relics")
