class_name Ember extends SkillBase

var _ember_stacks: int = 0
const EMBER_DAMAGE: int = 3
const MAX_STACKS: int = 5

func _init() -> void:
	skill_id = "ember"
	skill_name = "余烬"
	bd_path = "blaze"
	skill_type = "passive"
	description = "答对后敌人附加余烬（最多5层），每回合开始时各层造成 3 点伤害"

func on_correct(battle_state: Dictionary) -> void:
	_ember_stacks = min(_ember_stacks + 1, MAX_STACKS)
	battle_state["ember_stacks"] = _ember_stacks

func on_round_start(battle_state: Dictionary) -> void:
	if _ember_stacks > 0:
		battle_state["ember_damage"] = _ember_stacks * EMBER_DAMAGE

func on_wrong(battle_state: Dictionary) -> void:
	_ember_stacks = 0
	battle_state["ember_stacks"] = 0
