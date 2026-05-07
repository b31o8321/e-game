extends GutTest

const FeedbackSystemScript = preload("res://src/feedback/feedback_system.gd")

func _make() -> Node:
	var n = FeedbackSystemScript.new()
	add_child_autofree(n)
	n._persist_path_override = "user://test_feedback.jsonl"
	# 清空旧测试数据
	if FileAccess.file_exists(n._persist_path_override):
		DirAccess.remove_absolute(n._persist_path_override)
	return n


func test_report_writes_jsonl():
	var n = _make()
	n.report("question", "1F_emo", "answer_unreasonable", "正确答案不合理")
	var lines = n.get_all()
	assert_eq(lines.size(), 1)
	assert_eq(lines[0]["type"], "question")
	assert_eq(lines[0]["id"], "1F_emo")
	assert_eq(lines[0]["reason"], "answer_unreasonable")


func test_report_multiple_appends():
	var n = _make()
	n.report("question", "x", "other", "")
	n.report("card", "card_brave", "meaning_wrong", "")
	n.report("question", "y", "audio_missing", "")
	var lines = n.get_all()
	assert_eq(lines.size(), 3)


func test_export_returns_valid_json():
	var n = _make()
	n.report("card", "card_brave", "meaning_wrong", "")
	var s = n.export_json()
	var parsed = JSON.parse_string(s)
	assert_not_null(parsed)
	assert_true(parsed is Array)
	assert_eq(parsed.size(), 1)


func test_clear_empties():
	var n = _make()
	n.report("question", "x", "other", "")
	assert_eq(n.get_all().size(), 1)
	n.clear()
	assert_eq(n.get_all().size(), 0)


func test_get_all_with_no_file_returns_empty():
	var n = _make()
	# Already cleared in setup
	assert_eq(n.get_all().size(), 0)
