## CardMiniView — 备战界面 / 卡牌选择弹窗里使用的小卡片视图
##
## 布局（120 × 140，B4 重排：游戏属性优先，知识次要）：
##   ┌──────────┐
##   │ 🌱   C   │  ← Header（熟练度 + 稀有度）
##   │  ⚔ 8     │  ← 大字伤害（24pt）
##   │  brave   │  ← TextLabel（英文，14pt）
##   │ adj 🔗   │  ← Meta + 能力徽章
##   └──────────┘
## 中文释义/音标 默认隐藏，悬停（mouse_entered）显示。tooltip 也含完整信息。
##
## 与战斗用的 CardView 区别：
##   - 尺寸更小（120 × 140）
##   - 不支持拖拽，只支持点击（pressed 信号）
##
## 使用：
##   var v: CardMiniView = preload("res://src/battle/cards/card_mini_view.tscn").instantiate()
##   v.set_card(card, srs_system)
##   v.pressed.connect(_on_card_pressed.bind(card))
class_name CardMiniView extends Button


const RARITY_COLORS: Dictionary = {
	"common": Color(0.7, 0.7, 0.75),
	"rare": Color(0.4, 0.7, 1.0),
	"epic": Color(0.7, 0.4, 1.0),
	"legendary": Color(1.0, 0.7, 0.3),
}

@export var card: Card = null
var mastery_level: int = 0  # MasterySystem.MasteryLevel
## hover 时是否展开知识细节（B4 视觉降级：默认隐藏 释义/例句/音标）
var show_knowledge_on_hover: bool = true

@onready var _mastery_label: Label = $Layout/HeaderRow/MasteryLabel
@onready var _rarity_label: Label = $Layout/HeaderRow/RarityLabel
@onready var _damage_big_label: Label = $Layout/DamageBigLabel
@onready var _text_label: Label = $Layout/TextLabel
@onready var _phonetic_label: Label = $Layout/PhoneticLabel
@onready var _meaning_label: Label = $Layout/MeaningLabel
@onready var _meta_label: Label = $Layout/MetaRow/MetaLabel
@onready var _ability_badge: Label = $Layout/MetaRow/AbilityBadge
@onready var _audio_button: Button = $Layout/MetaRow/AudioButton


func _ready() -> void:
	custom_minimum_size = Vector2(120, 140)
	# 不让父容器把卡片压扁
	size_flags_horizontal = 0
	size_flags_vertical = 0
	# 全局 Kenney 主题的 Button 背景是浅灰，Label 默认白字会看不清。
	# 给 CardMiniView 单独覆盖一套深底 + 浅字 stylebox。
	_apply_dark_card_style()
	if _audio_button != null and not _audio_button.pressed.is_connected(_on_audio_button_pressed):
		_audio_button.pressed.connect(_on_audio_button_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	refresh()


func _apply_dark_card_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.17, 0.23, 1.0)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.3, 0.35, 0.45, 1.0)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = sb.bg_color.lightened(0.08)
	add_theme_stylebox_override("hover", sb_hover)
	add_theme_stylebox_override("pressed", sb_hover)
	add_theme_stylebox_override("focus", sb_hover)
	# 文字浅色让 Label 在深底上可读
	add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 0.85, 1.0))
	# 让内部 Label 子节点也浅色（Label 没继承 Button font_color，需要单独设）
	var light: Color = Color(0.95, 0.95, 1.0, 1.0)
	for n in [_damage_big_label, _text_label, _phonetic_label, _meaning_label,
			_meta_label, _mastery_label]:
		if n != null:
			n.add_theme_color_override("font_color", light)


func _on_mouse_entered() -> void:
	if show_knowledge_on_hover:
		_set_knowledge_visible(true)


func _on_mouse_exited() -> void:
	if show_knowledge_on_hover:
		_set_knowledge_visible(false)


func set_card(c: Card, srs: SRSSystem = null) -> void:
	card = c
	if c == null:
		return
	mastery_level = MasterySystem.get_level(c.id, srs)
	if not is_inside_tree():
		# 节点还没 _ready；仅记录，refresh 会在 _ready 触发
		return
	refresh()


func refresh() -> void:
	if card == null:
		if _text_label:
			_text_label.text = "?"
		if _phonetic_label:
			_phonetic_label.text = ""
		if _meaning_label:
			_meaning_label.text = ""
		if _audio_button:
			_audio_button.visible = false
		if _damage_big_label:
			_damage_big_label.text = ""
		if _ability_badge:
			_ability_badge.text = ""
		return
	if _damage_big_label:
		if card.base_damage > 0:
			_damage_big_label.text = "⚔ %d" % card.base_damage
			_damage_big_label.visible = true
		else:
			_damage_big_label.text = ""
			_damage_big_label.visible = false
	if _text_label:
		_text_label.text = card.text
	if _phonetic_label:
		_phonetic_label.text = card.phonetic
	if _meaning_label:
		_meaning_label.text = card.meaning
	# B4：默认隐藏中文释义/音标
	_set_knowledge_visible(false)
	if _meta_label:
		# 简化 meta 行——只显示词性缩写
		var pos_short := _pos_short(card.pos)
		if pos_short != "":
			_meta_label.text = pos_short
		elif not card.type.is_empty():
			_meta_label.text = card.type.substr(0, 3)
		else:
			_meta_label.text = ""
	if _ability_badge:
		var bt: String = _ability_badge_text()
		_ability_badge.text = bt
		_ability_badge.visible = bt != ""
	if _mastery_label:
		_mastery_label.text = MasterySystem.get_icon(mastery_level)
	if _rarity_label:
		_rarity_label.text = _rarity_short(card.rarity)
		_rarity_label.modulate = RARITY_COLORS.get(card.rarity, Color.WHITE)
	if _audio_button:
		_audio_button.visible = not card.audio_path.is_empty()
	tooltip_text = _build_tooltip()


func _set_knowledge_visible(v: bool) -> void:
	if _phonetic_label:
		_phonetic_label.visible = v and card != null and card.phonetic != ""
	if _meaning_label:
		_meaning_label.visible = v and card != null and card.meaning != ""


func _ability_badge_text() -> String:
	if card == null:
		return ""
	if not CardAbilities.has_ability(card):
		return ""
	var icon: String = CardAbilities.icon(card.ability_type)
	var mag: int = card.ability_magnitude
	if mag > 0:
		return "%s+%d" % [icon, mag]
	return icon


func _build_tooltip() -> String:
	if card == null:
		return ""
	var lines: Array[String] = []
	# 标题：英文 + 音标
	var title := card.text
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


func _pos_short(p: String) -> String:
	match p:
		"adjective": return "形"
		"noun": return "名"
		"verb": return "动"
		"adverb": return "副"
		"pronoun": return "代"
		"verb_be": return "be"
		"sight_word": return "高频"
		"letter": return "字母"
		"syllable": return "韵"
		_: return ""


func _rarity_short(rarity: String) -> String:
	match rarity:
		"common": return "C"
		"rare": return "R"
		"epic": return "E"
		"legendary": return "L"
		_: return ""
