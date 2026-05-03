class_name BossBattleController extends BattleController

var _boss: BossBase = null
var _current_phase: int = 1
var _sealed_types: Array[String] = []
var _pending_shuffle: bool = false
var _timer_reduction: float = 0.0

var _question_ui: Control = null
var _question_controller: QuestionController = null

func _ready() -> void:
	# Does not call super._ready() — BattleController._ready() also connects
	# battle_ended.connect(_on_battle_ended), which would double-connect the signal.
	# BossBattleController owns its full setup here.
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
	var boss_path: String = GameState.pending_gate_config.get("boss_script_path", "")
	if not boss_path.is_empty():
		var boss_script := load(boss_path)
		if boss_script:
			_boss = boss_script.new() as BossBase
			if _boss:
				add_child(_boss)
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
	if not _question_controller:
		push_error("BossBattleController: question_ui.tscn root is not a QuestionController")
		return
	_question_controller.answered.connect(func(correct: bool, qid: String):
		_question_ui.visible = false
		on_question_answered(correct, qid))

func _get_active_skill_instances() -> Array[SkillBase]:
	return []

func _pop_gate_question() -> Dictionary:
	if GameState.gate_questions_pool.is_empty():
		return {}
	return GameState.gate_questions_pool.pop_front()

func _shuffle_question_options(q: Dictionary) -> Dictionary:
	var shuffled: Dictionary = q.duplicate()
	var options: Array = shuffled.get("options", []).duplicate()
	if options.is_empty():
		return shuffled
	var correct_answer: String = options[shuffled.get("correct_index", 0)]
	options.shuffle()
	shuffled["options"] = options
	shuffled["correct_index"] = options.find(correct_answer)
	return shuffled

func select_attack(attack_type_id: String) -> void:
	if state != State.PLAYER_TURN:
		return
	if attack_type_id in _sealed_types:
		return
	current_attack_type = attack_type_id
	state = State.QUESTION
	var question: Dictionary = _pop_gate_question()
	if question.is_empty():
		state = State.PLAYER_TURN
		return
	if _pending_shuffle:
		question = _shuffle_question_options(question)
		_pending_shuffle = false
	if _question_controller:
		var base_time: float = 10.0
		_question_controller.time_limit = max(3.0, base_time - _timer_reduction)
		_question_controller.load_question(question)
		_question_ui.visible = true
	attack_selected.emit(attack_type_id, question)

func build_attack_buttons() -> void:
	if not attack_buttons_container or not _pack:
		return
	for child in attack_buttons_container.get_children():
		child.queue_free()
	for attack_type in _pack.get_attack_types():
		var type_id: String = attack_type["id"]
		if type_id in _sealed_types:
			continue
		var btn: Button = Button.new()
		btn.text = attack_type.get("icon", "") + " " + attack_type.get("name", "")
		btn.pressed.connect(func(): select_attack(type_id))
		attack_buttons_container.add_child(btn)

## 供单元测试调用：应用单条 boss action
func _apply_boss_action(action: Dictionary) -> void:
	match action.get("type", "none"):
		"damage":
			GameState.take_damage(action.get("value", 0))
		"seal_attack":
			var type_id: String = action.get("value", "")
			if type_id and type_id not in _sealed_types:
				_sealed_types.append(type_id)
				build_attack_buttons()
		"shuffle_options":
			_pending_shuffle = true
		"shorten_timer":
			_timer_reduction = min(_timer_reduction + action.get("value", 0.0), 7.0)
		"none":
			pass

## 供单元测试调用：阶段切换检测
func _check_phase_transition(phase_count: int) -> void:
	if _current_phase >= phase_count:
		return
	var max_hp: int = _enemy.max_hp if _enemy else 100
	var hp_pct: float = float(enemy_hp) / float(max_hp)
	var new_phase: int = _current_phase
	if phase_count == 2:
		if hp_pct <= 0.5:
			new_phase = 2
	elif phase_count == 3:
		if hp_pct <= 0.33:
			new_phase = 3
		elif hp_pct <= 0.66:
			new_phase = 2
	if new_phase > _current_phase:
		_current_phase = new_phase
		if _boss:
			var bs: Dictionary = _build_battle_state()
			bs["phase"] = _current_phase
			bs["sealed_types"] = _sealed_types
			_boss.on_phase_start(_current_phase, bs)
			var new_seals: Array = bs.get("seal_types", [])
			for t in new_seals:
				if t not in _sealed_types:
					_sealed_types.append(t)
			build_attack_buttons()

func _execute_boss_action() -> void:
	if not _boss:
		return
	var bs: Dictionary = _build_battle_state()
	bs["phase"] = _current_phase
	bs["sealed_types"] = _sealed_types
	var action: Dictionary = _boss.boss_action(bs)
	_apply_boss_action(action)

func _apply_player_attack() -> void:
	super._apply_player_attack()
	if state != State.END:
		var pc: int = _boss.get_phase_count() if _boss else 1
		_check_phase_transition(pc)
		_execute_boss_action()

func _apply_enemy_attack() -> void:
	super._apply_enemy_attack()
	if state != State.END:
		_execute_boss_action()

func _on_battle_ended(victory: bool) -> void:
	GameState.pending_enemy = null
	if not victory:
		GameState.fail_gate()
		get_tree().change_scene_to_file("res://src/gate/gate_intro_scene.tscn")
		return
	if _boss:
		GameState.gate_boss_defeat_lines = _boss.get_defeat_dialogue()
	GameState.complete_gate()
	get_tree().change_scene_to_file("res://src/gate/gate_complete_scene.tscn")
