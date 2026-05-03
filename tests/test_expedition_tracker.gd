extends GutTest

var tracker: ExpeditionTracker

func before_each() -> void:
	tracker = ExpeditionTracker.new()
	add_child_autofree(tracker)

func test_initial_report_has_zero_questions() -> void:
	var report: Dictionary = tracker.build_report()
	assert_eq(report.get("total_questions", -1), 0)

func test_record_answer_increments_total() -> void:
	tracker.record_answer("q1", "vocabulary", true)
	tracker.record_answer("q2", "vocabulary", false)
	tracker.record_answer("q3", "grammar", true)
	var report: Dictionary = tracker.build_report()
	assert_eq(report["total_questions"], 3)

func test_correct_count_tracks_only_correct() -> void:
	tracker.record_answer("q1", "vocabulary", true)
	tracker.record_answer("q2", "vocabulary", false)
	tracker.record_answer("q3", "grammar", true)
	var report: Dictionary = tracker.build_report()
	assert_eq(report["correct_count"], 2)

func test_accuracy_calculation() -> void:
	tracker.record_answer("q1", "vocabulary", true)
	tracker.record_answer("q2", "vocabulary", true)
	tracker.record_answer("q3", "grammar", false)
	tracker.record_answer("q4", "grammar", false)
	var report: Dictionary = tracker.build_report()
	assert_almost_eq(report["accuracy"], 0.5, 0.001)

func test_by_attack_type_tracking() -> void:
	tracker.record_answer("q1", "vocabulary", true)
	tracker.record_answer("q2", "vocabulary", false)
	tracker.record_answer("q3", "vocabulary", true)  # vocab: 2/3
	tracker.record_answer("q4", "grammar", true)     # grammar: 1/1
	var report: Dictionary = tracker.build_report()
	var by_type: Dictionary = report["by_attack_type"]
	assert_eq(by_type["vocabulary"]["correct"], 2)
	assert_eq(by_type["vocabulary"]["total"], 3)
	assert_eq(by_type["grammar"]["correct"], 1)
	assert_eq(by_type["grammar"]["total"], 1)

func test_most_wrong_ids_contains_wrong_question() -> void:
	tracker.record_answer("q_bad", "vocabulary", false)
	tracker.record_answer("q_bad", "vocabulary", false)
	tracker.record_answer("q_good", "vocabulary", true)
	var report: Dictionary = tracker.build_report()
	var wrong_ids: Dictionary = report["most_wrong_ids"]
	assert_true(wrong_ids.has("q_bad"))
	assert_eq(wrong_ids["q_bad"], 2)
	assert_false(wrong_ids.has("q_good"))

func test_peak_combo_tracked() -> void:
	tracker.update_peak_combo(3)
	tracker.update_peak_combo(7)
	tracker.update_peak_combo(5)  # lower — shouldn't override
	var report: Dictionary = tracker.build_report()
	assert_eq(report["peak_combo"], 7)

func test_reset_clears_all_data() -> void:
	tracker.record_answer("q1", "vocabulary", true)
	tracker.update_peak_combo(10)
	tracker.reset()
	var report: Dictionary = tracker.build_report()
	assert_eq(report["total_questions"], 0)
	assert_eq(report["peak_combo"], 0)
