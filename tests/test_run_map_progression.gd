## test_run_map_progression — RunState Act 推进 + RunMapScene 渲染冒烟
##
## 夹具：每个 test before_each 重置 RunState.act_maps / nodes_visited /
##   current_act_index / current_floor_id；after_each 还原。
## 不依赖真实内容包，用手动构造的 RunMap / RunNode 对象作为测试数据。
extends GutTest

const RunMapScene := preload("res://src/run/run_map_scene.tscn")

# ─── 备份字段 ────────────────────────────────────────────────────────────────
var _bak_act_maps: Array[RunMap] = []
var _bak_nodes_visited: Array[String] = []
var _bak_act_index: int = 0
var _bak_floor_id: String = ""
var _bak_node_id: String = ""
var _bak_floor_config: Dictionary = {}

# 信号捕获
var _captured_act_index: int = -1


func before_each() -> void:
	if typeof(RunState) == TYPE_NIL:
		return
	_bak_act_maps      = RunState.act_maps.duplicate()
	_bak_nodes_visited = RunState.nodes_visited.duplicate()
	_bak_act_index     = RunState.current_act_index
	_bak_floor_id      = RunState.current_floor_id
	_bak_node_id       = RunState.current_node_id
	_bak_floor_config  = RunState.floor_config.duplicate(true)

	RunState.act_maps             = []
	RunState.nodes_visited        = []
	RunState.current_act_index    = 0
	RunState.current_floor_id     = ""
	RunState.current_node_id      = ""
	RunState.floor_config         = {}
	_captured_act_index           = -1


func after_each() -> void:
	if typeof(RunState) == TYPE_NIL:
		return
	RunState.act_maps             = _bak_act_maps
	RunState.nodes_visited        = _bak_nodes_visited
	RunState.current_act_index    = _bak_act_index
	RunState.current_floor_id     = _bak_floor_id
	RunState.current_node_id      = _bak_node_id
	RunState.floor_config         = _bak_floor_config


# ─── 辅助：构造最小 RunMap ─────────────────────────────────────────────────

func _make_simple_map(act_idx: int) -> RunMap:
	var m := RunMap.new()
	m.act_index = act_idx
	var n := RunNode.make("node_%d_0" % act_idx, "battle", 0, 0)
	m.nodes = [n]
	return m


func _on_act_advanced(new_act: int) -> void:
	_captured_act_index = new_act


# ═══════════════════════════════════════════════════════════════════
# 1. complete_node：已访问列表增加该 id
# ═══════════════════════════════════════════════════════════════════

func test_complete_node_marks_visited() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	var m := _make_simple_map(0)
	RunState.act_maps = [m]
	RunState.complete_node("node_0_0")
	assert_true("node_0_0" in RunState.nodes_visited,
		"nodes_visited should contain the completed node id")


# ═══════════════════════════════════════════════════════════════════
# 2. complete_node：重复调用不产生重复 id
# ═══════════════════════════════════════════════════════════════════

func test_complete_node_unique() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	RunState.complete_node("some_node")
	RunState.complete_node("some_node")
	RunState.complete_node("some_node")
	assert_eq(RunState.nodes_visited.size(), 1,
		"nodes_visited must deduplicate repeated complete_node calls")


# ═══════════════════════════════════════════════════════════════════
# 3. advance_to_next_act：current_act_index 递增
# ═══════════════════════════════════════════════════════════════════

func test_advance_act_increments_current_act_index() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	# act_maps 必须 >=2 以防止触发 settle_victory
	RunState.act_maps = [_make_simple_map(0), _make_simple_map(1)]
	RunState.current_act_index = 0
	RunState.advance_to_next_act()
	assert_eq(RunState.current_act_index, 1,
		"current_act_index should be 1 after advance_to_next_act")


# ═══════════════════════════════════════════════════════════════════
# 4. advance_to_next_act：发射 act_advanced 信号，payload = new_act_index
# ═══════════════════════════════════════════════════════════════════

func test_advance_act_emits_act_advanced_signal() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	# 3 个 act，从 index 0 推进到 1；信号应携带 1
	RunState.act_maps = [_make_simple_map(0), _make_simple_map(1), _make_simple_map(2)]
	RunState.current_act_index = 0
	RunState.act_advanced.connect(_on_act_advanced)
	RunState.advance_to_next_act()
	RunState.act_advanced.disconnect(_on_act_advanced)
	assert_eq(_captured_act_index, 1,
		"act_advanced signal payload must be new_act_index (1)")


# ═══════════════════════════════════════════════════════════════════
# 5. advance_past_last_act：触发 settle_victory（current_act_index >= size）
# ═══════════════════════════════════════════════════════════════════

func test_advance_past_last_act_triggers_settle_victory() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	# act_maps.size() = 2；从 index 1 推进 → index 2 >= 2 → settle_victory 被调用
	RunState.act_maps = [_make_simple_map(0), _make_simple_map(1)]
	RunState.current_act_index = 1
	RunState.current_floor_id  = ""  # 无 floor_id 避免写存档

	# 用 GUT watch_signals 捕获 run_settled 信号
	watch_signals(RunState)
	RunState.advance_to_next_act()

	assert_eq(RunState.current_act_index, 2,
		"current_act_index should be 2 after advancing past last act")
	assert_signal_emitted(RunState, "run_settled",
		"run_settled should have been emitted via settle_victory")


# ═══════════════════════════════════════════════════════════════════
# 6. get_current_map：返回 act_maps[current_act_index]
# ═══════════════════════════════════════════════════════════════════

func test_get_current_map_returns_correct_act() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	var m0 := _make_simple_map(0)
	var m1 := _make_simple_map(1)
	var m2 := _make_simple_map(2)
	RunState.act_maps = [m0, m1, m2]
	RunState.current_act_index = 1
	var got: RunMap = RunState.get_current_map()
	assert_eq(got, m1,
		"get_current_map() should return act_maps[current_act_index]")


# ═══════════════════════════════════════════════════════════════════
# 7. RunMapScene：instantiate 不崩溃
# ═══════════════════════════════════════════════════════════════════

func test_run_map_scene_instantiates_without_crash() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	# 给 RunState 一张 act map，避免 _refresh() 时 get_current_map() 返 null
	RunState.act_maps = [_make_simple_map(0)]
	RunState.current_act_index = 0

	var scene: Control = RunMapScene.instantiate()
	assert_not_null(scene, "RunMapScene should instantiate without error")
	add_child_autofree(scene)
	await get_tree().process_frame
	assert_not_null(scene, "RunMapScene should still be alive after one frame")


# ═══════════════════════════════════════════════════════════════════
# 8. RunNode.make 工厂：type == "battle" 的节点属性正确
# ═══════════════════════════════════════════════════════════════════

func test_run_node_battle_type_properties() -> void:
	var n := RunNode.make("1F-A1-battle-0", "battle", 0, 0)
	assert_eq(n.id,   "1F-A1-battle-0", "id mismatch")
	assert_eq(n.type, "battle",          "type should be 'battle'")
	assert_eq(n.row,  0,                 "row should be 0")
	assert_eq(n.col,  0,                 "col should be 0")
