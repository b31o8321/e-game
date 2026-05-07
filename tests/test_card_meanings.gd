## Tests for Card meaning / phonetic / audio_path enrichment (Phase 4.x).
##
## Verifies:
##   - Card.from_dict / to_dict round-trips meaning / example / phonetic
##   - All non-letter word cards in cards.json have a populated meaning
##   - Audio paths reference files that actually exist (skip empty)
##   - CardMiniView renders without errors when given a card
##   - CardAudio.play_card_audio handles empty / missing paths gracefully
extends GutTest


const CARDS_JSON_PATH := "res://src/content/english/data/cards.json"


# ───── Card.from_dict / to_dict round-trip ────────────────────────────

func test_card_roundtrip_preserves_meaning_and_examples() -> void:
	var src := {
		"id": "card_brave",
		"text": "brave",
		"type": "word",
		"pos": "adjective",
		"tags": ["positive_emotion"],
		"skill": "vocab",
		"base_damage": 8,
		"rarity": "common",
		"audio_path": "res://src/content/english/audio/words/brave.mp3",
		"phonetic": "[breɪv]",
		"meaning": "勇敢的",
		"example_en": "The brave knight saved the village.",
		"example_zh": "勇敢的骑士救了村庄。",
	}
	var c := Card.from_dict(src)
	assert_eq(c.meaning, "勇敢的")
	assert_eq(c.phonetic, "[breɪv]")
	assert_eq(c.example_en, "The brave knight saved the village.")
	assert_eq(c.example_zh, "勇敢的骑士救了村庄。")
	var d := c.to_dict()
	assert_eq(d["meaning"], "勇敢的")
	assert_eq(d["phonetic"], "[breɪv]")
	assert_eq(d["example_en"], "The brave knight saved the village.")
	assert_eq(d["example_zh"], "勇敢的骑士救了村庄。")
	# 完整 round-trip
	var c2 := Card.from_dict(d)
	assert_eq(c2.meaning, c.meaning)
	assert_eq(c2.example_en, c.example_en)


func test_card_missing_new_fields_default_to_empty_string() -> void:
	var c := Card.from_dict({"id": "x", "text": "x"})
	assert_eq(c.meaning, "")
	assert_eq(c.example_en, "")
	assert_eq(c.example_zh, "")
	assert_eq(c.phonetic, "")


# ───── cards.json content audit ───────────────────────────────────────

func _load_cards_json() -> Array:
	if not FileAccess.file_exists(CARDS_JSON_PATH):
		return []
	var f := FileAccess.open(CARDS_JSON_PATH, FileAccess.READ)
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return []
	var arr_v: Variant = (parsed as Dictionary).get("cards", [])
	return arr_v if arr_v is Array else []


func test_all_non_letter_word_cards_have_meanings() -> void:
	var cards: Array = _load_cards_json()
	assert_gt(cards.size(), 0, "cards.json should not be empty")
	var missing: Array[String] = []
	for entry in cards:
		if not (entry is Dictionary):
			continue
		var card_dict: Dictionary = entry
		var ctype := str(card_dict.get("type", ""))
		var pos := str(card_dict.get("pos", ""))
		# 字母 / 韵脚卡片不强制要 meaning（letter 实际上有 "字母 X" meaning，韵脚是简短说明）
		# 这里只 enforce word + 非 letter 的实义词
		if ctype == "word" and pos != "letter":
			var meaning := str(card_dict.get("meaning", ""))
			if meaning.is_empty():
				missing.append(str(card_dict.get("id", "?")))
	assert_eq(missing.size(), 0,
		"These word cards are missing 'meaning': " + ", ".join(missing))


func test_audio_paths_reference_existing_files() -> void:
	var cards: Array = _load_cards_json()
	var bad: Array[String] = []
	for entry in cards:
		if not (entry is Dictionary):
			continue
		var card_dict: Dictionary = entry
		var ap := str(card_dict.get("audio_path", ""))
		if ap.is_empty():
			continue
		if not ResourceLoader.exists(ap):
			bad.append(str(card_dict.get("id", "?")) + " → " + ap)
	assert_eq(bad.size(), 0,
		"Cards reference non-existent audio: " + "; ".join(bad))


func test_letter_cards_have_letter_audio() -> void:
	var cards: Array = _load_cards_json()
	var checked := 0
	for entry in cards:
		if not (entry is Dictionary):
			continue
		var card_dict: Dictionary = entry
		if str(card_dict.get("pos", "")) != "letter":
			continue
		checked += 1
		var ap := str(card_dict.get("audio_path", ""))
		assert_true(ap.begins_with("res://src/content/english/audio/letters/"),
			"Letter card audio_path looks wrong: " + str(card_dict.get("id")) + " → " + ap)
	assert_gt(checked, 0, "Should have found letter cards")


# ───── CardMiniView smoke test ────────────────────────────────────────

func test_card_mini_view_renders_without_errors() -> void:
	var scene: PackedScene = load("res://src/battle/cards/card_mini_view.tscn")
	assert_not_null(scene, "card_mini_view.tscn should load")
	var view := scene.instantiate() as CardMiniView
	assert_not_null(view, "CardMiniView should instantiate")
	add_child_autofree(view)
	var c := Card.from_dict({
		"id": "card_test",
		"text": "brave",
		"type": "word",
		"pos": "adjective",
		"meaning": "勇敢的",
		"phonetic": "[breɪv]",
		"audio_path": "",
		"base_damage": 8,
	})
	view.set_card(c)
	# 强制走一次 refresh 路径
	view.refresh()
	# 关键节点都应该存在并可访问
	assert_not_null(view.get_node_or_null("Layout/TextLabel"))
	assert_not_null(view.get_node_or_null("Layout/PhoneticLabel"))
	assert_not_null(view.get_node_or_null("Layout/MeaningLabel"))


# ───── CardAudio safety ───────────────────────────────────────────────

func test_card_audio_empty_path_returns_silently() -> void:
	var c := Card.from_dict({"id": "x", "text": "x", "audio_path": ""})
	var parent := Node.new()
	add_child_autofree(parent)
	# 不应抛错
	CardAudio.play_card_audio(c, parent)
	assert_eq(parent.get_child_count(), 0,
		"No AudioStreamPlayer should be created when audio_path empty")


func test_card_audio_missing_file_returns_silently() -> void:
	var c := Card.from_dict({
		"id": "x", "text": "x",
		"audio_path": "res://does/not/exist.mp3",
	})
	var parent := Node.new()
	add_child_autofree(parent)
	CardAudio.play_card_audio(c, parent)
	assert_eq(parent.get_child_count(), 0,
		"No AudioStreamPlayer should be created when file missing")
	# push_warning 触发；GUT 默认不把 warning 当失败
