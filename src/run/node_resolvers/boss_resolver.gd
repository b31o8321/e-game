## BossResolver — "boss" 类型节点解析器
##
## 流程：
##   1. 播放 boss_pre 面板（CutscenePlayer.play）
##   2. 等 cutscene_finished 后，把 BossBase 转成 EnemyData 喂给战斗系统
##   3. 战斗结束（由 BattleController 在战胜后回到地图）后，触发 boss_post
##      面板由 RunMapScene 处理（这里只负责前置）
class_name BossResolver extends Object


const RUN_MAP_SCENE: String = "res://src/run/run_map_scene.tscn"
const BATTLE_SCENE: String = "res://src/battle/battle_scene.tscn"


static func resolve(node: RunNode, pack: ContentPackBase, tree: SceneTree) -> void:
	if pack == null:
		push_warning("[BossResolver] no content pack")
		return
	var boss_id: String = node.enemy_id
	var pre_panels: Array[CutscenePanel] = pack.get_boss_pre_panels(boss_id)

	var enemy: EnemyData = _resolve_boss_enemy(boss_id, pack)
	if enemy == null:
		push_warning("[BossResolver] cannot resolve boss enemy for %s" % boss_id)
		return

	GameState.pending_enemy = enemy
	GameState.expedition_return_scene = RUN_MAP_SCENE

	# 标记 metadata 为 is_boss，供战斗系统识别（暂时通过 EnemyData.enemy_id 后缀区分）
	if not enemy.enemy_id.ends_with("_boss"):
		enemy.enemy_id += "_boss"

	# 记录 boss 战胜（在 BattleController.on_battle_ended(victory=true) 时由调用方触发）
	# 这里仅播放前置 cutscene
	if pre_panels != null and pre_panels.size() > 0:
		# CutscenePlayer 是 autoload；如果不存在（单元测试），降级直接进战斗
		var root := tree.root if tree != null else null
		if root != null and root.has_node("CutscenePlayer"):
			var cp: Node = root.get_node("CutscenePlayer")
			cp.play("boss_pre_" + boss_id, pre_panels)
			await cp.cutscene_finished
	if tree != null:
		tree.change_scene_to_file(BATTLE_SCENE)


static func _resolve_boss_enemy(boss_id: String, pack: ContentPackBase) -> EnemyData:
	# 部分包用 BossBase（cutscene 系统）描述 Boss；战斗输入仍是 EnemyData。
	# 优先尝试 get_enemy(boss_id)；回落到 BossBase.to_enemy_data()（如果存在）。
	var e: EnemyData = pack.get_enemy(boss_id)
	if e != null:
		return e
	var boss := pack.get_boss(boss_id)
	if boss != null and boss.has_method("to_enemy_data"):
		return boss.call("to_enemy_data")
	# 通用兜底：从 pack.get_boss_data(boss_id) 元数据 dict 构建 EnemyData
	if pack.has_method("get_boss_data"):
		var data: Dictionary = pack.call("get_boss_data", boss_id)
		if not data.is_empty():
			var ed := EnemyData.new()
			ed.enemy_id = str(data.get("id", boss_id))
			ed.enemy_name = str(data.get("display_name", boss_id))
			ed.max_hp = int(data.get("max_hp", 100))
			ed.base_attack = int(data.get("base_attack", 12))
			ed.sprite_path = str(data.get("portrait_path", ""))
			ed.topic_id = str(data.get("topic_id", ""))
			var raw_axes: Array = data.get("weak_axes", [])
			var axes: Array[String] = []
			for v in raw_axes:
				axes.append(str(v))
			ed.weak_axes = axes
			var raw_ids: Array = data.get("challenge_template_ids", [])
			var ids: Array[String] = []
			for v in raw_ids:
				ids.append(str(v))
			ed.challenge_template_ids = ids
			# 关键：复制 ability_ids，否则 invoke_spice_<id> / multi_action / regen 等
			# boss 能力全部丢失（之前 spice 永不触发的 bug 根因）
			var raw_abilities: Array = data.get("ability_ids", [])
			var abilities: Array[String] = []
			for v in raw_abilities:
				abilities.append(str(v))
			ed.ability_ids = abilities
			return ed
	return null


## 战斗胜利后由 RunMapScene 调用：播放 boss_post + 标记 + 进入营地或下一 Act
static func on_boss_victory(node: RunNode, pack: ContentPackBase, tree: SceneTree) -> void:
	var save: SaveSystem = GameState.save_system if typeof(GameState) != TYPE_NIL else null
	if save != null:
		save.record_boss_defeated(node.enemy_id)
	_maybe_award_equipment_after_boss(node.enemy_id)
	if pack == null or tree == null:
		return
	var post_panels: Array[CutscenePanel] = pack.get_boss_post_panels(node.enemy_id)
	if post_panels != null and post_panels.size() > 0:
		var root := tree.root
		if root != null and root.has_node("CutscenePlayer"):
			var cp: Node = root.get_node("CutscenePlayer")
			cp.play("boss_post_" + node.enemy_id, post_panels)


## Boss 胜利后必给 1 件未装备 slot 的装备（优先空槽；全满则随机替换）。
static func _maybe_award_equipment_after_boss(_boss_id: String) -> void:
	if typeof(RunState) == TYPE_NIL or RunState == null:
		return
	var pool: Array[Equipment] = EquipmentRegistry.get_all()
	pool.shuffle()
	for eq in pool:
		var already_equipped: bool = (
			RunState.equipped_weapon == eq
			or RunState.equipped_shield == eq
			or RunState.equipped_ring == eq
		)
		if not already_equipped:
			RunState.equip(eq)
			return
