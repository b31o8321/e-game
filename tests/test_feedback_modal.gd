extends GutTest

const FeedbackModalScene = preload("res://src/feedback/feedback_modal.tscn")


func test_modal_loads():
	var m = FeedbackModalScene.instantiate()
	add_child_autofree(m)
	assert_not_null(m.get_node_or_null("Card"))
	assert_not_null(m.get_node_or_null("Card/VBox/HeaderLabel"))
	assert_not_null(m.get_node_or_null("Card/VBox/ContentLabel"))


func test_setup_with_question_populates_header_and_content():
	var m = FeedbackModalScene.instantiate()
	add_child_autofree(m)
	m.setup("question", "1F_emo", "I am very ___")
	var header = m.get_node("Card/VBox/HeaderLabel") as Label
	var content = m.get_node("Card/VBox/ContentLabel") as Label
	assert_true("题" in header.text)
	assert_true("I am very ___" in content.text)


func test_setup_with_card_uses_card_label():
	var m = FeedbackModalScene.instantiate()
	add_child_autofree(m)
	m.setup("card", "card_brave", "brave")
	var header = m.get_node("Card/VBox/HeaderLabel") as Label
	assert_true("卡" in header.text)


func test_submit_emits_signal():
	var m = FeedbackModalScene.instantiate()
	add_child_autofree(m)
	m.setup("question", "1F_emo", "I am very ___")
	# GDScript lambdas capture by value, so use a Dictionary (reference type)
	# to record what the signal handler observed.
	var captured := {"emitted": false, "type": "", "reason": ""}
	m.submitted.connect(func(t: String, r: String, c: String):
		captured["emitted"] = true
		captured["type"] = t
		captured["reason"] = r
	)
	m._on_submit("answer_unreasonable", "测试评论")
	assert_true(captured["emitted"])
	assert_eq(captured["type"], "question")
	assert_eq(captured["reason"], "answer_unreasonable")
