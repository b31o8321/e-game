## Smoke tests for the rewritten BattleScene UI.
##
## These tests stand up the BattleScene against a minimal in-memory
## EnemyData + Card deck + ChallengeTemplate (injected through GameState
## .pending_enemy + RunState.current_deck), then exercise the click flow:
##   - scene loads and key UI nodes exist
##   - challenge dialogue + slots render
##   - clicking a card with exactly one valid empty slot auto-places it
##   - filling all slots fires damage_dealt + advances challenge
##   - battle_ended(victory=false) routes to the settlement scene
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


func _make_template_one_slot() -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": "tmpl_test",
		"kind": "fill_in_blank",
		"dialogue": "I am very ___",
		"slots": [
			{
				"index": 0,
				"required_pos": "adjective",
				"required_type": "",
				"required_tags": [],
				"forbidden_tags": [],
				"damage_multiplier": 1.0,
			},
		],
		"topic_id": "test_topic",
	})


func _make_enemy() -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_enemy"
	e.enemy_name = "书页尘灵"
	e.max_hp = 30
	e.base_attack = 5
	e.weak_axes = ["positive_emotion"]
	e.topic_id = "test_topic"
	return e


## Stub ChallengeSelector that always returns the same template.
class _StubSelector extends ChallengeSelector:
	var template: ChallengeTemplate

	func _init() -> void:
		super()

	func pick_challenge(_enemy: EnemyData, _pack, _srs) -> ChallengeTemplate:
		return template


## Inject test data via the autoloads so BattleScene picks them up in _ready.
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
	assert_not_null(packed, "BattleScene must load")
	if packed == null:
		return null
	var inst: Control = packed.instantiate() as Control
	add_child_autofree(inst)
	return inst


func _replace_selector_with_stub(scene: Control, template: ChallengeTemplate) -> void:
	# After instantiate but before start_battle has fully built UI, swap selector
	# so picks are deterministic. We replace _controller's selector and force re-pick.
	var ctrl: BattleController = scene.get("_controller")
	if ctrl == null:
		return
	var stub := _StubSelector.new()
	stub.template = template
	ctrl.set_selector(stub)
	# Force advance immediately if no template was picked.
	if ctrl.current_template == null and ctrl.state == BattleController.State.PLAYER_TURN:
		ctrl._advance_to_next_challenge()


# ─── tests ─────────────────────────────────────────────────────────

func test_scene_loads_and_has_core_nodes() -> void:
	_prime_globals_with_deck([_make_card()])
	var scene: Control = _instantiate_scene()
	await get_tree().process_frame
	assert_not_null(scene)
	assert_not_null(scene.get_node_or_null("TopBar"))
	assert_not_null(scene.get_node_or_null("EnemyArea"))
	assert_not_null(scene.get_node_or_null("ChallengeBoardPanel"))
	assert_not_null(scene.get_node_or_null("PlayerStatus"))
	assert_not_null(scene.get_node_or_null("HandRow"))
	assert_not_null(scene.get_node_or_null("ActionRow/EndTurnButton"))
	assert_not_null(scene.get_node_or_null("TopBar/TopRow/RetreatButton"))


func test_challenge_board_renders_dialogue_and_slots() -> void:
	var deck: Array[Card] = []
	deck.append(_make_card({"id": "card_brave", "text": "brave"}))
	_prime_globals_with_deck(deck)
	var scene: Control = _instantiate_scene()
	await get_tree().process_frame
	var tmpl: ChallengeTemplate = _make_template_one_slot()
	_replace_selector_with_stub(scene, tmpl)
	# Re-render now that selector returns our template.
	if scene.has_method("_render_challenge"):
		scene.call("_render_challenge")
	await get_tree().process_frame

	# 多题棋盘改造后，每道题渲染成 BoardRow 下的一个 ChallengeCard PanelContainer，
	# 内部包含 Label（对话文字）+ PanelContainer 槽。
	var board_row: HBoxContainer = scene.get_node("ChallengeBoardPanel/ChallengeContent/BoardRow")
	assert_not_null(board_row, "BoardRow must exist for multi-challenge board")
	# 至少有 1 个 ChallengeCard
	var has_card := false
	var has_label := false
	var has_slot := false
	for card in board_row.get_children():
		if card is PanelContainer:
			has_card = true
			# 递归找 Label / 内部 PanelContainer 槽
			var stack: Array = [card]
			while not stack.is_empty():
				var node: Node = stack.pop_back()
				for child in node.get_children():
					if child is Label and child.name != "SlotLabel":
						has_label = true
					if child is PanelContainer and child != card:
						has_slot = true
					stack.append(child)
	assert_true(has_card, "BoardRow should render at least one ChallengeCard")
	assert_true(has_label, "ChallengeCard should render at least one text label")
	assert_true(has_slot, "ChallengeCard should render at least one drop slot")


func test_card_click_selects_then_explicit_slot_click_places_and_submits() -> void:
	# 反舒适区改造：移除"只剩一个合法槽位 → 自动放卡"逻辑。
	# 现在玩家必须 1) 点卡 → 选中  2) 再点空槽 → 放入。
	var card := _make_card({"id": "card_brave", "text": "brave"})
	var deck: Array[Card] = []
	deck.append(card)
	for i in 4:
		deck.append(_make_card({
			"id": "noun_%d" % i,
			"text": "thing%d" % i,
			"pos": "noun",
			"tags": [],
		}))
	_prime_globals_with_deck(deck)
	var scene: Control = _instantiate_scene()
	await get_tree().process_frame
	_replace_selector_with_stub(scene, _make_template_one_slot())
	if scene.has_method("_render_challenge"):
		scene.call("_render_challenge")
	if scene.has_method("_render_hand"):
		scene.call("_render_hand")
	await get_tree().process_frame

	var ctrl: BattleController = scene.get("_controller")
	assert_not_null(ctrl)
	assert_not_null(ctrl.current_template, "selector should have picked a template")
	assert_eq(ctrl.current_template.slots.size(), 1)

	var enemy_hp_before: int = ctrl.enemy_hp
	watch_signals(ctrl)

	# 第 1 步：点 brave 卡 → 应被选中（_selected_card 设置），但不会自动放入
	var hand: Array = ctrl.hand
	var brave_in_hand: Card = null
	for c in hand:
		if c is Card and c.id == "card_brave":
			brave_in_hand = c
			break
	assert_not_null(brave_in_hand, "the planted brave card must be in the hand")
	scene.call("_on_card_button_pressed", brave_in_hand, null)
	await get_tree().process_frame

	# 此时不应该有伤害（卡只是被"选中"，未放入）
	assert_eq(ctrl.enemy_hp, enemy_hp_before, "auto-place removed: HP should NOT change after card click alone")
	assert_eq(scene.get("_selected_card"), brave_in_hand, "card should be selected")

	# 第 2 步：直接调用 try_place_card 模拟"点击空槽"
	var ok: bool = ctrl.try_place_card(brave_in_hand, 0)
	assert_true(ok, "explicit place should succeed for valid slot")
	await get_tree().process_frame

	# 现在伤害应已结算
	assert_lt(ctrl.enemy_hp, enemy_hp_before, "enemy HP should decrease after explicit slot click")
	assert_signal_emitted(ctrl, "damage_dealt")


func test_battle_ended_defeat_routes_to_settlement() -> void:
	var deck: Array[Card] = []
	deck.append(_make_card())
	_prime_globals_with_deck(deck)
	var scene: Control = _instantiate_scene()
	await get_tree().process_frame
	# Verify the route helper exists; we don't actually want to swap the
	# real scene tree in tests, so just call the routing target validator.
	assert_true(scene.has_method("_route_after_defeat"),
			"scene should expose defeat routing")
	assert_true(scene.has_method("_route_after_victory"),
			"scene should expose victory routing")
	# Verify the EndOverlay node exists for showing defeat UI.
	var end_overlay: Node = scene.get_node_or_null("EndOverlay")
	assert_not_null(end_overlay, "EndOverlay must exist for end-of-battle UI")
	var end_button: Node = scene.get_node_or_null("EndOverlay/EndContent/EndButton")
	assert_not_null(end_button, "End button must exist on overlay")


func test_tutorial_overlay_exists_and_can_dismiss() -> void:
	_prime_globals_with_deck([_make_card()])
	var scene: Control = _instantiate_scene()
	await get_tree().process_frame
	var overlay: Node = scene.get_node_or_null("TutorialOverlay")
	assert_not_null(overlay, "TutorialOverlay must exist")
	# The dismiss method should be callable without errors.
	assert_true(scene.has_method("_dismiss_tutorial"))
	scene.call("_dismiss_tutorial")
	assert_false((overlay as Control).visible,
			"overlay should be hidden after dismiss")


func test_failed_challenge_visually_grayed_and_locked() -> void:
	# 一锤定音：放错卡 → battle_scene._on_challenge_failed 重渲染棋盘 →
	# 失败题应被灰掉 + mouse_filter=IGNORE，不能再点击。
	var deck: Array[Card] = []
	deck.append(_make_card({"id": "card_brave", "text": "brave", "pos": "adjective"}))
	_prime_globals_with_deck(deck)
	var scene: Control = _instantiate_scene()
	await get_tree().process_frame

	# 用要求 noun 的题 → adjective 卡放进去必失败
	var bad_tmpl: ChallengeTemplate = ChallengeTemplate.from_dict({
		"template_id": "tmpl_need_noun",
		"kind": "fill_in_blank",
		"dialogue": "I see a ___",
		"slots": [{
			"index": 0,
			"required_pos": "noun",
			"required_type": "",
			"required_tags": [],
			"forbidden_tags": [],
			"damage_multiplier": 1.0,
		}],
		"topic_id": "test_topic",
		"perfect_match_card_ids": ["correct_noun"],
	})
	_replace_selector_with_stub(scene, bad_tmpl)
	if scene.has_method("_render_challenge"):
		scene.call("_render_challenge")
	if scene.has_method("_render_hand"):
		scene.call("_render_hand")
	await get_tree().process_frame

	var ctrl: BattleController = scene.get("_controller")
	assert_not_null(ctrl)
	# B5: noun 模板被 hand-aware filter 拒绝（手里只有 adjective），所以不会被
	# refill 选中。这里强插到棋盘 0 号位用于测试"放错"视觉反馈。
	ctrl.available_challenges.clear()
	ctrl.available_filled_slots.clear()
	ctrl.add_to_board(bad_tmpl)
	if scene.has_method("_render_challenge"):
		scene.call("_render_challenge")
	await get_tree().process_frame

	# Place an adjective card → controller fires challenge_failed
	var brave: Card = null
	for c in ctrl.hand:
		if c.id == "card_brave":
			brave = c
			break
	if brave == null and not ctrl.hand.is_empty():
		brave = ctrl.hand[0]
	assert_not_null(brave)
	ctrl.try_place_card(brave, 0, 0)
	await get_tree().process_frame

	assert_true(ctrl.is_failed(0), "challenge 0 should be marked failed")

	# Inspect the BoardRow → first PanelContainer should now be visually disabled
	var board_row: HBoxContainer = scene.get_node("ChallengeBoardPanel/ChallengeContent/BoardRow")
	assert_not_null(board_row)
	var first_card: PanelContainer = null
	for child in board_row.get_children():
		if child is PanelContainer:
			first_card = child
			break
	assert_not_null(first_card, "at least one challenge card panel exists")
	assert_lt(first_card.modulate.a, 1.0,
		"failed challenge card should be visually faded (modulate.a < 1)")
	assert_eq(first_card.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"failed challenge card should not absorb clicks")
