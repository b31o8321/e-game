## SettlementScene — Run 结算（撤退或通关）
##
## 此场景仅显示结算结果。结算本身由 RunState.settle_victory() / settle_retreat()
## 完成（已经在击败最终 Boss 或玩家死亡时调用过）。
##
## 进入约定：
##   - 通关：advance_to_next_act() 跨过最后一 Act 后自动触发 settle_victory；camp_scene
##     在 advance 后切到本场景。
##   - 撤退：BattleResolver / EliteResolver 在判定玩家死亡时调用 settle_retreat 后切到本场景。
##
## 显示数据从 RunState 读取（即使 settle_* 已 reset 部分字段，本场景使用结算前的累加值
## —— 因此 RunState 在 settle 中保留了 crystals_collected / blueprints_collected /
## current_floor_id 等最终值，未清空）。
##
## 详见: docs/superpowers/specs/2026-05-04-run-structure-design.md
extends Control

const CITY_SCENE_PATH: String = "res://src/city/city_scene.tscn"
const RETREAT_CRYSTAL_RETENTION: float = 0.7

@onready var _title_label: Label = $TitleLabel
@onready var _summary_label: RichTextLabel = $SummaryPanel/SummaryLabel
@onready var _back_button: Button = $BackButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_render()
	_back_button.pressed.connect(_on_back_pressed)


func _render() -> void:
	var victory: bool = _infer_victory()
	if victory:
		_title_label.text = "★ 通关 ★"
	else:
		_title_label.text = "撤退"
	_summary_label.bbcode_enabled = true
	_summary_label.text = _build_summary(victory)


func _infer_victory() -> bool:
	# 简易判定：当前 act_index >= 总 act 数 = 通关
	if typeof(RunState) == TYPE_NIL:
		return false
	if RunState.act_maps.is_empty():
		# 没有地图（异常路径）→ 默认按撤退处理
		return false
	return RunState.current_act_index >= RunState.act_maps.size()


func _build_summary(victory: bool) -> String:
	var lines: Array[String] = []

	# 词晶
	var collected: int = 0
	if typeof(RunState) != TYPE_NIL:
		collected = RunState.crystals_collected
	if victory:
		lines.append("🔮 词晶: +%d (100%%)" % collected)
	else:
		var kept: int = int(floor(collected * RETREAT_CRYSTAL_RETENTION))
		lines.append("🔮 词晶: +%d  [color=#aaa](保留 %d%%；累计 %d)[/color]" % [
			kept,
			int(RETREAT_CRYSTAL_RETENTION * 100),
			collected,
		])

	# 蓝图
	var blueprints: int = 0
	if typeof(RunState) != TYPE_NIL:
		blueprints = RunState.blueprints_collected
	lines.append("🧩 蓝图: +%d  [color=#aaa](全保留)[/color]" % blueprints)

	# 图鉴
	var codex_count: int = _count_codex_unlocks_this_run()
	lines.append("📖 图鉴解锁: %d 项" % codex_count)

	# 装备
	var equip_text: String = _format_equipment()
	lines.append("🏆 装备: %s" % equip_text)

	# 三星挑战（仅通关展示）
	if victory:
		lines.append("⭐ 三星挑战: %s" % _format_three_star_status())

	# 学习数据：薄弱单词（来自 SRSSystem 全局统计；当前没有 per-run breakdown）
	var weak_section: String = _format_weak_cards()
	if weak_section != "":
		lines.append("")
		lines.append("[b]📊 学习数据[/b]")
		lines.append(weak_section)

	# 剧情提示
	lines.append("")
	if victory:
		lines.append("[i]通关感言：你掌握了这一层的精髓。[/i]")
	else:
		lines.append("[i]每次撤退都是新的成长。[/i]")
	return "\n".join(lines)


func _format_weak_cards() -> String:
	if typeof(GameState) == TYPE_NIL or GameState == null or GameState.srs_system == null:
		return ""
	var srs: SRSSystem = GameState.srs_system
	if not srs.has_weak_questions():
		return ""
	var ids: Array[String] = srs.get_weakest_card_ids(3)
	if ids.is_empty():
		return ""
	var labels: Array[String] = []
	var pack: ContentPackBase = null
	if GameState.content_loader != null:
		pack = GameState.content_loader.get_active_pack()
	for cid in ids:
		var label: String = cid
		if pack != null:
			var c: Card = pack.get_card(cid)
			if c != null and not c.text.is_empty():
				label = c.text
		labels.append(label)
	return "薄弱知识点: %s" % ", ".join(labels)


func _count_codex_unlocks_this_run() -> int:
	# MVP 占位：本局解锁数量在没有 RunState.codex_delta 之前难以精确计数；
	# 这里返回 0 避免误导。Phase 3 接入逐节点 codex 增量。
	return 0


func _format_equipment() -> String:
	if typeof(RunState) == TYPE_NIL or RunState.current_equipment.is_empty():
		return "（无）"
	var names: Array[String] = []
	for e in RunState.current_equipment:
		if e == null:
			continue
		if e is Resource and "name" in e:
			names.append(str(e.name))
		else:
			names.append(str(e))
	if names.is_empty():
		return "（无）"
	return ", ".join(names)


func _format_three_star_status() -> String:
	var floor_id: String = ""
	if typeof(RunState) != TYPE_NIL:
		floor_id = RunState.current_floor_id
	if floor_id == "":
		return "0/3"
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return "0/3"
	var state: Dictionary = GameState.save_system.load_game_state()
	var prog: Variant = state.get("three_star_progress", {})
	if not (prog is Dictionary):
		return "0/3"
	var stars: Variant = (prog as Dictionary).get(floor_id, [])
	if not (stars is Array):
		return "0/3"
	var arr: Array = stars
	var got: int = 0
	for v in arr:
		if bool(v):
			got += 1
	return "%d/3" % got


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(CITY_SCENE_PATH)
