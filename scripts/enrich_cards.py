#!/usr/bin/env python3
"""Enrich src/content/english/data/cards.json with meaning, phonetic, audio_path,
and example sentences for word cards. Letter / syllable / sight word / pattern
cards get appropriate minimal annotations.

Idempotent: re-running overwrites these fields with current dict values.
Run from project root or anywhere — paths are computed from this script's
location.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CARDS_JSON = ROOT / "src" / "content" / "english" / "data" / "cards.json"
WORD_AUDIO_DIR = ROOT / "src" / "content" / "english" / "audio" / "words"
LETTER_AUDIO_DIR = ROOT / "src" / "content" / "english" / "audio" / "letters"

WORD_AUDIO_RES_PREFIX = "res://src/content/english/audio/words/"
LETTER_AUDIO_RES_PREFIX = "res://src/content/english/audio/letters/"


# ─── Meanings & phonetic & examples ──────────────────────────────────────

# Adjectives (and a few descriptive)
ADJECTIVES: dict[str, dict[str, str]] = {
    "happy": {
        "phonetic": "[ˈhæpi]", "meaning": "快乐的；高兴的",
        "example_en": "I am happy today.",
        "example_zh": "我今天很开心。",
    },
    "sad": {
        "phonetic": "[sæd]", "meaning": "悲伤的；难过的",
        "example_en": "She feels sad.",
        "example_zh": "她感到难过。",
    },
    "angry": {
        "phonetic": "[ˈæŋɡri]", "meaning": "生气的；愤怒的",
        "example_en": "Don't be angry with me.",
        "example_zh": "别生我的气。",
    },
    "tired": {
        "phonetic": "[ˈtaɪərd]", "meaning": "疲惫的；累的",
        "example_en": "I am tired after school.",
        "example_zh": "放学后我很累。",
    },
    "excited": {
        "phonetic": "[ɪkˈsaɪtɪd]", "meaning": "兴奋的；激动的",
        "example_en": "We are excited about the trip.",
        "example_zh": "我们对这次旅行很兴奋。",
    },
    "brave": {
        "phonetic": "[breɪv]", "meaning": "勇敢的",
        "example_en": "The brave knight saved the village.",
        "example_zh": "勇敢的骑士救了村庄。",
    },
    "kind": {
        "phonetic": "[kaɪnd]", "meaning": "善良的；体贴的",
        "example_en": "She is kind to everyone.",
        "example_zh": "她对每个人都很友善。",
    },
    "lazy": {
        "phonetic": "[ˈleɪzi]", "meaning": "懒惰的",
        "example_en": "The lazy cat sleeps all day.",
        "example_zh": "懒猫整天睡觉。",
    },
    "smart": {
        "phonetic": "[smɑːrt]", "meaning": "聪明的；机灵的",
        "example_en": "He is a smart boy.",
        "example_zh": "他是个聪明的男孩。",
    },
    "quiet": {
        "phonetic": "[ˈkwaɪət]", "meaning": "安静的；沉默的",
        "example_en": "Please be quiet in the library.",
        "example_zh": "在图书馆请保持安静。",
    },
    "big": {
        "phonetic": "[bɪɡ]", "meaning": "大的",
        "example_en": "An elephant is big.",
        "example_zh": "大象很大。",
    },
    "small": {
        "phonetic": "[smɔːl]", "meaning": "小的",
        "example_en": "A mouse is small.",
        "example_zh": "老鼠很小。",
    },
    "beautiful": {
        "phonetic": "[ˈbjuːtɪfl]", "meaning": "美丽的；漂亮的",
        "example_en": "What a beautiful flower!",
        "example_zh": "多么美丽的花啊！",
    },
    "strong": {
        "phonetic": "[strɔːŋ]", "meaning": "强壮的；有力的",
        "example_en": "My father is strong.",
        "example_zh": "我爸爸很强壮。",
    },
    "fast": {
        "phonetic": "[fæst]", "meaning": "快的；迅速的",
        "example_en": "A cheetah runs fast.",
        "example_zh": "猎豹跑得很快。",
    },
}

# Nouns
NOUNS: dict[str, dict[str, str]] = {
    "mother": {
        "phonetic": "[ˈmʌðər]", "meaning": "妈妈；母亲",
        "example_en": "My mother is a teacher.",
        "example_zh": "我妈妈是一位老师。",
    },
    "father": {
        "phonetic": "[ˈfɑːðər]", "meaning": "爸爸；父亲",
        "example_en": "My father reads books.",
        "example_zh": "我爸爸看书。",
    },
    "sister": {
        "phonetic": "[ˈsɪstər]", "meaning": "姐妹",
        "example_en": "I have one sister.",
        "example_zh": "我有一个姐妹。",
    },
    "brother": {
        "phonetic": "[ˈbrʌðər]", "meaning": "兄弟",
        "example_en": "My brother is tall.",
        "example_zh": "我哥哥很高。",
    },
    "grandma": {
        "phonetic": "[ˈɡrænmɑː]", "meaning": "奶奶；外婆",
        "example_en": "Grandma makes cookies.",
        "example_zh": "奶奶做饼干。",
    },
    "grandpa": {
        "phonetic": "[ˈɡrænpɑː]", "meaning": "爷爷；外公",
        "example_en": "Grandpa tells stories.",
        "example_zh": "爷爷讲故事。",
    },
    "son": {
        "phonetic": "[sʌn]", "meaning": "儿子",
        "example_en": "Their son is six.",
        "example_zh": "他们的儿子六岁。",
    },
    "daughter": {
        "phonetic": "[ˈdɔːtər]", "meaning": "女儿",
        "example_en": "Her daughter is cute.",
        "example_zh": "她的女儿很可爱。",
    },
    "family": {
        "phonetic": "[ˈfæməli]", "meaning": "家庭；家人",
        "example_en": "I love my family.",
        "example_zh": "我爱我的家人。",
    },
    "baby": {
        "phonetic": "[ˈbeɪbi]", "meaning": "婴儿；宝宝",
        "example_en": "The baby is sleeping.",
        "example_zh": "宝宝在睡觉。",
    },
    "head": {
        "phonetic": "[hed]", "meaning": "头",
        "example_en": "Touch your head.",
        "example_zh": "摸摸你的头。",
    },
    "hand": {
        "phonetic": "[hænd]", "meaning": "手",
        "example_en": "Wash your hand.",
        "example_zh": "洗洗你的手。",
    },
    "eye": {
        "phonetic": "[aɪ]", "meaning": "眼睛",
        "example_en": "I have two eyes.",
        "example_zh": "我有两只眼睛。",
    },
    "foot": {
        "phonetic": "[fʊt]", "meaning": "脚",
        "example_en": "My foot hurts.",
        "example_zh": "我的脚疼。",
    },
    "hair": {
        "phonetic": "[her]", "meaning": "头发",
        "example_en": "Her hair is long.",
        "example_zh": "她的头发很长。",
    },
    "ear": {
        "phonetic": "[ɪr]", "meaning": "耳朵",
        "example_en": "Rabbits have long ears.",
        "example_zh": "兔子有长耳朵。",
    },
    "nose": {
        "phonetic": "[noʊz]", "meaning": "鼻子",
        "example_en": "An elephant has a long nose.",
        "example_zh": "大象有长鼻子。",
    },
    "mouth": {
        "phonetic": "[maʊθ]", "meaning": "嘴巴",
        "example_en": "Open your mouth.",
        "example_zh": "张开你的嘴。",
    },
    "arm": {
        "phonetic": "[ɑːrm]", "meaning": "胳膊；手臂",
        "example_en": "Lift your arm.",
        "example_zh": "举起你的胳膊。",
    },
    "leg": {
        "phonetic": "[leɡ]", "meaning": "腿",
        "example_en": "He broke his leg.",
        "example_zh": "他摔断了腿。",
    },
    "book": {
        "phonetic": "[bʊk]", "meaning": "书；书本",
        "example_en": "I read a book.",
        "example_zh": "我读一本书。",
    },
    "pen": {
        "phonetic": "[pen]", "meaning": "钢笔；笔",
        "example_en": "This is my pen.",
        "example_zh": "这是我的笔。",
    },
    "bag": {
        "phonetic": "[bæɡ]", "meaning": "包；书包",
        "example_en": "My bag is heavy.",
        "example_zh": "我的书包很重。",
    },
    "desk": {
        "phonetic": "[desk]", "meaning": "书桌；课桌",
        "example_en": "Books are on the desk.",
        "example_zh": "书在书桌上。",
    },
    "chair": {
        "phonetic": "[tʃer]", "meaning": "椅子",
        "example_en": "Sit on the chair.",
        "example_zh": "坐在椅子上。",
    },
}

# Adverbs
ADVERBS: dict[str, dict[str, str]] = {
    "very": {
        "phonetic": "[ˈveri]", "meaning": "非常；很（程度副词）",
        "example_en": "She is very kind.",
        "example_zh": "她非常善良。",
    },
    "so": {
        "phonetic": "[soʊ]", "meaning": "如此；这么（程度副词）",
        "example_en": "I am so happy!",
        "example_zh": "我太开心了！",
    },
    "too": {
        "phonetic": "[tuː]", "meaning": "太……了；也（程度副词）",
        "example_en": "It is too hot.",
        "example_zh": "太热了。",
    },
}

# Sight words / pronouns / be-verbs / determiners — brief usage notes
SIGHT_WORDS: dict[str, dict[str, str]] = {
    "a": {"phonetic": "[ə]", "meaning": "一个（不定冠词，用于辅音音前）"},
    "the": {"phonetic": "[ðə]", "meaning": "这个；那个（定冠词）"},
    "i": {"phonetic": "[aɪ]", "meaning": "我（主格代词）"},
    "am": {"phonetic": "[æm]", "meaning": "是（be 动词，用于 I）"},
    "is": {"phonetic": "[ɪz]", "meaning": "是（be 动词，第三人称单数）"},
    "are": {"phonetic": "[ɑːr]", "meaning": "是（be 动词，复数 / you）"},
    "was": {"phonetic": "[wəz]", "meaning": "是（be 动词过去式，单数）"},
    "you": {"phonetic": "[juː]", "meaning": "你；你们（主格代词）"},
    "he": {"phonetic": "[hiː]", "meaning": "他（主格代词）"},
    "she": {"phonetic": "[ʃiː]", "meaning": "她（主格代词）"},
    "it": {"phonetic": "[ɪt]", "meaning": "它（主格代词）"},
    "we": {"phonetic": "[wiː]", "meaning": "我们（主格代词）"},
    "they": {"phonetic": "[ðeɪ]", "meaning": "他们；她们；它们（主格代词）"},
    "me": {"phonetic": "[miː]", "meaning": "我（宾格代词）"},
    "this": {"phonetic": "[ðɪs]", "meaning": "这；这个（指示代词）"},
    "that": {"phonetic": "[ðæt]", "meaning": "那；那个（指示代词）"},
    "my": {"phonetic": "[maɪ]", "meaning": "我的（物主代词）"},
    "no": {"phonetic": "[noʊ]", "meaning": "不；没有（否定）"},
}

# Patterns
PATTERNS: dict[str, dict[str, str]] = {
    "card_pattern_i_am_blank": {
        "meaning": "我是 ___（描述自己的状态或身份）",
        "example_en": "I am happy. / I am brave.",
        "example_zh": "我很开心。/ 我很勇敢。",
    },
    "card_pattern_he_is_blank": {
        "meaning": "他是 ___（描述他人）",
        "example_en": "He is tall.",
        "example_zh": "他很高。",
    },
    "card_pattern_it_is_blank": {
        "meaning": "它是 ___（描述事物）",
        "example_en": "It is small.",
        "example_zh": "它很小。",
    },
    "card_pattern_this_is_blank": {
        "meaning": "这是 ___（介绍近处事物）",
        "example_en": "This is my book.",
        "example_zh": "这是我的书。",
    },
    "card_pattern_that_is_blank": {
        "meaning": "那是 ___（介绍远处事物）",
        "example_en": "That is a desk.",
        "example_zh": "那是一张书桌。",
    },
}

# Syllables (phonics rimes) — meaning is brief usage hint
SYLLABLES: dict[str, dict[str, str]] = {
    "-at": {"meaning": "韵脚 -at，例: cat, hat, bat", "phonetic": "[æt]"},
    "-an": {"meaning": "韵脚 -an，例: man, can, fan", "phonetic": "[æn]"},
    "-in": {"meaning": "韵脚 -in，例: pin, win, bin", "phonetic": "[ɪn]"},
    "-ig": {"meaning": "韵脚 -ig，例: pig, big, dig", "phonetic": "[ɪɡ]"},
    "-un": {"meaning": "韵脚 -un，例: sun, run, fun", "phonetic": "[ʌn]"},
    "-et": {"meaning": "韵脚 -et，例: pet, get, net", "phonetic": "[et]"},
    "-op": {"meaning": "韵脚 -op，例: top, hop, mop", "phonetic": "[ɑːp]"},
    "-ut": {"meaning": "韵脚 -ut，例: nut, cut, hut", "phonetic": "[ʌt]"},
    "-ed": {"meaning": "韵脚 -ed，例: bed, red, fed", "phonetic": "[ed]"},
    "-ay": {"meaning": "韵脚 -ay，例: day, play, say", "phonetic": "[eɪ]"},
}


# ─── Main enrichment ─────────────────────────────────────────────────────


def list_audio_words() -> set[str]:
    if not WORD_AUDIO_DIR.is_dir():
        return set()
    return {p.stem.lower() for p in WORD_AUDIO_DIR.glob("*.mp3")}


def list_audio_letters() -> set[str]:
    if not LETTER_AUDIO_DIR.is_dir():
        return set()
    return {p.stem.lower() for p in LETTER_AUDIO_DIR.glob("*.mp3")}


def enrich_card(card: dict[str, Any], audio_words: set[str], audio_letters: set[str]) -> None:
    cid: str = card.get("id", "")
    text: str = card.get("text", "")
    ctype: str = card.get("type", "")
    pos: str = card.get("pos", "")
    text_lower = text.lower()

    # Defaults — overwrite whatever was there with a fresh value
    meaning = ""
    phonetic = ""
    example_en = ""
    example_zh = ""
    audio_path = ""

    # Letters: card_letter_a … card_letter_z
    if pos == "letter":
        letter = text_lower
        meaning = f"字母 {text}"
        if letter in audio_letters:
            audio_path = LETTER_AUDIO_RES_PREFIX + letter + ".mp3"

    # Syllables (phrase + pos=syllable)
    elif pos == "syllable":
        syl = SYLLABLES.get(text)
        if syl:
            meaning = syl.get("meaning", "")
            phonetic = syl.get("phonetic", "")

    # Patterns
    elif ctype == "pattern":
        p = PATTERNS.get(cid)
        if p:
            meaning = p.get("meaning", "")
            example_en = p.get("example_en", "")
            example_zh = p.get("example_zh", "")

    # Adjectives / nouns / adverbs / verbs / sight_words / pronouns / verb_be
    else:
        # Choose dict by pos
        if pos == "adjective":
            entry = ADJECTIVES.get(text_lower)
        elif pos == "noun":
            entry = NOUNS.get(text_lower)
        elif pos == "adverb":
            entry = ADVERBS.get(text_lower)
        elif pos in ("sight_word", "verb_be", "pronoun"):
            # Disambiguate "I" — sight_word vs pronoun both spell "I"
            entry = SIGHT_WORDS.get(text_lower)
        else:
            entry = None

        if entry is not None:
            meaning = entry.get("meaning", "")
            phonetic = entry.get("phonetic", "")
            example_en = entry.get("example_en", "")
            example_zh = entry.get("example_zh", "")

        # Audio: only attach if the file actually exists
        if text_lower in audio_words:
            audio_path = WORD_AUDIO_RES_PREFIX + text_lower + ".mp3"

    # Write back — always overwrite to ensure idempotence
    card["meaning"] = meaning
    card["phonetic"] = phonetic
    card["example_en"] = example_en
    card["example_zh"] = example_zh
    # Only set audio_path if non-empty, or if key already exists keep "" — preserve key
    card["audio_path"] = audio_path


def main() -> int:
    if not CARDS_JSON.is_file():
        print(f"FATAL: cards.json not found at {CARDS_JSON}")
        return 1

    audio_words = list_audio_words()
    audio_letters = list_audio_letters()
    print(f"Found {len(audio_words)} word audio files, {len(audio_letters)} letter audio files")

    with CARDS_JSON.open("r", encoding="utf-8") as f:
        data = json.load(f)

    cards = data.get("cards", [])
    word_count = 0
    audio_count = 0
    missing_meaning: list[str] = []
    for card in cards:
        enrich_card(card, audio_words, audio_letters)
        if card.get("type") == "word" and card.get("pos") not in ("letter",):
            word_count += 1
            if not card.get("meaning"):
                missing_meaning.append(card.get("id", "?") + " (text=" + card.get("text", "") + ", pos=" + card.get("pos", "") + ")")
        if card.get("audio_path"):
            audio_count += 1

    with CARDS_JSON.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Enriched {len(cards)} cards (words={word_count}, audio_attached={audio_count})")
    if missing_meaning:
        print(f"WARN: {len(missing_meaning)} word cards still missing meaning:")
        for m in missing_meaning:
            print("  -", m)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
