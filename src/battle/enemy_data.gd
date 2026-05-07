## EnemyData — 战斗中的敌人数据
##
## Phase 2 卡片战斗扩展：增加 weak_axes / topic_id / challenge_template_ids，
## 同时保留 weaknesses / weakness_multipliers / base_attack 等旧字段，
## 以便 BossBattleController（将于后续移除）继续编译。
class_name EnemyData extends Resource

@export var enemy_id: String = ""
@export var enemy_name: String = ""
@export var max_hp: int = 100
## 基础攻击伤害（敌人回合对玩家造成的伤害）
@export var base_attack: int = 10
## 精灵图路径（占位符）
@export var sprite_path: String = ""

# === Phase 2 卡片战斗字段 ===
## 弱点轴：可命中 card.skill 或 card.tags 中的字符串。
## 例：["positive_emotion", "vocab"] 表示用 positive_emotion 标签的卡或 vocab 技能卡能打弱点。
@export var weak_axes: Array[String] = []
## 该敌人主题，用于 ChallengeSelector 抓取 ChallengeTemplate
@export var topic_id: String = ""
## 该敌人专属 ChallengeTemplate ID 列表（多阶段或多句台词）
@export var challenge_template_ids: Array[String] = []
## 敌人能力 ID 列表（参见 AbilitiesRegistry）。例：["regen_2", "shield_at_50"]。
## 战斗开始时由 BattleController 实例化为 EntityAbility 数组。
@export var ability_ids: Array[String] = []

# === @deprecated 旧字段（保留供 boss_battle_controller / 旧测试编译）===
## @deprecated Phase 2: 改用 weak_axes（直接命中 card.skill / tags）
@export var weaknesses: Array[String] = []
## @deprecated Phase 2: 弱点改为固定 ×1.5（见 DamageCalculator）
@export var weakness_multipliers: Dictionary = {}


## @deprecated Phase 2: 旧攻击类型倍率查询。新战斗用 weak_axes + DamageCalculator。
func get_damage_multiplier(attack_type_id: String) -> float:
	return weakness_multipliers.get(attack_type_id, 1.0)


## 判断 card 是否命中本敌人弱点（card.skill 或 card.tags 与 weak_axes 有交集）。
func is_weakness_hit(card: Card) -> bool:
	if card == null or weak_axes.is_empty():
		return false
	if card.skill != "" and card.skill in weak_axes:
		return true
	for t in card.tags:
		if t in weak_axes:
			return true
	return false


## 从 Dictionary 构造（便于 JSON 加载 / 测试）
static func from_dict(data: Dictionary) -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = str(data.get("enemy_id", ""))
	e.enemy_name = str(data.get("enemy_name", ""))
	e.max_hp = int(data.get("max_hp", 100))
	e.base_attack = int(data.get("base_attack", 10))
	e.sprite_path = str(data.get("sprite_path", ""))
	e.topic_id = str(data.get("topic_id", ""))

	var raw_axes: Array = data.get("weak_axes", [])
	var axes: Array[String] = []
	for v in raw_axes:
		axes.append(str(v))
	e.weak_axes = axes

	var raw_ids: Array = data.get("challenge_template_ids", [])
	var ids: Array[String] = []
	for v in raw_ids:
		ids.append(str(v))
	e.challenge_template_ids = ids

	var raw_abilities: Array = data.get("ability_ids", [])
	var abilities: Array[String] = []
	for v in raw_abilities:
		abilities.append(str(v))
	e.ability_ids = abilities

	# 旧字段兼容
	var raw_weaks: Array = data.get("weaknesses", [])
	var weaks: Array[String] = []
	for v in raw_weaks:
		weaks.append(str(v))
	e.weaknesses = weaks
	e.weakness_multipliers = data.get("weakness_multipliers", {})

	return e
