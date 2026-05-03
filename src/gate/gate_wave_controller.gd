class_name GateWaveController extends BattleController

var _question_ui: Control = null
var _question_controller: QuestionController = null

func _ready() -> void:
	var enemy_name_lbl := get_node_or_null("EnemyArea/EnemyNameLabel") as Label
	var enemy_hp_bar_node := get_node_or_null("EnemyArea/EnemyHpBar") as ProgressBar
	var weakness_lbl := get_node_or_null("EnemyArea/WeaknessLabel") as Label
	var player_hp_bar_node := get_node_or_null("PlayerArea/PlayerHpBar") as ProgressBar
	var combo_lbl := get_node_or_null("PlayerArea/ComboLabel") as Label
	var attack_btns := get_node_or_null("AttackButtons") as HBoxContainer
	if enemy_name_lbl:
		setup_scene_nodes(enemy_name_lbl, enemy_hp_bar_node, weakness_lbl,
			player_hp_bar_node, combo_lbl, attack_btns, null)
		_setup_question_ui()
	if GameState.pending_enemy != null and GameState.is_gate_active:
		setup(GameState.pending_enemy, GameState.content_loader.get_active_pack())
		refresh_enemy_ui()
		build_attack_buttons()
		start_player_turn()
	battle_ended.connect(_on_battle_ended)

func _setup_question_ui() -> void:
	var scene: PackedScene = load("res://src/battle/question_ui.tscn")
	_question_ui = scene.instantiate() as Control
	_question_ui.visible = false
	add_child(_question_ui)
	_question_controller = _question_ui as QuestionController
	_question_controller.answered.connect(func(correct: bool, qid: String):
		_question_ui.visible = false
		on_question_answered(correct, qid))

func _get_active_skill_instances() -> Array[SkillBase]:
	return []

func _pop_gate_question() -> Dictionary:
	if GameState.gate_questions_pool.is_empty():
		return {}
	return GameState.gate_questions_pool.pop_front()

func select_attack(attack_type_id: String) -> void:
	if state != State.PLAYER_TURN:
		return
	current_attack_type = attack_type_id
	state = State.QUESTION
	var question: Dictionary = _pop_gate_question()
	if question.is_empty():
		state = State.PLAYER_TURN
		return
	if _question_controller:
		_question_controller.load_question(question)
		_question_ui.visible = true
	attack_selected.emit(attack_type_id, question)

## 处理波次胜利逻辑（供单元测试直接调用）
func _handle_gate_victory() -> void:
	GameState.gate_wave_index += 1

## 处理大关失败逻辑（供单元测试直接调用）
func _handle_gate_failure() -> void:
	GameState.fail_gate()

func _on_battle_ended(victory: bool) -> void:
	GameState.pending_enemy = null
	if not victory:
		_handle_gate_failure()
		get_tree().change_scene_to_file("res://src/gate/gate_intro_scene.tscn")
		return
	_handle_gate_victory()
	if GameState.gate_wave_index < GameState.gate_wave_count:
		var cfg: Dictionary = GameState.pending_gate_config
		var wave_cfg: Dictionary = cfg.get("wave_enemy", {})
		var ed := EnemyData.new()
		ed.enemy_id = "gate_wave_enemy"
		ed.enemy_name = wave_cfg.get("enemy_name", "关卡敌人")
		ed.max_hp = wave_cfg.get("max_hp", 20)
		ed.base_attack = wave_cfg.get("base_attack", 3)
		ed.weaknesses = wave_cfg.get("weaknesses", [])
		ed.weakness_multipliers = wave_cfg.get("multipliers", {})
		GameState.pending_enemy = ed
		get_tree().change_scene_to_file("res://src/gate/gate_wave_scene.tscn")
	else:
		var cfg: Dictionary = GameState.pending_gate_config
		var boss_cfg: Dictionary = cfg.get("boss_enemy", {})
		var ed := EnemyData.new()
		ed.enemy_id = cfg.get("gate_id", "boss") + "_boss"
		ed.enemy_name = boss_cfg.get("enemy_name", "Boss")
		ed.max_hp = boss_cfg.get("max_hp", 150)
		ed.base_attack = boss_cfg.get("base_attack", 10)
		ed.weaknesses = boss_cfg.get("weaknesses", [])
		ed.weakness_multipliers = boss_cfg.get("multipliers", {})
		GameState.pending_enemy = ed
		get_tree().change_scene_to_file("res://src/gate/boss_battle_scene.tscn")
