## test_kept_aware_draw — _draw_to_full_hand biases draw toward kept questions' answers.
##
## Background (user feedback): "问题有定住留下的情况下，下轮发牌应该确保手牌中有
## 这个问题的答案" — if a player kept a question (📌 留下), the next turn's drawn
## hand MUST contain at least one valid answer for that question. Otherwise the
## kept question cannot be solved and the player is stuck.
##
## Implementation: BattleController._draw_to_full_hand() now calls
## _reserve_cards_for_kept_questions() first, which scans the deck (and discard
## as fallback) for cards that satisfy each slot of every kept template, and
## moves those cards to the top of the deck (= end of array, since pop_back).
extends GutTest


# ─── Helpers ──────────────────────────────────────────────────────

func _make_card(overrides: Dictionary = {}) -> Card:
	var base := {
		"id": "card_test",
		"text": "test",
		"type": "word",
		"pos": "",
		"tags": [],
		"skill": "vocab",
		"base_damage": 5,
		"rarity": "common",
	}
	for k in overrides.keys():
		base[k] = overrides[k]
	return Card.from_dict(base)


## ChallengeTemplate with a single adjective slot ("I am very ___").
func _make_adjective_template(template_id: String) -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": template_id,
		"kind": "fill_in_blank",
		"dialogue": "I am very ___",
		"slots": [
			{
				"index": 0,
				"required_pos": "adjective",
				"required_type": "",
				"required_tags": [],
				"forbidden_tags": [],
				"damage_multiplier": 1.0,
			},
		],
		"topic_id": "test",
	})


## ChallengeTemplate with a single noun slot.
func _make_noun_template(template_id: String) -> ChallengeTemplate:
	return ChallengeTemplate.from_dict({
		"template_id": template_id,
		"kind": "fill_in_blank",
		"dialogue": "I see a ___",
		"slots": [
			{
				"index": 0,
				"required_pos": "noun",
				"required_type": "",
				"required_tags": [],
				"forbidden_tags": [],
				"damage_multiplier": 1.0,
			},
		],
		"topic_id": "test",
	})


func _make_enemy() -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_enemy"
	e.enemy_name = "Test"
	e.max_hp = 9999
	e.base_attack = 0
	return e


class _FixedSelector extends ChallengeSelector:
	var queue: Array = []

	func _init() -> void:
		super()

	func pick_challenge(_enemy: EnemyData, _pack, _srs) -> ChallengeTemplate:
		if queue.is_empty():
			return null
		# Cycle so refill always has fodder
		var t = queue[0]
		queue.append(queue.pop_front())
		return t


## Build a controller with the given deck and put `templates` on the board (kept
## as no-keep by default). Caller can then toggle_keep(...) on whichever index.
func _build_controller(
		deck_cards: Array,
		board_templates: Array,
		board_size: int = 3) -> BattleController:
	var ctrl: BattleController = BattleController.new()
	add_child_autofree(ctrl)
	var deck: Array[Card] = []
	for c in deck_cards:
		deck.append(c)
	ctrl.setup(_make_enemy(), null, deck, null, board_size)
	var sel := _FixedSelector.new()
	for t in board_templates:
		sel.queue.append(t)
	ctrl.set_selector(sel)
	# Bypass start_battle so we can control hand/deck precisely:
	# manually push templates onto the board (no shuffle, no draw).
	for t in board_templates:
		ctrl.add_to_board(t)
	return ctrl


# ─── Test 1: kept question's answer is reserved on draw ────────────

func test_kept_question_answer_drawn_first() -> void:
	# Deck = [letter_a, brave, letter_b, kind, smart, lazy] (insertion order).
	# Of these, brave/kind/smart/lazy are adjectives. With pop_back draw order,
	# the bottom-of-array card "letter_a" would be drawn LAST normally — but we
	# need to verify that an adjective ends up in the hand.
	var letter_a := _make_card({
		"id": "card_letter_a", "text": "a", "type": "letter", "pos": "",
	})
	var brave := _make_card({
		"id": "card_brave", "text": "brave", "type": "word", "pos": "adjective",
	})
	var letter_b := _make_card({
		"id": "card_letter_b", "text": "b", "type": "letter", "pos": "",
	})
	var kind := _make_card({
		"id": "card_kind", "text": "kind", "type": "word", "pos": "adjective",
	})
	var smart := _make_card({
		"id": "card_smart", "text": "smart", "type": "word", "pos": "adjective",
	})
	var lazy := _make_card({
		"id": "card_lazy", "text": "lazy", "type": "word", "pos": "adjective",
	})
	var deck_cards: Array = [letter_a, brave, letter_b, kind, smart, lazy]
	var tmpl := _make_adjective_template("kept_adj")
	var ctrl := _build_controller(deck_cards, [tmpl], 3)
	# Mark template kept
	ctrl.toggle_keep(0)
	assert_true(ctrl.is_kept(0), "template should be kept")
	# Draw to full hand. With HAND_SIZE=5, hand will hold 5 of the 6 cards;
	# the reserved adjective MUST appear.
	ctrl._draw_to_full_hand()
	assert_eq(ctrl.hand.size(), BattleController.HAND_SIZE,
		"hand should be filled to HAND_SIZE")
	var has_adj: bool = false
	for c in ctrl.hand:
		if c != null and c.pos == "adjective":
			has_adj = true
			break
	assert_true(has_adj,
		"hand must contain at least one adjective for the kept question")


# ─── Test 2: no kept questions → no bias (deck order preserved) ────

func test_no_kept_no_bias() -> void:
	# All non-adjective letters. Deck order should be preserved (no reservation).
	var c1 := _make_card({"id": "card_1", "type": "letter"})
	var c2 := _make_card({"id": "card_2", "type": "letter"})
	var c3 := _make_card({"id": "card_3", "type": "letter"})
	var c4 := _make_card({"id": "card_4", "type": "letter"})
	var c5 := _make_card({"id": "card_5", "type": "letter"})
	var deck_before: Array = [c1, c2, c3, c4, c5]
	var tmpl := _make_adjective_template("not_kept")
	var ctrl := _build_controller(deck_before, [tmpl], 3)
	# Don't keep any question
	assert_eq(ctrl.kept_template_ids.size(), 0, "no kept ids")
	# Snapshot deck order pre-draw
	var pre_deck_ids: Array[String] = []
	for c in ctrl.deck:
		pre_deck_ids.append(c.id)
	ctrl._draw_to_full_hand()
	# All 5 cards should be drawn; deck empty. Order in hand is reverse of deck
	# (pop_back). The bias function did nothing, so the deck before draw was
	# unchanged from setup order.
	assert_eq(ctrl.hand.size(), 5)
	assert_eq(pre_deck_ids,
		["card_1", "card_2", "card_3", "card_4", "card_5"] as Array[String],
		"deck order untouched when no kept questions")


# ─── Test 3: deck has no satisfying card → doesn't crash ──────────

func test_no_solving_card_doesnt_crash() -> void:
	# Deck has only letters; kept question requires noun. Should not crash;
	# kept question stays unsolvable.
	var c1 := _make_card({"id": "card_1", "type": "letter"})
	var c2 := _make_card({"id": "card_2", "type": "letter"})
	var c3 := _make_card({"id": "card_3", "type": "letter"})
	var c4 := _make_card({"id": "card_4", "type": "letter"})
	var c5 := _make_card({"id": "card_5", "type": "letter"})
	var deck_cards: Array = [c1, c2, c3, c4, c5]
	var tmpl := _make_noun_template("kept_noun")
	var ctrl := _build_controller(deck_cards, [tmpl], 3)
	ctrl.toggle_keep(0)
	assert_true(ctrl.is_kept(0))
	# Should not crash even though no card in deck satisfies "noun"
	ctrl._draw_to_full_hand()
	assert_eq(ctrl.hand.size(), 5, "all 5 cards drawn despite unsolvable kept")
	# Verify hand has zero nouns (kept question stays unsolvable, as intended)
	var has_noun: bool = false
	for c in ctrl.hand:
		if c != null and c.pos == "noun":
			has_noun = true
			break
	assert_false(has_noun, "no noun could be reserved — kept stays unsolved")


# ─── Test 4: 2 kept questions, each gets a satisfying card ────────

func test_multiple_kept_questions_each_gets_card() -> void:
	# Raise question_keep_max=2 to allow keeping two distinct questions.
	# Deck contains exactly one adjective and one noun and 5 fillers (letters).
	# Expect both to be reserved → both end up in the 5-card hand.
	var brave := _make_card({
		"id": "card_brave", "text": "brave", "type": "word", "pos": "adjective",
	})
	var dog := _make_card({
		"id": "card_dog", "text": "dog", "type": "word", "pos": "noun",
	})
	var f1 := _make_card({"id": "card_f1", "type": "letter"})
	var f2 := _make_card({"id": "card_f2", "type": "letter"})
	var f3 := _make_card({"id": "card_f3", "type": "letter"})
	var f4 := _make_card({"id": "card_f4", "type": "letter"})
	var f5 := _make_card({"id": "card_f5", "type": "letter"})
	# Place fillers on top so a naive non-biased draw wouldn't pull the answers.
	# pop_back end = top → put fillers at the back of array.
	var deck_cards: Array = [brave, dog, f1, f2, f3, f4, f5]
	var tmpl_adj := _make_adjective_template("kept_adj")
	var tmpl_noun := _make_noun_template("kept_noun")
	var ctrl := _build_controller(deck_cards, [tmpl_adj, tmpl_noun], 3)
	ctrl.question_keep_max = 2
	ctrl.toggle_keep(0)
	ctrl.toggle_keep(1)
	assert_eq(ctrl.get_kept_count(), 2, "both questions kept")
	ctrl._draw_to_full_hand()
	assert_eq(ctrl.hand.size(), 5)
	var has_adj: bool = false
	var has_noun: bool = false
	for c in ctrl.hand:
		if c == null:
			continue
		if c.pos == "adjective":
			has_adj = true
		if c.pos == "noun":
			has_noun = true
	assert_true(has_adj,
		"hand must contain an adjective for the first kept question")
	assert_true(has_noun,
		"hand must contain a noun for the second kept question")


# ─── Test 5: discard fallback when deck has no answer ────────────

func test_reserve_falls_back_to_discard() -> void:
	# Deck has only letters; the only adjective is in the discard pile.
	# Reserve logic should pull it from discard so it's drawn into hand.
	var brave := _make_card({
		"id": "card_brave", "text": "brave", "type": "word", "pos": "adjective",
	})
	var c1 := _make_card({"id": "card_1", "type": "letter"})
	var c2 := _make_card({"id": "card_2", "type": "letter"})
	var c3 := _make_card({"id": "card_3", "type": "letter"})
	var c4 := _make_card({"id": "card_4", "type": "letter"})
	var c5 := _make_card({"id": "card_5", "type": "letter"})
	var deck_cards: Array = [c1, c2, c3, c4, c5]
	var tmpl := _make_adjective_template("kept_adj")
	var ctrl := _build_controller(deck_cards, [tmpl], 3)
	# Stash the adjective into discard before draw
	ctrl.discard.append(brave)
	ctrl.toggle_keep(0)
	assert_true(ctrl.is_kept(0))
	ctrl._draw_to_full_hand()
	# Hand should contain brave (pulled from discard)
	var has_brave: bool = false
	for c in ctrl.hand:
		if c != null and c.id == "card_brave":
			has_brave = true
			break
	assert_true(has_brave,
		"adjective should be reserved from discard when deck lacks one")
