## PreRunSetupController / CardMiniView / CardPickerModal 测试
##
## 覆盖：
##   - 场景加载无错
##   - 默认卡组 = 内容包 starting_deck
##   - 添加 / 移除卡 → 卡组变化
##   - compute_deck_mastery_distribution 正确分组
##   - 启程触发 RunState.start_floor + 写 last_launched_floor_id
extends GutTest


const PreRunSetupScene := preload("res://src/city/pre_run_setup_scene.tscn")


# ─── 简易 Mock：只实现 starting_deck / get_card / pool ─────────────
class _MockCardPack extends ContentPackBase:
	var _cards: Dictionary = {}                   # id -> Card
	var _starting_ids: Array[String] = []
	var _floor_pool_ids: Dictionary = {}          # floor_id -> Array[String]

	func _init() -> void:
		pack_id = "test_card_pack"

	func get_id() -> String: return pack_id
	func get_display_name() -> String: return "Test Pack"
	func get_subject_category() -> String: return "english"
	func get_grade_range() -> Array[int]: return [4]
	func get_version() -> String: return "test"
	func get_card_types() -> Array[Dictionary]: return [{"id": "word", "display": "词卡", "icon": ""}]
	func get_supported_challenge_kinds() -> Array[String]: return ["fill_in_blank"]
	func validate() -> Array[String]: return []

	func get_card(card_id: String) -> Card:
		return _cards.get(card_id, null)

	func get_all_cards() -> Array[Card]:
		var out: Array[Card] = []
		for c in _cards.values():
			out.append(c)
		return out

	func get_starting_deck_card_ids() -> Array[String]:
		return _starting_ids.duplicate()

	func get_card_pool_for_floor(floor_id: String) -> Array[Card]:
		var out: Array[Card] = []
		var ids: Array = _floor_pool_ids.get(floor_id, [])
		for cid in ids:
			var c: Card = _cards.get(cid, null)
			if c != null:
				out.append(c)
		return out

	func get_floor_config(floor_id: String) -> Dictionary:
		return {
			"floor_id": floor_id,
			"unit_name": "测试楼层",
			"recommended_run_minutes": 10,
			"player_starting_hp": 100,
			"acts": [
				{
					"act_index": 1, "sub_topic_id": "topic_a", "node_count": 3,
					"node_distribution": {"battle": 2, "elite": 0, "shop": 0, "rest": 0, "puzzle": 0, "mystery": 0},
					"boss_id": "boss_a",
				},
			],
		}

	func get_floor_intro_panels(_floor_id: String) -> Array[CutscenePanel]:
		return []


func _make_card(id: String, text: String, type_str: String = "word") -> Card:
	var c := Card.new()
	c.id = id
	c.text = text
	c.type = type_str
	c.base_damage = 5
	c.rarity = "common"
	return c


func _make_pack_with_cards() -> _MockCardPack:
	var pack := _MockCardPack.new()
	for entry in [
		["card_happy", "happy"],
		["card_brave", "brave"],
		["card_sad", "sad"],
		["card_quiet", "quiet"],
		["card_angry", "angry"],
		["card_kind", "kind"],
	]:
		var c: Card = _make_card(entry[0], entry[1])
		pack._cards[c.id] = c
	pack._starting_ids = ["card_happy", "card_brave", "card_sad"]
	pack._floor_pool_ids = {"1F": ["card_quiet", "card_angry", "card_kind"]}
	return pack


# ─── 测试夹具：注入 mock pack 到 GameState ─────────────────────────
var _mock_pack: _MockCardPack = null
var _saved_active_id: String = ""


func before_each() -> void:
	# 保存 + 切换到测试包
	if typeof(GameState) != TYPE_NIL and GameState.content_loader != null:
		_saved_active_id = GameState.content_loader.get_active_pack_id()
		_mock_pack = _make_pack_with_cards()
		add_child_autofree(_mock_pack)
		GameState.content_loader.register_pack(_mock_pack)
		GameState.content_loader.set_active_pack(_mock_pack.get_id())
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.pending_floor_id = "1F"


func after_each() -> void:
	# 恢复原 active pack（避免污染其他测试）
	if typeof(GameState) != TYPE_NIL and GameState.content_loader != null and _saved_active_id != "":
		GameState.content_loader.set_active_pack(_saved_active_id)
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.pending_floor_id = ""


func _instance_setup_scene() -> Control:
	var scene: Control = PreRunSetupScene.instantiate()
	scene.test_disable_scene_change = true
	add_child_autofree(scene)
	return scene


# ───────────────────────────────────────────────────────────────────
# 测试用例
# ───────────────────────────────────────────────────────────────────

func test_scene_loads_without_errors() -> void:
	var scene: PreRunSetupController = _instance_setup_scene()
	assert_not_null(scene, "scene should instantiate")
	# 触发 _ready
	await get_tree().process_frame
	assert_not_null(scene.get_current_deck(), "deck array exists")


func test_default_deck_matches_starting_deck() -> void:
	var scene: PreRunSetupController = _instance_setup_scene()
	await get_tree().process_frame
	var deck: Array[Card] = scene.get_current_deck()
	assert_eq(deck.size(), 3, "starting deck has 3 cards")
	var ids: Array[String] = []
	for c in deck:
		ids.append(c.id)
	assert_true("card_happy" in ids, "deck contains card_happy")
	assert_true("card_brave" in ids, "deck contains card_brave")
	assert_true("card_sad" in ids, "deck contains card_sad")


func test_add_card_increases_deck_size() -> void:
	var scene: PreRunSetupController = _instance_setup_scene()
	await get_tree().process_frame
	var initial: int = scene.get_current_deck().size()
	var c: Card = _make_card("card_extra", "extra")
	var ok: bool = scene.add_card_to_deck(c)
	assert_true(ok, "add should succeed")
	assert_eq(scene.get_current_deck().size(), initial + 1, "deck size +1")


func test_add_card_respects_deck_slot_max() -> void:
	var scene: PreRunSetupController = _instance_setup_scene()
	await get_tree().process_frame
	var max_slots: int = scene.get_deck_slot_max()
	# 用循环填满
	while scene.get_current_deck().size() < max_slots:
		var c: Card = _make_card("filler_%d" % scene.get_current_deck().size(), "filler")
		scene.add_card_to_deck(c)
	assert_eq(scene.get_current_deck().size(), max_slots, "filled to max")
	# 再加一张应失败
	var extra: Card = _make_card("overflow", "overflow")
	var ok: bool = scene.add_card_to_deck(extra)
	assert_false(ok, "should reject when full")


func test_remove_card_at_index() -> void:
	var scene: PreRunSetupController = _instance_setup_scene()
	await get_tree().process_frame
	var initial: int = scene.get_current_deck().size()
	assert_true(initial > 0, "starting deck not empty")
	var ok: bool = scene.remove_card_at(0)
	assert_true(ok, "remove should succeed")
	assert_eq(scene.get_current_deck().size(), initial - 1, "deck size -1")
	# 越界
	assert_false(scene.remove_card_at(999), "out-of-range removal returns false")
	assert_false(scene.remove_card_at(-1), "negative index returns false")


func test_compute_deck_mastery_distribution_all_fresh_when_no_srs() -> void:
	var deck: Array[Card] = [
		_make_card("a", "a"),
		_make_card("b", "b"),
		_make_card("c", "c"),
	]
	var counts: Dictionary = PreRunSetupController.compute_deck_mastery_distribution(deck, null)
	assert_eq(int(counts["fresh"]), 3, "all 3 fresh when no SRS")
	assert_eq(int(counts["learning"]), 0, "0 learning")
	assert_eq(int(counts["proficient"]), 0, "0 proficient")
	assert_eq(int(counts["mastered"]), 0, "0 mastered")


func test_compute_deck_mastery_distribution_with_srs() -> void:
	var srs := SRSSystem.new()
	add_child_autofree(srs)
	# 让 card_b 处于 LEARNING（1-3 次正确），card_c 处于 PROFICIENT（4-7 次）
	srs.record_answer("b", true)
	for i in 5:
		srs.record_answer("c", true)
	# card_d MASTERED (8+)
	for i in 9:
		srs.record_answer("d", true)
	var deck: Array[Card] = [
		_make_card("a", "a"),     # FRESH
		_make_card("b", "b"),     # LEARNING
		_make_card("c", "c"),     # PROFICIENT
		_make_card("d", "d"),     # MASTERED
	]
	var counts: Dictionary = PreRunSetupController.compute_deck_mastery_distribution(deck, srs)
	assert_eq(int(counts["fresh"]), 1, "1 fresh")
	assert_eq(int(counts["learning"]), 1, "1 learning")
	assert_eq(int(counts["proficient"]), 1, "1 proficient")
	assert_eq(int(counts["mastered"]), 1, "1 mastered")


func test_launch_calls_run_state_start_floor() -> void:
	var scene: PreRunSetupController = _instance_setup_scene()
	await get_tree().process_frame
	# 测试模式下不真切场景
	assert_true(scene.test_disable_scene_change)
	scene._on_launch_pressed()
	assert_eq(scene.last_launched_floor_id, "1F", "floor_id captured")
	if typeof(RunState) != TYPE_NIL and RunState != null:
		assert_eq(RunState.current_floor_id, "1F", "RunState floor_id set")
		assert_true(RunState.current_deck.size() > 0, "deck transferred")


func test_clear_pressed_empties_deck() -> void:
	var scene: PreRunSetupController = _instance_setup_scene()
	await get_tree().process_frame
	assert_true(scene.get_current_deck().size() > 0, "deck has cards")
	scene._on_clear_pressed()
	assert_eq(scene.get_current_deck().size(), 0, "deck cleared")


func test_recommend_pressed_fills_deck_from_floor_pool() -> void:
	var scene: PreRunSetupController = _instance_setup_scene()
	await get_tree().process_frame
	# 清空再推荐
	scene._on_clear_pressed()
	assert_eq(scene.get_current_deck().size(), 0, "cleared")
	scene._on_recommend_pressed()
	# 应至少加入了 floor pool 中的某些卡
	var deck: Array[Card] = scene.get_current_deck()
	assert_true(deck.size() > 0, "recommend filled deck")
	var ids: Array[String] = []
	for c in deck:
		ids.append(c.id)
	# 至少其中一张应来自 1F pool
	var matched: bool = ("card_quiet" in ids) or ("card_angry" in ids) or ("card_kind" in ids)
	assert_true(matched, "recommended cards include floor pool entries")


func test_card_mini_view_loads_with_card() -> void:
	var scene := preload("res://src/battle/cards/card_mini_view.tscn").instantiate()
	add_child_autofree(scene)
	var c: Card = _make_card("vmini", "happy", "word")
	scene.set_card(c, null)
	await get_tree().process_frame
	assert_eq(scene.card.id, "vmini", "card id stored")


func test_card_picker_modal_emits_signal() -> void:
	var modal := preload("res://src/city/buildings/card_picker_modal.tscn").instantiate()
	add_child_autofree(modal)
	var c1: Card = _make_card("p1", "p1")
	var c2: Card = _make_card("p2", "p2")
	var typed: Array[Card] = [c1, c2]
	modal.set_options(typed, null)
	# 触发 _ready
	await get_tree().process_frame
	# 用 Array 容器接收（GDScript lambda 对局部值的赋值不会回写）
	var captured: Array = []
	modal.card_picked.connect(func(c: Card) -> void: captured.append(c))
	modal._on_card_button_pressed(c1)
	assert_eq(captured.size(), 1, "exactly one signal emission")
	assert_not_null(captured[0], "captured card not null")
	assert_eq(captured[0].id, "p1", "picker emitted picked card")
