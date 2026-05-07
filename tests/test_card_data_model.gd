## Tests for Card / ChallengeSlot / ChallengeTemplate data layer
## (Phase 1.2 — pure data, no battle logic)
extends GutTest


# ---------- helpers ----------

func _make_card(overrides: Dictionary = {}) -> Card:
	var base := {
		"id": "card_test",
		"text": "test",
		"type": "word",
		"pos": "adjective",
		"tags": ["positive_emotion"],
		"skill": "vocab",
		"base_damage": 5,
		"rarity": "common",
	}
	for k in overrides.keys():
		base[k] = overrides[k]
	return Card.from_dict(base)


func _make_slot(overrides: Dictionary = {}) -> ChallengeSlot:
	var base := {
		"index": 0,
		"required_type": "",
		"required_pos": "",
		"required_tags": [],
		"forbidden_tags": [],
		"damage_multiplier": 1.0,
	}
	for k in overrides.keys():
		base[k] = overrides[k]
	return ChallengeSlot.from_dict(base)


# ---------- Card.from_dict ----------

func test_card_from_dict_full() -> void:
	var data := {
		"id": "card_brave",
		"text": "brave",
		"type": "word",
		"pos": "adjective",
		"tags": ["positive_emotion", "personality"],
		"skill": "vocab",
		"base_damage": 8,
		"rarity": "common",
		"on_play_effect": "buff_atk",
		"icon_path": "res://icons/brave.png",
		"audio_path": "res://audio/brave.ogg",
	}
	var c := Card.from_dict(data)
	assert_eq(c.id, "card_brave")
	assert_eq(c.text, "brave")
	assert_eq(c.type, "word")
	assert_eq(c.pos, "adjective")
	assert_eq(c.tags.size(), 2)
	assert_true("positive_emotion" in c.tags)
	assert_true("personality" in c.tags)
	assert_eq(c.skill, "vocab")
	assert_eq(c.base_damage, 8)
	assert_eq(c.rarity, "common")
	assert_eq(c.on_play_effect, "buff_atk")
	assert_eq(c.icon_path, "res://icons/brave.png")
	assert_eq(c.audio_path, "res://audio/brave.ogg")


func test_card_from_dict_missing_optional_fields_uses_defaults() -> void:
	# 只给最少字段（id + text + type）
	var c := Card.from_dict({"id": "c1", "text": "x", "type": "word"})
	assert_eq(c.id, "c1")
	assert_eq(c.text, "x")
	assert_eq(c.type, "word")
	assert_eq(c.pos, "")
	assert_eq(c.tags, [] as Array[String])
	assert_eq(c.skill, "")
	assert_eq(c.base_damage, 0)
	assert_eq(c.rarity, "common")
	assert_eq(c.on_play_effect, "")
	assert_eq(c.icon_path, "")
	assert_eq(c.audio_path, "")


func test_card_from_dict_empty_dict() -> void:
	var c := Card.from_dict({})
	assert_eq(c.id, "")
	assert_eq(c.text, "")
	assert_eq(c.type, "")
	assert_eq(c.base_damage, 0)
	assert_eq(c.rarity, "common")


func test_card_to_dict_roundtrip_preserves_fields() -> void:
	var original := _make_card({"audio_path": "res://x.ogg"})
	var d := original.to_dict()
	var restored := Card.from_dict(d)
	assert_eq(restored.id, original.id)
	assert_eq(restored.tags, original.tags)
	assert_eq(restored.audio_path, original.audio_path)


func test_card_tags_are_stringified() -> void:
	# 保护：JSON 里数字混进 tag 数组也不应崩
	var c := Card.from_dict({"id": "x", "tags": ["a", 42]})
	assert_eq(c.tags.size(), 2)
	assert_eq(c.tags[0], "a")
	assert_eq(c.tags[1], "42")


# ---------- ChallengeSlot.from_dict ----------

func test_challenge_slot_from_dict_full() -> void:
	var slot := ChallengeSlot.from_dict({
		"index": 2,
		"required_type": "word",
		"required_pos": "adjective",
		"required_tags": ["positive_emotion"],
		"forbidden_tags": ["negation"],
		"damage_multiplier": 1.5,
	})
	assert_eq(slot.index, 2)
	assert_eq(slot.required_type, "word")
	assert_eq(slot.required_pos, "adjective")
	assert_eq(slot.required_tags, ["positive_emotion"] as Array[String])
	assert_eq(slot.forbidden_tags, ["negation"] as Array[String])
	assert_almost_eq(slot.damage_multiplier, 1.5, 0.0001)


func test_challenge_slot_from_dict_defaults() -> void:
	var slot := ChallengeSlot.from_dict({})
	assert_eq(slot.index, 0)
	assert_eq(slot.required_type, "")
	assert_eq(slot.required_pos, "")
	assert_eq(slot.required_tags, [] as Array[String])
	assert_eq(slot.forbidden_tags, [] as Array[String])
	assert_almost_eq(slot.damage_multiplier, 1.0, 0.0001)
	assert_eq(slot.accept_card_ids, [] as Array[String])
	assert_eq(slot.tag_match_mode, "any")


func test_challenge_slot_from_dict_accept_card_ids() -> void:
	var slot := ChallengeSlot.from_dict({
		"accept_card_ids": ["card_happy", "card_excited"],
		"tag_match_mode": "all",
	})
	assert_eq(slot.accept_card_ids.size(), 2)
	assert_true("card_happy" in slot.accept_card_ids)
	assert_true("card_excited" in slot.accept_card_ids)
	assert_eq(slot.tag_match_mode, "all")


func test_challenge_slot_to_dict_includes_new_fields() -> void:
	var slot := ChallengeSlot.from_dict({
		"accept_card_ids": ["card_a"],
		"tag_match_mode": "all",
		"required_tags": ["positive_emotion"],
	})
	var d := slot.to_dict()
	assert_true(d.has("accept_card_ids"))
	assert_true(d.has("tag_match_mode"))
	assert_eq(d["tag_match_mode"], "all")


# ---------- CardValidator.can_place ----------

func test_can_place_unconstrained_slot_accepts_any_card() -> void:
	var card := _make_card()
	var slot := _make_slot()
	assert_true(CardValidator.can_place(card, slot))


func test_can_place_type_match() -> void:
	var card := _make_card({"type": "word"})
	var slot := _make_slot({"required_type": "word"})
	assert_true(CardValidator.can_place(card, slot))


func test_can_place_type_mismatch() -> void:
	var card := _make_card({"type": "sound"})
	var slot := _make_slot({"required_type": "word"})
	assert_false(CardValidator.can_place(card, slot))


func test_can_place_pos_match() -> void:
	var card := _make_card({"pos": "adjective"})
	var slot := _make_slot({"required_pos": "adjective"})
	assert_true(CardValidator.can_place(card, slot))


func test_can_place_pos_mismatch() -> void:
	var card := _make_card({"pos": "noun"})
	var slot := _make_slot({"required_pos": "adjective"})
	assert_false(CardValidator.can_place(card, slot))


func test_can_place_required_tags_any_match() -> void:
	# 槽要 any of [positive_emotion, animal]，卡有 positive_emotion → 通过
	var card := _make_card({"tags": ["positive_emotion", "personality"]})
	var slot := _make_slot({"required_tags": ["positive_emotion", "animal"]})
	assert_true(CardValidator.can_place(card, slot))


func test_can_place_required_tags_no_intersection() -> void:
	var card := _make_card({"tags": ["personality"]})
	var slot := _make_slot({"required_tags": ["positive_emotion", "animal"]})
	assert_false(CardValidator.can_place(card, slot))


func test_can_place_forbidden_tag_blocks() -> void:
	var card := _make_card({"tags": ["positive_emotion", "negation"]})
	var slot := _make_slot({"forbidden_tags": ["negation"]})
	assert_false(CardValidator.can_place(card, slot))


func test_can_place_forbidden_tag_no_intersection_passes() -> void:
	var card := _make_card({"tags": ["positive_emotion"]})
	var slot := _make_slot({"forbidden_tags": ["negation"]})
	assert_true(CardValidator.can_place(card, slot))


func test_can_place_required_and_forbidden_combined() -> void:
	# 命中 required 但同时被 forbidden 拦下
	var card := _make_card({"tags": ["positive_emotion", "negation"]})
	var slot := _make_slot({
		"required_tags": ["positive_emotion"],
		"forbidden_tags": ["negation"],
	})
	assert_false(CardValidator.can_place(card, slot))


func test_can_place_all_constraints_satisfied() -> void:
	var card := _make_card({
		"type": "word",
		"pos": "adjective",
		"tags": ["positive_emotion", "personality"],
	})
	var slot := _make_slot({
		"required_type": "word",
		"required_pos": "adjective",
		"required_tags": ["positive_emotion"],
		"forbidden_tags": ["negation"],
	})
	assert_true(CardValidator.can_place(card, slot))


func test_can_place_null_inputs_return_false() -> void:
	var slot := _make_slot()
	var card := _make_card()
	assert_false(CardValidator.can_place(null, slot))
	assert_false(CardValidator.can_place(card, null))


# ---------- CardLoader.load_cards_from_json ----------

func test_load_cards_from_json_object_format() -> void:
	var cards := CardLoader.load_cards_from_json("res://tests/fixtures/test_cards.json")
	assert_eq(cards.size(), 2)
	assert_eq(cards[0].id, "test_brave")
	assert_eq(cards[0].type, "word")
	assert_eq(cards[0].pos, "adjective")
	assert_eq(cards[0].base_damage, 8)
	assert_true("positive_emotion" in cards[0].tags)
	assert_eq(cards[1].id, "test_sound_brave")
	assert_eq(cards[1].type, "sound")
	assert_eq(cards[1].audio_path, "res://test/audio/brave.ogg")


func test_load_cards_from_json_bare_array_format() -> void:
	var cards := CardLoader.load_cards_from_json("res://tests/fixtures/test_cards_array.json")
	assert_eq(cards.size(), 1)
	assert_eq(cards[0].id, "bare_card_1")


func test_load_cards_from_json_malformed_returns_empty() -> void:
	# 期望 push_error 被调用一次（损坏 JSON 解析失败）
	var cards := CardLoader.load_cards_from_json("res://tests/fixtures/test_cards_malformed.json")
	assert_eq(cards.size(), 0)
	assert_push_error_count(1, "malformed JSON 应触发一次 push_error")


func test_load_cards_from_json_missing_file_returns_empty() -> void:
	var cards := CardLoader.load_cards_from_json("res://tests/fixtures/does_not_exist.json")
	assert_eq(cards.size(), 0)
	assert_push_error_count(1, "缺失文件应触发一次 push_error")


# ---------- CardLoader.load_challenges_from_json ----------

func test_load_challenges_from_json_object_format() -> void:
	var tmpls := CardLoader.load_challenges_from_json("res://tests/fixtures/test_challenges.json")
	assert_eq(tmpls.size(), 1)
	var t := tmpls[0]
	assert_eq(t.template_id, "fill_in_blank_v1")
	assert_eq(t.kind, "fill_in_blank")
	assert_eq(t.dialogue, "I am very ___")
	assert_eq(t.topic_id, "adjectives_basic")
	assert_eq(t.perfect_match_card_ids, ["test_brave"] as Array[String])
	assert_eq(t.slots.size(), 1)
	var slot := t.slots[0]
	assert_eq(slot.index, 0)
	assert_eq(slot.required_type, "word")
	assert_eq(slot.required_pos, "adjective")
	assert_true("positive_emotion" in slot.required_tags)
	assert_true("negation" in slot.forbidden_tags)


func test_load_challenges_from_json_missing_file_returns_empty() -> void:
	var tmpls := CardLoader.load_challenges_from_json("res://tests/fixtures/does_not_exist_challenges.json")
	assert_eq(tmpls.size(), 0)
	assert_push_error_count(1, "缺失 challenges 文件应触发一次 push_error")


func test_challenge_template_from_dict_uses_array_index_when_slot_missing_index() -> void:
	var t := ChallengeTemplate.from_dict({
		"template_id": "t1",
		"slots": [
			{"required_type": "word"},
			{"required_type": "phrase"},
		],
	})
	assert_eq(t.slots.size(), 2)
	assert_eq(t.slots[0].index, 0)
	assert_eq(t.slots[1].index, 1)
