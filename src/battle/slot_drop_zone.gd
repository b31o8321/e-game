## SlotDropZone — Challenge slot panel that accepts dragged CardView payload.
##
## Used by BattleScene._make_slot_node as the slot container, replacing a plain
## PanelContainer. When the player drags a CardView from the hand and drops on
## this zone, we emit `card_dropped(card)`. BattleScene routes that to
## BattleController.add_to_ap_queue(card, challenge_index, slot_index) and
## refreshes hand + board + AP row.
##
## Drag payload contract (produced by CardView._get_drag_data):
##   {
##     "type": "card",       # marker identifying card payload
##     "card_id": <id>,      # informational
##     "ref": <Card>,        # the actual Card resource
##     ...                   # other compat keys
##   }
extends PanelContainer

signal card_dropped(card)


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not (data is Dictionary):
		return false
	# Accept both new ("type") and legacy ("kind") payload markers — the same
	# CardView emits both, but defending against payload-format drift keeps the
	# zone resilient to future renames.
	var marker: String = str(data.get("type", data.get("kind", "")))
	return marker == "card"


func _drop_data(_at_position: Vector2, data) -> void:
	if not (data is Dictionary):
		return
	# Prefer "ref" (T16); fall back to "card" (legacy CardView payload).
	var card = data.get("ref", data.get("card", null))
	if card == null:
		return
	emit_signal("card_dropped", card)
