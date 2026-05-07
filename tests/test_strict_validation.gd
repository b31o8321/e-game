## Tests for the strict CardValidator behavior introduced for the
## "POS-only matching is misleading" educational fix.
##
## Educational rationale: with old "required_pos only" logic, ANY adjective
## could go into "I am very ___" — even "lazy" or "small" — which doesn't
## test if the player understands the meaning. These tests verify:
##
##   1. accept_card_ids whitelist short-circuits other constraints
##   2. tag_match_mode="all" requires ALL tags (not just any)
##   3. tag_match_mode="any" preserves legacy any-match behavior
##   4. forbidden_tags still blocks
##   5. Existing challenges.json all parse without crashing
extends GutTest


func _make_card(overrides: Dictionary = {}) -> Card:
	var base := {
		"id": "card_test",
		"text": "test",
		"type": "word",
		"pos": "adjective",
		"tags": ["positive_emotion", "feeling"],
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
		"accept_card_ids": [],
		"tag_match_mode": "any",
	}
	for k in overrides.keys():
		base[k] = overrides[k]
	return ChallengeSlot.from_dict(base)


# ───────── accept_card_ids whitelist ─────────

func test_accept_card_ids_only_allows_whitelisted_card() -> void:
	var card := _make_card({"id": "card_happy"})
	var slot := _make_slot({"accept_card_ids": ["card_happy", "card_excited"]})
	assert_true(CardValidator.can_place(card, slot))


func test_accept_card_ids_rejects_card_not_in_list() -> void:
	# Card has the right type/pos/tags but its ID isn't whitelisted → rejected.
	# This is the entire point of the fix: "I am very ___" with positive context
	# must NOT accept "card_lazy" just because it's an adjective.
	var card := _make_card({"id": "card_lazy", "tags": ["adjective", "personality"]})
	var slot := _make_slot({
		"accept_card_ids": ["card_happy", "card_excited"],
		"required_pos": "adjective",  # would normally pass!
	})
	assert_false(CardValidator.can_place(card, slot))


func test_accept_card_ids_short_circuits_type_check() -> void:
	# Even if type/pos don't match, accept_card_ids is the sole gate.
	var card := _make_card({"id": "card_special", "type": "phrase", "pos": ""})
	var slot := _make_slot({
		"accept_card_ids": ["card_special"],
		"required_type": "word",  # would normally fail!
		"required_pos": "adjective",
	})
	assert_true(CardValidator.can_place(card, slot))


# ───────── tag_match_mode="all" ─────────

func test_tag_match_mode_all_requires_all_tags() -> void:
	# Card has only one of the two required tags → rejected.
	var card := _make_card({"tags": ["body"]})
	var slot := _make_slot({
		"required_tags": ["body", "paired_appendage"],
		"tag_match_mode": "all",
	})
	assert_false(CardValidator.can_place(card, slot))


func test_tag_match_mode_all_passes_when_all_present() -> void:
	# Card has both required tags → passes.
	var card := _make_card({"tags": ["body", "paired_appendage", "lower_body"]})
	var slot := _make_slot({
		"required_tags": ["body", "paired_appendage"],
		"tag_match_mode": "all",
	})
	assert_true(CardValidator.can_place(card, slot))


func test_tag_match_mode_any_default_preserves_legacy_behavior() -> void:
	# tag_match_mode default is "any" → having ONE of the required_tags suffices.
	var card := _make_card({"tags": ["positive_emotion"]})
	var slot := _make_slot({
		"required_tags": ["positive_emotion", "negative_emotion"],
		# tag_match_mode omitted → defaults to "any"
	})
	assert_true(CardValidator.can_place(card, slot))


func test_tag_match_mode_any_explicit_works_like_default() -> void:
	var card := _make_card({"tags": ["positive_emotion"]})
	var slot := _make_slot({
		"required_tags": ["positive_emotion", "negative_emotion"],
		"tag_match_mode": "any",
	})
	assert_true(CardValidator.can_place(card, slot))


# ───────── forbidden_tags still works alongside new logic ─────────

func test_forbidden_tags_still_blocks_with_strict_required() -> void:
	var card := _make_card({"tags": ["positive_emotion", "feeling", "negation"]})
	var slot := _make_slot({
		"required_tags": ["positive_emotion", "feeling"],
		"tag_match_mode": "all",
		"forbidden_tags": ["negation"],
	})
	assert_false(CardValidator.can_place(card, slot))


# ───────── Educational scenario: "I am very ___" with positive context ─────────

func test_lazy_card_rejected_from_positive_emotion_slot() -> void:
	# This is the bug from the playtest report. Setup:
	#   - Slot expects required_tags=["positive_emotion"], tag_match_mode="all"
	#   - Card "lazy" is adjective + personality + negative_personality
	# Expected: rejected (lazy is not a positive_emotion)
	var lazy := _make_card({
		"id": "card_lazy",
		"pos": "adjective",
		"tags": ["adjective", "negative_personality", "personality"],
	})
	var slot := _make_slot({
		"required_type": "word",
		"required_pos": "adjective",
		"required_tags": ["positive_emotion"],
		"tag_match_mode": "all",
	})
	assert_false(CardValidator.can_place(lazy, slot))


func test_happy_card_accepted_into_positive_emotion_slot() -> void:
	var happy := _make_card({
		"id": "card_happy",
		"pos": "adjective",
		"tags": ["adjective", "positive_emotion", "feeling"],
	})
	var slot := _make_slot({
		"required_type": "word",
		"required_pos": "adjective",
		"required_tags": ["positive_emotion"],
		"tag_match_mode": "all",
	})
	assert_true(CardValidator.can_place(happy, slot))


# ───────── Existing challenges.json parses correctly ─────────

func test_existing_challenges_json_parses_with_new_fields() -> void:
	var tmpls := CardLoader.load_challenges_from_json("res://src/content/english/data/challenges.json")
	assert_gt(tmpls.size(), 0, "challenges.json should load some templates")
	# Spot-check: the curated emotion slot should have accept_card_ids set.
	var found_strict_slot: bool = false
	for tmpl in tmpls:
		for slot in tmpl.slots:
			if not slot.accept_card_ids.is_empty():
				found_strict_slot = true
				break
		if found_strict_slot:
			break
	assert_true(found_strict_slot,
		"Expected at least one slot to use accept_card_ids whitelist")


func test_existing_challenges_have_strict_slots() -> void:
	# Every slot should be either Strategy A (accept_card_ids) or Strategy B
	# (required_tags non-empty) — otherwise it's the old lax "POS-only" mode
	# we're trying to eliminate.
	var tmpls := CardLoader.load_challenges_from_json("res://src/content/english/data/challenges.json")
	var lax_slots: Array[String] = []
	for tmpl in tmpls:
		for slot in tmpl.slots:
			var strict: bool = (not slot.accept_card_ids.is_empty()) or (not slot.required_tags.is_empty())
			if not strict:
				lax_slots.append("%s slot %d" % [tmpl.template_id, slot.index])
	assert_eq(lax_slots.size(), 0,
		"Found lax (POS-only) slots: %s" % str(lax_slots))
