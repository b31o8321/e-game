## BattleResolver — "battle" 类型节点解析器
##
## 职责：
##   1. 从内容包里取出敌人（按 RunNode.enemy_id 或楼层敌人池随机）
##   2. 写入 GameState.pending_enemy + expedition_return_scene = run_map_scene
##   3. 切换到战斗场景；战斗结束后由 BattleController 决定回到地图或撤退
##
## 调用方：run_map_scene.gd 在玩家点击 battle 节点时 await Resolver.resolve(node)
class_name BattleResolver extends Object


const RUN_MAP_SCENE: String = "res://src/run/run_map_scene.tscn"
const BATTLE_SCENE: String = "res://src/battle/battle_scene.tscn"


static func resolve(node: RunNode, pack: ContentPackBase, tree: SceneTree) -> void:
	var enemy: EnemyData = _pick_enemy(node, pack)
	if enemy == null:
		push_warning("[BattleResolver] no enemy resolved for node %s; skipping" % node.id)
		return
	GameState.pending_enemy = enemy
	GameState.expedition_return_scene = RUN_MAP_SCENE
	if tree != null:
		tree.change_scene_to_file(BATTLE_SCENE)


static func _pick_enemy(node: RunNode, pack: ContentPackBase) -> EnemyData:
	if pack == null:
		return null
	if node.enemy_id != "":
		var e: EnemyData = pack.get_enemy(node.enemy_id)
		if e != null:
			return e
	var pool: Array[EnemyData] = pack.get_enemy_pool_for_floor(RunState.current_floor_id)
	if pool.size() > 0:
		return pool[randi() % pool.size()]
	return null
