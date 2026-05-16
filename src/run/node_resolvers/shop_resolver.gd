## ShopResolver — "shop" 节点解析器（自定义弹窗，含遗物购买）
##
## 弹出一个 PanelContainer 弹窗，内含：
##   - 标题 + 词晶数量
##   - 2 张随机卡（每张 10 词晶）
##   - 2 个 random 未装备遗物（按 rarity 定价）
##   - "离开" 按钮 → complete_node
class_name ShopResolver extends Object


const CARD_COST: int = 10

const RELIC_PRICE_BY_RARITY: Dictionary = {
	"common":   30,
	"uncommon": 50,
	"rare":     80,
}


## 同步解析：在 parent 上叠加一个自定义 PanelContainer 弹窗
static func resolve(node: RunNode, pack: ContentPackBase, parent: Node) -> void:
	if parent == null:
		RunState.complete_node(node.id)
		return

	# ── 构造弹窗根容器 ──────────────────────────────────────────────
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# ── 标题 ────────────────────────────────────────────────────────
	var title_lbl := Label.new()
	title_lbl.text = "💰 商人"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	# ── 词晶行（每次购买后更新）────────────────────────────────────
	var crystal_lbl := Label.new()
	crystal_lbl.text = "🔮 词晶：%d" % RunState.crystals_collected
	vbox.add_child(crystal_lbl)

	# ── 卡片栏 ──────────────────────────────────────────────────────
	var card_sep := HSeparator.new()
	vbox.add_child(card_sep)

	var card_title := Label.new()
	card_title.text = "── 卡片 ──"
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(card_title)

	var pool: Array[Card] = pack.get_card_pool_for_floor(RunState.current_floor_id) if pack != null else []
	pool.shuffle()
	var card_offers: Array[Card] = []
	for i in min(2, pool.size()):
		card_offers.append(pool[i])

	for card in card_offers:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "「%s」  %d 💰" % [card.text, CARD_COST]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "买 %d 💰" % CARD_COST
		if RunState.crystals_collected < CARD_COST:
			btn.disabled = true
		btn.pressed.connect(func():
			if _try_buy_card(card, pool.size()):
				btn.disabled = true
				crystal_lbl.text = "🔮 词晶：%d" % RunState.crystals_collected
				_refresh_buy_buttons(panel, crystal_lbl)
		)
		row.add_child(btn)
		vbox.add_child(row)

	if card_offers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（货架空空如也）"
		vbox.add_child(empty_lbl)

	# ── 遗物栏 ──────────────────────────────────────────────────────
	var relic_sep := HSeparator.new()
	vbox.add_child(relic_sep)

	var relic_title := Label.new()
	relic_title.text = "── 遗物 ──"
	relic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(relic_title)

	var all_relics: Array[Relic] = RelicRegistry.get_all()
	var available_relics: Array[Relic] = []
	for r in all_relics:
		if not RunState.has_relic(r.id):
			available_relics.append(r)
	available_relics.shuffle()
	var relic_offers: Array[Relic] = []
	for i in min(2, available_relics.size()):
		relic_offers.append(available_relics[i])

	for relic in relic_offers:
		var price: int = RELIC_PRICE_BY_RARITY.get(relic.rarity, 50)
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s %s  %d 💰" % [relic.icon, relic.display_name, price]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = "买 %d 💰" % price
		if RunState.crystals_collected < price:
			btn.disabled = true
		btn.pressed.connect(func():
			if _try_buy_relic(relic):
				btn.disabled = true
				crystal_lbl.text = "🔮 词晶：%d" % RunState.crystals_collected
				_refresh_buy_buttons(panel, crystal_lbl)
		)
		row.add_child(btn)
		vbox.add_child(row)

	if relic_offers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "（没有可购买的遗物）"
		vbox.add_child(empty_lbl)

	# ── 离开按钮 ────────────────────────────────────────────────────
	var leave_sep := HSeparator.new()
	vbox.add_child(leave_sep)

	var leave_btn := Button.new()
	leave_btn.text = "离开"
	leave_btn.pressed.connect(func():
		panel.queue_free()
		RunState.complete_node(node.id)
	)
	vbox.add_child(leave_btn)

	parent.add_child(panel)


# ═══════════════════════════════════════════════════════════════════
# 纯逻辑 helpers（可被测试直接调用）
# ═══════════════════════════════════════════════════════════════════

## 尝试购买遗物。词晶足 + 未装备 → 扣词晶 + 装备 → 返回 true；否则返回 false。
static func _try_buy_relic(relic: Relic) -> bool:
	if relic == null:
		return false
	if RunState.has_relic(relic.id):
		return false
	var price: int = RELIC_PRICE_BY_RARITY.get(relic.rarity, 50)
	if RunState.crystals_collected < price:
		return false
	RunState.crystals_collected -= price
	RunState.add_relic(relic)
	return true


## 尝试购买卡片。pool_size > 0 且词晶足 → 扣词晶 + 加入牌组 → 返回 true；否则返回 false。
static func _try_buy_card(card: Card, pool_size: int) -> bool:
	if card == null or pool_size <= 0:
		return false
	if RunState.crystals_collected < CARD_COST:
		return false
	RunState.crystals_collected -= CARD_COST
	RunState.add_card_to_deck(card)
	return true


## 刷新面板内所有购买按钮的 disabled 状态（词晶变动后调用）。
## 遍历 panel 树，找到文本以 "买" 开头的 Button，根据当前词晶重新判断。
static func _refresh_buy_buttons(panel: Control, crystal_lbl: Label) -> void:
	crystal_lbl.text = "🔮 词晶：%d" % RunState.crystals_collected
	_refresh_buttons_recursive(panel)


static func _refresh_buttons_recursive(node: Node) -> void:
	if node is Button:
		var btn := node as Button
		if btn.text.begins_with("买 "):
			# 解析价格
			var parts := btn.text.split(" ")
			if parts.size() >= 2:
				var price_str: String = parts[1]
				if price_str.is_valid_int():
					btn.disabled = RunState.crystals_collected < int(price_str)
	for child in node.get_children():
		_refresh_buttons_recursive(child)
