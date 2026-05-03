class_name SkillBase extends Resource

@export var skill_id: String = ""
@export var skill_name: String = ""
@export var bd_path: String = ""        # "blaze" | "tank" | "element" | "summon"
@export var skill_type: String = ""     # "active" | "passive" | "legendary"
@export var description: String = ""
@export var icon_path: String = ""

## 被动技能：每回合开始时调用，可修改 battle_state
func on_round_start(battle_state: Dictionary) -> void:
	pass

## 主动技能：玩家手动触发，返回技能效果
func activate(battle_state: Dictionary) -> Dictionary:
	return {}

## 协同检查：传入当前持有的所有技能ID，返回是否触发协同及效果
func check_synergy(held_skill_ids: Array[String]) -> Dictionary:
	return { "triggered": false }

## 答对时触发（被动）
func on_correct(battle_state: Dictionary) -> void:
	pass

## 答错时触发（被动）
func on_wrong(battle_state: Dictionary) -> void:
	pass
