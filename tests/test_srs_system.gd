extends GutTest

var srs: SRSSystem

func before_each():
	srs = SRSSystem.new()
	add_child_autofree(srs)

func test_new_question_has_default_priority():
	var priority = srs.get_priority("q_001")
	assert_eq(priority, 0.0)

func test_wrong_answer_increases_priority():
	srs.record_answer("q_001", false)
	assert_gt(srs.get_priority("q_001"), 0.0)

func test_correct_answer_decreases_priority():
	srs.record_answer("q_001", false)
	srs.record_answer("q_001", false)
	var priority_before = srs.get_priority("q_001")
	srs.record_answer("q_001", true)
	assert_lt(srs.get_priority("q_001"), priority_before)

func test_next_question_prefers_high_priority():
	srs.record_answer("q_low", true)
	srs.record_answer("q_low", true)
	srs.record_answer("q_high", false)
	srs.record_answer("q_high", false)
	srs.record_answer("q_high", false)
	var candidates: Array[String] = ["q_low", "q_high"]
	var picked = srs.pick_question(candidates)
	assert_eq(picked, "q_high")

func test_save_and_load():
	srs.record_answer("q_001", false)
	var data = srs.serialize()
	var srs2 = SRSSystem.new()
	add_child_autofree(srs2)
	srs2.deserialize(data)
	assert_eq(srs2.get_priority("q_001"), srs.get_priority("q_001"))
