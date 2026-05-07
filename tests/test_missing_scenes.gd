## 4 个新场景的最小烟雾测试：
##   - camp_scene.tscn
##   - settlement_scene.tscn
##   - blueprint_workshop_scene.tscn
##   - guardians_quarters_scene.tscn
##
## 仅验证：场景能 load + instantiate + add_child 而不抛错（覆盖 _ready 路径）。
## 详细业务逻辑测试可后续补。
extends GutTest

const CAMP_SCENE := "res://src/run/camp_scene.tscn"
const SETTLEMENT_SCENE := "res://src/run/settlement_scene.tscn"
const BLUEPRINT_WORKSHOP_SCENE := "res://src/city/buildings/blueprint_workshop_scene.tscn"
const GUARDIANS_QUARTERS_SCENE := "res://src/city/buildings/guardians_quarters_scene.tscn"


func _instantiate_and_attach(path: String) -> Node:
	var packed: PackedScene = load(path)
	assert_not_null(packed, "PackedScene must load: " + path)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	assert_not_null(inst, "instantiate must succeed: " + path)
	add_child_autofree(inst)
	return inst


func test_camp_scene_instantiates() -> void:
	var n: Node = _instantiate_and_attach(CAMP_SCENE)
	await get_tree().process_frame
	assert_not_null(n)
	assert_true(n is Control, "camp_scene root should be Control")


func test_settlement_scene_instantiates() -> void:
	var n: Node = _instantiate_and_attach(SETTLEMENT_SCENE)
	await get_tree().process_frame
	assert_not_null(n)
	assert_true(n is Control, "settlement_scene root should be Control")


func test_blueprint_workshop_scene_instantiates() -> void:
	var n: Node = _instantiate_and_attach(BLUEPRINT_WORKSHOP_SCENE)
	await get_tree().process_frame
	assert_not_null(n)
	assert_true(n is Control, "blueprint_workshop_scene root should be Control")


func test_guardians_quarters_scene_instantiates() -> void:
	var n: Node = _instantiate_and_attach(GUARDIANS_QUARTERS_SCENE)
	await get_tree().process_frame
	assert_not_null(n)
	assert_true(n is Control, "guardians_quarters_scene root should be Control")


func test_camp_scene_has_expected_buttons() -> void:
	var n: Node = _instantiate_and_attach(CAMP_SCENE)
	await get_tree().process_frame
	assert_not_null(n.get_node_or_null("DepartButton"), "DepartButton must exist")
	assert_not_null(n.get_node_or_null("LeftPanel/SkipButton"), "SkipButton must exist")
	assert_not_null(n.get_node_or_null("RightPanel/HealButton"), "HealButton must exist")


func test_settlement_scene_has_back_button() -> void:
	var n: Node = _instantiate_and_attach(SETTLEMENT_SCENE)
	await get_tree().process_frame
	assert_not_null(n.get_node_or_null("BackButton"), "BackButton must exist")


func test_blueprint_workshop_has_items_container() -> void:
	var n: Node = _instantiate_and_attach(BLUEPRINT_WORKSHOP_SCENE)
	await get_tree().process_frame
	assert_not_null(n.get_node_or_null("ItemScroll/ItemList"), "ItemList must exist")


func test_guardians_quarters_has_tabs() -> void:
	var n: Node = _instantiate_and_attach(GUARDIANS_QUARTERS_SCENE)
	await get_tree().process_frame
	var tabs: Node = n.get_node_or_null("Tabs")
	assert_not_null(tabs, "TabContainer must exist")
	assert_not_null(n.get_node_or_null("Tabs/角色"), "角色 tab must exist")
	assert_not_null(n.get_node_or_null("Tabs/卡组库"), "卡组库 tab must exist")
	assert_not_null(n.get_node_or_null("Tabs/三星挑战"), "三星挑战 tab must exist")
