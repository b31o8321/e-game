## CardPickerModal — "添加卡片" 弹窗（备战界面使用）
##
## 列出全部候选卡（unlocked + starting deck），可按 type 过滤，
## 选中后通过 `card_picked` 信号返回单张卡，调用方负责实际入组。
##
## 使用：
##   var modal: CardPickerModal = preload(".../card_picker_modal.tscn").instantiate()
##   modal.set_options(candidates, srs)
##   modal.card_picked.connect(_on_card_picked)
##   modal.cancelled.connect(_on_picker_cancelled)
##   add_child(modal)
##   modal.popup_centered()
##
## 详见: docs/superpowers/specs/2026-05-04-knowledge-city-design.md
class_name CardPickerModal extends Window


const CardMiniViewScene := preload("res://src/battle/cards/card_mini_view.tscn")

signal card_picked(card: Card)
signal cancelled

@onready var _grid: GridContainer = $Margin/VBox/Scroll/Grid
@onready var _filter_option: OptionButton = $Margin/VBox/HeaderRow/FilterOption
@onready var _empty_label: Label = $Margin/VBox/EmptyLabel
@onready var _close_button: Button = $Margin/VBox/Footer/CloseButton

var _candidates: Array[Card] = []
var _srs: SRSSystem = null
var _current_filter: String = ""


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	if _close_button != null:
		_close_button.pressed.connect(_on_close_requested)
	if _filter_option != null:
		_filter_option.item_selected.connect(_on_filter_changed)
	_rebuild()


## 设置候选卡 + 当前 SRS（用来显示熟练度）
func set_options(cards: Array[Card], srs: SRSSystem = null) -> void:
	_candidates = cards.duplicate()
	_srs = srs
	if is_inside_tree():
		_populate_filter()
		_rebuild()


func _populate_filter() -> void:
	if _filter_option == null:
		return
	_filter_option.clear()
	_filter_option.add_item("全部类型", 0)
	# 收集出现过的 type 集合，按字母排序
	var types: Array[String] = []
	for c in _candidates:
		if c != null and not c.type.is_empty() and not types.has(c.type):
			types.append(c.type)
	types.sort()
	for i in types.size():
		_filter_option.add_item(types[i], i + 1)


func _on_filter_changed(index: int) -> void:
	if index <= 0:
		_current_filter = ""
	else:
		_current_filter = _filter_option.get_item_text(index)
	_rebuild()


func _rebuild() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		child.queue_free()
	var visible_count: int = 0
	for c in _candidates:
		if c == null:
			continue
		if not _current_filter.is_empty() and c.type != _current_filter:
			continue
		var view: CardMiniView = CardMiniViewScene.instantiate() as CardMiniView
		_grid.add_child(view)
		view.set_card(c, _srs)
		view.pressed.connect(_on_card_button_pressed.bind(c))
		visible_count += 1
	if _empty_label != null:
		_empty_label.visible = visible_count == 0


func _on_card_button_pressed(c: Card) -> void:
	card_picked.emit(c)


func _on_close_requested() -> void:
	cancelled.emit()
	hide()
	queue_free()
