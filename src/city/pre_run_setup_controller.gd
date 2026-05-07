## PreRunSetupController — 备战界面（神塔之门 → 楼层简介 → 备战 → Run）
##
## 职责：
##   - 展示当前楼层信息（unit_name / 推荐时长 / 子主题）
##   - 展示永久升级摘要（HP / 起手抽 / 词晶）
##   - 卡组编辑（添加 / 移除 / 推荐补全 / 清空）
##   - 卡组分析（熟练度分布 + 新卡奖励预估）
##   - 装备 / 卷轴只读概览（Phase 4.3 才接入完整选择）
##   - 复习卡片入口（CutscenePlayer）
##   - [启程] → RunState.start_floor + 切到 RunMapScene
##   - [返回] → 回 TowerGate
##
## 输入：RunState.pending_floor_id（TowerGateController 切场景前写入）
##
## 详见: docs/superpowers/specs/2026-05-04-knowledge-city-design.md
##       docs/superpowers/specs/2026-05-04-run-structure-design.md
class_name PreRunSetupController extends Control


const TOWER_GATE_SCENE: String = "res://src/city/buildings/tower_gate_scene.tscn"
const RUN_MAP_SCENE: String = "res://src/run/run_map_scene.tscn"

const CardMiniViewScene := preload("res://src/battle/cards/card_mini_view.tscn")
const CardPickerModalScene := preload("res://src/city/buildings/card_picker_modal.tscn")

# 测试钩子：true 时 _on_launch_pressed 不真的 change_scene_to_file，
# 仅设 last_launched_floor_id 让测试可断言。
var test_disable_scene_change: bool = false
var last_launched_floor_id: String = ""

var _pack: ContentPackBase = null
var _floor_id: String = ""
var _floor_config: Dictionary = {}
var _current_deck: Array[Card] = []
var _deck_slot_max: int = 12

# UI 引用
@onready var _header_label: Label = $Header/HeaderLabel
@onready var _back_button: Button = $Footer/BackButton
@onready var _launch_button: Button = $Footer/LaunchButton

@onready var _class_label: Label = $Body/Sections/ClassRow/ClassLabel
@onready var _upgrades_label: Label = $Body/Sections/ClassRow/UpgradesLabel

@onready var _deck_size_label: Label = $Body/Sections/DeckSection/DeckHeader/DeckSizeLabel
@onready var _deck_grid: GridContainer = $Body/Sections/DeckSection/DeckScroll/DeckGrid
@onready var _add_card_button: Button = $Body/Sections/DeckSection/DeckActionsRow/AddCardButton
@onready var _remove_card_button: Button = $Body/Sections/DeckSection/DeckActionsRow/RemoveButton
@onready var _recommend_button: Button = $Body/Sections/DeckSection/DeckActionsRow/RecommendButton
@onready var _clear_button: Button = $Body/Sections/DeckSection/DeckActionsRow/ClearButton

@onready var _analysis_fresh: Label = $Body/Sections/AnalysisSection/AnalysisGrid/FreshLabel
@onready var _analysis_learning: Label = $Body/Sections/AnalysisSection/AnalysisGrid/LearningLabel
@onready var _analysis_proficient: Label = $Body/Sections/AnalysisSection/AnalysisGrid/ProficientLabel
@onready var _analysis_mastered: Label = $Body/Sections/AnalysisSection/AnalysisGrid/MasteredLabel
@onready var _analysis_reward: Label = $Body/Sections/AnalysisSection/AnalysisGrid/RewardLabel

@onready var _equipment_label: Label = $Body/Sections/EquipmentRow/EquipmentLabel
@onready var _spice_label: Label = $Body/Sections/EquipmentRow/SpiceLabel

@onready var _review_button: Button = $Body/Sections/ReviewSection/ReviewActionsRow/ReviewButton
@onready var _skip_review_button: Button = $Body/Sections/ReviewSection/ReviewActionsRow/SkipReviewButton
@onready var _review_section: VBoxContainer = $Body/Sections/ReviewSection

@onready var _status_label: Label = $StatusLabel

# 移除模式：true 时点击卡 → 移除并重置
var _remove_mode: bool = false

# 调试小工具行（只在 DebugMode.enabled 时出现）
var _debug_row: HBoxContainer = null


func _ready() -> void:
	_resolve_pack()
	_floor_id = _resolve_pending_floor_id()
	_load_permanent_upgrades()
	_load_floor_config()
	_load_initial_deck()
	_render_all()
	_hookup_buttons()
	_setup_debug_cheats()


func _hookup_buttons() -> void:
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)
	if _launch_button != null:
		_launch_button.pressed.connect(_on_launch_pressed)
	if _add_card_button != null:
		_add_card_button.pressed.connect(_on_add_card_pressed)
	if _remove_card_button != null:
		_remove_card_button.pressed.connect(_on_remove_mode_toggled)
	if _recommend_button != null:
		_recommend_button.pressed.connect(_on_recommend_pressed)
	if _clear_button != null:
		_clear_button.pressed.connect(_on_clear_pressed)
	if _review_button != null:
		_review_button.pressed.connect(_on_review_pressed)
	if _skip_review_button != null:
		_skip_review_button.pressed.connect(_on_skip_review_pressed)


# ───────────────────────────────────────────────────────────────────
# 资源解析
# ───────────────────────────────────────────────────────────────────

func _resolve_pack() -> void:
	if typeof(GameState) == TYPE_NIL or GameState.content_loader == null:
		return
	_pack = GameState.content_loader.get_active_pack()


func _resolve_pending_floor_id() -> String:
	if typeof(RunState) != TYPE_NIL and RunState != null:
		var fid: String = str(RunState.pending_floor_id)
		if not fid.is_empty():
			return fid
	# 回退默认 1F，避免空白页面
	return "1F"


func _load_permanent_upgrades() -> void:
	# 默认值（来自 spec 第 246 行附近）
	_deck_slot_max = 12


func _load_floor_config() -> void:
	if _pack == null:
		_floor_config = {}
		return
	_floor_config = _pack.get_floor_config(_floor_id)
	if not (_floor_config is Dictionary):
		_floor_config = {}


func _load_initial_deck() -> void:
	_current_deck = []
	if _pack == null:
		return
	# 优先使用 SaveSystem 上保存的 deck_templates[0]；否则用按楼层定制的起手卡组
	# （解决"题目和手卡对不上"——0F 给字母卡 / 2F 给名词卡，而不是默认形容词）
	var saved_ids: Array[String] = _read_saved_deck_ids()
	var ids_to_use: Array[String] = saved_ids
	if ids_to_use.is_empty():
		ids_to_use = _pack.get_starting_deck_for_floor(_floor_id)
		if ids_to_use.is_empty():
			ids_to_use = _pack.get_starting_deck_card_ids()
	for cid in ids_to_use:
		var c: Card = _pack.get_card(cid)
		if c != null:
			_current_deck.append(c)


# ───────────────────────────────────────────────────────────────────
# 渲染
# ───────────────────────────────────────────────────────────────────

func _render_all() -> void:
	_render_header()
	_render_class_and_upgrades()
	_render_deck()
	_render_analysis()
	_render_equipment()


func _render_header() -> void:
	if _header_label == null:
		return
	var unit_name: String = str(_floor_config.get("unit_name", _floor_id))
	var minutes: int = int(_floor_config.get("recommended_run_minutes", 0))
	var suffix: String = ""
	if minutes > 0:
		suffix = "  ·  推荐 %d 分钟" % minutes
	_header_label.text = "楼层 %s · %s%s" % [_floor_id, unit_name, suffix]


func _render_class_and_upgrades() -> void:
	if _class_label != null:
		var class_name_text: String = "守护者"
		_class_label.text = "职业：%s ▾" % class_name_text
	if _upgrades_label != null:
		var u: Dictionary = _read_permanent_upgrades()
		var hp: int = int(u.get("starting_hp", 100))
		var draw: int = int(u.get("starting_draw", 5))
		var bonus_crystals: int = int(u.get("starting_crystals", 0))
		_deck_slot_max = int(u.get("deck_slot_max", 12))
		_upgrades_label.text = "HP %d  ·  起手抽 %d  ·  词晶 +%d" % [hp, draw, bonus_crystals]


func _render_deck() -> void:
	if _deck_size_label != null:
		_deck_size_label.text = "当前卡组（%d/%d）：" % [_current_deck.size(), _deck_slot_max]
	if _deck_grid == null:
		return
	for child in _deck_grid.get_children():
		child.queue_free()
	if _current_deck.is_empty():
		var lbl := Label.new()
		lbl.text = "（卡组为空，点击 '+ 添加卡' 或 '推荐补全'）"
		_deck_grid.add_child(lbl)
		return
	var srs: SRSSystem = _resolve_srs()
	for i in _current_deck.size():
		var card: Card = _current_deck[i]
		var view: CardMiniView = CardMiniViewScene.instantiate() as CardMiniView
		# 不让 GridContainer 把卡片压缩到看不到内容；保持自然尺寸
		view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		view.custom_minimum_size = Vector2(120, 140)
		_deck_grid.add_child(view)
		view.set_card(card, srs)
		view.pressed.connect(_on_deck_card_pressed.bind(i))


func _render_analysis() -> void:
	var counts: Dictionary = compute_deck_mastery_distribution(_current_deck, _resolve_srs())
	var fresh: int = int(counts.get("fresh", 0))
	var learning: int = int(counts.get("learning", 0))
	var proficient: int = int(counts.get("proficient", 0))
	var mastered: int = int(counts.get("mastered", 0))
	var total: int = max(1, _current_deck.size())  # 用作百分比基数
	if _analysis_fresh != null:
		_analysis_fresh.text = "🌱 新     %d 张 (%d%%)" % [fresh, _pct(fresh, total)]
	if _analysis_learning != null:
		_analysis_learning.text = "🌿 学习中 %d 张 (%d%%)" % [learning, _pct(learning, total)]
	if _analysis_proficient != null:
		_analysis_proficient.text = "🌳 熟练   %d 张 (%d%%)" % [proficient, _pct(proficient, total)]
	if _analysis_mastered != null:
		_analysis_mastered.text = "⭐ 掌握   %d 张 (%d%%)" % [mastered, _pct(mastered, total)]
	if _analysis_reward != null:
		# 简单估算：每张 fresh 卡通关后 +5 词晶
		var reward: int = fresh * 5
		_analysis_reward.text = "预估本局新卡奖励：+%d 词晶" % reward


func _render_equipment() -> void:
	# Phase 4.2 只读占位（Phase 4.3 接入完整槽位选择）
	if _equipment_label != null:
		_equipment_label.text = "装备：⚔ 木剑  /  🛡 无  /  💍 无"
	if _spice_label != null:
		_spice_label.text = "卷轴：📜 (Phase 4.3)"


func _pct(n: int, total: int) -> int:
	if total <= 0:
		return 0
	return int(round(100.0 * float(n) / float(total)))


# ───────────────────────────────────────────────────────────────────
# 公共：卡组分析（静态，可被 test 调用）
# ───────────────────────────────────────────────────────────────────

## 按熟练度等级分组统计；返回 {"fresh": n, "learning": n, "proficient": n, "mastered": n}
static func compute_deck_mastery_distribution(deck: Array[Card], srs: SRSSystem) -> Dictionary:
	var out: Dictionary = {"fresh": 0, "learning": 0, "proficient": 0, "mastered": 0}
	for c in deck:
		if c == null:
			continue
		var lvl: int = MasterySystem.get_level(c.id, srs)
		match lvl:
			MasterySystem.MasteryLevel.FRESH:
				out["fresh"] = int(out["fresh"]) + 1
			MasterySystem.MasteryLevel.LEARNING:
				out["learning"] = int(out["learning"]) + 1
			MasterySystem.MasteryLevel.PROFICIENT:
				out["proficient"] = int(out["proficient"]) + 1
			MasterySystem.MasteryLevel.MASTERED:
				out["mastered"] = int(out["mastered"]) + 1
	return out


# ───────────────────────────────────────────────────────────────────
# Save / 永久升级 / SRS / 解锁
# ───────────────────────────────────────────────────────────────────

func _read_permanent_upgrades() -> Dictionary:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return _default_permanent_upgrades()
	var state: Dictionary = GameState.save_system.load_game_state()
	var u: Variant = state.get("permanent_upgrades", null)
	if u is Dictionary:
		var d: Dictionary = u
		# 用默认值兜底缺失字段
		var defaults: Dictionary = _default_permanent_upgrades()
		for k in defaults.keys():
			if not d.has(k):
				d[k] = defaults[k]
		return d
	return _default_permanent_upgrades()


func _default_permanent_upgrades() -> Dictionary:
	return {
		"starting_hp": 100,
		"starting_crystals": 0,
		"starting_draw": 5,
		"deck_slot_max": 12,
	}


func _read_saved_deck_ids() -> Array[String]:
	var out: Array[String] = []
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return out
	var state: Dictionary = GameState.save_system.load_game_state()
	var templates: Variant = state.get("deck_templates", [])
	if not (templates is Array):
		return out
	if templates.is_empty():
		return out
	var first: Variant = templates[0]
	if not (first is Dictionary):
		return out
	var ids_raw: Variant = first.get("card_ids", [])
	if ids_raw is Array:
		for v in ids_raw:
			out.append(str(v))
	return out


func _read_unlocked_card_ids() -> Array[String]:
	var out: Array[String] = []
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return out
	var state: Dictionary = GameState.save_system.load_game_state()
	var arr: Variant = state.get("unlocked_card_ids", [])
	if arr is Array:
		for v in arr:
			out.append(str(v))
	return out


func _resolve_srs() -> SRSSystem:
	if typeof(GameState) == TYPE_NIL:
		return null
	return GameState.srs_system


# ───────────────────────────────────────────────────────────────────
# 按钮回调
# ───────────────────────────────────────────────────────────────────

func _on_add_card_pressed() -> void:
	_remove_mode = false
	_set_status("")
	if _current_deck.size() >= _deck_slot_max:
		_set_status("卡组已满（%d/%d）" % [_current_deck.size(), _deck_slot_max])
		return
	if _pack == null:
		_set_status("内容包未加载，无法选卡")
		return
	var candidates: Array[Card] = _build_candidate_pool()
	if candidates.is_empty():
		_set_status("没有可添加的卡片")
		return
	var modal: CardPickerModal = CardPickerModalScene.instantiate() as CardPickerModal
	add_child(modal)
	modal.set_options(candidates, _resolve_srs())
	modal.card_picked.connect(_on_card_picked.bind(modal))
	modal.cancelled.connect(_on_picker_cancelled)
	modal.popup_centered()


func _on_card_picked(card: Card, modal: CardPickerModal) -> void:
	if card != null:
		add_card_to_deck(card)
		_render_deck()
		_render_analysis()
	if modal != null and is_instance_valid(modal):
		modal.hide()
		modal.queue_free()


func _on_picker_cancelled() -> void:
	pass


func _on_remove_mode_toggled() -> void:
	_remove_mode = not _remove_mode
	if _remove_mode:
		_set_status("[移除模式] 点击卡组中要移除的卡片，再次点击按钮取消")
	else:
		_set_status("")


func _on_recommend_pressed() -> void:
	_remove_mode = false
	_set_status("")
	if _pack == null:
		_set_status("内容包未加载，无法推荐")
		return
	var srs: SRSSystem = _resolve_srs()
	var pool: Array[Card] = _pack.get_card_pool_for_floor(_floor_id)
	if pool.is_empty():
		# 兜底：所有卡里挑非掌握的
		pool = _pack.get_all_cards()
	# 已在卡组中的卡
	var have_ids: Dictionary = {}
	for c in _current_deck:
		if c != null:
			have_ids[c.id] = true
	# 取尚未掌握 + 不在当前卡组的；按熟练度从低到高排序
	var picks: Array[Card] = []
	for c in pool:
		if c == null:
			continue
		if have_ids.has(c.id):
			continue
		var lvl: int = MasterySystem.get_level(c.id, srs)
		if lvl == MasterySystem.MasteryLevel.MASTERED:
			continue
		picks.append(c)
	picks.sort_custom(func(a: Card, b: Card) -> bool:
		return MasterySystem.get_level(a.id, srs) < MasterySystem.get_level(b.id, srs))
	var slots_left: int = _deck_slot_max - _current_deck.size()
	if slots_left <= 0:
		_set_status("卡组已满，无法推荐补全")
		return
	var added: int = 0
	for c in picks:
		if added >= slots_left:
			break
		add_card_to_deck(c)
		added += 1
	if added == 0:
		_set_status("没找到合适的推荐卡片")
	else:
		_set_status("已推荐补全 %d 张" % added)
	_render_deck()
	_render_analysis()


func _on_clear_pressed() -> void:
	_remove_mode = false
	_current_deck = []
	_render_deck()
	_render_analysis()
	_set_status("已清空卡组")


func _on_deck_card_pressed(index: int) -> void:
	if not _remove_mode:
		return
	if index < 0 or index >= _current_deck.size():
		return
	var removed: Card = _current_deck[index]
	_current_deck.remove_at(index)
	_render_deck()
	_render_analysis()
	if removed != null:
		_set_status("已移除 [%s]" % removed.text)


func _on_review_pressed() -> void:
	if _pack == null:
		_set_status("内容包未加载，无法启动复习")
		return
	# Phase 4.2 简化：直接播放楼层 intro panels（如果有），算"复习预热"
	var panels: Array[CutscenePanel] = _pack.get_floor_intro_panels(_floor_id)
	if panels.is_empty():
		_set_status("本楼层暂无复习内容（Phase 3 接入后启用）")
		return
	if typeof(CutscenePlayer) == TYPE_NIL or CutscenePlayer == null:
		_set_status("CutscenePlayer 不可用")
		return
	CutscenePlayer.play("review_" + _floor_id, panels)


func _on_skip_review_pressed() -> void:
	if _review_section != null:
		_review_section.visible = false
	_set_status("已跳过复习")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(TOWER_GATE_SCENE)


func _on_launch_pressed() -> void:
	# 持久化 deck（覆盖第一个 template）
	_persist_deck()
	# 启动 RunState
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.start_floor(_floor_id, _pack)
		# 用玩家在备战界面里的最终卡组覆盖（start_floor 内会重置为 starting_deck）
		var typed_deck: Array[Card] = []
		for c in _current_deck:
			typed_deck.append(c)
		RunState.current_deck = typed_deck
	last_launched_floor_id = _floor_id
	if test_disable_scene_change:
		return
	# 切换到 RunMap 场景；如果还没落地则给提示
	if ResourceLoader.exists(RUN_MAP_SCENE):
		get_tree().change_scene_to_file(RUN_MAP_SCENE)
		return
	_set_status("[Phase 2.3 RunMap 场景待落地]")


# ───────────────────────────────────────────────────────────────────
# 卡组 helper（公共，供测试使用）
# ───────────────────────────────────────────────────────────────────

## 添加一张卡到当前卡组，遵守 deck_slot_max；返回是否成功
func add_card_to_deck(card: Card) -> bool:
	if card == null:
		return false
	if _current_deck.size() >= _deck_slot_max:
		return false
	_current_deck.append(card)
	return true


## 从当前卡组移除指定 index 的卡；返回是否成功
func remove_card_at(index: int) -> bool:
	if index < 0 or index >= _current_deck.size():
		return false
	_current_deck.remove_at(index)
	return true


func get_current_deck() -> Array[Card]:
	return _current_deck


func get_deck_slot_max() -> int:
	return _deck_slot_max


func set_floor_id(fid: String) -> void:
	_floor_id = fid
	_load_floor_config()
	_render_header()


# ───────────────────────────────────────────────────────────────────
# 内部
# ───────────────────────────────────────────────────────────────────

func _build_candidate_pool() -> Array[Card]:
	# 候选 = 已解锁卡 ∪ 起始卡池 ∪ 本层卡池，去重；排除当前卡组里已有的
	var seen: Dictionary = {}
	var have_ids: Dictionary = {}
	for c in _current_deck:
		if c != null:
			have_ids[c.id] = true
	var out: Array[Card] = []
	if _pack == null:
		return out

	var unlocked: Array[String] = _read_unlocked_card_ids()
	for cid in unlocked:
		if seen.has(cid) or have_ids.has(cid):
			continue
		var c: Card = _pack.get_card(cid)
		if c != null:
			seen[cid] = true
			out.append(c)

	for cid in _pack.get_starting_deck_card_ids():
		if seen.has(cid) or have_ids.has(cid):
			continue
		var c: Card = _pack.get_card(cid)
		if c != null:
			seen[cid] = true
			out.append(c)

	for c in _pack.get_card_pool_for_floor(_floor_id):
		if c == null:
			continue
		if seen.has(c.id) or have_ids.has(c.id):
			continue
		seen[c.id] = true
		out.append(c)

	return out


func _persist_deck() -> void:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return
	var ids: Array = []
	for c in _current_deck:
		if c != null:
			ids.append(c.id)
	var save: SaveSystem = GameState.save_system
	var state: Dictionary = save.load_game_state()
	var templates_v: Variant = state.get("deck_templates", [])
	var templates: Array = templates_v if templates_v is Array else []
	if templates.is_empty():
		templates.append({"name": "默认", "card_ids": ids})
	else:
		var first_v: Variant = templates[0]
		var first: Dictionary = first_v if first_v is Dictionary else {"name": "默认"}
		first["card_ids"] = ids
		templates[0] = first
	state["deck_templates"] = templates
	save.save_game_state(state)


func _set_status(t: String) -> void:
	if _status_label != null:
		_status_label.text = t


# ───────────────────────────────────────────────────────────────────
# 调试作弊工具（仅 DebugMode.enabled 时显示）
# ───────────────────────────────────────────────────────────────────

func _setup_debug_cheats() -> void:
	var dm: Node = _resolve_debug_mode_node()
	if dm == null:
		return
	if not dm.debug_toggled.is_connected(_on_debug_mode_toggled):
		dm.debug_toggled.connect(_on_debug_mode_toggled)
	_apply_debug_visibility(bool(dm.enabled))


func _resolve_debug_mode_node() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("DebugMode")


func _on_debug_mode_toggled(enabled: bool) -> void:
	_apply_debug_visibility(enabled)


func _apply_debug_visibility(enabled: bool) -> void:
	if not enabled:
		if _debug_row != null and is_instance_valid(_debug_row):
			_debug_row.visible = false
		if _header_label != null and _header_label.text.begins_with("[DEBUG] "):
			_header_label.text = _header_label.text.substr(len("[DEBUG] "))
		return
	# 在 header 前缀 [DEBUG]
	if _header_label != null and not _header_label.text.begins_with("[DEBUG] "):
		_header_label.text = "[DEBUG] " + _header_label.text
	# 创建作弊行（如尚未存在）
	if _debug_row == null or not is_instance_valid(_debug_row):
		_debug_row = _build_debug_row()
		if _debug_row != null:
			# 把它挂在 Footer 同级，紧邻 Footer 上方。
			var parent: Node = self
			parent.add_child(_debug_row)
			_debug_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			_debug_row.offset_top = -88
			_debug_row.offset_bottom = -52
			_debug_row.offset_left = 16
			_debug_row.offset_right = -16
	if _debug_row != null:
		_debug_row.visible = true


func _build_debug_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "DebugCheatRow"

	var hint: Label = Label.new()
	hint.text = "[DEBUG]"
	hint.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	row.add_child(hint)

	var crystal_btn: Button = Button.new()
	crystal_btn.text = "+1000 词晶"
	crystal_btn.pressed.connect(_on_debug_crystals_pressed)
	row.add_child(crystal_btn)

	var bp_btn: Button = Button.new()
	bp_btn.text = "+50 蓝图"
	bp_btn.pressed.connect(_on_debug_blueprints_pressed)
	row.add_child(bp_btn)

	var unlock_btn: Button = Button.new()
	unlock_btn.text = "解锁全部卡"
	unlock_btn.pressed.connect(_on_debug_unlock_all_pressed)
	row.add_child(unlock_btn)

	return row


func _on_debug_crystals_pressed() -> void:
	if typeof(GameState) == TYPE_NIL or GameState == null or GameState.save_system == null:
		_set_status("[DEBUG] SaveSystem 不可用")
		return
	GameState.save_system.add_crystals(1000)
	_set_status("[DEBUG] +1000 词晶 (当前 %d)"
		% int(GameState.save_system.get_wallet().get("crystals", 0)))


func _on_debug_blueprints_pressed() -> void:
	if typeof(GameState) == TYPE_NIL or GameState == null or GameState.save_system == null:
		_set_status("[DEBUG] SaveSystem 不可用")
		return
	GameState.save_system.add_blueprints(50)
	_set_status("[DEBUG] +50 蓝图 (当前 %d)"
		% int(GameState.save_system.get_wallet().get("blueprints", 0)))


func _on_debug_unlock_all_pressed() -> void:
	if _pack == null or typeof(GameState) == TYPE_NIL or GameState == null \
			or GameState.save_system == null:
		_set_status("[DEBUG] 内容包或 SaveSystem 不可用")
		return
	var count: int = 0
	for c in _pack.get_all_cards():
		if c == null:
			continue
		if not GameState.save_system.is_card_unlocked(c.id):
			GameState.save_system.unlock_card(c.id)
			count += 1
	_set_status("[DEBUG] 解锁 %d 张新卡（候选池已刷新）" % count)
