extends GutTest

var node_: ResourceNode
var mock_pack: MockContentPack

func before_each() -> void:
	node_ = ResourceNode.new()
	add_child_autofree(node_)
	node_.resource_type_id = "vocabulary_crystal"
	node_.resource_amount = 3
	node_.attack_type_id = "vocabulary"
	mock_pack = MockContentPack.new()
	GameState.inventory_resources = {}

func test_initial_state_is_available() -> void:
	assert_eq(node_.node_state, ResourceNode.NodeState.AVAILABLE)

func test_try_collect_changes_state_to_pending() -> void:
	node_.try_collect(mock_pack)
	assert_eq(node_.node_state, ResourceNode.NodeState.PENDING_ANSWER)

func test_try_collect_emits_question_requested() -> void:
	watch_signals(node_)
	node_.try_collect(mock_pack)
	assert_signal_emitted(node_, "question_requested")

func test_correct_answer_adds_resource_to_game_state() -> void:
	node_.try_collect(mock_pack)
	node_.on_question_answered(true)
	assert_eq(GameState.inventory_resources.get("vocabulary_crystal", 0), 3)

func test_correct_answer_marks_collected() -> void:
	node_.try_collect(mock_pack)
	node_.on_question_answered(true)
	assert_eq(node_.node_state, ResourceNode.NodeState.COLLECTED)

func test_wrong_answer_resets_to_available() -> void:
	node_.try_collect(mock_pack)
	node_.on_question_answered(false)
	assert_eq(node_.node_state, ResourceNode.NodeState.AVAILABLE)
	assert_eq(GameState.inventory_resources.get("vocabulary_crystal", 0), 0)

func test_try_collect_ignored_when_pending() -> void:
	node_.try_collect(mock_pack)
	node_.try_collect(mock_pack)  # second call should be ignored
	assert_eq(node_.node_state, ResourceNode.NodeState.PENDING_ANSWER)
