class_name BuildingBase extends Resource

@export var building_id: String = ""
@export var building_name: String = ""
@export var max_level: int = 5
@export var attack_type_id: String = ""  # 对应的攻击类型

## 返回升级到 level 需要的资源
## 格式: { resource_id: count }
func get_upgrade_cost(level: int) -> Dictionary:
	return {}

## 返回 level 级别的战斗效果
## 格式: { attack_bonus, special_effect_id, special_effect_value }
func get_effects(level: int) -> Dictionary:
	return {}

## 返回 level 级别解锁的技能ID列表
func get_unlocked_skills(level: int) -> Array[String]:
	return []
