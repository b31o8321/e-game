## test_battle_death_flow — verify the player-death path routes to settlement.
##
## We don't spin up the entire BattleScene (it depends on GameState autoload + a
## real BattleController + an EnemyData). Instead we verify:
##   1. battle_scene.gd contains the wiring that calls RunState.settle_retreat()
##      and changes scene to SETTLEMENT_SCENE on victory=false.
##   2. RunState.settle_retreat correctly persists shrunk crystals + full blueprints.
##   3. SettlementScene renders both 撤退 and 通关 paths without crashing.
extends GutTest

const SETTLEMENT_SCENE_PATH := "res://src/run/settlement_scene.tscn"


# --- 1. battle_scene.gd source wiring ---

func test_battle_scene_routes_to_settlement_on_defeat() -> void:
	var f: FileAccess = FileAccess.open("res://src/battle/battle_scene.gd", FileAccess.READ)
	assert_not_null(f, "battle_scene.gd should be readable")
	var src: String = f.get_as_text()
	f.close()
	# The handler should reference SETTLEMENT_SCENE constant + settle_retreat.
	assert_true(src.contains("SETTLEMENT_SCENE"), "should reference settlement scene constant")
	assert_true(src.contains("settle_retreat"), "should call RunState.settle_retreat on defeat")
	# Defeat path must exist (helper function or inline branch).
	assert_true(
		src.contains("_route_after_defeat") or src.contains("if not victory"),
		"battle_scene must have a defeat-routing path"
	)


# --- 2. RunState.settle_retreat persists with reduced crystal ratio ---

func test_settle_retreat_keeps_70_percent_crystals_and_full_blueprints() -> void:
	# Use a fresh local RunState (autoload still exists at root, but a local
	# instance lets us avoid contaminating shared state).
	var rs: Node = preload("res://src/run/run_state.gd").new()
	add_child_autofree(rs)
	rs.crystals_collected = 100
	rs.blueprints_collected = 7
	rs.current_floor_id = "0F"
	# settle_retreat will try to access GameState.save_system; OK to no-op.
	var report: Dictionary = rs.settle_retreat()
	assert_true(report.get("victory", true) == false, "report should mark victory=false")
	assert_eq(int(report.get("crystals_collected", 0)), 100)
	assert_eq(int(report.get("crystals_kept", 0)), 70, "撤退保留 70% 词晶")
	assert_eq(int(report.get("blueprints_kept", 0)), 7, "蓝图全部保留")
	assert_true(rs.did_retreat_this_run, "should mark retreat flag for star calculation")


# --- 3. Settlement scene renders without crashing ---

func test_settlement_scene_loads_without_crashing() -> void:
	var packed: PackedScene = load(SETTLEMENT_SCENE_PATH)
	assert_not_null(packed, "settlement_scene.tscn should load")
	var inst: Control = packed.instantiate()
	add_child_autofree(inst)
	# 等一帧让 _ready 跑完
	await get_tree().process_frame
	# 标题应被设置（撤退 OR 通关）
	var title: Label = inst.get_node_or_null("TitleLabel") as Label
	assert_not_null(title)
	assert_true(title.text == "撤退" or title.text == "★ 通关 ★",
		"title should match one of the two settled states: %s" % title.text)
	# Back 按钮必须存在并文案正确
	var back: Button = inst.get_node_or_null("BackButton") as Button
	assert_not_null(back, "BackButton expected")
	assert_eq(back.text, "回知识城")


# --- 4. Settlement scene shows retreat copy when no act maps exist ---

func test_settlement_renders_retreat_when_run_state_empty() -> void:
	# Tap the existing autoload RunState (clear act maps so _infer_victory returns false)
	if typeof(RunState) == TYPE_NIL:
		pass_test("RunState autoload not present in test runtime; skipping")
		return
	RunState.act_maps = []
	RunState.current_act_index = 0
	var packed: PackedScene = load(SETTLEMENT_SCENE_PATH)
	var inst: Control = packed.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var title: Label = inst.get_node_or_null("TitleLabel") as Label
	assert_eq(title.text, "撤退", "no act_maps means defeat path")
