#!/usr/bin/env python3
"""Assign effect_type + effect_magnitude to every challenge in challenges.json.

Distribution per floor (0F / 1F / 2F):
- damage (default) — majority
- heal              — 1-2 per floor with magnitude 15-25
- shield            — 1-2 per floor with magnitude 10-20
- draw_card         — 1-2 per floor with magnitude 1-2
- draw_question     — 1 per floor with magnitude 1
- weakness_strike   — 1-2 per floor (preferring harder challenges)
- combo_boost       — 1 per floor

Strategy: bucket challenges by floor, then deterministically assign
effects so the file diff is reproducible.
"""

import json
import sys
from pathlib import Path

INPUT = Path(__file__).parent.parent / "src/content/english/data/challenges.json"


# (template_id → (effect_type, effect_magnitude))
# Designed to be hand-tuned: easy starter challenges keep "damage"; later
# challenges in each floor get the variety.
EFFECT_PLAN = {
	# === 0F (alphabet / phonics / sight words) ===
	"0F_alphabet_next":          ("damage", 0),
	"0F_alphabet_before_h":      ("damage", 0),
	"0F_alphabet_after_n":       ("draw_card", 1),       # 抽卡
	"0F_alphabet_listen_b":      ("heal", 15),            # 回血
	"0F_phonics_cat":            ("damage", 0),
	"0F_alphabet_next_b":        ("shield", 10),          # 护盾
	"0F_phonics_dog_multi":      ("damage", 0),
	"0F_phonics_pig":            ("draw_question", 1),    # 加题
	"0F_phonics_run":            ("combo_boost", 0),      # 连击翻倍
	"0F_sight_iam":              ("damage", 0),
	"0F_sight_thisis":           ("weakness_strike", 0),  # 弱点强击
	"0F_sight_he_is":            ("heal", 15),

	# === 1F (emotion / personality / grammar) ===
	"1F_emotion_blank":          ("damage", 0),
	"1F_emotion_positive":       ("damage", 0),
	"1F_emotion_contrast":       ("draw_card", 2),
	"1F_personality_three":      ("weakness_strike", 0),
	"1F_emotion_tired":          ("heal", 20),
	"1F_emotion_listen":         ("shield", 15),
	"1F_personality_blank":      ("damage", 0),
	"1F_personality_he_brave":   ("damage", 0),
	"1F_personality_lazy_correct": ("combo_boost", 0),
	"1F_personality_quiet":      ("damage", 0),
	"1F_be_correct":             ("draw_question", 1),
	"1F_be_we_are":              ("heal", 18),
	"1F_grammar_size":           ("damage", 0),
	"1F_grammar_pattern_iam":    ("shield", 12),

	# === 2F (family / body / pronoun) — harder, more strategic effects ===
	"2F_family_blank":           ("damage", 0),
	"2F_family_grandma":         ("heal", 25),
	"2F_family_listen":          ("shield", 18),
	"2F_family_baby_correct":    ("draw_card", 2),
	"2F_body_blank":             ("damage", 0),
	"2F_body_head":              ("weakness_strike", 0),
	"2F_body_listen":            ("damage", 0),
	"2F_pronoun_correct":        ("damage", 0),
	"2F_pronoun_she":            ("damage", 0),
	"2F_pronoun_we":             ("draw_question", 1),
	"2F_this_that":              ("damage", 0),
	"2F_pronoun_object_me":      ("combo_boost", 0),
	"2F_family_describe":        ("weakness_strike", 0),
	"2F_body_pronoun_combo":     ("heal", 20),
	"2F_family_body_full":       ("shield", 20),
}


def main() -> int:
	with INPUT.open("r", encoding="utf-8") as f:
		data = json.load(f)

	missing: list[str] = []
	for c in data["challenges"]:
		tid = c["template_id"]
		if tid not in EFFECT_PLAN:
			missing.append(tid)
			# Default unknown to "damage"
			c["effect_type"] = "damage"
			c["effect_magnitude"] = 0
			continue
		et, mag = EFFECT_PLAN[tid]
		c["effect_type"] = et
		c["effect_magnitude"] = mag

	if missing:
		print(f"WARNING: missing plan for {len(missing)} challenges: {missing}", file=sys.stderr)

	# Re-write JSON, indented same as before (2 spaces).
	with INPUT.open("w", encoding="utf-8") as f:
		json.dump(data, f, indent=2, ensure_ascii=False)
		f.write("\n")

	# Distribution summary
	from collections import Counter
	dist = Counter(c["effect_type"] for c in data["challenges"])
	print("Effect type distribution:")
	for k, v in sorted(dist.items(), key=lambda x: -x[1]):
		print(f"  {k:20s}: {v}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
