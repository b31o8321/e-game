## ShopResolver — "shop" 节点解析器（MVP 占位实现）
##
## 在没有专属商店场景之前，弹一个简单的 AcceptDialog 让玩家用 RunState.crystals_collected
## 直接买 1 张随机卡（10 词晶）。完成后自动 complete_node。
class_name ShopResolver extends Object


const CARD_COST: int = 10


## 同步解析：直接在当前场景上叠一个 dialog
static func resolve(node: RunNode, pack: ContentPackBase, parent: Node) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "💰 商人"
	var pool: Array[Card] = pack.get_card_pool_for_floor(RunState.current_floor_id) if pack != null else []
	var offer: Card = pool[randi() % pool.size()] if pool.size() > 0 else null
	var lbl: Label = Label.new()
	if offer != null:
		lbl.text = "你愿意花 %d 词晶买下「%s」吗？\n（当前词晶：%d）" % [CARD_COST, offer.text, RunState.crystals_collected]
	else:
		lbl.text = "（货架空空如也，下次再来吧）"
	dialog.add_child(lbl)
	dialog.confirmed.connect(func():
		if offer != null and RunState.crystals_collected >= CARD_COST:
			RunState.crystals_collected -= CARD_COST
			RunState.add_card_to_deck(offer)
		RunState.complete_node(node.id)
	)
	if parent != null:
		parent.add_child(dialog)
		dialog.popup_centered()
