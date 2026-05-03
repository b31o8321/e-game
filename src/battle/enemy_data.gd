class_name EnemyData extends Resource

@export var enemy_id: String = ""
@export var enemy_name: String = ""
@export var max_hp: int = 100
## 弱点攻击类型列表，如 ["vocabulary", "grammar"]
@export var weaknesses: Array[String] = []
## 弱点倍率，如 { "vocabulary": 2.0, "grammar": 1.5 }
@export var weakness_multipliers: Dictionary = {}
## 基础攻击伤害
@export var base_attack: int = 10
## 精灵图路径（Phase 2 用占位符，美术后替换）
@export var sprite_path: String = ""

## 计算对此敌人使用 attack_type 的伤害倍率
func get_damage_multiplier(attack_type_id: String) -> float:
	return weakness_multipliers.get(attack_type_id, 1.0)
