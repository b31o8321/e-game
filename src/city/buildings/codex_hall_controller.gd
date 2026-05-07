## CodexHallController — 图鉴馆子场景
##
## Phase 2.7 MVP：3 个 tab（卡片 / 敌人 / 剧情碎片）。
## 数据来自：
##   - SaveSystem.codex.discovered_cards
##   - SaveSystem.codex.defeated_enemies
##   - LoreCodexSystem.get_all_unlocked()
##
## 未发现的卡 / 敌人显示 "?"，已发现的显示 ID（Phase 3 再接入名称 + 立绘）。
## 剧情碎片改用 ContentPackBase.get_lore_title 显示友好名称；
## 双击或激活某条 → ContentPackBase.get_panels_containing_lore() 重播整段。
##
## TODO Phase 3：从 ContentPackBase 拉显示名 / 立绘 / 例句等。
## TODO Phase 4：Boss 图鉴 / 装备图鉴 / 剧情图鉴完整版。
##
## 详见: docs/superpowers/specs/2026-05-04-knowledge-city-design.md
extends Control

const CITY_SCENE_PATH: String = "res://src/city/city_scene.tscn"

var _pack: ContentPackBase = null
## 行号 → lore_id 映射；用于点击 ItemList 项时反查
var _lore_row_to_id: Array[String] = []

@onready var _back_button: Button = $Header/BackButton
@onready var _cards_header: Label = $Tabs/卡片/CardsHeader
@onready var _cards_list: ItemList = $Tabs/卡片/CardsList
@onready var _enemies_header: Label = $Tabs/敌人/EnemiesHeader
@onready var _enemies_list: ItemList = $Tabs/敌人/EnemiesList
@onready var _lore_header: Label = $Tabs/剧情碎片/LoreHeader
@onready var _lore_list: ItemList = $Tabs/剧情碎片/LoreList


func _ready() -> void:
	_resolve_pack()
	_back_button.pressed.connect(_on_back_pressed)
	_lore_list.item_activated.connect(_on_lore_item_activated)
	_render_cards()
	_render_enemies()
	_render_lore()


func _resolve_pack() -> void:
	if typeof(GameState) == TYPE_NIL or GameState.content_loader == null:
		return
	_pack = GameState.content_loader.get_active_pack()


func _read_codex() -> Dictionary:
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		return {}
	var state: Dictionary = GameState.save_system.load_game_state()
	var codex: Variant = state.get("codex", {})
	return codex if codex is Dictionary else {}


func _render_cards() -> void:
	_cards_list.clear()
	var codex: Dictionary = _read_codex()
	var arr: Variant = codex.get("discovered_cards", [])
	var discovered: Array = arr if arr is Array else []
	_cards_header.text = "已发现卡片：%d" % discovered.size()
	if discovered.is_empty():
		_cards_list.add_item("? (尚未发现任何卡)")
		return
	for cid in discovered:
		var label: String = str(cid)
		if _pack != null:
			var c: Card = _pack.get_card(str(cid))
			if c != null and not c.text.is_empty():
				label = "%s — %s" % [c.text, str(cid)]
		_cards_list.add_item(label)


func _render_enemies() -> void:
	_enemies_list.clear()
	var codex: Dictionary = _read_codex()
	var arr: Variant = codex.get("defeated_enemies", [])
	var defeated: Array = arr if arr is Array else []
	_enemies_header.text = "已击败敌人：%d" % defeated.size()
	if defeated.is_empty():
		_enemies_list.add_item("? (还没击败任何敌人)")
		return
	for eid in defeated:
		var label: String = str(eid)
		if _pack != null:
			var e: EnemyData = _pack.get_enemy(str(eid))
			if e != null and not e.enemy_name.is_empty():
				label = e.enemy_name
		_enemies_list.add_item(label)


func _render_lore() -> void:
	_lore_list.clear()
	_lore_row_to_id.clear()
	var unlocked: Array[String] = []
	if LoreCodexSystem != null:
		unlocked = LoreCodexSystem.get_all_unlocked()
	# 稳定排序：按友好标题字母序，方便玩家定位
	var sorted_ids: Array[String] = unlocked.duplicate()
	sorted_ids.sort_custom(func(a: String, b: String) -> bool:
		return _lore_title_for(a) < _lore_title_for(b)
	)
	_lore_header.text = "已解锁剧情：%d" % sorted_ids.size()
	if sorted_ids.is_empty():
		_lore_list.add_item("? (还没解锁任何剧情)")
		return
	for lid in sorted_ids:
		_lore_list.add_item(_lore_title_for(lid))
		_lore_row_to_id.append(lid)


func _lore_title_for(lore_id: String) -> String:
	if _pack != null:
		var t: String = _pack.get_lore_title(lore_id)
		if t != "":
			return t
	return lore_id


func _on_lore_item_activated(index: int) -> void:
	# 双击 lore 条目 → 重播包含它的整段剧情
	if _pack == null or CutscenePlayer == null:
		return
	if index < 0 or index >= _lore_row_to_id.size():
		return
	var lid: String = _lore_row_to_id[index]
	var panels: Array[CutscenePanel] = _pack.get_panels_containing_lore(lid)
	if panels.is_empty():
		push_warning("[CodexHall] no panels found for lore_id: %s" % lid)
		return
	CutscenePlayer.play("codex_replay_" + lid, panels)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(CITY_SCENE_PATH)
