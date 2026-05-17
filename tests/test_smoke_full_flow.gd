## 全流程 smoke test：自动跑通 城市→楼门→备战→战斗→结算 关键路径
##
## 目的：每次推送前自动捕捉"按钮没接信号 / 节点缺失 / 战斗死锁 / 切场景崩溃
## / 跨楼层污染"这类客观 bug。主观感受（丑/挤/节奏）不在 scope。
##
## 这个文件刻意 **不用** GUT 的 mock pack —— 直接用真实的 EnglishContentPack，
## 因为我们就是要抓"真包"在真流程下的 bug。
extends GutTest

const BattleScene := preload("res://src/battle/battle_scene.tscn")
const PreRunSetupScene := preload("res://src/city/pre_run_setup_scene.tscn")
const SettlementScene := preload("res://src/run/settlement_scene.tscn")
const CityScene := preload("res://src/city/city_scene.tscn")
const TowerGateScene := preload("res://src/city/buildings/tower_gate_scene.tscn")


# ─── 共享：拿到真 English pack ─────────────────────────────────────
var _pack: ContentPackBase = null


func before_each() -> void:
	if typeof(GameState) != TYPE_NIL and GameState.content_loader != null:
		_pack = GameState.content_loader.get_active_pack()


# ─── A. 每个顶层场景都能干净实例化 ────────────────────────────────

func test_smoke_city_scene_instantiates() -> void:
	var s: Control = CityScene.instantiate()
	add_child_autofree(s)
	await get_tree().process_frame
	assert_not_null(s, "city scene loads")


func test_smoke_tower_gate_instantiates() -> void:
	var s: Control = TowerGateScene.instantiate()
	add_child_autofree(s)
	await get_tree().process_frame
	assert_not_null(s, "tower gate loads")


func test_smoke_pre_run_setup_instantiates_for_each_floor() -> void:
	# 真包目前有 0F/1F/2F。每个楼层 PreRunSetupScene 都要能开。
	for fid in ["0F", "1F", "2F"]:
		if typeof(RunState) != TYPE_NIL:
			RunState.pending_floor_id = fid
		var s: PreRunSetupController = PreRunSetupScene.instantiate()
		s.test_disable_scene_change = true
		add_child_autofree(s)
		await get_tree().process_frame
		var deck = s.get_current_deck()
		assert_not_null(deck, "%s deck array exists" % fid)
		assert_gt(deck.size(), 0, "%s loads non-empty starting deck" % fid)
	if typeof(RunState) != TYPE_NIL:
		RunState.pending_floor_id = ""


func test_smoke_battle_scene_instantiates() -> void:
	var b: Control = BattleScene.instantiate()
	add_child_autofree(b)
	await get_tree().process_frame
	assert_not_null(b, "battle scene loads")
	# 关键节点存在
	for path in ["EnemyArea", "ChallengeBoardPanel", "HandRow", "HandLabelRow", "ActionRow"]:
		assert_not_null(b.get_node_or_null(path), "battle scene has %s" % path)


func test_smoke_settlement_scene_instantiates() -> void:
	var s: Control = SettlementScene.instantiate()
	add_child_autofree(s)
	await get_tree().process_frame
	assert_not_null(s, "settlement scene loads")


# ─── B. BattleScene 关键 UI 按钮都接了信号 ─────────────────────────

func test_smoke_no_dead_buttons_in_battle() -> void:
	# 死按钮 = 可见 Button 但 pressed 信号没人 connect。
	var b: Control = BattleScene.instantiate()
	add_child_autofree(b)
	await get_tree().process_frame
	var dead: Array[String] = []
	_collect_dead_buttons(b, dead)
	assert_eq(dead, [] as Array[String], "no visible Buttons missing pressed handler: %s" % str(dead))


func _collect_dead_buttons(node: Node, out: Array[String]) -> void:
	if node is Button:
		var btn: Button = node
		if btn.visible and btn.pressed.get_connections().is_empty():
			out.append(str(btn.get_path()))
	for ch in node.get_children():
		_collect_dead_buttons(ch, out)


# ─── C. 每个楼层都能进战斗 + 不死锁地结束战斗 ─────────────────────

func test_smoke_battle_completes_for_each_floor() -> void:
	if _pack == null:
		pending("no pack; skipping battle smoke")
		return
	# 0F-5F 全跑（Slice 18+19 扩展后）
	for fid in ["0F", "1F", "2F", "3F", "4F", "5F"]:
		var result: Dictionary = await _run_battle_for_floor(fid)
		assert_true(result.get("ended", false),
			"%s battle must reach END state — got: %s" % [fid, str(result)])


## 启动 BattleScene + 自动玩到战斗结束（END）；返回 {ended: bool, turns: int, ...}
func _run_battle_for_floor(floor_id: String) -> Dictionary:
	# 准备 RunState（真路径里 PreRunSetupController.start 走的事）
	if typeof(RunState) != TYPE_NIL:
		RunState.start_floor(floor_id, _pack)
	# 拿一只该楼的非 boss 敌人
	var pool: Array[EnemyData] = _pack.get_enemy_pool_for_floor(floor_id)
	if pool.is_empty():
		return {"ended": false, "reason": "no enemies for %s" % floor_id}
	if typeof(GameState) != TYPE_NIL:
		GameState.pending_enemy = pool[0]

	var bs = BattleScene.instantiate()
	add_child_autofree(bs)
	await get_tree().process_frame

	# 找 controller
	var ctrl = bs.get_node_or_null("BattleController")
	if ctrl == null:
		# scene 把 controller 当成子节点；脚本里通常叫 _controller
		ctrl = bs.get("_controller")
	if ctrl == null:
		return {"ended": false, "reason": "no controller after scene ready"}

	# 限定最多 30 个回合，防卡死
	var max_turns: int = 30
	var turn: int = 0
	while turn < max_turns:
		if ctrl.state == BattleController.State.END:
			return {"ended": true, "turns": turn, "floor": floor_id}
		# 试着把每张库内的卡塞到能放的槽。塞不进就跳过。
		var placed_any: bool = false
		for c in ctrl.card_library:
			if c == null:
				continue
			# 遍历题/槽找合法放点
			for ci in ctrl.available_challenges.size():
				if ctrl.is_failed(ci):
					continue
				var tmpl = ctrl.available_challenges[ci]
				if tmpl == null:
					continue
				var slots: Array = ctrl.available_filled_slots[ci] if ci < ctrl.available_filled_slots.size() else []
				for si in tmpl.slots.size():
					var existing = slots[si] if si < slots.size() else null
					if existing != null:
						continue
					if not CardValidator.can_place(c, tmpl.slots[si]):
						continue
					if ctrl.add_to_ap_queue(c, ci, si):
						ctrl.submit_all_ap()
						placed_any = true
					break  # 一张卡塞一处就行
				if placed_any:
					break
			if placed_any:
				break
		# 结束回合（无论是否放到卡——避免死锁）
		ctrl.end_player_turn()
		await get_tree().process_frame
		turn += 1
	return {"ended": false, "reason": "max_turns reached", "turns": turn, "floor": floor_id}


# ─── D. 跨楼层污染回归（黑盒视角；test_per_floor_deck_isolation 是白盒） ─

func test_smoke_floor_switch_loads_correct_starting_deck() -> void:
	if _pack == null:
		pending("no pack")
		return
	# 0F 默认 != 1F 默认（pack 必须按楼层分流）
	var d0: Array[String] = _pack.get_starting_deck_for_floor("0F")
	var d1: Array[String] = _pack.get_starting_deck_for_floor("1F")
	assert_false(d0.is_empty(), "0F has a defined starting deck")
	assert_false(d1.is_empty(), "1F has a defined starting deck")
	assert_ne(d0, d1, "0F and 1F starting decks must differ — otherwise pack defines no per-floor deck")


# ─── E. 战斗死锁防护：所有题失败后能否安全结束回合 ────────────────

func test_smoke_end_turn_never_crashes_in_any_state() -> void:
	# 反复调 end_player_turn 不能崩，状态机要稳定到 END 或 PLAYER_TURN。
	if _pack == null:
		pending("no pack")
		return
	if typeof(RunState) != TYPE_NIL:
		RunState.start_floor("0F", _pack)
	var pool := _pack.get_enemy_pool_for_floor("0F")
	if pool.is_empty():
		pending("no enemies")
		return
	if typeof(GameState) != TYPE_NIL:
		GameState.pending_enemy = pool[0]
	var bs = BattleScene.instantiate()
	add_child_autofree(bs)
	await get_tree().process_frame
	var ctrl = bs.get("_controller")
	assert_not_null(ctrl, "controller exists")
	# 连续 end_player_turn 50 次（不出牌）—— 模拟"玩家挂机让敌人慢慢打"。
	# 必须收敛到 END，不应该无限循环或崩溃。
	var cap: int = 50
	var i: int = 0
	while i < cap and ctrl.state != BattleController.State.END:
		ctrl.end_player_turn()
		await get_tree().process_frame
		i += 1
	assert_eq(ctrl.state, BattleController.State.END,
		"50 idle end_turns should reach END (got state=%s)" % ctrl.state)
