class_name Unyielding extends SkillBase

const LOW_HP_THRESHOLD: float = 0.2
const DAMAGE_MULTIPLIER: float = 2.0

func _init() -> void:
	skill_id = "unyielding"
	skill_name = "不屈"
	bd_path = "tank"
	skill_type = "passive"
	description = "HP 低于 20% 时，攻击伤害翻倍"

func on_correct(battle_state: Dictionary) -> void:
	var hp_ratio: float = float(GameState.player_hp) / float(GameState.player_max_hp)
	if hp_ratio < LOW_HP_THRESHOLD:
		battle_state["damage_multiplier"] = DAMAGE_MULTIPLIER
