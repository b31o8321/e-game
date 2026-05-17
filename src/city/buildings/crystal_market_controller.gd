## CrystalMarketController — 水晶集市（永久小升级）
##
## 展示 5 项可购买的永久升级，每项显示当前等级 + 价格 + 购买按钮。
## 升级数据持久化到 state["permanent_upgrades"][upgrade_id]: int。
##
## 详见: docs/superpowers/specs/2026-05-04-knowledge-city-design.md
class_name CrystalMarketController extends Control


const CITY_SCENE_PATH: String = "res://src/city/city_scene.tscn"

## 升级定义表：每项包含 id / icon / name / desc_fmt / prices / max_level
## desc_fmt 用 %d 代表 level（用于 "效果说明"）
const UPGRADES: Array = [
	{
		"id": "starting_hp_plus",
		"icon": "❤️",
		"name": "起始 HP +10",
		"desc_fmt": "起始 HP +%d×10",
		"prices": [50, 100, 200, 400],
		"max_level": 4,
	},
	{
		"id": "starting_crystals_plus",
		"icon": "🔮",
		"name": "起始词晶 +5",
		"desc_fmt": "每局开始多 %d×5 词晶",
		"prices": [30, 60, 120],
		"max_level": 3,
	},
	{
		"id": "deck_slot_plus",
		"icon": "📚",
		"name": "单词库槽位 +1",
		"desc_fmt": "最大单词库 +%d 格",
		"prices": [80, 160, 320],
		"max_level": 3,
	},
	{
		"id": "starting_draw_plus",
		"icon": "🎴",
		"name": "起手抽卡 +1",
		"desc_fmt": "起手多抽 %d 张（reserved）",
		"prices": [40, 80, 160],
		"max_level": 3,
	},
	{
		"id": "relic_init_plus",
		"icon": "🎁",
		"name": "起始遗物 +1",
		"desc_fmt": "每局开始随机获得 %d 个遗物",
		"prices": [200, 400],
		"max_level": 2,
	},
]

var _back_button: Button = null
var _wallet_label: Label = null
var _item_list: VBoxContainer = null
var _status_label: Label = null


func _ready() -> void:
	_back_button = get_node_or_null("Header/BackButton")
	_wallet_label = get_node_or_null("WalletLabel")
	_item_list = get_node_or_null("ItemScroll/ItemList")
	_status_label = get_node_or_null("StatusLabel")
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)
	_refresh_ui()


# ─── 读写永久升级 ──────────────────────────────────────────────────

func _read_upgrade_level(uid: String) -> int:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return 0
	var state: Dictionary = GameState.save_system.load_game_state()
	var u: Dictionary = state.get("permanent_upgrades", {})
	return int(u.get(uid, 0))


func _write_upgrade_level(uid: String, lvl: int) -> void:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return
	var state: Dictionary = GameState.save_system.load_game_state()
	var u: Dictionary = state.get("permanent_upgrades", {})
	u[uid] = lvl
	state["permanent_upgrades"] = u
	GameState.save_system.save_game_state(state)


## 尝试购买升级。返回 true 表示成功，false 表示钱包不足或已满级。
func try_purchase(uid: String) -> bool:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return false
	# 找出 upgrade 定义
	var udef: Dictionary = {}
	for entry in UPGRADES:
		if entry["id"] == uid:
			udef = entry
			break
	if udef.is_empty():
		return false
	var cur_lvl: int = _read_upgrade_level(uid)
	var max_lvl: int = int(udef["max_level"])
	if cur_lvl >= max_lvl:
		return false
	var prices: Array = udef["prices"]
	if cur_lvl >= prices.size():
		return false
	var price: int = int(prices[cur_lvl])
	var ok: bool = GameState.save_system.spend_crystals(price)
	if not ok:
		return false
	_write_upgrade_level(uid, cur_lvl + 1)
	return true


# ─── UI 刷新 ───────────────────────────────────────────────────────

func _refresh_ui() -> void:
	_refresh_wallet()
	_render_items()


func _refresh_wallet() -> void:
	if _wallet_label == null:
		return
	var crystals: int = 0
	if typeof(GameState) != TYPE_NIL and GameState != null and GameState.save_system != null:
		var w: Dictionary = GameState.save_system.get_wallet()
		crystals = int(w.get("crystals", 0))
	_wallet_label.text = "🔮 词晶: %d" % crystals


func _render_items() -> void:
	if _item_list == null:
		return
	for child in _item_list.get_children():
		child.queue_free()

	var crystals: int = 0
	if typeof(GameState) != TYPE_NIL and GameState != null and GameState.save_system != null:
		var w: Dictionary = GameState.save_system.get_wallet()
		crystals = int(w.get("crystals", 0))

	for udef in UPGRADES:
		var uid: String = udef["id"]
		var cur_lvl: int = _read_upgrade_level(uid)
		var max_lvl: int = int(udef["max_level"])
		var prices: Array = udef["prices"]

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# 左：图标 + 名字 + 等级 + 效果
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon: String = udef["icon"]
		var uname: String = udef["name"]
		var desc: String = udef["desc_fmt"] % cur_lvl
		if cur_lvl >= max_lvl:
			lbl.text = "%s %s  Lv %d/%d · %s" % [icon, uname, cur_lvl, max_lvl, desc]
		else:
			var price: int = int(prices[cur_lvl])
			lbl.text = "%s %s  Lv %d/%d · %s · 词晶 %d" % [icon, uname, cur_lvl, max_lvl, desc, price]
		row.add_child(lbl)

		# 右：按钮
		var btn := Button.new()
		if cur_lvl >= max_lvl:
			btn.text = "（已满）"
			btn.disabled = true
		else:
			var price: int = int(prices[cur_lvl])
			btn.text = "升级"
			btn.disabled = crystals < price
			btn.pressed.connect(_on_upgrade_pressed.bind(uid))
		row.add_child(btn)

		_item_list.add_child(row)

		# 分隔线
		var sep := HSeparator.new()
		_item_list.add_child(sep)


func _on_upgrade_pressed(uid: String) -> void:
	var ok: bool = try_purchase(uid)
	if _status_label != null:
		if ok:
			_status_label.text = "升级成功！"
		else:
			_status_label.text = "词晶不足或已满级。"
	_refresh_ui()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(CITY_SCENE_PATH)
