#!/usr/bin/env python3
"""
Curate challenges.json so each slot uses *strict* validation:

Strategy A — accept_card_ids whitelist (1-3 cards make sense in context).
Strategy B — required_tags + tag_match_mode="all" (a category fits).

Educational rationale: with old "required_pos only" logic, ANY adjective could
go into "I am very ___" — even "lazy" or "small" — which doesn't test if the
player understands the meaning. We tighten every slot to one of the two
strategies above.

Idempotent: re-running produces the same JSON.

Run from project root:
    python3 scripts/curate_challenges.py
"""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CHALLENGES_JSON = PROJECT_ROOT / "src" / "content" / "english" / "data" / "challenges.json"

# ─── Per-template overrides ────────────────────────────────────────────
# Each entry: template_id -> list of slot specs (one per slot).
# Each slot spec is a dict with the curated values; remaining fields are
# preserved from the original.
#
# Strategy A example: {"accept_card_ids": ["card_letter_d"]}
# Strategy B example: {"required_tags": ["positive_emotion"], "tag_match_mode": "all"}

CURATED: dict[str, list[dict]] = {
    # ───────── 0F: alphabet & phonics ─────────
    "0F_alphabet_next": [
        # "A, B, C, ___, E" → only D
        {"accept_card_ids": ["card_letter_d"]},
    ],
    "0F_alphabet_before_h": [
        # "E, F, ___, H" → only G
        {"accept_card_ids": ["card_letter_g"]},
    ],
    "0F_alphabet_after_n": [
        # "L, M, N, ___" → only O
        {"accept_card_ids": ["card_letter_o"]},
    ],
    "0F_alphabet_listen_b": [
        # Listen → only B
        {"accept_card_ids": ["card_letter_b"]},
    ],
    "0F_phonics_cat": [
        # c-_-t → only "a" + "-at"
        {"accept_card_ids": ["card_letter_a"]},
        {"accept_card_ids": ["card_syllable_at"]},
    ],
    "0F_alphabet_next_b": [
        # B 后面 → only C
        {"accept_card_ids": ["card_letter_c"]},
    ],
    "0F_phonics_dog_multi": [
        # ___-o-___ (dog) → only D, only G
        {"accept_card_ids": ["card_letter_d"]},
        {"accept_card_ids": ["card_letter_g"]},
    ],
    "0F_phonics_pig": [
        # p-_-g → only "i" + "-ig"
        {"accept_card_ids": ["card_letter_i"]},
        {"accept_card_ids": ["card_syllable_ig"]},
    ],
    "0F_phonics_run": [
        # r + ___ = run → only "-un"
        {"accept_card_ids": ["card_syllable_un"]},
    ],
    "0F_sight_iam": [
        # "I ___ a boy." → only "am"
        {"accept_card_ids": ["card_word_am", "card_be_am"]},
    ],
    "0F_sight_thisis": [
        # "___ is my pen." → "this" or "that"
        {"accept_card_ids": ["card_word_this", "card_word_that"]},
    ],
    "0F_sight_he_is": [
        # "He [are] my friend." → only "is"
        {"accept_card_ids": ["card_word_is", "card_be_is"]},
    ],

    # ───────── 1F: emotion & personality ─────────
    "1F_emotion_blank": [
        # "I am very ___" — ambiguous in tone; allow ALL emotions but require
        # the cards to be feelings (not personality / not size).
        # Accept both positive & negative emotion words (5 total).
        {"accept_card_ids": ["card_happy", "card_sad", "card_angry",
                              "card_tired", "card_excited"]},
    ],
    "1F_emotion_positive": [
        # "Today I feel so ___!" → must be positive emotion (Strategy B)
        {"required_tags": ["positive_emotion"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "adjective"},
    ],
    "1F_emotion_contrast": [
        # "I am very ___ but my friend is ___." → positive + negative emotion
        {"required_tags": ["positive_emotion"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "adjective"},
        {"required_tags": ["negative_emotion"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "adjective"},
    ],
    "1F_personality_three": [
        # "She is ___, ___, and ___." — 3 personality words; positive only
        # (you wouldn't praise someone with "lazy") → use Strategy A whitelist
        {"accept_card_ids": ["card_brave", "card_kind", "card_smart", "card_quiet"]},
        {"accept_card_ids": ["card_brave", "card_kind", "card_smart", "card_quiet"]},
        {"accept_card_ids": ["card_brave", "card_kind", "card_smart", "card_quiet"]},
    ],
    "1F_emotion_tired": [
        # "After class I am too ___." → only "tired" makes contextual sense
        {"accept_card_ids": ["card_tired"]},
    ],
    "1F_emotion_listen": [
        # Listening (excited.mp3) → only "excited"
        {"accept_card_ids": ["card_excited"]},
    ],
    "1F_personality_blank": [
        # "She is so ___." → positive personality (Strategy B)
        {"required_tags": ["positive_personality"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "adjective"},
    ],
    "1F_personality_he_brave": [
        # "He is very ___." → positive personality
        {"required_tags": ["positive_personality"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "adjective"},
    ],
    "1F_personality_lazy_correct": [
        # Error-correct: "He [are] very lazy." → must be "is"
        {"accept_card_ids": ["card_be_is"]},
    ],
    "1F_personality_quiet": [
        # "My sister is ___." → personality but contextually mild;
        # whitelist a small natural set.
        {"accept_card_ids": ["card_quiet", "card_kind", "card_smart"]},
    ],
    "1F_be_correct": [
        # Error-correct: "He [are] happy." → "is"
        {"accept_card_ids": ["card_be_is"]},
    ],
    "1F_be_we_are": [
        # Error-correct: "We [is] strong." → "are"
        {"accept_card_ids": ["card_be_are"]},
    ],
    "1F_grammar_size": [
        # "The cat is ___." → size (Strategy B)
        {"required_tags": ["size"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "adjective"},
    ],
    "1F_grammar_pattern_iam": [
        # Build: pattern + adj — pattern slot whitelisted; adj slot whitelisted to positive.
        {"accept_card_ids": ["card_pattern_i_am_blank"]},
        # Adj slot: positive emotion or personality (so the sentence reads naturally).
        {"accept_card_ids": ["card_happy", "card_brave", "card_kind",
                              "card_smart", "card_excited", "card_strong"]},
    ],

    # ───────── 2F: family / body / pronoun ─────────
    "2F_family_blank": [
        # "My ___ is kind." → family member (Strategy B)
        {"required_tags": ["family"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "noun"},
    ],
    "2F_family_grandma": [
        # "My ___ is so old." → grandparent (Strategy B)
        {"required_tags": ["grandparent"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "noun"},
    ],
    "2F_family_listen": [
        # Listen → "family"
        {"accept_card_ids": ["card_noun_family"]},
    ],
    "2F_family_baby_correct": [
        # Error-correct: "The [baby] are cute." → singular "is"
        {"accept_card_ids": ["card_be_is"]},
    ],
    "2F_body_blank": [
        # "I have two ___." → paired body parts (Strategy B)
        {"required_tags": ["body", "paired_appendage"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "noun"},
    ],
    "2F_body_head": [
        # "My ___ hurts." → only "head"
        {"accept_card_ids": ["card_noun_head"]},
    ],
    "2F_body_listen": [
        # Listen (nose.mp3) → only "nose"
        {"accept_card_ids": ["card_noun_nose"]},
    ],
    "2F_pronoun_correct": [
        # "[Him] is my brother." → subject "he"
        {"accept_card_ids": ["card_pronoun_he"]},
    ],
    "2F_pronoun_she": [
        # "___ is my mother." → only "she"
        {"accept_card_ids": ["card_pronoun_she"]},
    ],
    "2F_pronoun_we": [
        # "___ are happy." → "we" or "they"
        {"accept_card_ids": ["card_pronoun_we", "card_pronoun_they"]},
    ],
    "2F_this_that": [
        # "___ is my book." → "this" or "that"
        {"accept_card_ids": ["card_word_this", "card_word_that"]},
    ],
    "2F_pronoun_object_me": [
        # "She likes ___." → object form, first person → "me"
        {"accept_card_ids": ["card_pronoun_me"]},
    ],
    "2F_family_describe": [
        # "My ___ is so ___." → family + positive descriptor
        {"required_tags": ["family"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "noun"},
        # Positive descriptor: positive emotion / personality / appearance
        {"accept_card_ids": ["card_happy", "card_kind", "card_brave",
                              "card_smart", "card_beautiful", "card_strong",
                              "card_quiet"]},
    ],
    "2F_body_pronoun_combo": [
        # "___ has two ___." → singular third-person subject + paired body part
        {"accept_card_ids": ["card_pronoun_he", "card_pronoun_she", "card_pronoun_it"]},
        {"required_tags": ["body", "paired_appendage"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "noun"},
    ],
    "2F_family_body_full": [
        # "My ___ has ___ ___." → family noun + appearance/size adj + body noun
        {"required_tags": ["family"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "noun"},
        # Adj that describes a body part: size or appearance
        {"accept_card_ids": ["card_big", "card_small", "card_beautiful",
                              "card_strong", "card_fast"]},
        {"required_tags": ["body"], "tag_match_mode": "all",
         "required_type": "word", "required_pos": "noun"},
    ],
}


def merge_slot(orig: dict, override: dict) -> dict:
    """Merge curated override into an original slot dict.

    - If override sets accept_card_ids: clear required_type/pos/tags
      (whitelist takes precedence; keeping them would be confusing).
    - Otherwise: override the keys that are explicitly set.
    """
    out = copy.deepcopy(orig)
    if "accept_card_ids" in override:
        out["accept_card_ids"] = list(override["accept_card_ids"])
        # Strategy A → strict whitelist; clear other constraints (validator
        # short-circuits on accept_card_ids anyway, but cleaner data).
        out["required_type"] = ""
        out["required_pos"] = ""
        out["required_tags"] = []
        out["forbidden_tags"] = []
        out["tag_match_mode"] = "any"
    else:
        # Strategy B: explicit fields
        if "required_type" in override:
            out["required_type"] = override["required_type"]
        if "required_pos" in override:
            out["required_pos"] = override["required_pos"]
        if "required_tags" in override:
            out["required_tags"] = list(override["required_tags"])
        if "forbidden_tags" in override:
            out["forbidden_tags"] = list(override["forbidden_tags"])
        if "tag_match_mode" in override:
            out["tag_match_mode"] = override["tag_match_mode"]
        # Ensure accept_card_ids is empty (we're using Strategy B).
        out["accept_card_ids"] = []
    # Default any missing fields.
    out.setdefault("accept_card_ids", [])
    out.setdefault("tag_match_mode", "any")
    out.setdefault("required_tags", [])
    out.setdefault("forbidden_tags", [])
    return out


def main() -> int:
    if not CHALLENGES_JSON.exists():
        print(f"[curate] ERROR: challenges.json not found at {CHALLENGES_JSON}", file=sys.stderr)
        return 1

    with CHALLENGES_JSON.open("r", encoding="utf-8") as fh:
        data = json.load(fh)

    challenges = data.get("challenges", [])
    updated_templates = 0
    untouched = []
    strategy_a_count = 0
    strategy_b_count = 0

    for ch in challenges:
        tid = ch.get("template_id", "")
        if tid not in CURATED:
            untouched.append(tid)
            continue
        slots = ch.get("slots", [])
        overrides = CURATED[tid]
        if len(overrides) != len(slots):
            print(f"[curate] WARN: {tid} has {len(slots)} slots but {len(overrides)} overrides", file=sys.stderr)
        new_slots = []
        for i, slot in enumerate(slots):
            if i < len(overrides):
                merged = merge_slot(slot, overrides[i])
                if merged.get("accept_card_ids"):
                    strategy_a_count += 1
                elif merged.get("required_tags"):
                    strategy_b_count += 1
                new_slots.append(merged)
            else:
                new_slots.append(slot)
        ch["slots"] = new_slots
        updated_templates += 1

    with CHALLENGES_JSON.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    print(f"[curate] updated {updated_templates} challenge template(s)")
    print(f"[curate]   strategy A (accept_card_ids):    {strategy_a_count} slots")
    print(f"[curate]   strategy B (required_tags ALL):  {strategy_b_count} slots")
    if untouched:
        print(f"[curate] {len(untouched)} template(s) had no curation rule:")
        for t in untouched:
            print(f"           - {t}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
