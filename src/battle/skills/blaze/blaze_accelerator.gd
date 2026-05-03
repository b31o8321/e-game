class_name BlazeAccelerator extends SkillBase

func _init() -> void:
	skill_id = "blaze_accelerator"
	skill_name = "连击加速"
	bd_path = "blaze"
	skill_type = "passive"
	description = "每次连击后，下一题答题时限 +0.5 秒（最多 +5 秒）"

## 被动：答对后通知 QuestionController 延长时限
func on_correct(battle_state: Dictionary) -> void:
	var bonus: float = min(GameState.combo_count * 0.5, 5.0)
	battle_state["time_limit_bonus"] = bonus
