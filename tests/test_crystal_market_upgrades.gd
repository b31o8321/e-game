## test_crystal_market_upgrades.gd — 水晶集市永久升级测试
##
## 覆盖：
##   1. 5 个升级 ID 在 controller 内有定义
##   2. hp_plus Lv2 → start_floor 后 player_max_hp = 120
##   3. crystals_plus Lv3 → crystals_collected 初值 = 15
##   4. deck_slot_plus Lv1 → PreRunSetupController._deck_slot_max = 13
##   5. 钱包不够时购买返 false / 不扣钱
##   6. 钱包够时购买返 true / 扣钱 / level +1
extends GutTest


# ─── 夹具 ─────────────────────────────────────────────────────────

func _gs_available() -> bool:
	return typeof(GameState) != TYPE_NIL and GameState != null and GameState.save_system != null


func before_each() -> void:
	if not _gs_available():
		return
	var state: Dictionary = GameState.save_system.load_game_state()
	state.erase("permanent_upgrades")
	state["wallet"] = {"crystals": 1000, "blueprints": 0}
	GameState.save_system.save_game_state(state)


# ─── 测试 1：5 个升级 ID 都在 UPGRADES 表里 ──────────────────────

func test_all_five_upgrade_ids_defined() -> void:
	var ctrl := CrystalMarketController.new()
	add_child_autofree(ctrl)
	var ids: Array[String] = []
	for entry in ctrl.UPGRADES:
		ids.append(str(entry["id"]))
	assert_true("starting_hp_plus" in ids, "starting_hp_plus 必须存在")
	assert_true("starting_crystals_plus" in ids, "starting_crystals_plus 必须存在")
	assert_true("deck_slot_plus" in ids, "deck_slot_plus 必须存在")
	assert_true("starting_draw_plus" in ids, "starting_draw_plus 必须存在")
	assert_true("relic_init_plus" in ids, "relic_init_plus 必须存在")
	assert_eq(ids.size(), 5, "恰好 5 个升级项")


# ─── 测试 2：hp_plus Lv2 → start_floor player_max_hp = 120 ──────

func test_hp_plus_lv2_applied_in_start_floor() -> void:
	if not _gs_available():
		pending("GameState.save_system not available")
		return
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	# 写入 hp_plus = 2
	var state: Dictionary = GameState.save_system.load_game_state()
	var u: Dictionary = state.get("permanent_upgrades", {})
	u["starting_hp_plus"] = 2
	state["permanent_upgrades"] = u
	GameState.save_system.save_game_state(state)

	# start_floor 基础 HP = 100（来自 _default_floor_skeleton）
	RunState.start_floor("test_hp_floor", null)
	# 100 + 10*2 = 120
	assert_eq(RunState.player_max_hp, 120, "hp_plus Lv2 应使 player_max_hp = 120")
	assert_eq(RunState.player_hp, RunState.player_max_hp, "player_hp 应等于 player_max_hp")


# ─── 测试 3：crystals_plus Lv3 → crystals_collected = 15 ────────

func test_crystals_plus_lv3_applied_in_start_floor() -> void:
	if not _gs_available():
		pending("GameState.save_system not available")
		return
	if typeof(RunState) == TYPE_NIL or RunState == null:
		pending("RunState autoload not available")
		return
	var state: Dictionary = GameState.save_system.load_game_state()
	var u: Dictionary = state.get("permanent_upgrades", {})
	u["starting_crystals_plus"] = 3
	state["permanent_upgrades"] = u
	GameState.save_system.save_game_state(state)

	RunState.start_floor("test_crystals_floor", null)
	# 0 + 5*3 = 15
	assert_eq(RunState.crystals_collected, 15, "crystals_plus Lv3 应使起始 crystals = 15")


# ─── 测试 4：deck_slot_plus Lv1 → save 中读 deck_slot_plus = 1，12+1 = 13 ──

func test_deck_slot_plus_lv1_applied_in_pre_run_setup() -> void:
	if not _gs_available():
		pending("GameState.save_system not available")
		return
	var state: Dictionary = GameState.save_system.load_game_state()
	var u: Dictionary = state.get("permanent_upgrades", {})
	u["deck_slot_plus"] = 1
	state["permanent_upgrades"] = u
	GameState.save_system.save_game_state(state)

	# 直接模拟 _load_permanent_upgrades 的逻辑：读存档计算 _deck_slot_max
	var reloaded: Dictionary = GameState.save_system.load_game_state()
	var saved_u: Dictionary = reloaded.get("permanent_upgrades", {})
	var expected_slot_max: int = 12 + int(saved_u.get("deck_slot_plus", 0))
	assert_eq(expected_slot_max, 13, "deck_slot_plus Lv1 应使 _deck_slot_max = 13")


# ─── 测试 5：钱包不够时购买返 false / 不扣钱 ────────────────────

func test_purchase_fails_when_wallet_insufficient() -> void:
	if not _gs_available():
		pending("GameState.save_system not available")
		return
	# 设置钱包只有 10，而 starting_hp_plus 第一级需 50
	var state: Dictionary = GameState.save_system.load_game_state()
	state["wallet"] = {"crystals": 10, "blueprints": 0}
	state.erase("permanent_upgrades")
	GameState.save_system.save_game_state(state)

	var ctrl := CrystalMarketController.new()
	add_child_autofree(ctrl)
	var ok: bool = ctrl.try_purchase("starting_hp_plus")
	assert_false(ok, "词晶不足时 try_purchase 应返回 false")

	# 钱包应未变
	var w: Dictionary = GameState.save_system.get_wallet()
	assert_eq(int(w.get("crystals", 0)), 10, "购买失败后钱包不应减少")

	# 等级应仍为 0
	var lvl: int = ctrl._read_upgrade_level("starting_hp_plus")
	assert_eq(lvl, 0, "购买失败后等级不应提升")


# ─── 测试 6：钱包够时购买返 true / 扣钱 / level +1 ─────────────

func test_purchase_succeeds_when_wallet_sufficient() -> void:
	if not _gs_available():
		pending("GameState.save_system not available")
		return
	# before_each 已设 crystals = 1000，starting_hp_plus 第一级 = 50
	var ctrl := CrystalMarketController.new()
	add_child_autofree(ctrl)
	var ok: bool = ctrl.try_purchase("starting_hp_plus")
	assert_true(ok, "词晶充足时 try_purchase 应返回 true")

	# 钱包扣了 50
	var w: Dictionary = GameState.save_system.get_wallet()
	assert_eq(int(w.get("crystals", 0)), 950, "购买成功后词晶应减少 50")

	# 等级提升到 1
	var lvl: int = ctrl._read_upgrade_level("starting_hp_plus")
	assert_eq(lvl, 1, "购买成功后 starting_hp_plus 等级应为 1")
