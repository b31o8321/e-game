#!/usr/bin/env python3
"""Procedural BGM generator for 知识神塔.

Generates 6 anime/JRPG-style royalty-free background tracks as 44.1kHz
mono 16-bit WAV files. Output is then converted to OGG by the bash
driver script.

All synthesized from scratch using numpy: no external samples used,
so the output is guaranteed CC0 / public-domain by the project author.
"""

from __future__ import annotations

import math
import os
import struct
import wave
from typing import List, Tuple

import numpy as np

SR = 44100  # sample rate

# ──────────────────────────────────────────────────────────────
# Music theory helpers
# ──────────────────────────────────────────────────────────────

NOTE_OFFSETS = {
    "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4,
    "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9,
    "A#": 10, "Bb": 10, "B": 11,
}


def note_to_freq(note: str, octave: int) -> float:
    """Convert e.g. ('C', 4) → 261.63 Hz. A4 = 440."""
    midi = 12 * (octave + 1) + NOTE_OFFSETS[note]
    return 440.0 * (2 ** ((midi - 69) / 12))


def parse_note(token: str) -> Tuple[str, int]:
    """Parse 'C4' / 'F#5' → ('C', 4) / ('F#', 5)."""
    if token[1] in ("#", "b"):
        return token[:2], int(token[2:])
    return token[0], int(token[1:])


# ──────────────────────────────────────────────────────────────
# Oscillators / patches
# ──────────────────────────────────────────────────────────────

def sine(freq: float, dur: float, amp: float = 1.0, phase: float = 0.0) -> np.ndarray:
    n = int(SR * dur)
    t = np.arange(n) / SR
    return amp * np.sin(2 * np.pi * freq * t + phase)


def soft_saw(freq: float, dur: float, amp: float = 1.0) -> np.ndarray:
    """Anti-aliased-ish saw using first 6 harmonics (band-limited approx)."""
    out = np.zeros(int(SR * dur))
    for h in range(1, 7):
        out += sine(freq * h, dur, amp / h)
    return 0.55 * out / 6.0


def piano_patch(freq: float, dur: float, amp: float = 1.0) -> np.ndarray:
    """Soft piano-ish tone: fundamental + minor harmonics with sharp attack
    and exponential decay."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    tone = (
        np.sin(2 * np.pi * freq * t)
        + 0.45 * np.sin(2 * np.pi * freq * 2 * t)
        + 0.18 * np.sin(2 * np.pi * freq * 3 * t)
        + 0.07 * np.sin(2 * np.pi * freq * 4 * t)
    )
    # ADSR-ish envelope: 8ms attack, exponential decay to ~0 over dur.
    attack = max(int(SR * 0.008), 1)
    env = np.ones(n)
    env[:attack] = np.linspace(0, 1, attack)
    decay_tau = max(dur * 0.7, 0.25)
    env *= np.exp(-t / decay_tau)
    return amp * tone * env


def pad_patch(freq: float, dur: float, amp: float = 1.0) -> np.ndarray:
    """Warm string-pad: detuned saws + slow attack/release."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    tone = (
        soft_saw(freq, dur)
        + soft_saw(freq * 1.005, dur) * 0.7
        + soft_saw(freq * 0.995, dur) * 0.7
    )
    if len(tone) > n:
        tone = tone[:n]
    elif len(tone) < n:
        tone = np.pad(tone, (0, n - len(tone)))
    # slow attack & release
    attack = max(int(SR * 0.18), 1)
    release = max(int(SR * 0.25), 1)
    env = np.ones(n)
    env[:attack] = np.linspace(0, 1, attack)
    if release < n:
        env[-release:] = np.linspace(1, 0, release)
    return amp * tone * env / 3.0


def pluck_patch(freq: float, dur: float, amp: float = 1.0) -> np.ndarray:
    """Karplus-Strong-ish pluck (simplified low-pass feedback)."""
    n = int(SR * dur)
    period = max(int(SR / freq), 2)
    # Seed buffer with white noise
    buf = (np.random.rand(period) - 0.5) * 2.0
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        # low-pass average (simple feedback)
        nxt = 0.5 * (buf[i % period] + buf[(i + 1) % period]) * 0.996
        buf[i % period] = nxt
    # Soft attack
    attack = max(int(SR * 0.005), 1)
    env = np.ones(n)
    env[:attack] = np.linspace(0, 1, attack)
    return amp * out * env


def bell_patch(freq: float, dur: float, amp: float = 1.0) -> np.ndarray:
    """Anime/JRPG-ish bell: FM-modulated sine."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * freq * 1.4 * t) * 2.5 * np.exp(-t / 0.4)
    car = np.sin(2 * np.pi * freq * t + mod)
    env = np.exp(-t / max(dur * 0.5, 0.2))
    return amp * car * env


def kick(dur: float = 0.18, amp: float = 1.0) -> np.ndarray:
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 110 * np.exp(-t * 30) + 50
    sig = np.sin(2 * np.pi * np.cumsum(f) / SR)
    env = np.exp(-t / 0.07)
    return amp * sig * env


def snare(dur: float = 0.16, amp: float = 1.0) -> np.ndarray:
    n = int(SR * dur)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 200 * t) * np.exp(-t / 0.04)
    noise = (np.random.rand(n) - 0.5) * 2.0 * np.exp(-t / 0.08)
    return amp * (0.5 * body + 0.7 * noise)


def hat(dur: float = 0.06, amp: float = 1.0) -> np.ndarray:
    n = int(SR * dur)
    noise = (np.random.rand(n) - 0.5) * 2.0
    t = np.arange(n) / SR
    env = np.exp(-t / 0.015)
    return amp * noise * env


# ──────────────────────────────────────────────────────────────
# Composition helpers
# ──────────────────────────────────────────────────────────────

def mix_at(track: np.ndarray, sample: np.ndarray, start_sample: int) -> None:
    end = start_sample + len(sample)
    if end > len(track):
        sample = sample[: len(track) - start_sample]
        end = len(track)
    if start_sample >= len(track):
        return
    track[start_sample:end] += sample


def render_arpeggio(
    track: np.ndarray,
    chord_notes: List[str],
    start_sec: float,
    dur_sec: float,
    note_dur: float,
    patch,
    amp: float = 0.4,
) -> None:
    n_notes = int(dur_sec / note_dur)
    for i in range(n_notes):
        token = chord_notes[i % len(chord_notes)]
        note, octave = parse_note(token)
        freq = note_to_freq(note, octave)
        s = int((start_sec + i * note_dur) * SR)
        mix_at(track, patch(freq, note_dur * 1.4, amp), s)


def render_chord_pad(
    track: np.ndarray,
    chord_notes: List[str],
    start_sec: float,
    dur_sec: float,
    amp: float = 0.32,
) -> None:
    for token in chord_notes:
        note, octave = parse_note(token)
        freq = note_to_freq(note, octave)
        s = int(start_sec * SR)
        mix_at(track, pad_patch(freq, dur_sec, amp / max(len(chord_notes) - 1, 1)), s)


def render_melody(
    track: np.ndarray,
    melody: List[Tuple[str, float]],  # (note_token_or_'r', duration_in_beats)
    start_sec: float,
    beat_sec: float,
    patch,
    amp: float = 0.55,
    octave_shift: int = 0,
) -> None:
    cursor = start_sec
    for token, beats in melody:
        dur = beats * beat_sec
        if token != "r":
            note, octave = parse_note(token)
            freq = note_to_freq(note, octave + octave_shift)
            s = int(cursor * SR)
            mix_at(track, patch(freq, dur * 1.05, amp), s)
        cursor += dur


def render_drum_pattern(
    track: np.ndarray,
    pattern: List[str],  # tokens: 'k', 's', 'h', '.' per 16th
    start_sec: float,
    bar_sec: float,
    amp_k: float = 0.55,
    amp_s: float = 0.4,
    amp_h: float = 0.18,
) -> None:
    step = bar_sec / len(pattern)
    for i, tok in enumerate(pattern):
        s = int((start_sec + i * step) * SR)
        if tok == "k":
            mix_at(track, kick(amp=amp_k), s)
        elif tok == "s":
            mix_at(track, snare(amp=amp_s), s)
        elif tok == "h":
            mix_at(track, hat(amp=amp_h), s)


# ──────────────────────────────────────────────────────────────
# Output
# ──────────────────────────────────────────────────────────────

def write_wav(path: str, samples: np.ndarray) -> None:
    # Normalize, then quantize to 16-bit
    peak = np.max(np.abs(samples))
    if peak > 0:
        samples = samples / peak * 0.92
    samples_i16 = (samples * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(samples_i16.tobytes())


def reverb_lite(samples: np.ndarray, decay: float = 0.32, delay_ms: int = 90) -> np.ndarray:
    """Cheap one-tap feedback reverb for 'space'."""
    delay = int(SR * delay_ms / 1000)
    out = samples.copy()
    fb = samples.copy()
    for _ in range(4):
        fb = np.roll(fb, delay) * decay
        fb[:delay] = 0
        out += fb
        decay *= 0.55
    return out


# ──────────────────────────────────────────────────────────────
# Tracks
# ──────────────────────────────────────────────────────────────

# Reusable chord progressions in C major / A minor (both share key signature),
# arranged for warm anime-RPG vibe.

# 4-bar progression in C: I → V → vi → IV (Pachelbel-ish anime classic)
PROG_CITY = [
    ["C3", "C4", "E4", "G4"],
    ["G2", "G3", "B3", "D4"],
    ["A2", "A3", "C4", "E4"],
    ["F2", "F3", "A3", "C4"],
]

# Hopeful menu progression (C → G → Am → Em → F → C → F → G)
PROG_MENU = [
    ["C3", "C4", "E4", "G4"],
    ["G2", "G3", "B3", "D4"],
    ["A2", "A3", "C4", "E4"],
    ["E2", "E3", "G3", "B3"],
    ["F2", "F3", "A3", "C4"],
    ["C3", "C4", "E4", "G4"],
    ["F2", "F3", "A3", "C4"],
    ["G2", "G3", "B3", "D4"],
]

# Battle (Am driving): Am F C G   |   Am F G E
PROG_BATTLE = [
    ["A2", "A3", "C4", "E4"],
    ["F2", "F3", "A3", "C4"],
    ["C3", "C4", "E4", "G4"],
    ["G2", "G3", "B3", "D4"],
    ["A2", "A3", "C4", "E4"],
    ["F2", "F3", "A3", "C4"],
    ["G2", "G3", "B3", "D4"],
    ["E2", "E3", "G3", "B3"],
]

# Boss (Dm phrygian-ish, more dramatic): Dm Bb F A | Dm Bb C A
PROG_BOSS = [
    ["D2", "D3", "F3", "A3"],
    ["A#1", "A#2", "D3", "F3"],
    ["F2", "F3", "A3", "C4"],
    ["A2", "A3", "C#4", "E4"],
    ["D2", "D3", "F3", "A3"],
    ["A#1", "A#2", "D3", "F3"],
    ["C3", "C4", "E4", "G4"],
    ["A2", "A3", "C#4", "E4"],
]


def build_main_menu(target_sec: float = 70.0) -> np.ndarray:
    """Dreamy hopeful piano + strings, sense of adventure. ~70 s loop."""
    bpm = 78
    beat = 60.0 / bpm
    bar = beat * 4
    total_samples = int(target_sec * SR)
    track = np.zeros(total_samples)

    # Background pad: 2-bar cycles through 8-chord progression
    cursor = 0.0
    while cursor < target_sec:
        for chord in PROG_MENU:
            render_chord_pad(track, chord, cursor, bar * 2, amp=0.22)
            cursor += bar
            if cursor >= target_sec:
                break

    # Piano arpeggio (top 3 notes of each chord)
    cursor = 0.0
    while cursor < target_sec:
        for chord in PROG_MENU:
            arp = chord[1:]  # upper notes
            render_arpeggio(track, arp, cursor, bar, beat / 2, piano_patch, amp=0.30)
            cursor += bar
            if cursor >= target_sec:
                break

    # Lead melody: simple uplifting motif over bars 8-24
    melody_a = [
        ("C5", 1), ("E5", 1), ("G5", 2),
        ("D5", 1), ("F5", 1), ("A5", 2),
        ("E5", 1), ("G5", 1), ("C6", 1.5), ("B5", 0.5),
        ("A5", 2), ("G5", 2),
        ("F5", 1.5), ("E5", 0.5), ("D5", 1), ("E5", 1),
        ("C5", 4),
    ]
    melody_start = bar * 4
    if melody_start < target_sec:
        render_melody(track, melody_a, melody_start, beat, piano_patch, amp=0.45)
    melody_repeat = bar * 12
    if melody_repeat < target_sec:
        render_melody(track, melody_a, melody_repeat, beat, bell_patch, amp=0.3)

    # Subtle bell sparkle on bar 1 of every 4 bars
    cursor = 0.0
    while cursor < target_sec:
        mix_at(track, bell_patch(note_to_freq("C", 6), 1.5, 0.18), int(cursor * SR))
        cursor += bar * 4

    track = reverb_lite(track, decay=0.32, delay_ms=110)
    return track


def build_city(target_sec: float = 80.0) -> np.ndarray:
    """Warm cozy RPG town — soft acoustic plucks, gentle pad."""
    bpm = 82
    beat = 60.0 / bpm
    bar = beat * 4
    total_samples = int(target_sec * SR)
    track = np.zeros(total_samples)

    # Pad bed
    cursor = 0.0
    while cursor < target_sec:
        for chord in PROG_CITY:
            render_chord_pad(track, chord, cursor, bar, amp=0.18)
            cursor += bar
            if cursor >= target_sec:
                break

    # Pluck arpeggio (cozy guitar-like)
    cursor = 0.0
    while cursor < target_sec:
        for chord in PROG_CITY:
            render_arpeggio(track, chord, cursor, bar, beat / 4, pluck_patch, amp=0.20)
            cursor += bar
            if cursor >= target_sec:
                break

    # Top piano melody with breathing space
    melody = [
        ("E5", 1), ("G5", 1), ("C5", 2),
        ("D5", 1), ("E5", 1), ("G4", 2),
        ("E5", 1), ("D5", 1), ("C5", 1), ("E5", 1),
        ("F5", 2), ("E5", 1), ("D5", 1),
    ]
    cursor = bar * 4
    while cursor < target_sec - bar * 4:
        render_melody(track, melody, cursor, beat, piano_patch, amp=0.40)
        cursor += bar * 4

    # Bell on first beat every 8 bars
    cursor = 0.0
    while cursor < target_sec:
        mix_at(track, bell_patch(note_to_freq("E", 6), 1.0, 0.13), int(cursor * SR))
        cursor += bar * 8

    track = reverb_lite(track, decay=0.30, delay_ms=130)
    return track


def build_battle(target_sec: float = 75.0) -> np.ndarray:
    """Medium tempo, encouraging not threatening. Adventurous JRPG battle."""
    bpm = 124
    beat = 60.0 / bpm
    bar = beat * 4
    total_samples = int(target_sec * SR)
    track = np.zeros(total_samples)

    # Pad bed — softer to leave room for percussion + lead
    cursor = 0.0
    while cursor < target_sec:
        for chord in PROG_BATTLE:
            render_chord_pad(track, chord, cursor, bar, amp=0.16)
            cursor += bar
            if cursor >= target_sec:
                break

    # Pluck/saw bass on root notes — drives the energy
    cursor = 0.0
    while cursor < target_sec:
        for chord in PROG_BATTLE:
            note, octave = parse_note(chord[0])
            freq = note_to_freq(note, octave)
            for sub in range(8):  # 8th-note bass
                s_pos = cursor + sub * (beat / 2)
                if s_pos >= target_sec:
                    break
                # Note shorter than the step for staccato
                mix_at(track, soft_saw(freq, beat * 0.45, amp=0.18) * np.exp(-np.linspace(0, 3, int(SR * beat * 0.45))), int(s_pos * SR))
            cursor += bar
            if cursor >= target_sec:
                break

    # Drum pattern — energetic but not punishing
    drum = ["k", ".", "h", ".", "s", ".", "h", ".", "k", "k", "h", ".", "s", ".", "h", "."]
    cursor = 0.0
    while cursor < target_sec:
        render_drum_pattern(track, drum, cursor, bar, amp_k=0.5, amp_s=0.32, amp_h=0.16)
        cursor += bar

    # Heroic lead on 3rd chord of each cycle (entry: bar 8)
    melody = [
        ("A4", 1), ("C5", 1), ("E5", 1), ("A5", 1),
        ("G5", 2), ("E5", 2),
        ("F5", 1), ("E5", 1), ("D5", 1), ("C5", 1),
        ("E5", 4),
        ("F5", 2), ("E5", 1), ("D5", 1),
        ("C5", 1), ("D5", 1), ("E5", 2),
        ("D5", 1), ("C5", 1), ("B4", 1), ("A4", 1),
        ("A4", 4),
    ]
    cursor = bar * 4
    while cursor < target_sec - bar * 4:
        render_melody(track, melody, cursor, beat, bell_patch, amp=0.28)
        cursor += bar * 8

    track = reverb_lite(track, decay=0.20, delay_ms=70)
    return track


def build_boss(target_sec: float = 75.0) -> np.ndarray:
    """More intense, anime JRPG boss vibe. Minor, orchestral, dramatic."""
    bpm = 138
    beat = 60.0 / bpm
    bar = beat * 4
    total_samples = int(target_sec * SR)
    track = np.zeros(total_samples)

    # Heavy pad
    cursor = 0.0
    while cursor < target_sec:
        for chord in PROG_BOSS:
            render_chord_pad(track, chord, cursor, bar, amp=0.22)
            cursor += bar
            if cursor >= target_sec:
                break

    # Pulsing bass — 16ths on root
    cursor = 0.0
    while cursor < target_sec:
        for chord in PROG_BOSS:
            note, octave = parse_note(chord[0])
            freq = note_to_freq(note, octave)
            for sub in range(16):
                s_pos = cursor + sub * (beat / 4)
                if s_pos >= target_sec:
                    break
                mix_at(track, soft_saw(freq, beat * 0.22, amp=0.13) * np.exp(-np.linspace(0, 3, int(SR * beat * 0.22))), int(s_pos * SR))
            cursor += bar
            if cursor >= target_sec:
                break

    # Aggressive drum — 4-on-floor with ride
    drum = ["k", "h", "h", "h", "s", "h", "h", "h", "k", "h", "h", "k", "s", "h", "h", "h"]
    cursor = 0.0
    while cursor < target_sec:
        render_drum_pattern(track, drum, cursor, bar, amp_k=0.55, amp_s=0.4, amp_h=0.18)
        cursor += bar

    # Dramatic motif (D minor)
    melody = [
        ("D5", 1), ("F5", 1), ("A5", 1), ("D6", 1),
        ("C6", 2), ("A5", 2),
        ("Bb5", 1), ("A5", 1), ("G5", 1), ("F5", 1),
        ("A5", 4),
        ("D5", 0.5), ("E5", 0.5), ("F5", 1), ("E5", 1), ("D5", 1),
        ("C5", 2), ("D5", 2),
        ("F5", 1), ("E5", 1), ("D5", 1), ("C#5", 1),
        ("D5", 4),
    ]
    cursor = bar * 4
    while cursor < target_sec - bar * 4:
        render_melody(track, melody, cursor, beat, bell_patch, amp=0.32)
        cursor += bar * 8

    # Orchestral hit on every 4 bars
    cursor = 0.0
    while cursor < target_sec:
        for f in (note_to_freq("D", 3), note_to_freq("A", 3), note_to_freq("F", 4)):
            mix_at(track, piano_patch(f, 0.6, 0.28), int(cursor * SR))
        cursor += bar * 4

    track = reverb_lite(track, decay=0.28, delay_ms=85)
    return track


def build_victory(target_sec: float = 6.0) -> np.ndarray:
    """Triumphant short fanfare ~6s."""
    bpm = 120
    beat = 60.0 / bpm
    track = np.zeros(int(target_sec * SR))

    # C major victory motif
    melody = [
        ("C5", 0.5), ("E5", 0.5), ("G5", 0.5), ("C6", 1),
        ("G5", 0.5), ("C6", 1.5),
        ("E6", 2),
    ]
    render_melody(track, melody, 0.2, beat, bell_patch, amp=0.6)
    # Pad chord underneath
    render_chord_pad(track, ["C3", "E3", "G3", "C4"], 0.2, target_sec - 0.2, amp=0.30)
    render_chord_pad(track, ["C4", "E4", "G4", "C5"], 0.2, target_sec - 0.2, amp=0.18)

    # Final bell sparkle
    mix_at(track, bell_patch(note_to_freq("C", 6), 2.0, 0.4), int(0.2 * SR))
    mix_at(track, bell_patch(note_to_freq("E", 6), 2.0, 0.3), int(0.7 * SR))
    mix_at(track, bell_patch(note_to_freq("G", 6), 2.0, 0.3), int(1.2 * SR))

    track = reverb_lite(track, decay=0.4, delay_ms=120)
    return track


def build_retreat(target_sec: float = 8.0) -> np.ndarray:
    """Gentle melancholy short piece ~8s."""
    bpm = 70
    beat = 60.0 / bpm
    track = np.zeros(int(target_sec * SR))

    # A minor: Am → F → C → G (descending feel)
    chords = [
        ["A2", "A3", "C4", "E4"],
        ["F2", "F3", "A3", "C4"],
        ["C3", "C4", "E4", "G4"],
        ["G2", "G3", "B3", "D4"],
    ]
    cursor = 0.0
    bar = beat * 4
    for chord in chords:
        render_chord_pad(track, chord, cursor, bar, amp=0.32)
        cursor += bar / 2

    # Sad piano motif descending
    melody = [
        ("E5", 1), ("D5", 1), ("C5", 2),
        ("B4", 1), ("A4", 1), ("G4", 2),
    ]
    render_melody(track, melody, 0.6, beat, piano_patch, amp=0.45)

    track = reverb_lite(track, decay=0.4, delay_ms=140)
    return track


# ──────────────────────────────────────────────────────────────
# Driver
# ──────────────────────────────────────────────────────────────

def main():
    out_dir = os.environ.get("BGM_OUT", "/tmp/bgm_wav")
    os.makedirs(out_dir, exist_ok=True)

    np.random.seed(42)  # deterministic plucks/snares

    builders = [
        ("main_menu", build_main_menu),
        ("city", build_city),
        ("battle", build_battle),
        ("boss", build_boss),
        ("victory", build_victory),
        ("retreat", build_retreat),
    ]

    for name, fn in builders:
        print(f"[bgm] generating {name} …", flush=True)
        wave_data = fn()
        path = os.path.join(out_dir, f"{name}.wav")
        write_wav(path, wave_data)
        size_kb = os.path.getsize(path) / 1024
        sec = len(wave_data) / SR
        print(f"  → {path} ({size_kb:.0f} KB, {sec:.1f}s)")


if __name__ == "__main__":
    main()
