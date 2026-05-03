extends GutTest

var controller: QuestionController
var mock_pack: MockContentPack

func before_each() -> void:
	controller = QuestionController.new()
	add_child_autofree(controller)
	mock_pack = MockContentPack.new()

func test_load_question_sets_current() -> void:
	var q: Dictionary = mock_pack.get_question("vocabulary", 1, [])
	controller.load_question(q)
	assert_eq(controller.current_question["id"], "q_mock_001")

func test_answer_correct_emits_signal() -> void:
	watch_signals(controller)
	var q: Dictionary = mock_pack.get_question("vocabulary", 1, [])
	controller.load_question(q)
	controller.submit_answer(0)
	assert_signal_emitted(controller, "answered")
	assert_signal_emitted_with_parameters(controller, "answered", [true, "q_mock_001"])

func test_answer_wrong_emits_signal() -> void:
	watch_signals(controller)
	var q: Dictionary = mock_pack.get_question("vocabulary", 1, [])
	controller.load_question(q)
	controller.submit_answer(1)
	assert_signal_emitted_with_parameters(controller, "answered", [false, "q_mock_001"])

func test_timer_expiry_counts_as_wrong() -> void:
	watch_signals(controller)
	var q: Dictionary = mock_pack.get_question("vocabulary", 1, [])
	controller.load_question(q)
	controller.on_timer_expired()
	assert_signal_emitted_with_parameters(controller, "answered", [false, "q_mock_001"])
