## CardView — 单张手牌的可视化 + 拖拽控件（B4：游戏性优先重构）
##
## 视觉优先级翻转：
##   1) 大字 ⚔ 伤害（32pt）        — 最直观
##   2) 英文文本（16pt）              — 次要
##   3) 词性小字（12pt）              — 辅助
##   4) 能力徽章（emoji + 数字）      — 突出独特能力
##   5) 中文释义 / 例句               — 默认隐藏，仅在 tooltip / hover 显示
##
## 拖拽：使用 Godot 内建 _get_drag_data；payload 为本 CardView 节点
## 落点判定不在这里 —— ChallengeBoard / SlotDropZone 负责接住 drop。
class_name CardView extends PanelContainer


const RARITY_COLORS: Dictionary = {
	"common": Color(0.7, 0.7, 0.75),
	"rare": Color(0.4, 0.7, 1.0),
	"epic": Color(0.7, 0.4, 1.0),
	"legendary": Color(1.0, 0.7, 0.3),
}

const POS_DISPLAY: Dictionary = {
	"adjective": "形容词",
	"noun": "名词",
	"verb": "动词",
	"verb_be": "系动词",
	"adverb": "副词",
	"pronoun": "代词",
	"preposition": "介词",
	"conjunction": "连词",
	"determiner": "限定词",
	"article": "冠词",
	"letter": "字母",
	"syllable": "音节",
	"sight_word": "高频词",
}

const TYPE_DISPLAY: Dictionary = {
	"word": "词卡",
	"phrase": "短语",
	"pattern": "句型",
	"rule": "规则",
	"sound": "听音",
	"modifier": "修饰",
}

@export var card: Card = null
## 当前熟练度（外部传入；战斗启动时由 BattleScene 注入）
var mastery_level: int = 0  # MasterySystem.MasteryLevel
## 是否在 hover 时展示中文释义/例句（B4 视觉降级：默认隐藏）
var show_knowledge_on_hover: bool = true

@onready var damage_big_label: Label = $Layout/DamageBigLabel
@onready var text_label: Label = $Layout/TextLabel
@onready var pos_label: Label = $Layout/PosLabel
@onready var phonetic_label: Label = $Layout/PhoneticLabel
@onready var meaning_label: Label = $Layout/MeaningLabel
@onready var example_en_label: Label = $Layout/ExampleEnLabel
@onready var example_zh_label: Label = $Layout/ExampleZhLabel
@onready var ability_badge: Label = $Layout/MetaRow/AbilityBadge
@onready var audio_button: Button = $Layout/MetaRow/AudioButton
@onready var mastery_label: Label = $Layout/HeaderRow/MasteryLabel
@onready var rarity_label: Label = $Layout/HeaderRow/RarityLabel

# 旧节点（兼容；B4 改造后默认隐藏）
@onready var type_label: Label = $Layout/MetaRow/TypeLabel
@onready var pos_label_legacy: Label = $Layout/MetaRow/PosLabelLegacy
@onready var damage_label: Label = $Layout/MetaRow/DamageLabel

signal hover_started(card_view: CardView)
signal hover_ended(card_view: CardView)


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	custom_minimum_size = Vector2(200, 280)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if audio_button != null and not audio_button.pressed.is_connected(_on_audio_button_pressed):
		audio_button.pressed.connect(_on_audio_button_pressed)
	refresh()


func _on_mouse_entered() -> void:
	hover_started.emit(self)
	if show_knowledge_on_hover:
		_set_knowledge_visible(true)


func _on_mouse_exited() -> void:
	hover_ended.emit(self)
	if show_knowledge_on_hover:
		_set_knowledge_visible(false)


func set_card(c: Card, srs: SRSSystem = null) -> void:
	card = c
	if c == null:
		return
	mastery_level = MasterySystem.get_level(c.id, srs)
	refresh()


func refresh() -> void:
	if card == null:
		return
	# 大字伤害（如果 base_damage > 0）
	if damage_big_label:
		if card.base_damage > 0:
			damage_big_label.text = "⚔ %d" % card.base_damage
			damage_big_label.visible = true
		else:
			damage_big_label.text = ""
			damage_big_label.visible = false
	if text_label:
		text_label.text = card.text
	if pos_label:
		var pos_disp: String = POS_DISPLAY.get(card.pos, card.pos)
		if pos_disp == "" and card.type != "":
			pos_disp = TYPE_DISPLAY.get(card.type, card.type)
		pos_label.text = pos_disp
		pos_label.visible = pos_disp != ""
	if phonetic_label:
		phonetic_label.text = card.phonetic
	if meaning_label:
		meaning_label.text = card.meaning
	if example_en_label:
		example_en_label.text = card.example_en
	if example_zh_label:
		example_zh_label.text = card.example_zh
	# B4：默认隐藏中文释义 / 音标 / 例句——只在 hover 显示
	_set_knowledge_visible(false)
	# 旧节点保持隐藏（兼容老代码引用）
	if type_label:
		type_label.text = card.type
		type_label.visible = false
	if pos_label_legacy:
		pos_label_legacy.text = card.pos if card.pos != "" else ""
		pos_label_legacy.visible = false
	if damage_label:
		damage_label.text = "%d" % card.base_damage
		damage_label.visible = false
	# 能力徽章
	if ability_badge:
		var bt: String = _ability_badge_text()
		ability_badge.text = bt
		ability_badge.visible = bt != ""
	if audio_button:
		audio_button.visible = not card.audio_path.is_empty()
	if mastery_label:
		mastery_label.text = MasterySystem.get_icon(mastery_level)
	if rarity_label:
		rarity_label.text = _rarity_short(card.rarity)
		rarity_label.modulate = RARITY_COLORS.get(card.rarity, Color.WHITE)
	# 反舒适区视觉：当 card.icon_path 为空时，应用程序化卡面背景
	# （type 决定底色 / rarity 决定边框）
	if card.icon_path == "":
		_apply_placeholder_background()
	tooltip_text = _build_tooltip()


func _set_knowledge_visible(v: bool) -> void:
	if phonetic_label:
		phonetic_label.visible = v and card != null and card.phonetic != ""
	if meaning_label:
		meaning_label.visible = v and card != null and card.meaning != ""
	if example_en_label:
		example_en_label.visible = v and card != null and card.example_en != ""
	if example_zh_label:
		example_zh_label.visible = v and card != null and card.example_zh != ""


func _ability_badge_text() -> String:
	if card == null:
		return ""
	if not CardAbilities.has_ability(card):
		return ""
	var icon: String = CardAbilities.icon(card.ability_type)
	var mag: int = card.ability_magnitude
	if mag > 0:
		return "%s +%d" % [icon, mag]
	return icon


## 用 CardIconGenerator 的配色制作 StyleBoxFlat 背景，让没美术资源时
## 卡片仍能看出 type / rarity 区分。
func _apply_placeholder_background() -> void:
	var bg: Color = CardIconGenerator.type_color(card.type)
	var border: Color = CardIconGenerator.rarity_color(card.rarity)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", sb)


func _build_tooltip() -> String:
	if card == null:
		return ""
	var lines: Array[String] = []
	var title := "[%s] %s" % [card.type, card.text]
	if card.phonetic != "":
		title += " " + card.phonetic
	lines.append(title)
	if card.meaning != "":
		lines.append("释义: " + card.meaning)
	if card.example_en != "":
		lines.append("例: " + card.example_en)
	if card.example_zh != "":
		lines.append("    " + card.example_zh)
	if card.pos != "":
		lines.append("词性: %s" % card.pos)
	if not card.tags.is_empty():
		lines.append("标签: " + ", ".join(card.tags))
	if card.skill != "":
		lines.append("技能: " + card.skill)
	lines.append("基础伤害: %d" % card.base_damage)
	if CardAbilities.has_ability(card):
		var atxt: String = "%s %s" % [
			CardAbilities.icon(card.ability_type),
			CardAbilities.display_name(card.ability_type),
		]
		if card.ability_magnitude > 0:
			atxt += " +%d" % card.ability_magnitude
		lines.append("能力: " + atxt)
		if card.ability_description != "":
			lines.append("    " + card.ability_description)
	lines.append("熟练: %s %s" % [
		MasterySystem.get_icon(mastery_level),
		MasterySystem.get_display_name(mastery_level),
	])
	return "\n".join(lines)


func _on_audio_button_pressed() -> void:
	if card == null:
		return
	CardAudio.play_card_audio(card, self)


func _rarity_short(rarity: String) -> String:
	match rarity:
		"common": return "C"
		"rare": return "R"
		"epic": return "E"
		"legendary": return "L"
		_: return ""


# ─── 拖拽 ─────────────────────────────────────────────────────────

func _get_drag_data(_at_position: Vector2) -> Variant:
	if card == null:
		return null
	# 拖拽预览 = 复制一个简易 PanelContainer
	# set_drag_preview 只能在真实拖拽事件中调用（否则会触发
	# !gui_is_dragging() 引擎报错），所以在没有活动拖拽时跳过预览——
	# 这条路径主要在单元测试里命中，玩家真实拖拽时正常生成预览。
	var vp = get_viewport() if is_inside_tree() else null
	if vp != null and vp.gui_is_dragging():
		var preview := PanelContainer.new()
		var lbl := Label.new()
		lbl.text = card.text
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		preview.add_child(lbl)
		preview.modulate.a = 0.85
		set_drag_preview(preview)
	# payload 是 dict，识别字段：
	#   - "type"/"card_id"/"ref"：T16 SlotDropZone 使用的新格式
	#   - "kind"/"card"/"source_view"：旧 ChallengeBoard 路径兼容字段
	return {
		"type": "card",
		"card_id": card.id,
		"ref": card,
		"kind": "card",
		"card": card,
		"source_view": self,
	}
