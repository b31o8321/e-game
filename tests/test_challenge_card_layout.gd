## test_challenge_card_layout — verifies the inline-flow ChallengeCard layout
## (HFlowContainer-based) renders dialogue text + slot widgets as siblings so
## long questions stay readable (no vertical-strip char wrap).
##
## Bug fixed: when a card had 2 slots and dialogue like
##   "Listen: c-___-t. Spell it. ___"
## the previous HBoxContainer squeezed the text into ~40px columns and
## word-wrapped to single chars per row. Now slots & text fragments share a
## single HFlowContainer that wraps cleanly between words.
extends GutTest


const BATTLE_SCENE: String = "res://src/battle/battle_scene.tscn"


# ─── helpers ──────────────────────────────────────────────────────

func _make_card(overrides: Dictionary = {}) -> Card:
	var base := {
		"id": "card_brave",
		"text": "brave",
		"type": "word",
		"pos": "adjective",
		"tags": ["positive_emotion"],
		"skill": "vocab",
		"base_damage": 8,
		"rarity": "common",
	}
	for k in overrides.keys():
		base[k] = overrides[k]
	return Card.from_dict(base)


func _make_two_slot_template() -> ChallengeTemplate:
	# 双槽长句子——重现 "Listen: c-___-t. Spell it. ___" 这类问题。
	return ChallengeTemplate.from_dict({
		"template_id": "tmpl_two_slot",
		"kind": "fill_in_blank",
		"dialogue": "Listen: c-___-t. Spell it. ___",
		"slots": [
			{
				"index": 0,
				"required_pos": "adjective",
				"damage_multiplier": 1.0,
			},
			{
				"index": 1,
				"required_pos": "adjective",
				"damage_multiplier": 1.0,
			},
		],
		"topic_id": "test_topic",
	})


func _make_enemy() -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_enemy"
	e.enemy_name = "测试敌人"
	e.max_hp = 30
	e.base_attack = 5
	e.weak_axes = []
	e.topic_id = "test_topic"
	return e


class _StubSelector extends ChallengeSelector:
	var template: ChallengeTemplate

	func _init() -> void:
		super()

	func pick_challenge(_enemy: EnemyData, _pack, _srs) -> ChallengeTemplate:
		return template


func _prime_globals_with_deck(deck: Array[Card]) -> void:
	if typeof(GameState) != TYPE_NIL and GameState != null:
		GameState.pending_enemy = _make_enemy()
		GameState.expedition_return_scene = ""
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.current_deck.clear()
		for c in deck:
			RunState.current_deck.append(c)
		RunState.current_floor_id = "1F"
		RunState.current_act_index = 0


func _instantiate_scene() -> Control:
	var packed: PackedScene = load(BATTLE_SCENE)
	assert_not_null(packed)
	if packed == null:
		return null
	var inst: Control = packed.instantiate() as Control
	add_child_autofree(inst)
	return inst


func _replace_selector_and_force_render(scene: Control, template: ChallengeTemplate) -> BattleController:
	var ctrl: BattleController = scene.get("_controller")
	if ctrl == null:
		return null
	var stub := _StubSelector.new()
	stub.template = template
	ctrl.set_selector(stub)
	# Replace whatever the auto-refill picked with our 2-slot template.
	ctrl.available_challenges.clear()
	ctrl.available_filled_slots.clear()
	ctrl.add_to_board(template)
	if scene.has_method("_render_challenge"):
		scene.call("_render_challenge")
	return ctrl


# ─── tests ────────────────────────────────────────────────────────

func test_two_slot_card_renders_slots_and_text_in_flow_container() -> void:
	var deck: Array[Card] = [_make_card()]
	for i in 4:
		deck.append(_make_card({"id": "extra_%d" % i}))
	_prime_globals_with_deck(deck)
	var scene: Control = _instantiate_scene()
	await get_tree().process_frame

	_replace_selector_and_force_render(scene, _make_two_slot_template())
	await get_tree().process_frame

	var board_row: HBoxContainer = scene.get_node("ChallengeBoardPanel/ChallengeContent/BoardRow")
	assert_not_null(board_row, "BoardRow must exist")

	# Find the first ChallengeCard
	var card_panel: PanelContainer = null
	for child in board_row.get_children():
		if child is PanelContainer:
			card_panel = child
			break
	assert_not_null(card_panel, "BoardRow should hold at least one ChallengeCard PanelContainer")

	# Walk the tree and find the HFlowContainer holding dialogue + slots
	var flow: HFlowContainer = null
	var queue: Array = [card_panel]
	while not queue.is_empty():
		var n: Node = queue.pop_back()
		if n is HFlowContainer:
			flow = n as HFlowContainer
			break
		for c in n.get_children():
			queue.append(c)
	assert_not_null(flow, "ChallengeCard should use HFlowContainer for dialogue+slots")
	if flow == null:
		return

	# Inside the flow: count Labels (text fragments) and PanelContainers (slots)
	var label_count: int = 0
	var slot_panel_count: int = 0
	for child in flow.get_children():
		if child is PanelContainer:
			slot_panel_count += 1
		elif child is Label:
			label_count += 1
	assert_eq(slot_panel_count, 2, "two ___ in dialogue → 2 slot PanelContainers in flow")
	assert_gt(label_count, 1,
		"long dialogue text should be broken into multiple fragment labels for word-wrap")


func test_slot_widget_is_inline_friendly_size() -> void:
	# 槽位的最小尺寸应跟 16pt 文本同行高，不再像之前的 96×36 把对话挤变形。
	var deck: Array[Card] = [_make_card()]
	_prime_globals_with_deck(deck)
	var scene: Control = _instantiate_scene()
	await get_tree().process_frame

	_replace_selector_and_force_render(scene, _make_two_slot_template())
	await get_tree().process_frame

	var board_row: HBoxContainer = scene.get_node("ChallengeBoardPanel/ChallengeContent/BoardRow")
	assert_not_null(board_row)
	var card_panel: PanelContainer = null
	for child in board_row.get_children():
		if child is PanelContainer:
			card_panel = child
			break
	assert_not_null(card_panel)
	# Find the HFlowContainer's slot children
	var flow: HFlowContainer = null
	var queue: Array = [card_panel]
	while not queue.is_empty():
		var n: Node = queue.pop_back()
		if n is HFlowContainer:
			flow = n as HFlowContainer
			break
		for c in n.get_children():
			queue.append(c)
	assert_not_null(flow)
	if flow == null:
		return
	for child in flow.get_children():
		if child is PanelContainer:
			var p: PanelContainer = child as PanelContainer
			assert_lte(p.custom_minimum_size.y, 32,
				"slot height must stay close to 16pt text line so dialogue reads inline")
			assert_lte(p.custom_minimum_size.x, 90,
				"slot width must be compact (~70px) to keep multiple slots inline-friendly")


func test_slot_count_matches_template_slots() -> void:
	var deck: Array[Card] = [_make_card()]
	_prime_globals_with_deck(deck)
	var scene: Control = _instantiate_scene()
	await get_tree().process_frame

	var ctrl: BattleController = _replace_selector_and_force_render(scene, _make_two_slot_template())
	await get_tree().process_frame

	# _slot_nodes_by_challenge[0] should hold exactly 2 slot panels for our 2-slot template.
	var slot_nodes_by_challenge: Array = scene.get("_slot_nodes_by_challenge")
	assert_not_null(slot_nodes_by_challenge)
	assert_gt(slot_nodes_by_challenge.size(), 0,
		"_slot_nodes_by_challenge should have at least the inserted challenge")
	var first: Array = slot_nodes_by_challenge[0]
	assert_eq(first.size(), 2,
		"two-slot template should produce exactly 2 slot panels cached")
	assert_eq(ctrl.available_challenges[0].slots.size(), 2,
		"controller still sees 2 slots on the template")


func test_anchors_no_overlap_between_board_status_handlabel_handrow() -> void:
	# 验证 .tscn 的 anchor 范围互不重叠 (Step 6 要求).
	var packed: PackedScene = load(BATTLE_SCENE)
	assert_not_null(packed)
	var scene: Control = packed.instantiate() as Control
	add_child_autofree(scene)
	await get_tree().process_frame

	var board: Control = scene.get_node("ChallengeBoardPanel")
	var status: Control = scene.get_node("PlayerStatus")
	var hand_label: Control = scene.get_node("HandLabel")
	var hand_row: Control = scene.get_node("HandRow")
	var action_row: Control = scene.get_node("ActionRow")
	assert_not_null(board)
	assert_not_null(status)
	assert_not_null(hand_label)
	assert_not_null(hand_row)
	assert_not_null(action_row)

	# anchor_bottom of board must be ≤ anchor_top of status
	assert_lte(board.anchor_bottom, status.anchor_top,
		"ChallengeBoardPanel and PlayerStatus must not overlap vertically")
	# status_bottom ≤ hand_label_top
	assert_lte(status.anchor_bottom, hand_label.anchor_top,
		"PlayerStatus and HandLabel must not overlap")
	# hand_label_bottom ≤ hand_row_top
	assert_lte(hand_label.anchor_bottom, hand_row.anchor_top,
		"HandLabel and HandRow must not overlap")
	# hand_row_bottom ≤ action_row_top
	assert_lte(hand_row.anchor_bottom, action_row.anchor_top,
		"HandRow and ActionRow must not overlap")
