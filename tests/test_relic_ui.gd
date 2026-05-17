## test_relic_ui.gd — Slice 3: Relic UI 展示（战斗顶栏 + 备战界面）
##
## 覆盖：
##   1. BattleScene 有 RelicRow 节点 + 装备 2 个 relic 后 RelicRow 有 2 个 child Label
##   2. PreRunSetupScene 有 RelicSection 节点 + 装备 1 个 relic 后 RelicListLabel.text 含 display_name
##   3. BattleScene 空 equipped_relics 时 RelicRow 无 child（不崩）
extends GutTest


const BattleSceneScene = preload("res://src/battle/battle_scene.tscn")
const PreRunSetupScene = preload("res://src/city/pre_run_setup_scene.tscn")


func _has_run_state() -> bool:
	return typeof(RunState) != TYPE_NIL and RunState != null


func _make_relic(id: String, dname: String, rarity: String = "common") -> Relic:
	var r := Relic.new()
	r.id = id
	r.display_name = dname
	r.icon = "🎁"
	r.effect_type = "damage_boost"
	r.magnitude = 2
	r.rarity = rarity
	r.description = "test relic"
	return r


func after_each() -> void:
	if _has_run_state():
		RunState.equipped_relics = []


# ─── 测试 1：BattleScene RelicRow 存在 + 渲染 2 个 relic ─────────────
func test_battle_scene_has_relic_row_node():
	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)
	var row = s.get_node_or_null("RelicRow")
	assert_not_null(row, "BattleScene 应有 RelicRow 节点")


func test_battle_scene_relic_row_renders_two_relics():
	if not _has_run_state():
		pass_test("无 RunState autoload，跳过")
		return
	RunState.equipped_relics = []
	RunState.equipped_relics.append(_make_relic("r1", "铁甲", "common"))
	RunState.equipped_relics.append(_make_relic("r2", "暗影", "rare"))

	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)

	var row = s.get_node_or_null("RelicRow")
	assert_not_null(row, "RelicRow 应存在")
	if row == null:
		return

	# _ready 已调 _render_relic_row；等一帧确保 queue_free 完成
	await get_tree().process_frame
	var children = row.get_children()
	assert_eq(children.size(), 2, "装备 2 个遗物后 RelicRow 应有 2 个 child")


# ─── 测试 2：PreRunSetupScene RelicSection 存在 + 渲染遗物名 ──────────
func test_pre_run_setup_has_relic_section():
	var s = PreRunSetupScene.instantiate()
	add_child_autofree(s)
	var sec = s.get_node_or_null("Body/Split/RightCol/RelicSection")
	assert_not_null(sec, "PreRunSetupScene 应有 RelicSection 节点")


func test_pre_run_setup_relic_list_label_shows_display_name():
	if not _has_run_state():
		pass_test("无 RunState autoload，跳过")
		return
	RunState.equipped_relics = []
	RunState.equipped_relics.append(_make_relic("r_iron", "铁甲盾", "uncommon"))

	var s = PreRunSetupScene.instantiate()
	add_child_autofree(s)

	await get_tree().process_frame
	var lbl: Label = s.get_node_or_null("Body/Split/RightCol/RelicSection/RelicListLabel")
	assert_not_null(lbl, "RelicListLabel 应存在")
	if lbl == null:
		return
	assert_true(lbl.text.contains("铁甲盾"), "RelicListLabel 应包含 relic.display_name '铁甲盾'，实际：" + lbl.text)


# ─── 测试 3：BattleScene 空 equipped_relics 时 RelicRow 无 child ──────
func test_battle_scene_empty_relics_no_child_no_crash():
	if not _has_run_state():
		pass_test("无 RunState autoload，跳过")
		return
	RunState.equipped_relics = []

	var s = BattleSceneScene.instantiate()
	add_child_autofree(s)

	await get_tree().process_frame
	var row = s.get_node_or_null("RelicRow")
	assert_not_null(row, "RelicRow 应存在")
	if row == null:
		return
	assert_eq(row.get_child_count(), 0, "空 equipped_relics 时 RelicRow 应无 child")
