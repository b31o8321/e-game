class_name BattleController extends Node

enum State { IDLE, PLAYER_TURN, QUESTION, RESOLVING, ENEMY_TURN, END }

var state: State = State.IDLE
var enemy_hp: int = 0
var current_attack_type: String = ""
var base_player_damage: int = 10

var _enemy: EnemyData
var _pack: ContentPackBase

# Scene node refs (set by scene, null-safe in unit tests)
var enemy_name_label: Label
var enemy_hp_bar: ProgressBar
var weakness_label: Label
var player_hp_bar: ProgressBar
var combo_label: Label
var attack_buttons_container: HBoxContainer
var question_ui_node: Control

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

func setup_scene_nodes(
		p_enemy_name: Label,
		p_enemy_hp: ProgressBar,
		p_weakness: Label,
		p_player_hp: ProgressBar,
		p_combo: Label,
		p_attack_buttons: HBoxContainer,
		p_question_ui: Control) -> void:
	enemy_name_label = p_enemy_name
	enemy_hp_bar = p_enemy_hp
	weakness_label = p_weakness
	player_hp_bar = p_player_hp
	combo_label = p_combo
	attack_buttons_container = p_attack_buttons
	question_ui_node = p_question_ui
	GameState.hp_changed.connect(_on_player_hp_changed)
	GameState.combo_changed.connect(_on_combo_changed)

func refresh_enemy_ui() -> void:
	if enemy_name_label:
		enemy_name_label.text = _enemy.enemy_name
	if enemy_hp_bar:
		enemy_hp_bar.max_value = _enemy.max_hp
		enemy_hp_bar.value = enemy_hp
	if weakness_label and _pack:
		var types: Array[Dictionary] = _pack.get_attack_types()
		var weak_names: Array[String] = []
		for t in types:
			if t["id"] in _enemy.weaknesses:
				weak_names.append(t["name"])
		weakness_label.text = "弱点: " + ", ".join(weak_names)

func build_attack_buttons() -> void:
	if not attack_buttons_container or not _pack:
		return
	for child in attack_buttons_container.get_children():
		child.queue_free()
	for attack_type in _pack.get_attack_types():
		var btn: Button = Button.new()
		btn.text = attack_type.get("icon", "") + " " + attack_type.get("name", "")
		var type_id: String = attack_type["id"]
		btn.pressed.connect(func(): select_attack(type_id))
		attack_buttons_container.add_child(btn)

func _on_player_hp_changed(new_hp: int, max_hp: int) -> void:
	if player_hp_bar:
		player_hp_bar.max_value = max_hp
		player_hp_bar.value = new_hp

func _on_combo_changed(count: int) -> void:
	if combo_label:
		combo_label.text = "连击: " + str(count)
