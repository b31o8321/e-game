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

func test_get_question_unknown_type_returns_empty() -> void:
	var q: Dictionary = _pack.get_question("nonexistent_type", 1, [])
	assert_true(q.is_empty(), "unknown attack_type_id should return empty dict")

func test_get_question_by_id_missing_returns_empty() -> void:
	var q: Dictionary = _pack.get_question_by_id("does_not_exist")
	assert_true(q.is_empty(), "missing id should return empty dict")


# ─── 按楼层定制起手卡组（解决"题目和手卡对不上"）─────────────────

func test_get_starting_deck_for_floor_0F_letters_heavy() -> void:
	var ids: Array[String] = _pack.get_starting_deck_for_floor("0F")
	assert_gt(ids.size(), 0, "0F starting deck should be non-empty")
	# 0F 必须以字母 / 高频词 / 音节为主
	var letter_count: int = 0
	var sight_word_count: int = 0
	var syllable_count: int = 0
	for cid in ids:
		var card: Card = _pack.get_card(cid)
		assert_not_null(card, "card %s should exist" % cid)
		if card == null:
			continue
		match card.pos:
			"letter": letter_count += 1
			"sight_word": sight_word_count += 1
			"syllable": syllable_count += 1
	assert_gt(letter_count, 0, "0F deck should include letter cards")
	assert_gt(sight_word_count, 0, "0F deck should include sight word cards")
	# 至少应该没有形容词卡（因为 0F 与 1F 主题不重合）
	for cid in ids:
		var card: Card = _pack.get_card(cid)
		if card == null:
			continue
		assert_ne(card.pos, "adjective",
			"0F deck must NOT contain adjective cards: %s" % cid)


func test_get_starting_deck_for_floor_2F_nouns_pronouns() -> void:
	var ids: Array[String] = _pack.get_starting_deck_for_floor("2F")
	assert_gt(ids.size(), 0, "2F starting deck should be non-empty")
	var noun_count: int = 0
	var pronoun_count: int = 0
	for cid in ids:
		var card: Card = _pack.get_card(cid)
		if card == null:
			continue
		if card.pos == "noun":
			noun_count += 1
		elif card.pos == "pronoun":
			pronoun_count += 1
	assert_gt(noun_count, 0, "2F deck should include noun cards (family/body)")
	assert_gt(pronoun_count, 0, "2F deck should include pronoun cards")


func test_get_starting_deck_for_floor_1F_falls_back_to_default() -> void:
	# 1F 复用通用 starting deck（形容词为主）
	var floor_ids: Array[String] = _pack.get_starting_deck_for_floor("1F")
	var default_ids: Array[String] = _pack.get_starting_deck_card_ids()
	assert_eq(floor_ids.size(), default_ids.size(), "1F deck size matches default")
	for cid in floor_ids:
		assert_true(cid in default_ids, "1F deck %s should be in default" % cid)


func test_get_starting_deck_for_floor_unknown_falls_back() -> void:
	var ids: Array[String] = _pack.get_starting_deck_for_floor("999F_unknown")
	var default_ids: Array[String] = _pack.get_starting_deck_card_ids()
	assert_eq(ids, default_ids, "unknown floor falls back to default starting deck")
