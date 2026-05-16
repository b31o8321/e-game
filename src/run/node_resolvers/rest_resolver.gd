## RestResolver — "rest" 节点解析器
##
## 全屏模态：3 选 1
##   - 回血 30%（max_hp 的 30%）
##   - 升级一张卡（MVP：直接 base_damage += 2）
##   - 复习卡片（MVP 占位：仅给 5 词晶）
class_name RestResolver extends Object


const HEAL_PCT: float = 0.30
const REVIEW_REWARD: int = 5
const UPGRADE_DAMAGE_BONUS: int = 2


static func resolve(node: RunNode, parent: Node) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "🔥 营火"
	dialog.dialog_hide_on_ok = false  # 由按钮自行处理
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_make_label("你在营火边小憩，选择 1 项："))

	var btn_heal := Button.new()
	btn_heal.text = "❤  回复 30%% 最大 HP"
	btn_heal.pressed.connect(func():
		RunState.heal_percent(HEAL_PCT)
		RunState.complete_node(node.id)
		dialog.hide()
	)
	vbox.add_child(btn_heal)

	var btn_up := Button.new()
	btn_up.text = "🗡  升级一张卡（base_damage +%d）" % UPGRADE_DAMAGE_BONUS
	btn_up.pressed.connect(func():
		_upgrade_first_card()
		RunState.complete_node(node.id)
		dialog.hide()
	)
	vbox.add_child(btn_up)

	var btn_review := Button.new()
	btn_review.text = "📚  复习本 Act 单词（+%d 词晶）" % REVIEW_REWARD
	btn_review.pressed.connect(func():
		RunState.add_crystals(REVIEW_REWARD)
		RunState.complete_node(node.id)
		dialog.hide()
	)
	vbox.add_child(btn_review)

	var btn_boon := Button.new()
	btn_boon.text = "🎁  抽取 Boon（随机三选一增益）"
	btn_boon.pressed.connect(func():
		dialog.hide()
		_show_boon_picker(node, parent)
	)
	vbox.add_child(btn_boon)

	dialog.add_child(vbox)
	if parent != null:
		parent.add_child(dialog)
		dialog.popup_centered()


static func _show_boon_picker(node: RunNode, parent: Node) -> void:
	var all_boons := BoonRegistry.get_all()
	all_boons.shuffle()
	var choices: Array[Boon] = []
	for i in min(3, all_boons.size()):
		choices.append(all_boons[i])

	var pick_dialog := AcceptDialog.new()
	pick_dialog.title = "🎁 选择一个 Boon"
	pick_dialog.dialog_hide_on_ok = false
	var vbox2 := VBoxContainer.new()
	vbox2.add_theme_constant_override("separation", 8)
	vbox2.add_child(_make_label("选择一项立即生效的增益："))

	for b in choices:
		var btn := Button.new()
		btn.text = "%s %s — %s" % [b.icon, b.display_name, b.description]
		var captured_b: Boon = b
		btn.pressed.connect(func():
			BoonRegistry.apply(captured_b)
			RunState.complete_node(node.id)
			pick_dialog.hide()
		)
		vbox2.add_child(btn)

	pick_dialog.add_child(vbox2)
	if parent != null:
		parent.add_child(pick_dialog)
		pick_dialog.popup_centered()


static func _upgrade_first_card() -> void:
	if RunState.current_deck.is_empty():
		return
	var c: Card = RunState.current_deck[0]
	if c != null:
		c.base_damage += UPGRADE_DAMAGE_BONUS


static func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l
