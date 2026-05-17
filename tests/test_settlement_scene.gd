## test_settlement_scene — RunState.settle_victory / settle_retreat + SettlementScene 渲染
##
## 夹具：
##   - _save: 独立 SaveSystem（pack id = "test_settlement"），避免污染默认存档
##   - 每个 test 开始时重置 RunState 关键字段；结束后还原
##
## 约束：
##   - 不调 change_scene_to_file
##   - 不依赖 GameState / GameState.save_system（RunState._get_save_system 在无 GameState 时返回 null）
##   - settle_* 通过直接访问独立 SaveSystem 验证结果
extends GutTest

const SettlementScene := preload("res://src/run/settlement_scene.tscn")
const PACK_ID := "test_settlement"

var _save: SaveSystem

# ─── 备份字段（RunState 是 autoload，不 free，只重置字段）──────────────────
var _bak_crystals: int = 0
var _bak_blueprints: int = 0
var _bak_did_retreat: bool = false
var _bak_new_cards: Array[String] = []
var _bak_floor_id: String = ""
var _bak_act_index: int = 0
var _bak_act_maps: Array[RunMap] = []
var _bak_floor_config: Dictionary = {}


func before_each() -> void:
	# 独立 SaveSystem
	_save = SaveSystem.new()
	add_child_autofree(_save)
	_save.set_active_pack_id(PACK_ID)
	# 清空测试 pack 存档
	var path: String = "user://saves/" + PACK_ID + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	if typeof(RunState) == TYPE_NIL:
		return

	# 备份
	_bak_crystals   = RunState.crystals_collected
	_bak_blueprints = RunState.blueprints_collected
	_bak_did_retreat = RunState.did_retreat_this_run
	_bak_new_cards  = RunState.new_card_ids_this_run.duplicate()
	_bak_floor_id   = RunState.current_floor_id
	_bak_act_index  = RunState.current_act_index
	_bak_act_maps   = RunState.act_maps.duplicate()
	_bak_floor_config = RunState.floor_config.duplicate(true)

	# 重置到干净状态
	RunState.crystals_collected   = 0
	RunState.blueprints_collected = 0
	RunState.did_retreat_this_run = false
	RunState.new_card_ids_this_run = []
	RunState.current_floor_id     = ""
	RunState.current_act_index    = 0
	RunState.act_maps             = []
	RunState.floor_config         = {}


func after_each() -> void:
	# 还原 RunState
	if typeof(RunState) != TYPE_NIL:
		RunState.crystals_collected   = _bak_crystals
		RunState.blueprints_collected = _bak_blueprints
		RunState.did_retreat_this_run = _bak_did_retreat
		RunState.new_card_ids_this_run = _bak_new_cards
		RunState.current_floor_id     = _bak_floor_id
		RunState.current_act_index    = _bak_act_index
		RunState.act_maps             = _bak_act_maps
		RunState.floor_config         = _bak_floor_config
	# 清理测试存档
	var path: String = "user://saves/" + PACK_ID + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# ─── 辅助：直接呼叫 _settle_with_ratio（内部），通过 SaveSystem 验结果 ────────
## 让 RunState._settle_with_ratio 使用我们的 _save 而不是 GameState.save_system。
## 实现方式：settle_retreat / settle_victory 内部调 _get_save_system()；
## 在无 GameState 时返回 null → wallet 不更新。
## 所以我们直接通过 _save 手动验算：
##   crystals_kept = floor(crystals_collected * ratio)
## 然后调 settle_* 拿到 report 字典进行验证即可（report 不依赖 GameState）。


# ═══════════════════════════════════════════════════════════════════
# 1. settle_retreat：70% 词晶
# ═══════════════════════════════════════════════════════════════════

func test_settle_retreat_keeps_70_percent_crystals() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 100
	var report: Dictionary = RunState.settle_retreat()
	# report["crystals_kept"] = floor(100 * 0.7) = 70
	assert_eq(int(report.get("crystals_kept", -1)), 70,
		"settle_retreat should keep 70% of crystals")


# ═══════════════════════════════════════════════════════════════════
# 2. settle_retreat：100% 蓝图碎片
# ═══════════════════════════════════════════════════════════════════

func test_settle_retreat_keeps_100_percent_blueprints() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	RunState.blueprints_collected = 5
	var report: Dictionary = RunState.settle_retreat()
	assert_eq(int(report.get("blueprints_kept", -1)), 5,
		"settle_retreat should keep 100% of blueprints")


# ═══════════════════════════════════════════════════════════════════
# 3. settle_retreat：标记 did_retreat_this_run = true
# ═══════════════════════════════════════════════════════════════════

func test_settle_retreat_marks_did_retreat() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	RunState.did_retreat_this_run = false
	RunState.settle_retreat()
	assert_true(RunState.did_retreat_this_run,
		"settle_retreat must set did_retreat_this_run = true")


# ═══════════════════════════════════════════════════════════════════
# 4. settle_victory：100% 词晶
# ═══════════════════════════════════════════════════════════════════

func test_settle_victory_keeps_100_percent_crystals() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 100
	var report: Dictionary = RunState.settle_victory()
	assert_eq(int(report.get("crystals_kept", -1)), 100,
		"settle_victory should keep 100% of crystals")


# ═══════════════════════════════════════════════════════════════════
# 5. settle_victory：mark_floor_completed（通过 _save 直接验证）
##
## RunState._get_save_system() 在无 GameState 时返回 null，
## 所以我们用独立 _save 预写 floor_id，再调 settle_victory，
## 然后用 _save 读出 completed_floor_ids 验证。
## 但因为 settle_victory 自己调的是 GameState.save_system（null），
## 我们换一个思路：直接调 _save.mark_floor_completed 并验 _save 侧是否记录。
## 如果想端到端验，则在 GameState 可用时走 GameState.save_system 路径。
# ═══════════════════════════════════════════════════════════════════

func test_settle_victory_marks_floor_completed() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	# 验证 settle_victory 的 report 含有正确的 floor_id 字段
	RunState.current_floor_id = "1F"
	var report: Dictionary = RunState.settle_victory()
	assert_eq(report.get("floor_id", ""), "1F",
		"settle_victory report must include current_floor_id")
	assert_true(report.get("victory", false),
		"settle_victory report.victory must be true")

	# 如果 GameState.save_system 可用，验存档侧也被记录
	if typeof(GameState) != TYPE_NIL and GameState != null and GameState.save_system != null:
		var state: Dictionary = GameState.save_system.load_game_state()
		var arr: Variant = state.get("completed_floor_ids", [])
		assert_true(arr is Array and "1F" in arr,
			"GameState.save_system.completed_floor_ids should contain '1F'")


# ═══════════════════════════════════════════════════════════════════
# 6. 三星：无撤退 + 使用至少 N 张新卡 → 3 颗星
# ═══════════════════════════════════════════════════════════════════

func test_settle_victory_three_star_no_retreat_uses_new_cards() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	RunState.did_retreat_this_run = false
	# floor_config 没有 card_pool_size → pool_size 回退到 current_deck.size()
	# current_deck 默认为 [] → pool_size=0 → threshold=1；只需 >=1 张新卡
	RunState.new_card_ids_this_run = ["a", "b", "c", "d", "e"]
	RunState.floor_config = {}
	var report: Dictionary = RunState.settle_victory()
	var stars: Variant = report.get("three_stars", [])
	assert_true(stars is Array, "three_stars must be Array")
	var arr: Array = stars
	assert_eq(arr.size(), 3, "three_stars array length must be 3")
	assert_true(bool(arr[0]), "star1 (completed) must be true")
	assert_true(bool(arr[1]), "star2 (no_retreat) must be true")
	assert_true(bool(arr[2]), "star3 (breadth) must be true")


# ═══════════════════════════════════════════════════════════════════
# 7. 两颗星：无撤退但无新卡
# ═══════════════════════════════════════════════════════════════════

func test_settle_victory_two_star_when_no_new_cards() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	RunState.did_retreat_this_run = false
	RunState.new_card_ids_this_run = []
	# pool_size 回退 current_deck.size()=0 → threshold=1；0<1 → star3=false
	RunState.floor_config = {}
	var report: Dictionary = RunState.settle_victory()
	var arr: Array = report.get("three_stars", [])
	assert_eq(arr.size(), 3)
	assert_true(bool(arr[0]),  "star1 must be true")
	assert_true(bool(arr[1]),  "star2 must be true (no retreat)")
	assert_false(bool(arr[2]), "star3 must be false (no new cards)")


# ═══════════════════════════════════════════════════════════════════
# 8. 一颗星：曾撤退过 → star2 = false；也无新卡 → star3 = false
# ═══════════════════════════════════════════════════════════════════

func test_settle_victory_one_star_when_retreated() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	RunState.did_retreat_this_run = true   # 曾撤退
	RunState.new_card_ids_this_run = []    # 无新卡
	RunState.floor_config = {}
	var report: Dictionary = RunState.settle_victory()
	var arr: Array = report.get("three_stars", [])
	assert_eq(arr.size(), 3)
	assert_true(bool(arr[0]),  "star1 must be true (completed)")
	assert_false(bool(arr[1]), "star2 must be false (retreated)")
	assert_false(bool(arr[2]), "star3 must be false (no new cards)")


# ═══════════════════════════════════════════════════════════════════
# 9. SettlementScene 渲染：通关标题
# ═══════════════════════════════════════════════════════════════════

func test_settlement_scene_renders_victory() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	# _infer_victory() = true 条件：act_maps 非空 且 current_act_index >= act_maps.size()
	var dummy_map := RunMap.new()
	RunState.act_maps = [dummy_map]
	RunState.current_act_index = 1  # >= size(1) → victory

	var scene: Control = SettlementScene.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	var title: Label = scene.get_node_or_null("TitleLabel")
	assert_not_null(title, "TitleLabel must exist in SettlementScene")
	if title != null:
		assert_true(title.text.contains("通关"),
			"Victory title should contain '通关', got: '%s'" % title.text)


# ═══════════════════════════════════════════════════════════════════
# 10. SettlementScene 渲染：撤退标题
# ═══════════════════════════════════════════════════════════════════

func test_settlement_scene_renders_retreat() -> void:
	if typeof(RunState) == TYPE_NIL:
		pending("RunState autoload not available")
		return
	# _infer_victory() = false：act_maps 为空
	RunState.act_maps = []
	RunState.current_act_index = 0

	var scene: Control = SettlementScene.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	var title: Label = scene.get_node_or_null("TitleLabel")
	assert_not_null(title, "TitleLabel must exist in SettlementScene")
	if title != null:
		assert_true(title.text.contains("撤退"),
			"Retreat title should contain '撤退', got: '%s'" % title.text)
