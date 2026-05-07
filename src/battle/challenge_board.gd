## ChallengeBoard — 渲染当前 Challenge 台词 + 槽位（drop target）
##
## 职责：
##   - 输入：ChallengeTemplate（含 dialogue + slots）
##   - 渲染：把 dialogue 中的 ___ 替换为 SlotPanel（PanelContainer 子控件）
##   - 接住 CardView 拖入：调用 BattleController.try_place_card(card, slot_index)
##   - 槽满 / 合法 / 非法的视觉反馈
##
## 槽满后再次拖入：
##   - 若已填，先 remove_card_from_slot(slot_index) 退回原卡，再尝试新卡
##   - 设计上 BattleController 在 PLAYER_TURN 内允许任意撤回
class_name ChallengeBoard extends VBoxContainer


signal slot_drop_requested(card: Card, slot_index: int)
signal slot_clear_requested(slot_index: int)


const SLOT_PLACEHOLDER: String = "___"

var template: ChallengeTemplate = null
var filled_state: Array = []  # Array of (Card | null)

# 缓存：每个 slot_index → SlotDropArea 节点
var _slot_nodes: Array = []

@onready var dialogue_container: HBoxContainer = $DialogueContainer


func _ready() -> void:
	if dialogue_container == null:
		# 可能 .tscn 中节点尚未生成；refresh() 时再创建
		pass


func set_template(tmpl: ChallengeTemplate) -> void:
	template = tmpl
	# 槽状态在 BattleController 那边维护；本视图只做渲染
	filled_state = []
	if tmpl != null:
		for _i in tmpl.slots.size():
			filled_state.append(null)
	_rebuild()


func set_filled_state(filled: Array) -> void:
	filled_state = filled.duplicate()
	for i in _slot_nodes.size():
		var node = _slot_nodes[i]
		if node == null:
			continue
		var card = filled_state[i] if i < filled_state.size() else null
		_update_slot_visual(node, card)


# ─── 私有 ─────────────────────────────────────────────────────────

func _rebuild() -> void:
	if dialogue_container == null:
		dialogue_container = HBoxContainer.new()
		add_child(dialogue_container)
	for child in dialogue_container.get_children():
		child.queue_free()
	_slot_nodes.clear()
	if template == null:
		return

	var dialogue: String = template.dialogue
	var parts: PackedStringArray = dialogue.split(SLOT_PLACEHOLDER, true)
	# parts.size() == 槽数+1（最简模型）；不严格校验，多余 ___ 只取到 slots 数为止
	var slot_count: int = template.slots.size()
	for i in parts.size():
		if parts[i] != "":
			var lbl: Label = Label.new()
			lbl.text = parts[i]
			dialogue_container.add_child(lbl)
		# 在每段文本之后插入一个槽（最后一段后面没有槽）
		if i < parts.size() - 1 and i < slot_count:
			var slot_node := _make_slot_node(i)
			dialogue_container.add_child(slot_node)
			_slot_nodes.append(slot_node)
	# 兜底：如果 dialogue 没 ___ 但有槽，也把槽顺序追加在末尾
	while _slot_nodes.size() < slot_count:
		var idx: int = _slot_nodes.size()
		var slot_node := _make_slot_node(idx)
		dialogue_container.add_child(slot_node)
		_slot_nodes.append(slot_node)


func _make_slot_node(slot_index: int) -> Control:
	var slot := SlotDropArea.new()
	slot.slot_index = slot_index
	slot.custom_minimum_size = Vector2(90, 40)
	slot.set_meta("slot_index", slot_index)
	slot.drop_requested.connect(_on_slot_drop)
	slot.clear_requested.connect(_on_slot_clear)
	return slot


func _update_slot_visual(slot_node: Control, card) -> void:
	if not (slot_node is SlotDropArea):
		return
	(slot_node as SlotDropArea).set_card(card)


func _on_slot_drop(card: Card, slot_index: int) -> void:
	slot_drop_requested.emit(card, slot_index)


func _on_slot_clear(slot_index: int) -> void:
	slot_clear_requested.emit(slot_index)


# ═══════════════════════════════════════════════════════════════════
# SlotDropArea — 内部辅助类（一个可接卡的小框）
# ═══════════════════════════════════════════════════════════════════

class SlotDropArea extends PanelContainer:
	signal drop_requested(card: Card, slot_index: int)
	signal clear_requested(slot_index: int)

	var slot_index: int = 0
	var current_card: Card = null
	var _label: Label

	func _init() -> void:
		_label = Label.new()
		_label.text = "___"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_card(card) -> void:
		current_card = card
		if card is Card:
			_label.text = (card as Card).text
			modulate = Color(0.85, 1.0, 0.85)
		else:
			_label.text = "___"
			modulate = Color(1, 1, 1)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("kind", "") == "card"

	func _drop_data(_at: Vector2, data: Variant) -> void:
		if not (data is Dictionary):
			return
		var card = data.get("card", null)
		if not (card is Card):
			return
		drop_requested.emit(card, slot_index)

	func _gui_input(event: InputEvent) -> void:
		# 双击 / 右键清空已放卡
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and current_card != null:
				clear_requested.emit(slot_index)
