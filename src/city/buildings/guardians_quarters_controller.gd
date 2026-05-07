## GuardiansQuartersController — 守护者驻地子场景
##
## Phase 2.7 MVP shell：3 个 tab。
##   1. 角色页：当前职业 + 永久属性总览（来自 SaveSystem.permanent_upgrades）
##   2. 卡组库：所有已解锁卡的浏览（来自 SaveSystem.unlocked_card_ids；
##              通过 ContentPackBase.get_card 拉详情）
##   3. 三星挑战：每个已解锁楼层的 3 颗星状态
##
## 装备 / 卷轴页面留待 Phase 3。
##
## 详见: docs/superpowers/specs/2026-05-04-knowledge-city-design.md
extends Control

const CITY_SCENE_PATH: String = "res://src/city/city_scene.tscn"

const STAR_DESCRIPTIONS: Array = [
	"通关",
	"不撤退一次通关",
	"用至少 N 张新卡通关",
]

@onready var _back_button: Button = $Header/BackButton

# Tab 1: 角色
@onready var _class_label: Label = $Tabs/角色/ClassLabel
@onready var _stats_label: RichTextLabel = $Tabs/角色/StatsLabel

# Tab 2: 卡组库
@onready var _cards_header: Label = $Tabs/卡组库/CardsHeader
@onready var _filter_option: OptionButton = $Tabs/卡组库/FilterRow/FilterOption
@onready var _cards_list: ItemList = $Tabs/卡组库/CardsList

# Tab 3: 三星挑战
@onready var _stars_container: VBoxContainer = $Tabs/三星挑战/StarsContainer

var _pack: ContentPackBase = null
var _all_unlocked_cards: Array[Card] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resolve_pack()
	_back_button.pressed.connect(_on_back_pressed)
	_render_character_tab()
	_setup_filter()
	_load_unlocked_cards()
	_render_cards_tab()
	_render_stars_tab()


# ---------------------------------------------------------------------------
# 通用
# ---------------------------------------------------------------------------

func _resolve_pack() -> void:
	if typeof(GameState) == TYPE_NIL or GameState.content_loader == null:
		return
	_pack = GameState.content_loader.get_active_pack()


func _read_state() -> Dictionary:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return {}
	return GameState.save_system.load_game_state()


# ---------------------------------------------------------------------------
# Tab 1: 角色
# ---------------------------------------------------------------------------

func _render_character_tab() -> void:
	var state: Dictionary = _read_state()
	var class_id: String = str(state.get("current_class_id", "guardian"))
	_class_label.text = "职业：%s" % _format_class_name(class_id)

	var pu_v: Variant = state.get("permanent_upgrades", {})
	var pu: Dictionary = pu_v if pu_v is Dictionary else {}
	var hp: int = int(pu.get("starting_hp", 100))
	var crystals: int = int(pu.get("starting_crystals", 0))
	var draw: int = int(pu.get("starting_draw", 5))
	var deck_max: int = int(pu.get("deck_slot_max", 8))

	_stats_label.bbcode_enabled = true
	var lines: Array[String] = []
	lines.append("[b]永久属性[/b]")
	lines.append("❤  起手 HP: %d" % hp)
	lines.append("🔮  起手词晶: %d" % crystals)
	lines.append("✋  起手抽牌: %d" % draw)
	lines.append("🃏  卡组槽位上限: %d" % deck_max)
	_stats_label.text = "\n".join(lines)


func _format_class_name(class_id: String) -> String:
	match class_id:
		"guardian": return "守护者"
		"scholar": return "学者"
		"warrior": return "战士"
		"healer": return "治愈师"
		_: return class_id if class_id != "" else "守护者"


# ---------------------------------------------------------------------------
# Tab 2: 卡组库
# ---------------------------------------------------------------------------

func _setup_filter() -> void:
	_filter_option.clear()
	_filter_option.add_item("全部")
	_filter_option.add_item("仅 word")
	_filter_option.add_item("仅 phrase")
	_filter_option.add_item("仅 pattern")
	_filter_option.add_item("仅 rule")
	_filter_option.item_selected.connect(_on_filter_changed)


func _load_unlocked_cards() -> void:
	_all_unlocked_cards = []
	var state: Dictionary = _read_state()
	var ids_v: Variant = state.get("unlocked_card_ids", [])
	var ids: Array = ids_v if ids_v is Array else []
	if _pack == null:
		return
	for cid in ids:
		var c: Card = _pack.get_card(str(cid))
		if c != null:
			_all_unlocked_cards.append(c)


func _render_cards_tab() -> void:
	_cards_list.clear()
	var filter_idx: int = _filter_option.selected if _filter_option.selected >= 0 else 0
	var filter_type: String = _filter_label_to_type(filter_idx)
	var filtered: Array[Card] = []
	for c in _all_unlocked_cards:
		if filter_type == "" or c.type == filter_type:
			filtered.append(c)
	_cards_header.text = "已解锁卡片：%d / %d" % [filtered.size(), _all_unlocked_cards.size()]
	if filtered.is_empty():
		_cards_list.add_item("（无 — 通关楼层 / 集市购买后解锁）")
		return
	for c in filtered:
		var pos_text: String = c.pos if c.pos != "" else "-"
		_cards_list.add_item("%s  [%s/%s]  伤害 %d" % [c.text, c.type, pos_text, c.base_damage])


func _filter_label_to_type(idx: int) -> String:
	match idx:
		1: return "word"
		2: return "phrase"
		3: return "pattern"
		4: return "rule"
		_: return ""


func _on_filter_changed(_idx: int) -> void:
	_render_cards_tab()


# ---------------------------------------------------------------------------
# Tab 3: 三星挑战
# ---------------------------------------------------------------------------

func _render_stars_tab() -> void:
	for child in _stars_container.get_children():
		child.queue_free()
	var state: Dictionary = _read_state()
	var floors_v: Variant = state.get("unlocked_floor_ids", [])
	var floors: Array = floors_v if floors_v is Array else []
	if floors.is_empty():
		var empty := Label.new()
		empty.text = "（暂无已解锁楼层）"
		_stars_container.add_child(empty)
		return
	var prog_v: Variant = state.get("three_star_progress", {})
	var prog: Dictionary = prog_v if prog_v is Dictionary else {}
	for fid in floors:
		var floor_id: String = str(fid)
		var stars_v: Variant = prog.get(floor_id, [])
		var stars: Array = stars_v if stars_v is Array else []
		_stars_container.add_child(_make_floor_block(floor_id, stars))


func _make_floor_block(floor_id: String, stars: Array) -> VBoxContainer:
	var block := VBoxContainer.new()
	var head := Label.new()
	head.text = "楼层 %s  %s" % [floor_id, _format_star_row(stars)]
	head.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	block.add_child(head)
	for i in range(STAR_DESCRIPTIONS.size()):
		var lit: bool = i < stars.size() and bool(stars[i])
		var line := Label.new()
		var icon: String = "⭐" if lit else "☆"
		line.text = "  %s  %s" % [icon, STAR_DESCRIPTIONS[i]]
		line.modulate = Color(1, 1, 1, 1.0 if lit else 0.5)
		block.add_child(line)
	return block


func _format_star_row(stars: Array) -> String:
	var out: String = ""
	for i in range(STAR_DESCRIPTIONS.size()):
		var lit: bool = i < stars.size() and bool(stars[i])
		out += "⭐" if lit else "☆"
	return out


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(CITY_SCENE_PATH)
