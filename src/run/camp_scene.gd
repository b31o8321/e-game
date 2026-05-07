## CampScene — 中场营地 controller
##
## 在击败 Act Boss 之后进入。提供：
##   1. 3 选 1 卡片奖励（左侧）：从 pack.get_card_pool_for_floor 抽 3 张候选，
##      每张点击 → 加入 RunState.current_deck
##   2. 跳过卡片：+5 词晶
##   3. 营地行动（右侧）：升级一张已有卡 / 回血 30% / 复习卡片
##   4. 启程 → RunState.advance_to_next_act() + 切到下一 Act 地图
##
## MVP：极简 UI（VBox + Button）。复杂的 deck 可视化与升级选择对话留待 Phase 3。
##
## 详见: docs/superpowers/specs/2026-05-04-run-structure-design.md
extends Control

const RUN_MAP_SCENE: String = "res://src/run/run_map_scene.tscn"
const SETTLEMENT_SCENE: String = "res://src/run/settlement_scene.tscn"
const SKIP_REWARD: int = 5
const HEAL_PCT: float = 0.30
const REVIEW_REWARD: int = 5
const UPGRADE_DAMAGE_BONUS: int = 2
const CARD_OFFER_COUNT: int = 3

@onready var _title_label: Label = $TitleLabel
@onready var _cards_header: Label = $LeftPanel/CardsHeader
@onready var _cards_row: HBoxContainer = $LeftPanel/CardsRow
@onready var _skip_button: Button = $LeftPanel/SkipButton
@onready var _action_header: Label = $RightPanel/ActionHeader
@onready var _upgrade_button: Button = $RightPanel/UpgradeButton
@onready var _heal_button: Button = $RightPanel/HealButton
@onready var _review_button: Button = $RightPanel/ReviewButton
@onready var _action_status_label: Label = $RightPanel/ActionStatusLabel
@onready var _depart_button: Button = $DepartButton
@onready var _status_label: Label = $StatusLabel

var _card_chosen: bool = false
var _action_chosen: bool = false
var _offered_cards: Array[Card] = []
var _pack: ContentPackBase = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resolve_pack()
	_render_title()
	_offer_cards()
	_render_card_offers()
	_skip_button.pressed.connect(_on_skip_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_heal_button.pressed.connect(_on_heal_pressed)
	_review_button.pressed.connect(_on_review_pressed)
	_depart_button.pressed.connect(_on_depart_pressed)
	_refresh_depart_state()


# ---------------------------------------------------------------------------
# 初始化
# ---------------------------------------------------------------------------

func _resolve_pack() -> void:
	if typeof(GameState) == TYPE_NIL or GameState.content_loader == null:
		return
	_pack = GameState.content_loader.get_active_pack()


func _render_title() -> void:
	var act_num: int = 1
	if typeof(RunState) != TYPE_NIL:
		act_num = RunState.current_act_index + 1
	_title_label.text = "中场营地 · Act %d 完成" % act_num


# ---------------------------------------------------------------------------
# 卡片 3 选 1
# ---------------------------------------------------------------------------

func _offer_cards() -> void:
	_offered_cards.clear()
	if _pack == null or typeof(RunState) == TYPE_NIL:
		return
	var pool: Array[Card] = _pack.get_card_pool_for_floor(RunState.current_floor_id)
	# 排除已在牌组中的
	var deck_ids: Dictionary = {}
	for c in RunState.current_deck:
		if c != null:
			deck_ids[c.id] = true
	var candidates: Array[Card] = []
	for c in pool:
		if c == null:
			continue
		if not deck_ids.has(c.id):
			candidates.append(c)
	candidates.shuffle()
	for i in range(min(CARD_OFFER_COUNT, candidates.size())):
		_offered_cards.append(candidates[i])


func _render_card_offers() -> void:
	for child in _cards_row.get_children():
		child.queue_free()
	if _offered_cards.is_empty():
		var lbl := Label.new()
		lbl.text = "（卡池已空，可点跳过）"
		_cards_row.add_child(lbl)
		return
	for c in _offered_cards:
		_cards_row.add_child(_make_card_button(c))


func _make_card_button(card: Card) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 200)
	btn.text = "%s\n[%s]\n伤害: %d\n%s" % [
		card.text,
		card.type,
		card.base_damage,
		card.rarity,
	]
	btn.tooltip_text = "ID: %s\nPOS: %s\nSkill: %s" % [card.id, card.pos, card.skill]
	btn.pressed.connect(_on_card_picked.bind(card))
	return btn


func _on_card_picked(card: Card) -> void:
	if _card_chosen:
		return
	_card_chosen = true
	if typeof(RunState) != TYPE_NIL:
		RunState.add_card_to_deck(card)
	_status_label.text = "已加入牌组：%s" % card.text
	_disable_card_choices()
	_refresh_depart_state()


func _on_skip_pressed() -> void:
	if _card_chosen:
		return
	_card_chosen = true
	if typeof(RunState) != TYPE_NIL:
		RunState.add_crystals(SKIP_REWARD)
	_status_label.text = "已跳过 → +%d 词晶" % SKIP_REWARD
	_disable_card_choices()
	_refresh_depart_state()


func _disable_card_choices() -> void:
	_skip_button.disabled = true
	for child in _cards_row.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = true


# ---------------------------------------------------------------------------
# 营地行动 3 选 1
# ---------------------------------------------------------------------------

func _on_upgrade_pressed() -> void:
	if _action_chosen:
		return
	_action_chosen = true
	var msg: String = _upgrade_first_card()
	_action_status_label.text = msg
	_disable_actions()
	_refresh_depart_state()


func _on_heal_pressed() -> void:
	if _action_chosen:
		return
	_action_chosen = true
	var amount: int = 0
	if typeof(RunState) != TYPE_NIL:
		amount = int(RunState.player_max_hp * HEAL_PCT)
		RunState.heal_percent(HEAL_PCT)
	_action_status_label.text = "回复 %d HP（当前 %d/%d）" % [
		amount,
		RunState.player_hp if typeof(RunState) != TYPE_NIL else 0,
		RunState.player_max_hp if typeof(RunState) != TYPE_NIL else 0,
	]
	_disable_actions()
	_refresh_depart_state()


func _on_review_pressed() -> void:
	if _action_chosen:
		return
	_action_chosen = true
	# MVP：仅奖励词晶。Phase 3 接入 CutscenePlayer + review_cards_at_camp。
	if typeof(RunState) != TYPE_NIL:
		RunState.add_crystals(REVIEW_REWARD)
	_action_status_label.text = "已复习 → +%d 词晶" % REVIEW_REWARD
	_disable_actions()
	_refresh_depart_state()


func _disable_actions() -> void:
	_upgrade_button.disabled = true
	_heal_button.disabled = true
	_review_button.disabled = true


func _upgrade_first_card() -> String:
	if typeof(RunState) == TYPE_NIL or RunState.current_deck.is_empty():
		return "（牌组为空，无法升级）"
	var c: Card = RunState.current_deck[0]
	if c == null:
		return "（牌组首张为空）"
	c.base_damage += UPGRADE_DAMAGE_BONUS
	return "已升级「%s」(+%d 伤害)" % [c.text, UPGRADE_DAMAGE_BONUS]


# ---------------------------------------------------------------------------
# 启程
# ---------------------------------------------------------------------------

func _refresh_depart_state() -> void:
	_depart_button.disabled = not (_card_chosen and _action_chosen)
	if _depart_button.disabled:
		_depart_button.text = "启程下一 Act（先做出选择）"
	else:
		_depart_button.text = "启程下一 Act!"


func _on_depart_pressed() -> void:
	if typeof(RunState) == TYPE_NIL:
		# 测试或异常路径：直接退回知识城
		get_tree().change_scene_to_file("res://src/city/city_scene.tscn")
		return
	RunState.advance_to_next_act()
	# advance_to_next_act 在所有 Act 完成时会自动触发 settle_victory
	if RunState.current_act_index >= RunState.act_maps.size():
		get_tree().change_scene_to_file(SETTLEMENT_SCENE)
		return
	get_tree().change_scene_to_file(RUN_MAP_SCENE)
