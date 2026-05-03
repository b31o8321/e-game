extends GutTest

var controller: GateWaveController
var mock_pack: MockContentPack

func before_each() -> void:
	mock_pack = MockContentPack.new()
	controller = GateWaveController.new()
	add_child_autofree(controller)
	var enemy := EnemyData.new()
	enemy.enemy_name = "Test Wave Enemy"
	enemy.max_hp = 30
	enemy.base_attack = 4
	enemy.weaknesses = []
	enemy.weakness_multipliers = {}
	controller.setup(enemy, mock_pack)

func test_get_active_skill_instances_returns_empty() -> void:
	var skills: Array[SkillBase] = controller._get_active_skill_instances()
	assert_eq(skills.size(), 0)

func test_pop_gate_question_removes_from_pool() -> void:
	GameState.gate_questions_pool = [
		{ "id": "q1", "question": "Q1", "options": ["A", "B"], "correct_index": 0, "attack_type_id": "vocabulary" },
		{ "id": "q2", "question": "Q2", "options": ["A", "B"], "correct_index": 1, "attack_type_id": "vocabulary" },
	]
	var q: Dictionary = controller._pop_gate_question()
	assert_eq(q["id"], "q1")
	assert_eq(GameState.gate_questions_pool.size(), 1)

func test_pop_gate_question_returns_empty_when_pool_empty() -> void:
	GameState.gate_questions_pool = []
	var q: Dictionary = controller._pop_gate_question()
	assert_true(q.is_empty())

func test_select_attack_with_empty_pool_resets_state() -> void:
	GameState.gate_questions_pool = []
	controller.state = BattleController.State.PLAYER_TURN
	controller.select_attack("vocabulary")
	assert_eq(controller.state, BattleController.State.PLAYER_TURN)

func test_handle_gate_victory_increments_wave_index() -> void:
	GameState.gate_wave_index = 0
	GameState.gate_wave_count = 2
	GameState.is_gate_active = true
	GameState.pending_gate_config = {
		"wave_count": 2,
		"wave_enemy": { "enemy_name": "E", "max_hp": 20, "base_attack": 3, "weaknesses": [], "multipliers": {} },
		"boss_enemy": { "enemy_name": "Boss", "max_hp": 50, "base_attack": 5, "weaknesses": [], "multipliers": {} },
		"gate_id": "gate_mock_01",
	}
	controller._handle_gate_victory()
	assert_eq(GameState.gate_wave_index, 1)

func test_handle_gate_failure_resets_wave_index() -> void:
	GameState.gate_wave_index = 1
	GameState.gate_questions_pool = [{ "id": "q1" }]
	controller._handle_gate_failure()
	assert_eq(GameState.gate_wave_index, 0)
	assert_true(GameState.gate_questions_pool.is_empty())
