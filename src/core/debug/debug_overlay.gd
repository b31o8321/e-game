## DebugOverlay — 战斗内调试信息面板
##
## 由 BattleScene 实例化（仅一次）。订阅 BattleController 的 challenge_advanced /
## hand_changed 信号，把当前 Challenge 的 template_id / topic_id / kind / slots / perfect
## match 全展开显示在右上角。同时订阅 DebugMode.debug_toggled，关闭时整个 overlay 隐藏。
##
## 不修改任何战斗逻辑：只读 BattleController 字段。
class_name DebugOverlay extends CanvasLayer


const SLOT_PLACEHOLDER: String = "___"

var _controller: BattleController = null
var _label: Label = null


func _ready() -> void:
	layer = 900  # 在 DebugMode 角标 (1000) 之下，但在战斗 UI 之上
	_build_ui()
	visible = false
	_connect_debug_mode_signal()


# ═══════════════════════════════════════════════════════════════════
# 公共 API：BattleScene 调用
# ═══════════════════════════════════════════════════════════════════

func attach_controller(controller: BattleController) -> void:
	if controller == null:
		return
	_controller = controller
	if not controller.challenge_advanced.is_connected(_on_challenge_advanced):
		controller.challenge_advanced.connect(_on_challenge_advanced)
	if not controller.hand_changed.is_connected(_on_hand_changed):
		controller.hand_changed.connect(_on_hand_changed)
	if not controller.card_played.is_connected(_on_card_played):
		controller.card_played.connect(_on_card_played)
	_refresh()


# ═══════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "DebugPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -360
	panel.offset_top = 56
	panel.offset_right = -16
	panel.offset_bottom = 380
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.85)
	sb.border_color = Color(1, 0.8, 0.2, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)

	_label = Label.new()
	_label.name = "DebugInfoLabel"
	_label.text = "[DEBUG]\n(战斗未开始)"
	_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.7))
	_label.add_theme_font_size_override("font_size", 13)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)
	add_child(panel)


func _connect_debug_mode_signal() -> void:
	# DebugMode 是 autoload；用 SceneTree 取，避免类标识符未注册时的解析问题。
	var dm: Node = _resolve_debug_mode()
	if dm == null:
		return
	if not dm.debug_toggled.is_connected(_on_debug_toggled):
		dm.debug_toggled.connect(_on_debug_toggled)
	# 启动时若已经开着，立即显示。
	visible = bool(dm.enabled)


func _resolve_debug_mode() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DebugMode")


func _on_debug_toggled(is_enabled: bool) -> void:
	visible = is_enabled
	if is_enabled:
		_refresh()


func _on_challenge_advanced(_template: ChallengeTemplate) -> void:
	_refresh()


func _on_hand_changed(_hand: Array) -> void:
	_refresh()


func _on_card_played(_card: Card, _slot_index: int) -> void:
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	if _controller == null:
		_label.text = "[DEBUG]\n(controller 未挂载)"
		return
	_label.text = _format_debug_text()


# 把 Challenge 的核心字段拆开成多行文本
func _format_debug_text() -> String:
	var lines: Array[String] = ["[DEBUG]"]
	var tmpl: ChallengeTemplate = _controller.current_template
	if tmpl == null:
		lines.append("Challenge: (无；战斗结算中)")
	else:
		lines.append("Challenge: %s" % _safe(tmpl.template_id))
		lines.append("Kind:      %s" % _safe(tmpl.kind))
		lines.append("Topic:     %s" % _safe(tmpl.topic_id))
		if tmpl.audio_path != "":
			lines.append("Audio:     %s" % tmpl.audio_path)
		lines.append("Dialogue:  %s" % _safe(tmpl.dialogue))
		if tmpl.slots.is_empty():
			lines.append("Slots: (无)")
		else:
			lines.append("Slots:")
			for i in tmpl.slots.size():
				var slot: ChallengeSlot = tmpl.slots[i]
				lines.append("  [%d] %s" % [i, _format_slot(slot)])
				var valid: Array[String] = _enumerate_valid_card_ids(slot)
				lines.append("       valid: %s" % _format_id_list(valid))
		if tmpl.perfect_match_card_ids.is_empty():
			lines.append("Perfect: (无)")
		else:
			lines.append("Perfect: %s" % ", ".join(tmpl.perfect_match_card_ids))
	# Filled snapshot — 帮助测试时看清当前状态。
	if _controller.filled_slots != null and not _controller.filled_slots.is_empty():
		var filled_repr: Array[String] = []
		for v in _controller.filled_slots:
			if v is Card:
				filled_repr.append("%s" % v.id)
			else:
				filled_repr.append("∅")
		lines.append("Filled: [%s]" % ", ".join(filled_repr))
	return "\n".join(lines)


func _format_slot(slot: ChallengeSlot) -> String:
	if slot == null:
		return "(null slot)"
	var parts: Array[String] = []
	if slot.required_type != "":
		parts.append("type=%s" % slot.required_type)
	if slot.required_pos != "":
		parts.append("pos=%s" % slot.required_pos)
	if not slot.required_tags.is_empty():
		parts.append("tags=[%s]" % ", ".join(slot.required_tags))
	if not slot.forbidden_tags.is_empty():
		parts.append("!tags=[%s]" % ", ".join(slot.forbidden_tags))
	if slot.damage_multiplier != 1.0:
		parts.append("x%.2f" % slot.damage_multiplier)
	if parts.is_empty():
		return "(any)"
	return " ".join(parts)


# 列举牌库 + 手牌 + 弃牌中所有满足该 slot 的卡 ID（最多前 6 张）。
# 仅用于调试：让玩测能立刻看到答案。
func _enumerate_valid_card_ids(slot: ChallengeSlot) -> Array[String]:
	var out: Array[String] = []
	if slot == null or _controller == null:
		return out
	var seen: Dictionary = {}
	var pools: Array = [_controller.hand, _controller.deck, _controller.discard]
	for pool in pools:
		for c in pool:
			if c == null or not (c is Card):
				continue
			var card: Card = c
			if seen.has(card.id):
				continue
			if not CardValidator.can_place(card, slot):
				continue
			seen[card.id] = true
			out.append(card.id)
			if out.size() >= 6:
				return out
	return out


func _format_id_list(ids: Array[String]) -> String:
	if ids.is_empty():
		return "(none in hand/deck/discard)"
	return ", ".join(ids)


func _safe(s: String) -> String:
	return s if s != "" else "(空)"
