class_name SuperCombo extends SkillBase

func _init() -> void:
	skill_id = "super_combo"
	skill_name = "超连击"
	bd_path = "blaze"
	skill_type = "passive"
	description = "连击达到10时，触发范围爆炸，造成额外 50 点伤害"

func on_correct(battle_state: Dictionary) -> void:
	if GameState.combo_count == 10:
		battle_state["super_combo_triggered"] = true
		battle_state["super_combo_damage"] = 50
