## RunState — 当前 Run 全局状态（autoload）
##
## 与 GameState 协同：GameState 持有跨 Run 的玩家状态（永久仓库、解锁进度），
## RunState 只持有当前一局的临时数据（act 进度、词晶/碎片累加器、临时牌组）。
##
## TODO(autoload): 在 project.godot [autoload] 段注册：
##   RunState="*res://src/run/run_state.gd"
##
## 详见: docs/superpowers/specs/2026-05-04-run-structure-design.md
extends Node

# ─── 当前楼层 / Act 进度 ───────────────────────────────────────────
var current_floor_id: String = ""
var current_act_index: int = 0          # 0-based
var current_node_index: int = 0          # 当前已抵达的节点位置（仅 UI/调试用）
var current_node_id: String = ""         # 玩家最近进入的节点 ID

# ─── 备战阶段（pre-run setup）──────────────────────────────────────
## 玩家在 TowerGate 选好楼层但还没进入 Run 时的过渡变量。
## TowerGateController 在切到 PreRunSetupScene 前写入；
## PreRunSetupController 在 _ready() 时读取并展示对应楼层信息。
var pending_floor_id: String = ""

# ─── 局内累加器（撤退/通关时按比例结算到 SaveSystem.wallet）───────
var crystals_collected: int = 0
var blueprints_collected: int = 0

# ─── 局内牌组与装备（撤退时全部丢弃）─────────────────────────────
var current_deck: Array[Card] = []
var current_equipment: Array = []           # Equipment 类未实现，先用 Array
var current_spices: Array[String] = []      # Spice IDs

# ─── 遗物（Run 内持有，撤退时丢弃）──────────────────────────────
var equipped_relics: Array[Relic] = []

# ─── 玩家 HP（局内可被 rest 节点回血）────────────────────────────
var player_hp: int = 100
var player_max_hp: int = 100

# ─── Boon 临时加成（每回合开始消耗后重置）──────────────────────────
var ap_bonus_next_turn: int = 0

# ─── 已访问节点（防止重复进入同一节点）────────────────────────────
var nodes_visited: Array[String] = []

# ─── 反舒适区：本 Run 内首次使用过的卡 ID 集合 ─────────────────────
## 战斗 BattleController 在每场战斗结算时把当局首次使用的卡 ID 报给 RunState；
## 三星结算时统计本 Run 用过的"新卡"数量（第三颗星条件）。
var new_card_ids_this_run: Array[String] = []
## 本 Run 是否曾撤退过（用于第二颗星判定）。即便最终胜利，只要触发过
## settle_retreat 一次就视为撤退过。
var did_retreat_this_run: bool = false

# ─── 三幕地图（由 RunMapGenerator 生成）──────────────────────────
var act_maps: Array[RunMap] = []

# ─── 当前楼层完整配置（来自 ContentPackBase.get_floor_config）─────
var floor_config: Dictionary = {}

# ─── 信号 ──────────────────────────────────────────────────────────
signal floor_started(floor_id: String)
signal node_entered(node_id: String, type: String)
signal node_completed(node_id: String, type: String)
signal act_advanced(new_act: int)
signal run_settled(victory: bool)


# ═══════════════════════════════════════════════════════════════════
# 生命周期 / 启动
# ═══════════════════════════════════════════════════════════════════

## 启动新 Run：加载 floor_config + 生成三幕地图
func start_floor(floor_id: String, pack: ContentPackBase) -> void:
	current_floor_id = floor_id
	current_act_index = 0
	current_node_index = 0
	current_node_id = ""
	crystals_collected = 0
	blueprints_collected = 0
	current_deck = []
	current_equipment = []
	current_spices = []
	equipped_relics = []
	nodes_visited = []
	new_card_ids_this_run = []
	did_retreat_this_run = false
	act_maps = []
	ap_bonus_next_turn = 0

	if pack == null:
		push_warning("[RunState] start_floor called with null pack")
		floor_config = {}
		floor_started.emit(floor_id)
		return

	floor_config = pack.get_floor_config(floor_id)
	if floor_config.is_empty():
		# 内容包没实现 / 没该楼层；提供合理默认让流程不至于完全跑不通
		push_warning("[RunState] floor_config empty for %s; using default skeleton" % floor_id)
		floor_config = _default_floor_skeleton(floor_id)

	# 起手牌组：优先按楼层定制（解决"题目与手卡不对应"）；
	# 子类未实现 get_starting_deck_for_floor 时基类回退到 get_starting_deck_card_ids。
	var starting_ids: Array[String] = []
	if pack != null:
		starting_ids = pack.get_starting_deck_for_floor(floor_id)
		if starting_ids.is_empty():
			starting_ids = pack.get_starting_deck_card_ids()
	for cid in starting_ids:
		var c: Card = pack.get_card(cid)
		if c != null:
			current_deck.append(c)

	# 玩家 HP
	player_max_hp = int(floor_config.get("player_starting_hp", 100))
	player_hp = player_max_hp

	# 生成三幕地图
	var acts_in: Variant = floor_config.get("acts", [])
	var acts: Array = acts_in if acts_in is Array else []
	for i in acts.size():
		var act_cfg_in: Variant = acts[i]
		var act_cfg: Dictionary = act_cfg_in if act_cfg_in is Dictionary else {}
		var gen_cfg: Dictionary = act_cfg.duplicate()
		gen_cfg["act_index"] = i
		gen_cfg["floor_id"] = floor_id
		var run_map: RunMap = RunMapGenerator.generate(gen_cfg)
		act_maps.append(run_map)

	floor_started.emit(floor_id)


## 内置默认骨架：仅在内容包未实现 get_floor_config 时使用，
## 让 Phase 2 各模块独立可测。
func _default_floor_skeleton(floor_id: String) -> Dictionary:
	return {
		"floor_id": floor_id,
		"unit_name": floor_id,
		"recommended_run_minutes": 18,
		"player_starting_hp": 100,
		"acts": [
			{
				"act_index": 1, "sub_topic_id": "topic_a", "node_count": 6,
				"node_distribution": {"battle": 3, "elite": 1, "shop": 1, "rest": 0, "puzzle": 1, "mystery": 0},
				"boss_id": "boss_a",
			},
			{
				"act_index": 2, "sub_topic_id": "topic_b", "node_count": 7,
				"node_distribution": {"battle": 3, "elite": 1, "shop": 1, "rest": 1, "puzzle": 0, "mystery": 1},
				"boss_id": "boss_b",
			},
			{
				"act_index": 3, "sub_topic_id": "topic_c", "node_count": 8,
				"node_distribution": {"battle": 4, "elite": 1, "shop": 1, "rest": 1, "puzzle": 1, "mystery": 0},
				"boss_id": "boss_c",
			},
		],
	}


# ═══════════════════════════════════════════════════════════════════
# 节点进入 / 完成
# ═══════════════════════════════════════════════════════════════════

func get_current_map() -> RunMap:
	if current_act_index < 0 or current_act_index >= act_maps.size():
		return null
	return act_maps[current_act_index]


func enter_node(node_id: String) -> void:
	current_node_id = node_id
	var rmap: RunMap = get_current_map()
	if rmap != null:
		var n: RunNode = rmap.get_node_by_id(node_id)
		if n != null:
			node_entered.emit(node_id, n.type)
			return
	node_entered.emit(node_id, "")


func complete_node(node_id: String) -> void:
	if not node_id in nodes_visited:
		nodes_visited.append(node_id)
	var rmap: RunMap = get_current_map()
	var ntype: String = ""
	if rmap != null:
		var n: RunNode = rmap.get_node_by_id(node_id)
		if n != null:
			ntype = n.type
	node_completed.emit(node_id, ntype)


## 进入下一 Act（Boss 战胜利后调用）
func advance_to_next_act() -> void:
	current_act_index += 1
	current_node_index = 0
	current_node_id = ""
	if current_act_index >= act_maps.size():
		# 所有 Act 都已完成 → 通关
		settle_victory()
		return
	act_advanced.emit(current_act_index)


# ═══════════════════════════════════════════════════════════════════
# 资源累计 / 战利品（局内）
# ═══════════════════════════════════════════════════════════════════

func add_crystals(amount: int) -> void:
	if amount > 0:
		crystals_collected += amount


func add_blueprints(amount: int) -> void:
	if amount > 0:
		blueprints_collected += amount


func add_card_to_deck(card: Card) -> void:
	if card != null:
		current_deck.append(card)


# ─── 遗物 API ──────────────────────────────────────────────────────

## 装备遗物；同一遗物重复装备返回 false，成功返回 true。
func add_relic(relic: Relic) -> bool:
	if relic == null:
		return false
	for r in equipped_relics:
		if r.id == relic.id:
			return false
	equipped_relics.append(relic)
	return true


## 检查是否已装备指定 id 的遗物。
func has_relic(relic_id: String) -> bool:
	for r in equipped_relics:
		if r.id == relic_id:
			return true
	return false


## 合计所有已装备遗物中 effect_type 匹配的 magnitude 之和。
func get_relic_total_magnitude(effect_type: String) -> int:
	var total: int = 0
	for r in equipped_relics:
		if r.effect_type == effect_type:
			total += r.magnitude
	return total


## 反舒适区：BattleController 战斗结算时上报本场新用卡。
## 仅当 card_id 未在本 Run 内被使用过时记入 new_card_ids_this_run，
## 返回本批次中真正"新"的 ID（用于即时弹窗 + 词晶奖励）。
func record_cards_used(card_ids: Array) -> Array[String]:
	var new_ids: Array[String] = []
	for raw in card_ids:
		var cid: String = str(raw)
		if cid == "":
			continue
		if cid in new_card_ids_this_run:
			continue
		new_card_ids_this_run.append(cid)
		new_ids.append(cid)
	return new_ids


## 当玩家在 Run 中触发撤退（settle_retreat 之外的路径，例如战败）
## 也可调用此函数显式标记。
func mark_retreated() -> void:
	did_retreat_this_run = true


func heal(amount: int) -> void:
	player_hp = min(player_max_hp, player_hp + amount)


func heal_percent(pct: float) -> void:
	heal(int(player_max_hp * pct))


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	player_hp = max(0, player_hp - amount)


# ═══════════════════════════════════════════════════════════════════
# 结算
# ═══════════════════════════════════════════════════════════════════

## 通关结算：100% 词晶 + 100% 蓝图碎片 → SaveSystem。
## 同时计算三星：⭐ 通关 / ⭐⭐ 不撤退 / ⭐⭐⭐ 用至少 N 张新卡（N = 楼层卡池 30%）
func settle_victory() -> Dictionary:
	var report: Dictionary = _settle_with_ratio(1.0, 1.0, true)
	var stars: Array = _compute_three_stars()
	report["three_stars"] = stars
	report["new_cards_used"] = new_card_ids_this_run.size()
	if current_floor_id != "":
		var save: SaveSystem = _get_save_system()
		if save != null:
			save.mark_floor_completed(current_floor_id)
			save.set_three_star(current_floor_id, stars)
			save.flush_save()
	run_settled.emit(true)
	return report


## 撤退结算：70% 词晶 + 100% 蓝图碎片 → SaveSystem
func settle_retreat() -> Dictionary:
	did_retreat_this_run = true
	var report: Dictionary = _settle_with_ratio(0.7, 1.0, false)
	run_settled.emit(false)
	return report


## 计算三星 [completed, no_retreat, breadth]。
## breadth 阈值 N = floor.card_pool_size * 0.3（floor_config 中无字段时按 starting deck 估算）。
func _compute_three_stars() -> Array:
	var star1: bool = true   # 走到 settle_victory 即视为通关
	var star2: bool = not did_retreat_this_run
	var pool_size: int = int(floor_config.get("card_pool_size", 0))
	if pool_size <= 0:
		# 兜底：用起始牌组大小推算 → 至少 1 张新卡才能拿星
		pool_size = current_deck.size()
	var threshold: int = int(ceil(float(pool_size) * 0.3))
	if threshold < 1:
		threshold = 1
	var star3: bool = new_card_ids_this_run.size() >= threshold
	return [star1, star2, star3]


func _settle_with_ratio(crystal_ratio: float, blueprint_ratio: float, victory: bool) -> Dictionary:
	var crystals_kept: int = int(floor(crystals_collected * crystal_ratio))
	var blueprints_kept: int = int(floor(blueprints_collected * blueprint_ratio))
	var save: SaveSystem = _get_save_system()
	if save != null:
		save.add_crystals(crystals_kept)
		save.add_blueprints(blueprints_kept)
		save.flush_save()
	return {
		"victory": victory,
		"crystals_collected": crystals_collected,
		"blueprints_collected": blueprints_collected,
		"crystals_kept": crystals_kept,
		"blueprints_kept": blueprints_kept,
		"floor_id": current_floor_id,
	}


func _get_save_system() -> SaveSystem:
	# GameState autoload 持有 save_system；测试中直接 add_child(RunState)
	# 而无 GameState 时返回 null（调用方需自行处理）
	if typeof(GameState) == TYPE_NIL:
		return null
	if GameState == null:
		return null
	return GameState.save_system
