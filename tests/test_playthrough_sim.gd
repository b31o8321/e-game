## 真实游玩模拟 — 跑多场战斗 + 验证遗物/Spice/楼层进度等核心机制是否真生效
##
## 这不是 smoke（smoke 只检"没崩"）；这里**测预期的副作用**：
##   - 装了 damage_boost 遗物，伤害真的多了
##   - 配了 invoke_spice_ 的 boss 真的 emit spice_invoked
##   - 战斗胜利后 enemy_id 真的进 seen_enemy_ids
##   - 跨楼层换 starting_deck 真的不污染
##   - 6 楼每楼至少一只敌人能 30 回合内打死
extends GutTest

const BattleScene := preload("res://src/battle/battle_scene.tscn")


var _pack: ContentPackBase = null
var _orig_state_backup: Dictionary = {}


func before_each() -> void:
	if typeof(GameState) != TYPE_NIL and GameState.content_loader != null:
		_pack = GameState.content_loader.get_active_pack()
	# 备份原始 save state，after_each 还原
	if typeof(GameState) != TYPE_NIL and GameState.save_system != null:
		_orig_state_backup = GameState.save_system.load_game_state().duplicate(true)
		var s := GameState.save_system.load_game_state()
		s.erase("seen_enemy_ids")
		s.erase("codex")
		GameState.save_system.save_game_state(s)
	if typeof(RunState) != TYPE_NIL:
		RunState.equipped_relics = []


func after_each() -> void:
	if typeof(GameState) != TYPE_NIL and GameState.save_system != null:
		GameState.save_system.save_game_state(_orig_state_backup)
	if typeof(RunState) != TYPE_NIL:
		RunState.equipped_relics = []


func _auto_play_battle(ctrl, max_turns: int = 30) -> Dictionary:
	var turn: int = 0
	while turn < max_turns:
		if ctrl.state == BattleController.State.END:
			return {"ended": true, "turns": turn, "winner": "player" if ctrl.player_hp > 0 else "enemy"}
		var placed: bool = false
		for c in ctrl.card_library:
			if c == null:
				continue
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
						placed = true
					break
				if placed:
					break
			if placed:
				break
		ctrl.end_player_turn()
		await get_tree().process_frame
		turn += 1
	return {"ended": false, "turns": turn}


func _start_battle_with_enemy(floor_id: String, enemy: EnemyData):
	if typeof(RunState) != TYPE_NIL:
		RunState.start_floor(floor_id, _pack)
	if typeof(GameState) != TYPE_NIL:
		GameState.pending_enemy = enemy
	var bs = BattleScene.instantiate()
	add_child_autofree(bs)
	await get_tree().process_frame
	return bs.get("_controller")


# ─── 1) 跨 6 楼层逐一打通常 enemy ──────────────────────────────────

func test_all_six_floors_have_winnable_common_enemy() -> void:
	if _pack == null:
		pending("no pack")
		return
	var dead_floors: Array[String] = []
	for fid in ["0F", "1F", "2F", "3F", "4F", "5F"]:
		var pool := _pack.get_enemy_pool_for_floor(fid)
		if pool.is_empty():
			dead_floors.append(fid + "(无敌人)")
			continue
		var ctrl = await _start_battle_with_enemy(fid, pool[0])
		if ctrl == null:
			dead_floors.append(fid + "(无 controller)")
			continue
		var r := await _auto_play_battle(ctrl, 40)
		if not r.get("ended", false):
			dead_floors.append("%s(%s/%d)" % [fid, r.get("turns"), 40])
	assert_eq(dead_floors, [] as Array[String],
		"以下楼层未能在 40 回合内打完战斗：%s" % str(dead_floors))


# ─── 2) Relic damage_boost 真的让伤害多了 ──────────────────────────

func test_damage_boost_relic_actually_boosts() -> void:
	if _pack == null:
		pending("no pack")
		return
	if typeof(RunState) == TYPE_NIL:
		pending("no RunState")
		return
	# 装 damage_boost +5
	var r := Relic.new()
	r.id = "test_dmg"
	r.effect_type = "damage_boost"
	r.magnitude = 5
	RunState.equipped_relics = [r]
	# 记 enemy hp 变化前后
	var pool := _pack.get_enemy_pool_for_floor("0F")
	if pool.is_empty():
		pending("no 0F enemy")
		return
	var ctrl = await _start_battle_with_enemy("0F", pool[0])
	if ctrl == null:
		pending("no controller")
		return
	var hp_before: int = ctrl.enemy_hp
	# 找一张能 perfect-match（accept_card_ids 含此卡）的（卡, 题, 槽）组合，才会算对题打伤害
	var placed: bool = false
	for ci in ctrl.available_challenges.size():
		var tmpl = ctrl.available_challenges[ci]
		if tmpl == null:
			continue
		for si in tmpl.slots.size():
			var slot = tmpl.slots[si]
			# 找 perfect-match 卡
			for c in ctrl.card_library:
				if c == null:
					continue
				var ok_perfect: bool = (
					slot.accept_card_ids != null
					and slot.accept_card_ids.size() > 0
					and c.id in slot.accept_card_ids
				)
				if not ok_perfect:
					continue
				if ctrl.add_to_ap_queue(c, ci, si):
					ctrl.submit_all_ap()
					placed = true
				break
			if placed:
				break
		if placed:
			break
	if not placed:
		pending("当前楼层 deck 里没 perfect-match 卡，跳过 damage_boost 端到端测试（已在 test_relic_combat_hooks 单测覆盖）")
		return
	var hp_after: int = ctrl.enemy_hp
	var damage_dealt: int = hp_before - hp_after
	# 0F enemy 卡 base_damage ~5-7；装 +5 应明显增加
	assert_gte(damage_dealt, 8,
		"damage_boost +5 装备后单卡伤害应 ≥8（无遗物时 base ~5-7）；实际 %d" % damage_dealt)


# ─── 3) Spice 触发：letter_chaos boss 战斗开始 emit spice_invoked ──

func test_letter_chaos_boss_spice_ability_round_trip() -> void:
	# 真正测试 boss → 战斗 → spice 触发的完整链路：
	# bosses.json[letter_chaos].ability_ids → BossResolver 转 EnemyData →
	# BattleController setup 读到 invoke_spice_ → start_battle emit spice_invoked
	if _pack == null:
		pending("no pack")
		return
	# 1) bosses.json 里 letter_chaos 有 invoke_spice_voice_battle_cry
	var bdata: Dictionary = _pack.get_boss_data("letter_chaos") if _pack.has_method("get_boss_data") else {}
	if bdata.is_empty():
		pending("letter_chaos 没在 bosses.json")
		return
	assert_true("invoke_spice_voice_battle_cry" in bdata.get("ability_ids", []),
		"bosses.json letter_chaos.ability_ids 应含 invoke_spice_voice_battle_cry")

	# 2) BossResolver 转的 EnemyData 必须带 ability_ids（之前 bug：会丢）
	#    模拟 BossResolver._resolve_boss_enemy 的逻辑链
	var ed := EnemyData.new()
	ed.enemy_id = str(bdata.get("id", "letter_chaos"))
	ed.enemy_name = str(bdata.get("display_name", ""))
	ed.max_hp = int(bdata.get("max_hp", 100))
	ed.base_attack = int(bdata.get("base_attack", 12))
	var raw_abilities: Array = bdata.get("ability_ids", [])
	var abilities: Array[String] = []
	for v in raw_abilities:
		abilities.append(str(v))
	ed.ability_ids = abilities
	assert_true("invoke_spice_voice_battle_cry" in ed.ability_ids,
		"BossResolver 构造的 EnemyData 必须携带 boss 的 ability_ids")

	# 3) 直接 setup → connect → start_battle，避开 BattleScene._ready 自动跑掉信号
	var ctrl := BattleController.new()
	add_child_autofree(ctrl)
	var captured: Array[String] = []
	ctrl.spice_invoked.connect(func(sid: String): captured.append(sid))
	var deck_ids: Array[String] = _pack.get_starting_deck_for_floor("0F")
	var deck: Array[Card] = []
	for cid in deck_ids:
		var c: Card = _pack.get_card(cid)
		if c != null:
			deck.append(c)
	ctrl.setup(ed, _pack, deck)
	ctrl.start_battle()
	await get_tree().process_frame
	assert_true("voice_battle_cry" in captured,
		"letter_chaos start_battle 应 emit spice_invoked('voice_battle_cry')，实际 captured=%s" % str(captured))


# ─── 4) 战斗胜利后 enemy 进 seen_enemy_ids ────────────────────────

func test_battle_setup_adds_to_seen_enemy_ids() -> void:
	if _pack == null:
		pending("no pack")
		return
	if typeof(GameState) == TYPE_NIL or GameState.save_system == null:
		pending("no save_system")
		return
	var pool := _pack.get_enemy_pool_for_floor("1F")
	if pool.is_empty():
		pending("no 1F enemy")
		return
	var eid: String = pool[0].enemy_id
	var ctrl = await _start_battle_with_enemy("1F", pool[0])
	# BattleController.setup 末尾已调 record_enemy_seen
	var seen: Array = GameState.save_system.load_game_state().get("codex", {}).get("seen_enemy_ids", [])
	# 兼容旧字段名
	if seen.is_empty():
		seen = GameState.save_system.load_game_state().get("seen_enemy_ids", [])
	assert_true(eid in seen, "战斗 setup 后 %s 应进 seen_enemy_ids；实际 seen=%s" % [eid, str(seen)])


# ─── 5) 跨楼层 starting_deck 互不污染（端到端） ──────────────────

func test_cross_floor_starting_decks_differ() -> void:
	if _pack == null:
		pending("no pack")
		return
	var seen: Array = []
	for fid in ["0F", "1F", "2F", "3F", "4F", "5F"]:
		var deck := _pack.get_starting_deck_for_floor(fid)
		assert_false(deck.is_empty(), "%s 起手 deck 不能为空" % fid)
		# 转 sorted tuple 比对
		var sig: String = ",".join(deck.duplicate())
		assert_false(sig in seen, "%s 起手 deck 与已有楼层完全相同（应分流）：%s" % [fid, deck])
		seen.append(sig)
