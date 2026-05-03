class_name Regeneration extends SkillBase

const HEAL_AMOUNT: int = 15
const TRIGGER_COMBO: int = 10

func _init() -> void:
	skill_id = "regeneration"
	skill_name = "回血"
	bd_path = "tank"
	skill_type = "passive"
	description = "每达到10连击，回复 15 HP"

func on_correct(battle_state: Dictionary) -> void:
	if GameState.combo_count > 0 and GameState.combo_count % TRIGGER_COMBO == 0:
		var healed: int = min(HEAL_AMOUNT, GameState.player_max_hp - GameState.player_hp)
		GameState.player_hp += healed
		battle_state["healed"] = healed
		GameState.hp_changed.emit(GameState.player_hp, GameState.player_max_hp)
