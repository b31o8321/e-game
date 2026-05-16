## 防止"切楼层后单词库被前一楼存档覆盖"回归。
##
## 真实复现路径（用户上报）：
##   1. 0F 进入备战 → 用 0F 字母卡构成 13 张 → 启程 → 通关
##   2. 回城 → TowerGate → 1F → 备战 → 战斗里手牌还是 0F 的字母
##
## 根因：pre_run_setup_controller 早期实现把单词库存进全局 deck_templates[0]，
## 跨楼层共用一张表。修复后改成按 floor_id 分键：state["decks_by_floor"][floor_id]。
extends GutTest

const PreRunSetupScene := preload("res://src/city/pre_run_setup_scene.tscn")


# ─── Mock pack：0F 给字母 / 1F 给形容词，确认起始库按楼层分流 ──────
class _FloorAwareMockPack extends ContentPackBase:
	var _cards: Dictionary = {}
	var _starting_by_floor: Dictionary = {}

	func _init() -> void:
		pack_id = "test_floor_aware_pack"

	func get_id() -> String: return pack_id
	func get_display_name() -> String: return "Floor Test Pack"
	func get_subject_category() -> String: return "english"
	func get_grade_range() -> Array[int]: return [4]
	func get_version() -> String: return "test"
	func get_card_types() -> Array[Dictionary]: return [{"id": "word", "display": "词", "icon": ""}]
	func get_supported_challenge_kinds() -> Array[String]: return ["fill_in_blank"]
	func validate() -> Array[String]: return []
	func get_card(card_id: String) -> Card: return _cards.get(card_id, null)
	func get_all_cards() -> Array[Card]:
		var out: Array[Card] = []
		for c in _cards.values():
			out.append(c)
		return out

	func get_starting_deck_card_ids() -> Array[String]:
		# 缺省回退（任何未定义楼层都拿这个）
		var ids: Array[String] = _starting_by_floor.get("default", [])
		return ids.duplicate()

	func get_starting_deck_for_floor(floor_id: String) -> Array[String]:
		var ids_v: Variant = _starting_by_floor.get(floor_id, null)
		if ids_v is Array:
			var out: Array[String] = []
			for v in ids_v:
				out.append(str(v))
			return out
		return get_starting_deck_card_ids()

	func get_card_pool_for_floor(_floor_id: String) -> Array[Card]: return get_all_cards()
	func get_floor_config(floor_id: String) -> Dictionary:
		return {
			"floor_id": floor_id, "unit_name": "测试楼", "recommended_run_minutes": 5,
			"player_starting_hp": 100,
			"acts": [{"act_index": 1, "sub_topic_id": "t", "node_count": 1,
				"node_distribution": {"battle": 1, "elite": 0, "shop": 0, "rest": 0, "puzzle": 0, "mystery": 0},
				"boss_id": "b"}],
		}
	func get_floor_intro_panels(_floor_id: String) -> Array[CutscenePanel]: return []


func _make_card(id: String) -> Card:
	var c := Card.new()
	c.id = id
	c.text = id
	c.type = "word"
	c.base_damage = 5
	c.rarity = "common"
	return c


func _make_pack() -> _FloorAwareMockPack:
	var p := _FloorAwareMockPack.new()
	for cid in ["card_letter_a", "card_letter_b", "card_letter_c",
				"card_happy", "card_brave", "card_kind"]:
		p._cards[cid] = _make_card(cid)
	p._starting_by_floor = {
		"0F": ["card_letter_a", "card_letter_b", "card_letter_c"],
		"1F": ["card_happy", "card_brave", "card_kind"],
		"default": ["card_happy"],
	}
	return p


# ─── 夹具：替换 active pack + 清空存档里的 decks_by_floor ─────────
var _mock_pack: _FloorAwareMockPack = null
var _saved_active_id: String = ""
var _saved_state_snapshot: Dictionary = {}


func before_each() -> void:
	if typeof(GameState) != TYPE_NIL and GameState.content_loader != null:
		_saved_active_id = GameState.content_loader.get_active_pack_id()
		_mock_pack = _make_pack()
		add_child_autofree(_mock_pack)
		GameState.content_loader.register_pack(_mock_pack)
		GameState.content_loader.set_active_pack(_mock_pack.get_id())
	if typeof(GameState) != TYPE_NIL and GameState.save_system != null:
		_saved_state_snapshot = GameState.save_system.load_game_state().duplicate(true)
		var s: Dictionary = GameState.save_system.load_game_state()
		s.erase("decks_by_floor")
		s.erase("deck_templates")
		GameState.save_system.save_game_state(s)


func after_each() -> void:
	if typeof(GameState) != TYPE_NIL and GameState.content_loader != null and _saved_active_id != "":
		GameState.content_loader.set_active_pack(_saved_active_id)
	if typeof(GameState) != TYPE_NIL and GameState.save_system != null:
		GameState.save_system.save_game_state(_saved_state_snapshot)
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.pending_floor_id = ""


func _enter_floor(floor_id: String) -> PreRunSetupController:
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.pending_floor_id = floor_id
	var scene: PreRunSetupController = PreRunSetupScene.instantiate()
	scene.test_disable_scene_change = true
	add_child_autofree(scene)
	await get_tree().process_frame
	return scene


func _deck_ids(scene: PreRunSetupController) -> Array[String]:
	var out: Array[String] = []
	for c in scene.get_current_deck():
		if c != null:
			out.append(c.id)
	return out


# ─── 测试 ──────────────────────────────────────────────────────────

func test_floor_0F_empty_save_loads_floor_default_letters() -> void:
	var s := await _enter_floor("0F")
	var ids: Array[String] = _deck_ids(s)
	assert_eq(ids, ["card_letter_a", "card_letter_b", "card_letter_c"],
		"0F default = pack.get_starting_deck_for_floor('0F') letter cards")


func test_floor_1F_empty_save_loads_floor_default_adjectives() -> void:
	var s := await _enter_floor("1F")
	var ids: Array[String] = _deck_ids(s)
	assert_eq(ids, ["card_happy", "card_brave", "card_kind"],
		"1F default = pack.get_starting_deck_for_floor('1F') adjective cards")


func test_save_0F_deck_does_not_leak_into_1F() -> void:
	# 进 0F，保存（默认就保存）→ 进 1F → 必须是 1F 楼层默认，不是 0F 字母
	var s0 := await _enter_floor("0F")
	# 模拟玩家"启程"持久化（绕过场景切换：直接调内部 _persist_deck）
	s0._persist_deck()
	var s1 := await _enter_floor("1F")
	var ids1: Array[String] = _deck_ids(s1)
	assert_eq(ids1, ["card_happy", "card_brave", "card_kind"],
		"1F must NOT inherit 0F saved deck — bug from 2026-05-17 regression")


func test_save_0F_deck_round_trip_keeps_0F_custom() -> void:
	# 0F 自定义一下，启程持久化 → 再次进 0F 应该读到自定义内容
	var s0 := await _enter_floor("0F")
	s0.remove_card_at(0)  # 移走 card_letter_a
	s0._persist_deck()
	var s0b := await _enter_floor("0F")
	var ids: Array[String] = _deck_ids(s0b)
	assert_false("card_letter_a" in ids, "0F should reload the customized deck (no letter_a)")
	assert_true("card_letter_b" in ids, "rest preserved")
	assert_true("card_letter_c" in ids, "rest preserved")


func test_each_floor_has_independent_save_slot() -> void:
	# 0F 持久化一种自定义，1F 持久化另一种 → 互不影响
	var s0 := await _enter_floor("0F")
	s0._persist_deck()  # 写 [letter_a, letter_b, letter_c]
	var s1 := await _enter_floor("1F")
	s1.remove_card_at(0)  # 1F 移走 card_happy
	s1._persist_deck()  # 写 [brave, kind]

	var s0_reload := await _enter_floor("0F")
	assert_eq(_deck_ids(s0_reload), ["card_letter_a", "card_letter_b", "card_letter_c"],
		"0F slot untouched by 1F edits")
	var s1_reload := await _enter_floor("1F")
	assert_eq(_deck_ids(s1_reload), ["card_brave", "card_kind"],
		"1F slot kept its own customization")
