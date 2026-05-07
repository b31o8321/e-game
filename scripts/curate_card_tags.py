#!/usr/bin/env python3
"""
Curate semantic tags on src/content/english/data/cards.json.

Educational rationale: in-battle slot validation must reject cards that don't
fit the meaning of the sentence — not just match part-of-speech. To do that,
each Card needs a tag set that captures *what the word means*, not just its
grammatical role.

This script is idempotent: re-running it produces the same JSON.
- Preserves all existing fields (text, type, pos, meaning, audio_path, ...).
- Replaces `tags` for cards we have a curated tag set for.
- Leaves cards we don't have tags for untouched (safety: print a warning).
- Maintains the existing scaffolding tags ({floor}_X, grade_N) for back-compat.

Run from project root:
    python3 scripts/curate_card_tags.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CARDS_JSON = PROJECT_ROOT / "src" / "content" / "english" / "data" / "cards.json"

# ─── Tag curation tables ──────────────────────────────────────────────
# Each entry: card_id -> list of *semantic* tags (we'll merge with scaffolding).
# Scaffolding tags (e.g. "0F_alphabet", "grade_3") are detected by suffix /
# prefix and preserved automatically.

EMOTION_ADJ = {
    "card_happy":   ["adjective", "positive_emotion", "feeling", "personality", "emotion"],
    "card_sad":     ["adjective", "negative_emotion", "feeling", "emotion"],
    "card_angry":   ["adjective", "negative_emotion", "feeling", "emotion"],
    "card_tired":   ["adjective", "negative_emotion", "physical_state", "feeling", "emotion"],
    "card_excited": ["adjective", "positive_emotion", "feeling", "emotion"],
}

PERSONALITY_ADJ = {
    "card_brave":  ["adjective", "positive_personality", "personality"],
    "card_kind":   ["adjective", "positive_personality", "personality"],
    "card_lazy":   ["adjective", "negative_personality", "personality"],
    "card_smart":  ["adjective", "positive_personality", "personality", "ability"],
    "card_quiet":  ["adjective", "neutral_personality", "personality"],
}

DESCRIPTION_ADJ = {
    "card_big":       ["adjective", "size", "physical_attribute", "description"],
    "card_small":     ["adjective", "size", "physical_attribute", "description"],
    "card_beautiful": ["adjective", "positive_appearance", "appearance", "description"],
    "card_strong":    ["adjective", "physical_attribute", "ability", "description"],
    "card_fast":      ["adjective", "speed", "physical_attribute", "description"],
}

FAMILY_NOUNS = {
    "card_noun_mother":   ["noun", "family", "female_relative", "parent"],
    "card_noun_father":   ["noun", "family", "male_relative", "parent"],
    "card_noun_sister":   ["noun", "family", "female_relative", "sibling"],
    "card_noun_brother":  ["noun", "family", "male_relative", "sibling"],
    "card_noun_grandma":  ["noun", "family", "female_relative", "grandparent"],
    "card_noun_grandpa":  ["noun", "family", "male_relative", "grandparent"],
    "card_noun_son":      ["noun", "family", "male_relative", "child"],
    "card_noun_daughter": ["noun", "family", "female_relative", "child"],
    "card_noun_family":   ["noun", "family", "collective"],
    "card_noun_baby":     ["noun", "family", "child", "young"],
}

BODY_NOUNS = {
    "card_noun_head":   ["noun", "body", "upper_body", "single"],
    "card_noun_hand":   ["noun", "body", "upper_body", "paired_appendage"],
    "card_noun_eye":    ["noun", "body", "face", "paired_part"],
    "card_noun_foot":   ["noun", "body", "lower_body", "paired_appendage"],
    "card_noun_hair":   ["noun", "body", "head_part", "single_collection"],
    "card_noun_ear":    ["noun", "body", "face", "paired_part"],
    "card_noun_nose":   ["noun", "body", "face", "single"],
    "card_noun_mouth":  ["noun", "body", "face", "single"],
    "card_noun_arm":    ["noun", "body", "upper_body", "paired_appendage"],
    "card_noun_leg":    ["noun", "body", "lower_body", "paired_appendage"],
}

OBJECT_NOUNS = {
    "card_noun_book":  ["noun", "object", "school", "stationery"],
    "card_noun_pen":   ["noun", "object", "school", "stationery"],
    "card_noun_bag":   ["noun", "object", "school", "container"],
    "card_noun_desk":  ["noun", "object", "school", "furniture"],
    "card_noun_chair": ["noun", "object", "school", "furniture"],
}

# Full pronoun set (the dedicated "card_pronoun_*" cards).
PRONOUNS = {
    "card_pronoun_i":    ["pronoun", "subject_form", "first_person", "singular"],
    "card_pronoun_you":  ["pronoun", "subject_form", "object_form", "second_person"],
    "card_pronoun_he":   ["pronoun", "subject_form", "third_person", "singular", "male"],
    "card_pronoun_she":  ["pronoun", "subject_form", "third_person", "singular", "female"],
    "card_pronoun_it":   ["pronoun", "subject_form", "third_person", "singular", "neuter"],
    "card_pronoun_we":   ["pronoun", "subject_form", "first_person", "plural", "plural_subject"],
    "card_pronoun_they": ["pronoun", "subject_form", "third_person", "plural", "plural_subject"],
    "card_pronoun_me":   ["pronoun", "object_form", "first_person", "singular"],
}

# Be-verb cards (precise grammatical features).
BE_VERBS = {
    "card_be_am":  ["be_verb", "verb_be", "first_person", "singular_subject", "present_tense"],
    "card_be_is":  ["be_verb", "verb_be", "third_person", "singular_subject", "present_tense"],
    "card_be_are": ["be_verb", "verb_be", "plural_subject", "second_person", "present_tense"],
    "card_be_was": ["be_verb", "verb_be", "singular_subject", "past_tense"],
}

# Sight words (the small "card_word_*" cards that overlap pronouns/articles).
# These are kept simpler — but with semantic tags so they can be slotted.
SIGHT_WORDS = {
    "card_word_a":    ["sight_word", "article", "indefinite_article"],
    "card_word_the":  ["sight_word", "article", "definite_article"],
    "card_word_i":    ["sight_word", "pronoun", "subject_form", "first_person", "singular"],
    "card_word_am":   ["sight_word", "be_verb", "first_person", "singular_subject"],
    "card_word_is":   ["sight_word", "be_verb", "third_person", "singular_subject"],
    "card_word_are":  ["sight_word", "be_verb", "plural_subject", "second_person"],
    "card_word_you":  ["sight_word", "pronoun", "subject_form", "second_person"],
    "card_word_he":   ["sight_word", "pronoun", "subject_form", "third_person", "singular", "male"],
    "card_word_she":  ["sight_word", "pronoun", "subject_form", "third_person", "singular", "female"],
    "card_word_it":   ["sight_word", "pronoun", "subject_form", "third_person", "singular", "neuter"],
    "card_word_this": ["sight_word", "demonstrative", "near"],
    "card_word_that": ["sight_word", "demonstrative", "far"],
    "card_word_my":   ["sight_word", "possessive", "first_person"],
    "card_word_no":   ["sight_word", "negation"],
}

# Letters: precise alphabet tags (vowel vs consonant).
VOWELS = {"a", "e", "i", "o", "u"}

def letter_tags(letter_id: str) -> list[str]:
    # letter_id like "card_letter_a"
    letter = letter_id.split("_")[-1].lower()
    out = ["letter", "alphabet"]
    if letter in VOWELS:
        out.append("vowel")
    else:
        out.append("consonant")
    return out

# Syllables (rime).
SYLLABLES = {
    "card_syllable_at": ["syllable", "phonics", "rime", "short_a"],
    "card_syllable_an": ["syllable", "phonics", "rime", "short_a"],
    "card_syllable_in": ["syllable", "phonics", "rime", "short_i"],
    "card_syllable_ig": ["syllable", "phonics", "rime", "short_i"],
    "card_syllable_un": ["syllable", "phonics", "rime", "short_u"],
    "card_syllable_et": ["syllable", "phonics", "rime", "short_e"],
    "card_syllable_op": ["syllable", "phonics", "rime", "short_o"],
    "card_syllable_ut": ["syllable", "phonics", "rime", "short_u"],
    "card_syllable_ed": ["syllable", "phonics", "rime", "short_e"],
    "card_syllable_ay": ["syllable", "phonics", "rime", "long_a"],
}

# Sentence patterns.
PATTERNS = {
    "card_pattern_i_am_blank":   ["sentence_pattern", "first_person", "be_pattern"],
    "card_pattern_he_is_blank":  ["sentence_pattern", "third_person", "be_pattern", "male_subject"],
    "card_pattern_it_is_blank":  ["sentence_pattern", "third_person", "be_pattern", "neuter_subject"],
    "card_pattern_this_is_blank": ["sentence_pattern", "demonstrative", "be_pattern", "near"],
    "card_pattern_that_is_blank": ["sentence_pattern", "demonstrative", "be_pattern", "far"],
}

# Adverbs (intensifiers).
ADVERBS = {
    "card_adv_very": ["adverb", "intensifier"],
    "card_adv_so":   ["adverb", "intensifier"],
    "card_adv_too":  ["adverb", "intensifier"],
}

# ─── Build master map ──────────────────────────────────────────────────
CURATED: dict[str, list[str]] = {}
for table in (
    EMOTION_ADJ, PERSONALITY_ADJ, DESCRIPTION_ADJ,
    FAMILY_NOUNS, BODY_NOUNS, OBJECT_NOUNS,
    PRONOUNS, BE_VERBS, SIGHT_WORDS,
    SYLLABLES, PATTERNS, ADVERBS,
):
    for cid, tags in table.items():
        if cid in CURATED:
            print(f"[curate] WARN: duplicate tag def for {cid}", file=sys.stderr)
        CURATED[cid] = list(tags)


def is_scaffolding_tag(tag: str) -> bool:
    """Tags like '0F_alphabet', '1F_emotion', 'grade_3' are floor/grade scaffolding.
    We preserve them so existing floor pool / starting deck logic still works."""
    if tag.startswith("grade_"):
        return True
    # Floor prefix like "0F_", "1F_", ... "9F_"
    if len(tag) >= 3 and tag[0].isdigit() and tag[1] == "F" and tag[2] == "_":
        return True
    return False


def merged_tags(card_id: str, current_tags: list[str]) -> list[str]:
    """Return new tag list: curated semantic tags + preserved scaffolding tags.
    Order: semantic tags first, then scaffolding tags (sorted for determinism).
    """
    if card_id.startswith("card_letter_"):
        semantic = letter_tags(card_id)
    elif card_id in CURATED:
        semantic = CURATED[card_id]
    else:
        # No curation rule — keep current tags.
        return list(current_tags)

    scaffolding = sorted({t for t in current_tags if is_scaffolding_tag(t)})

    # Deduplicate while preserving order.
    seen: set[str] = set()
    out: list[str] = []
    for t in semantic + scaffolding:
        if t not in seen:
            seen.add(t)
            out.append(t)
    return out


def main() -> int:
    if not CARDS_JSON.exists():
        print(f"[curate] ERROR: cards.json not found at {CARDS_JSON}", file=sys.stderr)
        return 1

    with CARDS_JSON.open("r", encoding="utf-8") as fh:
        data = json.load(fh)

    cards = data.get("cards", [])
    updated = 0
    untouched = []
    for card in cards:
        cid = card.get("id", "")
        if not cid:
            continue
        old_tags = list(card.get("tags", []))
        new_tags = merged_tags(cid, old_tags)
        if new_tags != old_tags:
            card["tags"] = new_tags
            updated += 1
        if cid not in CURATED and not cid.startswith("card_letter_"):
            untouched.append(cid)

    with CARDS_JSON.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    print(f"[curate] updated tags on {updated} card(s)")
    if untouched:
        print(f"[curate] {len(untouched)} card(s) had no curation rule (left untouched):")
        for cid in untouched:
            print(f"           - {cid}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
