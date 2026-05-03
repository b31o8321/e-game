class_name BattleController extends Node

enum State { IDLE, PLAYER_TURN, QUESTION, RESOLVING, ENEMY_TURN, END }

var state: State = State.IDLE
var enemy_hp: int = 0
var current_attack_type: String = ""
var base_player_damage: int = 10

var _enemy: EnemyData
var _pack: ContentPackBase

signal battle_ended(victory: bool)
signal attack_selected(attack_type_id: String, question: Dictionary)
signal damage_dealt(amount: int, is_weakness: bool)
signal damage_received(amount: int)

func setup(enemy: EnemyData, pack: ContentPackBase) -> void:
	_enemy = enemy
	_pack = pack
	enemy_hp = enemy.max_hp
	state = State.IDLE

func start_player_turn() -> void:
	if state != State.IDLE:
		return
	state = State.PLAYER_TURN

func select_attack(attack_type_id: String) -> void:
	if state != State.PLAYER_TURN:
		return
	current_attack_type = attack_type_id
	state = State.QUESTION
	var question: Dictionary = _pack.get_question(attack_type_id, 1, [])
	attack_selected.emit(attack_type_id, question)

func on_question_answered(correct: bool, question_id: String) -> void:
	if state != State.QUESTION:
		return
	state = State.RESOLVING
	GameState.srs_system.record_answer(question_id, correct)
	if correct:
		_apply_player_attack()
	else:
		_apply_enemy_attack()

func _apply_player_attack() -> void:
	var pre_state: Dictionary = _build_battle_state()
	_call_skill_hooks_pre_attack(pre_state)
	var extra_multiplier: float = pre_state.get("damage_multiplier", 1.0)
	var multiplier: float = _enemy.get_damage_multiplier(current_attack_type)
	var is_weakness: bool = multiplier > 1.0
	var skill_bonus: int = _get_skill_attack_bonus()
	var damage: int = int((base_player_damage + skill_bonus) * multiplier * extra_multiplier)
	enemy_hp = max(0, enemy_hp - damage)
	damage_dealt.emit(damage, is_weakness)
	GameState.increment_combo()
	_call_skill_hooks_on_correct()
	if enemy_hp == 0:
		state = State.END
		battle_ended.emit(true)
		return
	state = State.IDLE

func _apply_enemy_attack() -> void:
	GameState.combo_count = 0
	GameState.combo_changed.emit(0)
	_call_skill_hooks_on_wrong()
	var damage: int = _enemy.base_attack
	damage_received.emit(damage)
	GameState.take_damage(damage)
	if GameState.player_hp == 0:
		state = State.END
		battle_ended.emit(false)
		return
	state = State.IDLE

func _get_skill_attack_bonus() -> int:
	return 0

func _call_skill_hooks_pre_attack(battle_state: Dictionary) -> void:
	for skill in _get_active_skill_instances():
		skill.on_correct(battle_state)

func _call_skill_hooks_on_correct() -> void:
	var battle_state: Dictionary = _build_battle_state()
	for skill in _get_active_skill_instances():
		skill.on_correct(battle_state)
	_apply_battle_state_effects(battle_state)

func _call_skill_hooks_on_wrong() -> void:
	var battle_state: Dictionary = _build_battle_state()
	for skill in _get_active_skill_instances():
		skill.on_wrong(battle_state)

func _build_battle_state() -> Dictionary:
	return {
		"player_hp": GameState.player_hp,
		"enemy_hp": enemy_hp,
		"combo": GameState.combo_count,
		"round": 0,
		"sealed_types": [],
		"time_limit_bonus": 0.0,
		"ember_stacks": 0,
		"ember_damage": 0,
		"super_combo_triggered": false,
		"super_combo_damage": 0,
		"damage_multiplier": 1.0,
	}

func _get_active_skill_instances() -> Array[SkillBase]:
	return []

func _apply_battle_state_effects(battle_state: Dictionary) -> void:
	if battle_state.get("super_combo_triggered", false):
		var extra: int = battle_state.get("super_combo_damage", 0)
		enemy_hp = max(0, enemy_hp - extra)
	if battle_state.get("ember_damage", 0) > 0:
		enemy_hp = max(0, enemy_hp - battle_state["ember_damage"])
