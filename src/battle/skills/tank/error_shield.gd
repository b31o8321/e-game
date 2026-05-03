class_name ErrorShield extends SkillBase

var _wrong_count: int = 0
const SHIELD_INTERVAL: int = 5
var _shield_active: bool = false

func _init() -> void:
	skill_id = "error_shield"
	skill_name = "错误护盾"
	bd_path = "tank"
	skill_type = "passive"
	description = "每答错 5 次，下一次答错不打断连击"

func on_wrong(battle_state: Dictionary) -> void:
	_wrong_count += 1
	if _wrong_count % SHIELD_INTERVAL == 0:
		_shield_active = true
	if _shield_active:
		battle_state["preserve_combo"] = true
		_shield_active = false
