## RunMapScene — 路径地图 UI
##
## 职责：
##   - 渲染 RunState.get_current_map() 的 nodes + connections
##   - 标记 visited / current / reachable / unreachable 四种状态
##   - 玩家点击可达节点 → 调用对应 NodeResolver
##   - 顶部 HUD 显示 Act / 词晶 / HP
##
## 详见: docs/superpowers/specs/2026-05-04-run-structure-design.md
extends Control


const NODE_BTN_SIZE: Vector2 = Vector2(72, 72)
const ROW_HEIGHT: float = 110.0
const COL_WIDTH: float = 220.0


@onready var header_label: Label = $Header/HeaderLabel
@onready var map_root: Control = $MapRoot
@onready var nodes_layer: Control = $MapRoot/NodesLayer
@onready var lines_layer: Control = $MapRoot/LinesLayer
@onready var retreat_button: Button = get_node_or_null("BottomBar/RetreatButton")

const SETTLEMENT_SCENE: String = "res://src/run/settlement_scene.tscn"

var _node_buttons: Dictionary = {}    # node_id -> Button


func _ready() -> void:
	if retreat_button != null:
		retreat_button.pressed.connect(_on_retreat_pressed)
	# Refresh map whenever a node finishes resolving (mystery/shop/rest dialogs are async).
	if typeof(RunState) != TYPE_NIL and RunState != null:
		if not RunState.node_completed.is_connected(_on_node_completed):
			RunState.node_completed.connect(_on_node_completed)
	_refresh()


func _on_node_completed(_node_id: String, _ntype: String) -> void:
	_refresh()


func _on_retreat_pressed() -> void:
	# Settle and route to settlement; keeps 70% crystals + 100% blueprints.
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.settle_retreat()
	get_tree().change_scene_to_file(SETTLEMENT_SCENE)


func _refresh() -> void:
	_clear()
	_render_header()
	var rmap: RunMap = RunState.get_current_map() if typeof(RunState) != TYPE_NIL else null
	if rmap == null:
		return
	_render_nodes(rmap)
	_render_connections(rmap)


func _clear() -> void:
	for child in nodes_layer.get_children():
		child.queue_free()
	for child in lines_layer.get_children():
		child.queue_free()
	_node_buttons.clear()


func _render_header() -> void:
	if header_label == null or typeof(RunState) == TYPE_NIL:
		return
	header_label.text = "Act %d  ·  词晶 %d  ·  HP %d/%d" % [
		RunState.current_act_index + 1,
		RunState.crystals_collected,
		RunState.player_hp,
		RunState.player_max_hp,
	]


func _render_nodes(rmap: RunMap) -> void:
	var row_count: int = rmap.get_row_count()
	var rect_size: Vector2 = nodes_layer.size
	if rect_size.x <= 0 or rect_size.y <= 0:
		rect_size = Vector2(900, 500)
	for n in rmap.nodes:
		var btn := Button.new()
		btn.text = _icon_for_type(n.type)
		btn.tooltip_text = "[%s] %s" % [n.type, n.id]
		btn.custom_minimum_size = NODE_BTN_SIZE
		btn.size = NODE_BTN_SIZE
		var pos: Vector2 = _grid_to_pos(n.row, n.col, row_count, rect_size)
		btn.position = pos - NODE_BTN_SIZE * 0.5
		btn.pressed.connect(_on_node_pressed.bind(n.id))
		_apply_visual_state(btn, n)
		nodes_layer.add_child(btn)
		_node_buttons[n.id] = btn


func _render_connections(rmap: RunMap) -> void:
	var row_count: int = rmap.get_row_count()
	var rect_size: Vector2 = nodes_layer.size
	if rect_size.x <= 0 or rect_size.y <= 0:
		rect_size = Vector2(900, 500)
	for src_id in rmap.connections.keys():
		var src: RunNode = rmap.get_node_by_id(src_id)
		if src == null:
			continue
		var src_pos: Vector2 = _grid_to_pos(src.row, src.col, row_count, rect_size)
		for dst_id in rmap.get_next_reachable(src_id):
			var dst: RunNode = rmap.get_node_by_id(dst_id)
			if dst == null:
				continue
			var dst_pos: Vector2 = _grid_to_pos(dst.row, dst.col, row_count, rect_size)
			var line := Line2D.new()
			line.add_point(src_pos)
			line.add_point(dst_pos)
			line.width = 2.0
			line.default_color = Color(0.5, 0.6, 0.8, 0.6)
			lines_layer.add_child(line)


func _grid_to_pos(row: int, col: int, row_count: int, rect_size: Vector2) -> Vector2:
	# row 0 在底部，最大 row 在顶部（让 Boss 在最上方）
	var inv_row: int = (row_count - 1) - row
	var x: float = rect_size.x * 0.5 + (col - 1) * COL_WIDTH
	var y: float = 80.0 + inv_row * ROW_HEIGHT
	return Vector2(x, y)


func _icon_for_type(t: String) -> String:
	match t:
		"battle": return "🗡"
		"elite": return "💀"
		"shop": return "💰"
		"rest": return "🔥"
		"puzzle": return "📜"
		"mystery": return "❓"
		"boss": return "👑"
		_: return "?"


func _apply_visual_state(btn: Button, n: RunNode) -> void:
	var state: String = _state_for(n)
	match state:
		"visited":
			btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
			btn.disabled = true
		"current":
			btn.modulate = Color(1.0, 0.95, 0.4, 1.0)
			btn.disabled = true
		"reachable":
			btn.modulate = Color(0.6, 0.8, 1.0, 1.0)
			btn.disabled = false
		"unreachable":
			btn.modulate = Color(1.0, 1.0, 1.0, 0.35)
			btn.disabled = true
		_:
			btn.disabled = false


func _state_for(n: RunNode) -> String:
	if n.id in RunState.nodes_visited:
		return "visited"
	if n.id == RunState.current_node_id and n.id in RunState.nodes_visited:
		return "current"
	# 当 current_node_id 为空 → 起始排可点
	var rmap: RunMap = RunState.get_current_map()
	if rmap == null:
		return "unreachable"
	if RunState.current_node_id == "":
		# 起点：所有 row==0 的节点都 reachable
		if n.row == 0:
			return "reachable"
		return "unreachable"
	# 其他情况：上一节点的 connections 决定
	var allowed: Array[String] = rmap.get_next_reachable(RunState.current_node_id)
	if n.id in allowed:
		return "reachable"
	return "unreachable"


func _on_node_pressed(node_id: String) -> void:
	var rmap: RunMap = RunState.get_current_map()
	if rmap == null:
		return
	var n: RunNode = rmap.get_node_by_id(node_id)
	if n == null:
		return
	RunState.enter_node(node_id)
	_dispatch(n)
	_refresh()


func _dispatch(n: RunNode) -> void:
	var pack: ContentPackBase = null
	if typeof(GameState) != TYPE_NIL and GameState.content_loader != null:
		pack = GameState.content_loader.get_active_pack()
	match n.type:
		"battle":
			BattleResolver.resolve(n, pack, get_tree())
		"elite":
			EliteResolver.resolve(n, pack, get_tree())
		"shop":
			ShopResolver.resolve(n, pack, self)
		"rest":
			RestResolver.resolve(n, self)
		"mystery":
			MysteryResolver.resolve(n, self)
		"puzzle":
			PuzzleResolver.resolve(n, pack, get_tree())
		"boss":
			BossResolver.resolve(n, pack, get_tree())
		_:
			push_warning("[RunMapScene] unknown node type: %s" % n.type)
