extends GutTest

var controller: BossBattleController
var mock_pack: MockContentPack

func before_each() -> void:
	mock_pack = MockContentPack.new()
	controller = BossBattleController.new()
	add_child_autofree(controller)
	var enemy := EnemyData.new()
	enemy.enemy_name = "Test Boss"
	enemy.max_hp = 100
	enemy.base_attack = 10
	enemy.weaknesses = []
	enemy.weakness_multipliers = {}
	controller.setup(enemy, mock_pack)
	controller.enemy_hp = 100
	GameState.player_hp = 100
	GameState.player_max_hp = 100

func test_boss_action_damage_reduces_player_hp() -> void:
	var action: Dictionary = { "type": "damage", "value": 15, "message": "" }
	controller._apply_boss_action(action)
	assert_eq(GameState.player_hp, 85)

func test_boss_action_seal_attack_adds_to_sealed_types() -> void:
	var action: Dictionary = { "type": "seal_attack", "value": "vocabulary", "message": "" }
	controller._apply_boss_action(action)
	assert_true("vocabulary" in controller._sealed_types)

func test_boss_action_seal_attack_no_duplicate() -> void:
	controller._sealed_types = ["vocabulary"]
	var action: Dictionary = { "type": "seal_attack", "value": "vocabulary", "message": "" }
	controller._apply_boss_action(action)
	assert_eq(controller._sealed_types.count("vocabulary"), 1)

func test_boss_action_shorten_timer_applies_reduction() -> void:
	controller._timer_reduction = 0.0
	var action: Dictionary = { "type": "shorten_timer", "value": 3.0, "message": "" }
	controller._apply_boss_action(action)
	assert_almost_eq(controller._timer_reduction, 3.0, 0.001)

func test_boss_action_shorten_timer_caps_at_max_reduction() -> void:
	controller._timer_reduction = 6.0
	var action: Dictionary = { "type": "shorten_timer", "value": 5.0, "message": "" }
	controller._apply_boss_action(action)
	assert_almost_eq(controller._timer_reduction, 7.0, 0.001)

func test_boss_action_shuffle_options_sets_pending_flag() -> void:
	var action: Dictionary = { "type": "shuffle_options", "value": true, "message": "" }
	controller._apply_boss_action(action)
	assert_true(controller._pending_shuffle)

func test_phase_transition_2phase_at_50_percent() -> void:
	controller._boss = null
	controller._current_phase = 1
	controller.enemy_hp = 50
	controller._check_phase_transition(2)
	assert_eq(controller._current_phase, 2)

func test_phase_transition_does_not_downgrade() -> void:
	controller._current_phase = 2
	controller.enemy_hp = 80
	controller._check_phase_transition(2)
	assert_eq(controller._current_phase, 2)

func test_shuffle_question_options_remaps_correct_index() -> void:
	var q: Dictionary = {
		"id": "q1",
		"options": ["A", "B", "C", "D"],
		"correct_index": 0,
	}
	var shuffled: Dictionary = controller._shuffle_question_options(q)
	var correct_answer: String = shuffled["options"][shuffled["correct_index"]]
	assert_eq(correct_answer, "A")
