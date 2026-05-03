extends GutTest

var _pack: EnglishContentPack

func before_each() -> void:
	_pack = EnglishContentPack.new()
	add_child(_pack)
	GameState.player_grade = 5

func after_each() -> void:
	_pack.queue_free()

func test_get_question_vocabulary_returns_vocab_type() -> void:
	var q: Dictionary = _pack.get_question("vocabulary", 1, [])
	assert_false(q.is_empty(), "should return a question")
	assert_eq(q.get("attack_type_id", ""), "vocabulary", "type should be vocabulary")

func test_get_question_excludes_ids() -> void:
	var exclude: Array[String] = []
	for i in range(20):
		var q: Dictionary = _pack.get_question("vocabulary", 1, exclude)
		if q.is_empty():
			break
		var qid: String = q.get("id", "")
		assert_false(qid in exclude, "excluded id should not be returned")
		exclude.append(qid)

func test_grade_filter_respects_player_grade() -> void:
	GameState.player_grade = 4
	for i in range(30):
		var q: Dictionary = _pack.get_question("", 1, [])
		if q.is_empty():
			break
		assert_true(q.get("grade", 0) <= 4, "grade should be <= 4 when player_grade is 4")

func test_get_gate_questions_returns_correct_count() -> void:
	var questions: Array[Dictionary] = _pack.get_gate_questions("gate_en_librarian", 8)
	assert_eq(questions.size(), 8, "should return exactly 8 questions")

func test_get_gate_questions_no_duplicates() -> void:
	var questions: Array[Dictionary] = _pack.get_gate_questions("gate_en_librarian", 8)
	var ids: Array[String] = []
	for q in questions:
		var qid: String = q.get("id", "")
		assert_false(qid in ids, "duplicate id found: " + qid)
		ids.append(qid)

func test_get_gates_contains_librarian() -> void:
	var gates: Array[Dictionary] = _pack.get_gates()
	var found := false
	for gate in gates:
		if gate.get("gate_id", "") == "gate_en_librarian":
			found = true
			break
	assert_true(found, "gates should contain gate_en_librarian")

func test_get_question_by_id_returns_correct() -> void:
	var q: Dictionary = _pack.get_question_by_id("q_vocab_001")
	assert_false(q.is_empty(), "should return a question")
	assert_eq(q.get("id", ""), "q_vocab_001", "id should match requested id")
