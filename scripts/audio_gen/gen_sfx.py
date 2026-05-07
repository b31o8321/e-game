#!/usr/bin/env python3
"""Procedural SFX generator for 知识神塔 — anime/JRPG-style UI/battle SFX.

All synthesized from scratch with numpy. Writes 44.1kHz mono WAV files.
"""

from __future__ import annotations

import math
import os
import wave
from typing import List

import numpy as np

SR = 44100


# ── basic helpers ────────────────────────────────────────────

def env_exp(n: int, tau: float) -> np.ndarray:
    t = np.arange(n) / SR
    return np.exp(-t / tau)


def env_attack_release(n: int, attack_s: float = 0.005, release_s: float | None = None) -> np.ndarray:
    env = np.ones(n)
    a = max(int(SR * attack_s), 1)
    env[:a] = np.linspace(0, 1, a)
    if release_s is not None:
        r = max(int(SR * release_s), 1)
        env[-r:] = np.linspace(1, 0, r)
    return env


def sine(freq, dur, amp=1.0, phase=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    return amp * np.sin(2 * np.pi * freq * t + phase)


def sweep(f_start, f_end, dur, amp=1.0, shape="exp"):
    n = int(SR * dur)
    t = np.arange(n) / SR
    if shape == "exp":
        f = f_start * (f_end / f_start) ** (t / dur)
    else:
        f = f_start + (f_end - f_start) * (t / dur)
    phase = 2 * np.pi * np.cumsum(f) / SR
    return amp * np.sin(phase)


def noise(dur, amp=1.0):
    n = int(SR * dur)
    return amp * (np.random.rand(n) - 0.5) * 2.0


def lowpass_one_pole(sig: np.ndarray, cutoff_hz: float) -> np.ndarray:
    rc = 1.0 / (2 * np.pi * cutoff_hz)
    dt = 1.0 / SR
    alpha = dt / (rc + dt)
    out = np.zeros_like(sig)
    out[0] = sig[0] * alpha
    for i in range(1, len(sig)):
        out[i] = out[i - 1] + alpha * (sig[i] - out[i - 1])
    return out


def write_wav(path: str, samples: np.ndarray) -> None:
    peak = np.max(np.abs(samples)) if samples.size else 0
    if peak > 0:
        samples = samples / peak * 0.92
    samples_i16 = (samples * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(samples_i16.tobytes())


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


# ── individual SFX ─────────────────────────────────────────────

def sfx_card_pickup() -> np.ndarray:
    """Subtle 'tap' when card selected — quick wood/click."""
    dur = 0.08
    n = int(SR * dur)
    # noise burst high-passed-ish (use noise minus its low-pass)
    raw = noise(dur, 0.7)
    lp = lowpass_one_pole(raw, 1500)
    hp = raw - lp
    env = env_exp(n, 0.012)
    # add high-pitched click body
    body = sine(2400, dur, 0.4) * env_exp(n, 0.008)
    return (hp * env + body) * env_attack_release(n, 0.001)


def sfx_card_drop_success() -> np.ndarray:
    """Satisfying place sound — soft thump + bright chime."""
    dur = 0.45
    thump = sweep(220, 90, 0.18, amp=0.7, shape="exp")
    n_thump = len(thump)
    thump = thump * env_exp(n_thump, 0.06)
    # sparkle rising — major third interval bell
    bell1 = sine(1320, 0.35, 0.5) * env_exp(int(SR * 0.35), 0.18)
    bell2 = sine(1760, 0.35, 0.4) * env_exp(int(SR * 0.35), 0.16)
    bell2_pad = np.zeros(int(SR * 0.05))
    bell_sum = mix(np.concatenate([bell2_pad, bell1]), np.concatenate([bell2_pad, bell2]))
    return mix(thump, bell_sum * 0.7)


def sfx_card_drop_fail() -> np.ndarray:
    """Soft 'wrong' tone — gentle minor second descending, not punishing."""
    dur = 0.28
    n = int(SR * dur)
    tone1 = sine(440, 0.14, 0.6) * env_exp(int(SR * 0.14), 0.07)
    tone2 = sine(415, 0.14, 0.5) * env_exp(int(SR * 0.14), 0.07)
    pad = np.zeros(int(SR * 0.10))
    return mix(tone1, np.concatenate([pad, tone2]))


def sfx_damage_hit() -> np.ndarray:
    """Punchy impact — kick-style."""
    dur = 0.18
    n = int(SR * dur)
    # downward freq sweep + body noise
    body = sweep(330, 60, dur, amp=0.9, shape="exp")
    body *= env_exp(n, 0.05)
    crack = noise(0.04, 0.7) * env_exp(int(SR * 0.04), 0.012)
    return mix(body, crack)


def sfx_heal() -> np.ndarray:
    """Sparkly chime — major arpeggio rising."""
    dur = 0.65
    notes = [880, 1108, 1320, 1760]  # A5 C#6 E6 A6
    parts = []
    for i, f in enumerate(notes):
        delay = i * 0.07
        offset = int(SR * delay)
        ndur = 0.45
        sig = sine(f, ndur, 0.5) * env_exp(int(SR * ndur), 0.20)
        # FM-y bell-ish brightness
        bell = sine(f * 2, ndur, 0.18) * env_exp(int(SR * ndur), 0.12)
        sig += bell
        seg = np.concatenate([np.zeros(offset), sig])
        parts.append(seg)
    return mix(*parts)


def sfx_shield() -> np.ndarray:
    """Magical barrier — sustained whoosh + shimmer."""
    dur = 0.55
    sw = sweep(180, 720, 0.45, amp=0.55, shape="exp")
    n_sw = len(sw)
    sw *= env_attack_release(n_sw, attack_s=0.04, release_s=0.15)
    shimmer = sine(1760, 0.55, 0.25) * np.sin(2 * np.pi * 7 * np.arange(int(SR * 0.55)) / SR) * env_exp(int(SR * 0.55), 0.35)
    air = lowpass_one_pole(noise(0.55, 0.35), 2400) * env_exp(int(SR * 0.55), 0.30)
    return mix(sw, shimmer, air * 0.5)


def sfx_combo_3() -> np.ndarray:
    """Rising whoosh — combo 3 trigger."""
    dur = 0.35
    sw = sweep(200, 1200, dur, amp=0.7, shape="exp")
    n = len(sw)
    sw *= env_attack_release(n, attack_s=0.02, release_s=0.10)
    air = lowpass_one_pole(noise(dur, 0.55), 3500) * env_attack_release(n, 0.01, 0.10)
    return mix(sw, air * 0.45)


def sfx_combo_perfect() -> np.ndarray:
    """Magical shimmer — perfect combo. Bright bell cascade."""
    dur = 0.85
    notes = [1320, 1760, 2093, 2637, 3136]  # E6 A6 C7 E7 G7
    parts = []
    for i, f in enumerate(notes):
        delay = i * 0.05
        offset = int(SR * delay)
        ndur = 0.6
        sig = sine(f, ndur, 0.45) * env_exp(int(SR * ndur), 0.18)
        # FM modulation gives it a bell-like character
        mod = sine(f * 1.5, ndur, 0.3) * env_exp(int(SR * ndur), 0.12)
        sig += mod * 0.6
        seg = np.concatenate([np.zeros(offset), sig])
        parts.append(seg)
    air = lowpass_one_pole(noise(0.4, 0.4), 5000) * env_exp(int(SR * 0.4), 0.18)
    parts.append(air)
    return mix(*parts)


def sfx_enemy_defeated() -> np.ndarray:
    """Triumphant pop — short major-third chord + sparkle."""
    dur = 0.55
    chord_freqs = [523, 659, 784]  # C5 E5 G5
    parts = []
    for f in chord_freqs:
        sig = sine(f, 0.5, 0.5) * env_exp(int(SR * 0.5), 0.22)
        parts.append(sig)
    sparkle = sine(2093, 0.4, 0.3) * env_exp(int(SR * 0.4), 0.15)
    parts.append(sparkle)
    # poppy attack — brief click
    click = noise(0.02, 0.5) * env_exp(int(SR * 0.02), 0.005)
    parts.append(click)
    return mix(*parts)


def sfx_victory() -> np.ndarray:
    """Victory chime — simple ascending fanfare."""
    notes = [(523, 0.0), (659, 0.10), (784, 0.20), (1047, 0.32)]  # C5 E5 G5 C6
    parts = []
    for f, delay in notes:
        offset = int(SR * delay)
        sig = sine(f, 0.6, 0.5) * env_exp(int(SR * 0.6), 0.25)
        bell = sine(f * 2, 0.6, 0.25) * env_exp(int(SR * 0.6), 0.18)
        seg = np.concatenate([np.zeros(offset), sig + bell])
        parts.append(seg)
    return mix(*parts)


def sfx_button_click() -> np.ndarray:
    """UI click — short tick."""
    dur = 0.05
    n = int(SR * dur)
    body = sine(1100, dur, 0.7) * env_exp(n, 0.012)
    click = noise(0.01, 0.5) * env_exp(int(SR * 0.01), 0.003)
    return mix(body, click)


def sfx_button_hover() -> np.ndarray:
    """Subtle hover — soft high tick."""
    dur = 0.06
    n = int(SR * dur)
    body = sine(2000, dur, 0.35) * env_exp(n, 0.020)
    return body * env_attack_release(n, 0.003, 0.020)


def sfx_submit_swoosh() -> np.ndarray:
    """AP submit start — magical swoosh up."""
    dur = 0.40
    sw = sweep(150, 1500, dur, amp=0.6, shape="exp")
    n = len(sw)
    sw *= env_attack_release(n, attack_s=0.03, release_s=0.10)
    # bright chime tail
    chime = sine(1760, 0.30, 0.4) * env_exp(int(SR * 0.30), 0.16)
    chime_pad = np.zeros(int(SR * 0.12))
    chime_seg = np.concatenate([chime_pad, chime])
    air = lowpass_one_pole(noise(dur, 0.4), 3000) * env_attack_release(n, 0.02, 0.12)
    return mix(sw, chime_seg, air * 0.35)


# ── driver ─────────────────────────────────────────────────────

SFX_BUILDERS = [
    ("card_pickup", sfx_card_pickup),
    ("card_drop_success", sfx_card_drop_success),
    ("card_drop_fail", sfx_card_drop_fail),
    ("damage_hit", sfx_damage_hit),
    ("heal", sfx_heal),
    ("shield", sfx_shield),
    ("combo_3", sfx_combo_3),
    ("combo_perfect", sfx_combo_perfect),
    ("enemy_defeated", sfx_enemy_defeated),
    ("victory", sfx_victory),
    ("button_click", sfx_button_click),
    ("button_hover", sfx_button_hover),
    ("submit_swoosh", sfx_submit_swoosh),
]


def main():
    out_dir = os.environ.get("SFX_OUT", "/tmp/sfx_wav")
    os.makedirs(out_dir, exist_ok=True)

    np.random.seed(7)

    for name, fn in SFX_BUILDERS:
        sig = fn()
        path = os.path.join(out_dir, f"{name}.wav")
        write_wav(path, sig)
        sec = len(sig) / SR
        kb = os.path.getsize(path) / 1024
        print(f"[sfx] {name}.wav  ({kb:.1f} KB, {sec*1000:.0f} ms)")


if __name__ == "__main__":
    main()
