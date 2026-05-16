## test_word_choice_spice — WordChoiceSpice 测试 + 验证 English pack 含 3 spice
extends GutTest

const WordChoiceSpice = preload("res://src/content/english/spices/word_choice_spice.gd")
const EnglishContentPack = preload("res://src/content/english/english_content_pack.gd")


func _make_spice() -> WordChoiceSpice:
	var s := WordChoiceSpice.new()
	s.target_word = "happy"
	s.prompt_meaning = "高兴的"
	s.choices = ["happy", "sad", "angry", "tired"]
	s.damage_bonus = 25
	return s


func test_correct_choice_returns_success() -> void:
	var s := _make_spice()
	var r: SpiceResult = s.evaluate("happy")
	assert_true(r.success, "correct choice should succeed")
	assert_eq(r.quality, 1.0)
	assert_eq(int(r.effect_payload.get("extra_damage", 0)), 25)


func test_wrong_choice_returns_failure() -> void:
	var s := _make_spice()
	var r: SpiceResult = s.evaluate("sad")
	assert_false(r.success)
	assert_eq(r.quality, 0.0)


func test_case_insensitive_match() -> void:
	var s := _make_spice()
	var r: SpiceResult = s.evaluate("HAPPY")
	assert_true(r.success, "uppercase should still match")


func test_dict_input_with_choice_key() -> void:
	var s := _make_spice()
	var r: SpiceResult = s.evaluate({"choice": "happy"})
	assert_true(r.success, "Dictionary{choice:…} input should work")


func test_empty_input_fails() -> void:
	var s := _make_spice()
	var r: SpiceResult = s.evaluate("")
	assert_false(r.success)


func test_metadata() -> void:
	var s := _make_spice()
	assert_eq(s.get_id(), "word_choice")
	assert_ne(s.get_display_name(), "")
	assert_ne(s.get_description(), "")


func test_english_pack_provides_three_spices() -> void:
	# 验证 English pack 注册了 voice + dictation + word_choice 三个
	var pack := EnglishContentPack.new()
	add_child_autofree(pack)
	var spices: Array = pack.get_available_spices()
	assert_gte(spices.size(), 3, "English pack must provide at least 3 spices")
	var ids: Array = []
	for s in spices:
		if s != null and s.has_method("get_id"):
			ids.append(s.get_id())
	assert_true("voice_scroll" in ids, "voice_scroll spice registered")
	assert_true("dictation" in ids, "dictation spice registered")
	assert_true("word_choice" in ids, "word_choice spice registered")
