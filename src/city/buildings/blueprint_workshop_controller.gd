## BlueprintWorkshopController — 蓝图工坊子场景
##
## Phase 2.7 MVP shell：用蓝图碎片买永久重大解锁。
## 当前真正可用的项目仅有"卡组槽位扩展"——其余项目（多职业 / 难度模式）作为
## "敬请期待"占位，便于 UI 验证与未来扩展。
##
## 卡组槽位升级写入 SaveSystem 的 permanent_upgrades.deck_slot_max。
##
## 详见: docs/superpowers/specs/2026-05-04-knowledge-city-design.md
extends Control

const CITY_SCENE_PATH: String = "res://src/city/city_scene.tscn"
const DEFAULT_DECK_SLOT_MAX: int = 8

## 升级项配置：每个 step 把 deck_slot_max 推到 to_value
const DECK_SLOT_TIERS: Array = [
	{"label": "卡组槽位 8 → 10", "from": 8, "to": 10, "cost": 10},
	{"label": "卡组槽位 10 → 12", "from": 10, "to": 12, "cost": 15},
	{"label": "卡组槽位 12 → 14", "from": 12, "to": 14, "cost": 20},
]

## 占位项（敬请期待）
const PLACEHOLDER_ITEMS: Array = [
	{"label": "解锁第二职业「学者」", "cost": 10},
	{"label": "解锁第二职业「战士」", "cost": 10},
	{"label": "解锁 1F+ 难度模式", "cost": 15},
	{"label": "解锁传说卡入永久卡池", "cost": 10},
	{"label": "解锁新 Spice 卷轴类型", "cost": 3},
]

@onready var _back_button: Button = $Header/BackButton
@onready var _balance_label: Label = $BalanceLabel
@onready var _items_container: VBoxContainer = $ItemScroll/ItemList
@onready var _status_label: Label = $StatusLabel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back_button.pressed.connect(_on_back_pressed)
	_refresh_balance()
	_render_items()


# ---------------------------------------------------------------------------
# 余额 / 永久升级 helper
# ---------------------------------------------------------------------------

func _refresh_balance() -> void:
	var blueprints: int = _get_blueprints()
	_balance_label.text = "🧩 蓝图碎片: %d" % blueprints


func _get_blueprints() -> int:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return 0
	var w: Dictionary = GameState.save_system.get_wallet()
	return int(w.get("blueprints", 0))


func _get_permanent_upgrades() -> Dictionary:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return {}
	var state: Dictionary = GameState.save_system.load_game_state()
	var pu: Variant = state.get("permanent_upgrades", {})
	return pu if pu is Dictionary else {}


func _set_permanent_upgrade(key: String, value: int) -> void:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return
	var state: Dictionary = GameState.save_system.load_game_state()
	var pu_v: Variant = state.get("permanent_upgrades", {})
	var pu: Dictionary = pu_v if pu_v is Dictionary else {}
	pu[key] = value
	state["permanent_upgrades"] = pu
	GameState.save_system.save_game_state(state)


func _get_deck_slot_max() -> int:
	var pu: Dictionary = _get_permanent_upgrades()
	return int(pu.get("deck_slot_max", DEFAULT_DECK_SLOT_MAX))


# ---------------------------------------------------------------------------
# 渲染
# ---------------------------------------------------------------------------

func _render_items() -> void:
	for child in _items_container.get_children():
		child.queue_free()
	var blueprints: int = _get_blueprints()
	var current_max: int = _get_deck_slot_max()

	# Section: 卡组槽位（功能项）
	_items_container.add_child(_make_section_header("卡组槽位升级"))
	for tier in DECK_SLOT_TIERS:
		var t: Dictionary = tier
		var label: String = t.get("label", "")
		var cost: int = int(t.get("cost", 0))
		var from_val: int = int(t.get("from", 0))
		var to_val: int = int(t.get("to", 0))
		var already_done: bool = current_max >= to_val
		var unlockable: bool = current_max == from_val
		var disabled: bool = already_done or not unlockable or blueprints < cost
		var hint: String = ""
		if already_done:
			hint = "已完成"
		elif not unlockable:
			hint = "需先达到 %d 槽位" % from_val
		elif blueprints < cost:
			hint = "蓝图不足"
		_items_container.add_child(_make_item_row(label, cost, disabled, hint, func() -> void:
			_buy_deck_slot(to_val, cost)
		))

	# Section: 占位项
	_items_container.add_child(_make_section_header("更多解锁（敬请期待）"))
	for it in PLACEHOLDER_ITEMS:
		var item: Dictionary = it
		var item_label: String = item.get("label", "")
		var item_cost: int = int(item.get("cost", 0))
		_items_container.add_child(_make_item_row(item_label, item_cost, true, "敬请期待", func() -> void:
			pass
		))


func _make_section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "── " + text + " ──"
	lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.4))
	return lbl


func _make_item_row(label: String, cost: int, disabled: bool, hint: String, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var cost_lbl := Label.new()
	cost_lbl.text = "🧩 %d" % cost
	cost_lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(cost_lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = hint
	hint_lbl.custom_minimum_size = Vector2(160, 0)
	hint_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(hint_lbl)
	var btn := Button.new()
	btn.text = "购买"
	btn.disabled = disabled
	btn.custom_minimum_size = Vector2(80, 0)
	btn.pressed.connect(callback)
	row.add_child(btn)
	return row


# ---------------------------------------------------------------------------
# 购买动作
# ---------------------------------------------------------------------------

func _buy_deck_slot(to_value: int, cost: int) -> void:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		_status_label.text = "存档系统不可用"
		return
	var ok: bool = GameState.save_system.spend_blueprints(cost)
	if not ok:
		_status_label.text = "蓝图不足"
		return
	_set_permanent_upgrade("deck_slot_max", to_value)
	_status_label.text = "卡组槽位扩展至 %d！" % to_value
	_refresh_balance()
	_render_items()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(CITY_SCENE_PATH)
