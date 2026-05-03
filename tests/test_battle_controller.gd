extends GutTest

var bc: BattleController
var enemy: EnemyData
var mock_pack: MockContentPack

func before_each() -> void:
	bc = BattleController.new()
	add_child_autofree(bc)
	enemy = EnemyData.new()
	enemy.enemy_id = "goblin"
	enemy.max_hp = 50
	enemy.weaknesses = ["vocabulary"]
	enemy.weakness_multipliers = { "vocabulary": 2.0 }
	enemy.base_attack = 8
	mock_pack = MockContentPack.new()
	bc.setup(enemy, mock_pack)
	GameState.player_hp = 100
	GameState.player_max_hp = 100
	GameState.combo_count = 0

func test_initial_state_is_idle() -> void:
	assert_eq(bc.state, BattleController.State.IDLE)

func test_start_player_turn_changes_state() -> void:
	bc.start_player_turn()
	assert_eq(bc.state, BattleController.State.PLAYER_TURN)

func test_select_attack_requires_player_turn_state() -> void:
	# In IDLE state, select_attack should be a no-op
	bc.select_attack("vocabulary")
	assert_eq(bc.state, BattleController.State.IDLE)

func test_correct_answer_damages_enemy() -> void:
	bc.start_player_turn()
	bc.select_attack("vocabulary")
	bc.on_question_answered(true, "q_mock_001")
	assert_lt(bc.enemy_hp, enemy.max_hp)

func test_weakness_multiplier_applied() -> void:
	bc.start_player_turn()
	bc.select_attack("vocabulary")  # vocabulary is a weakness (x2)
	bc.on_question_answered(true, "q_mock_001")
	# base damage is 10, weakness x2 = 20
	assert_eq(bc.enemy_hp, enemy.max_hp - 20)

func test_wrong_answer_damages_player() -> void:
	var hp_before: int = GameState.player_hp
	bc.start_player_turn()
	bc.select_attack("vocabulary")
	bc.on_question_answered(false, "q_mock_001")
	assert_lt(GameState.player_hp, hp_before)

func test_enemy_defeat_emits_signal() -> void:
	watch_signals(bc)
	bc.enemy_hp = 1
	bc.start_player_turn()
	bc.select_attack("vocabulary")
	bc.on_question_answered(true, "q_mock_001")
	assert_signal_emitted(bc, "battle_ended")
	assert_signal_emitted_with_parameters(bc, "battle_ended", [true])

func test_player_defeat_emits_signal() -> void:
	watch_signals(bc)
	GameState.player_hp = 1
	bc.start_player_turn()
	bc.select_attack("vocabulary")
	bc.on_question_answered(false, "q_mock_001")
	assert_signal_emitted_with_parameters(bc, "battle_ended", [false])
