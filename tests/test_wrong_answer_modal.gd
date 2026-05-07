## test_wrong_answer_modal — verifies the educational feedback modal renders
## correct-answer info and dismisses cleanly.
extends GutTest


const MODAL_SCENE: String = "res://src/battle/wrong_answer_modal.tscn"


func _make_card_full() -> Card:
	return Card.from_dict({
		"id": "card_lazy",
		"text": "lazy",
		"type": "word",
		"pos": "adjective",
		"tags": ["negative_emotion"],
		"meaning": "懒惰的",
		"phonetic": "[ˈleɪzi]",
		"example_en": "He is lazy.",
		"example_zh": "他很懒。",
		"skill": "vocab",
		"base_damage": 5,
		"rarity": "common",
	})


func _instantiate_modal() -> CanvasLayer:
	var packed: PackedScene = load(MODAL_SCENE)
	assert_not_null(packed, "modal scene must load")
	if packed == null:
		return null
	var inst: CanvasLayer = packed.instantiate() as CanvasLayer
	add_child_autofree(inst)
	return inst


func test_modal_loads_and_has_core_nodes() -> void:
	var modal: CanvasLayer = _instantiate_modal()
	assert_not_null(modal)
	assert_not_null(modal.get_node_or_null("Root"))
	assert_not_null(modal.get_node_or_null("Root/CenterPanel"))
	assert_not_null(modal.get_node_or_null("Root/CenterPanel/Box/CorrectWordLabel"))
	assert_not_null(modal.get_node_or_null("Root/CenterPanel/Box/Buttons/OkButton"))


func test_modal_renders_correct_answer_text() -> void:
	var modal: CanvasLayer = _instantiate_modal()
	await get_tree().process_frame
	var card: Card = _make_card_full()
	modal.call("setup", "I feel positive ___", card)
	await get_tree().process_frame

	var dlg_lbl: Label = modal.get_node("Root/CenterPanel/Box/DialogueLabel")
	var word_lbl: Label = modal.get_node("Root/CenterPanel/Box/CorrectWordLabel")
	var meaning_lbl: Label = modal.get_node("Root/CenterPanel/Box/MeaningLabel")
	var phonetic_lbl: Label = modal.get_node("Root/CenterPanel/Box/PhoneticLabel")
	assert_eq(dlg_lbl.text, "I feel positive ___")
	assert_eq(word_lbl.text, "lazy")
	assert_string_contains(meaning_lbl.text, "懒惰的")
	assert_string_contains(phonetic_lbl.text, "[ˈleɪzi]")


func test_modal_dismiss_emits_signal() -> void:
	# Verify dismissed signal fires when OK button is pressed.
	# Note: modal frees itself afterwards, so we just await the signal.
	var modal: CanvasLayer = _instantiate_modal()
	await get_tree().process_frame
	modal.call("setup", "Hello ___", _make_card_full())
	var got_dismissed: Array[bool] = [false]
	modal.dismissed.connect(func() -> void:
		got_dismissed[0] = true
	)
	# Trigger dismiss directly via the OK button's pressed signal handler.
	if modal.has_method("_on_dismiss_pressed"):
		modal.call("_on_dismiss_pressed")
	# Wait for the fade tween (0.2s) + finalize callback.
	await get_tree().create_timer(0.35).timeout
	assert_true(got_dismissed[0],
		"modal must emit dismissed when closed")


func test_modal_handles_null_correct_card_gracefully() -> void:
	var modal: CanvasLayer = _instantiate_modal()
	await get_tree().process_frame
	modal.call("setup", "I am very ___", null)
	await get_tree().process_frame
	var word_lbl: Label = modal.get_node("Root/CenterPanel/Box/CorrectWordLabel")
	# Should fallback to placeholder rather than crash.
	assert_string_contains(word_lbl.text, "暂无")
