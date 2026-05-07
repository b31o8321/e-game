## MysteryResolver — "mystery" 节点解析器（MVP 占位）
##
## 文字事件：随机展示一段叙述 + 1-2 个结局选项；结局以 +/- 词晶或 +/- HP 落实。
class_name MysteryResolver extends Object


const EVENTS: Array[Dictionary] = [
	{
		"text": "你发现路边有一个落单的小石灵……",
		"good": {"crystals": 15, "label": "送它回家"},
		"bad":  {"hp": -10,      "label": "夺走它的水晶"},
	},
	{
		"text": "一位流浪学者请求你帮他校对一份手稿。",
		"good": {"crystals": 10, "label": "答应他"},
		"bad":  {"hp": -5,       "label": "继续赶路"},
	},
]


static func resolve(node: RunNode, parent: Node) -> void:
	var event: Dictionary = EVENTS[randi() % EVENTS.size()]
	var dialog := AcceptDialog.new()
	dialog.title = "❓ 神秘事件"
	dialog.dialog_hide_on_ok = false
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = event.get("text", "")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)
	for key in ["good", "bad"]:
		var opt: Dictionary = event.get(key, {})
		if opt.is_empty():
			continue
		var btn := Button.new()
		btn.text = str(opt.get("label", key))
		btn.pressed.connect(func():
			_apply_outcome(opt)
			RunState.complete_node(node.id)
			dialog.hide()
		)
		vbox.add_child(btn)
	dialog.add_child(vbox)
	if parent != null:
		parent.add_child(dialog)
		dialog.popup_centered()


static func _apply_outcome(opt: Dictionary) -> void:
	var crystals: int = int(opt.get("crystals", 0))
	if crystals > 0:
		RunState.add_crystals(crystals)
	elif crystals < 0:
		RunState.crystals_collected = max(0, RunState.crystals_collected + crystals)
	var hp_delta: int = int(opt.get("hp", 0))
	if hp_delta > 0:
		RunState.heal(hp_delta)
	elif hp_delta < 0:
		RunState.take_damage(-hp_delta)
