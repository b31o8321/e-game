## APBlockView — AP 队列里一条连线的视图。可拖拽重排。
extends PanelContainer

signal reorder_requested(from_index: int, to_index: int)
signal remove_requested(slot_index: int)

var connection = null   # APConnection 类型

@onready var _slot_label: Label = $VBox/SlotLabel
@onready var _card_label: Label = $VBox/CardLabel
@onready var _preview_label: Label = $VBox/PreviewLabel


func render(c) -> void:
	connection = c
	if not is_node_ready():
		await ready
	_slot_label.text = "[%d]" % (c.slot_index + 1)
	_card_label.text = c.card.text if c.card else "—"
	if c.preview is Dictionary and c.preview.has("damage"):
		_preview_label.text = "⚔ %d" % c.preview.damage
	else:
		_preview_label.text = ""
	mouse_filter = Control.MOUSE_FILTER_STOP


# 右键 = 撤回（卡退回手牌，重新排序）。
func _gui_input(event: InputEvent) -> void:
	if connection == null:
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
		emit_signal("remove_requested", connection.slot_index)
		accept_event()


# Drag-source: returns marker so target's _can_drop_data can check
func _get_drag_data(_at_position: Vector2) -> Variant:
	if connection == null:
		return null
	return {"type": "ap_block", "from_index": connection.slot_index}


# Drop-target: accepts another ap_block to reorder
func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("type") == "ap_block"


func _drop_data(_at_position: Vector2, data) -> void:
	emit_signal("reorder_requested", data["from_index"], connection.slot_index)
