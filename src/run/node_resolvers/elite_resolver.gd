## EliteResolver — "elite" 类型节点解析器
##
## 与 BattleResolver 类似，但精英敌人血量 / 攻击 / 难度更高，并具备特殊能力
## （自给护盾 / 自动回血 / 多动 / 反伤 / 阈值触发等，参见 AbilitiesRegistry）。
##
## 优先级：
##   1. 当前楼层 sub_topic 对应的 "elite_*" 显式敌人（在 enemies.json 里手写定义，
##      自带 topic_id / weak_axes / challenge_template_ids / ability_ids）
##   2. 兜底：随机一个普通敌人 → 复制并放大数值（保留 weak_axes/topic_id 等
##      Phase 2 字段，避免 selector 找不到题导致 "敌人正在准备..."）
class_name EliteResolver extends Object


const RUN_MAP_SCENE: String = "res://src/run/run_map_scene.tscn"
const BATTLE_SCENE: String = "res://src/battle/battle_scene.tscn"


## 显式 elite 敌人按楼层映射（按 RunState.current_floor_id）。
## 若该楼层在 enemies.json 中存在对应 elite_* 条目，直接用它（不做缩放）。
const _FLOOR_ELITE_IDS := {
	"0F": "elite_letter_master",
	"1F": "elite_book_keeper",
	"2F": "elite_family_keeper",
}


static func resolve(node: RunNode, pack: ContentPackBase, tree: SceneTree) -> void:
	var enemy: EnemyData = _resolve_elite(node, pack)
	if enemy == null:
		push_warning("[EliteResolver] no elite enemy resolved for %s" % node.id)
		return
	GameState.pending_enemy = enemy
	GameState.expedition_return_scene = RUN_MAP_SCENE
	if tree != null:
		tree.change_scene_to_file(BATTLE_SCENE)


## 选/构造一个精英敌人。优先取手写 elite_*；否则缩放一只普通敌人。
static func _resolve_elite(node: RunNode, pack: ContentPackBase) -> EnemyData:
	if pack == null:
		return null
	# 1. 显式 elite_* 优先（手写定义带完整 ability_ids / 难题）
	var floor_id: String = ""
	if typeof(RunState) != TYPE_NIL and RunState != null:
		floor_id = RunState.current_floor_id
	var explicit_id: String = str(_FLOOR_ELITE_IDS.get(floor_id, ""))
	if explicit_id != "":
		var explicit: EnemyData = pack.get_enemy(explicit_id)
		if explicit != null:
			return explicit
	# 2. node.enemy_id 直接命中 elite_* 时也用之
	if node.enemy_id != "" and node.enemy_id.begins_with("elite_"):
		var direct: EnemyData = pack.get_enemy(node.enemy_id)
		if direct != null:
			return direct
	# 3. 兜底：随机一只普通敌人，按倍率缩放（保留 Phase 2 字段，避免 selector 失败）
	var base: EnemyData = BattleResolver._pick_enemy(node, pack)
	if base == null:
		return null
	var elite: EnemyData = EnemyData.new()
	elite.enemy_id = base.enemy_id + "_elite"
	elite.enemy_name = "[精英] " + base.enemy_name
	elite.max_hp = int(base.max_hp * 1.6)
	elite.base_attack = int(base.base_attack * 1.3)
	elite.sprite_path = base.sprite_path
	# Phase 2 字段必须复制，否则 ChallengeSelector 找不到题（"敌人正在准备..."）
	elite.topic_id = base.topic_id
	elite.weak_axes = base.weak_axes.duplicate()
	elite.challenge_template_ids = base.challenge_template_ids.duplicate()
	# 缩放精英自动获得一个温和能力（每回合回血 2）
	elite.ability_ids = ["regen_2"]
	# 旧字段兼容
	elite.weaknesses = base.weaknesses.duplicate()
	elite.weakness_multipliers = base.weakness_multipliers.duplicate()
	return elite
