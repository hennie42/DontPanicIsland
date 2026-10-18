"""make_music.py: the game's music loop (audio/music_loop.wav), cheerful steel drum and ukulele feel (BRIEF.md).

16 bars at 112 bpm over C G Am F (one chord per bar): ukulele strums (D-DU-UDU), a steel-drum melody (8-bar phrase,
varied on the repeat), a bass line, light kick/snare and a shaker. Note tails past the end wrap to the start, so
the file loops seamlessly (the import sets loop_mode forward). Run from the project: python3 tools/make_music.py

Director rewrite 2026-10-18: the first version passed beat counts to sa.bars() (which takes bars), so every strum
and drum hit was 4x too far apart and most of the drums fell past the end of the loop.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import studio_audio as sa  # noqa: E402

BPM = 112
BARS = 16
BEAT = 60.0 / BPM            # seconds per beat
EIGHTH = BEAT / 2
LOOP = BARS * 4 * BEAT       # seconds
TAIL = 3.0                   # rendered past the end, then folded onto the start

CHORDS = "C G Am F"
# Steel-drum melody: (bar in the 8-bar phrase, eighth 0-7, note, eighths long). Chord tones on strong beats.
PHRASE = [
    (0, 0, "E5", 2), (0, 2, "G5", 2), (0, 4, "C6", 3), (0, 7, "G5", 1),
    (1, 0, "B5", 2), (1, 2, "D6", 2), (1, 4, "B5", 2), (1, 6, "G5", 2),
    (2, 0, "C6", 2), (2, 2, "A5", 2), (2, 4, "E5", 3), (2, 7, "A5", 1),
    (3, 0, "F5", 2), (3, 2, "A5", 2), (3, 4, "C6", 2), (3, 6, "A5", 2),
    (4, 0, "G5", 2), (4, 2, "E5", 1), (4, 3, "G5", 1), (4, 4, "C6", 4),
    (5, 0, "D6", 2), (5, 2, "B5", 2), (5, 4, "G5", 2), (5, 6, "D5", 2),
    (6, 0, "E5", 2), (6, 2, "A5", 2), (6, 4, "C6", 2), (6, 6, "E6", 2),
    (7, 0, "F5", 2), (7, 2, "A5", 1), (7, 3, "C6", 1), (7, 4, "A5", 2), (7, 6, "G5", 2),
]
# The repeat ends higher and leads back to the C of bar 0.
ENDING = [(7, 0, "F5", 2), (7, 2, "A5", 2), (7, 4, "C6", 2), (7, 6, "D6", 1), (7, 7, "E6", 1)]
BASS_ROOTS = ["C2", "G2", "A2", "F2"]
BASS_FIFTHS = ["G2", "D3", "E3", "C3"]


def steel(freq, seconds):
    """Steel-drum-ish tone: a sine with a bright inharmonic overtone, quick decay."""
    t = sa.t_axis(seconds)
    tone = np.sin(2 * np.pi * freq * t) + 0.45 * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-t * 9)
    tone += 0.2 * np.sin(2 * np.pi * freq * 3.92 * t) * np.exp(-t * 14)
    return tone * np.exp(-t * 3.2) * sa.adsr(t.size, 0.003, 0.05, 1.0, 0.04)


def uke_strum(tl, chord, at, down=True, gain=0.22):
    """Four strings, 12 ms apart; upstrokes start from the top string and are softer."""
    notes = chord + [chord[0] * 2]
    order = notes if down else notes[::-1]
    for i, f in enumerate(order):
        tl.add(sa.pluck(f, 0.45), at=at + i * 0.012, gain=gain * (1.0 if down else 0.7), pan=-0.25)


def make_music(path="audio/music_loop.wav"):
    tl = sa.Timeline(LOOP + TAIL)
    chords = sa.progression(CHORDS, octave=4)
    pads = sa.progression(CHORDS, octave=3)
    strum = [(0, True), (2, True), (3, False), (5, False), (6, True), (7, False)]   # D-DU-UDU in eighths

    for bar in range(BARS):
        t0 = bar * 4 * BEAT
        ci = bar % 4
        for eighth, down in strum:
            uke_strum(tl, chords[ci], t0 + eighth * EIGHTH, down)
        # soft pad underneath for warmth
        tl.add(sa.pad(pads[ci], 4 * BEAT, attack=0.3, release=0.4, brightness=1400.0), at=t0, gain=0.07)
        # bass: root on 1, fifth on 3, a pickup root on the "and" of 4
        tl.add(sa.bass(sa.hz(BASS_ROOTS[ci]), 1.6 * BEAT), at=t0, gain=0.42)
        tl.add(sa.bass(sa.hz(BASS_FIFTHS[ci]), 1.4 * BEAT), at=t0 + 2 * BEAT, gain=0.36)
        tl.add(sa.bass(sa.hz(BASS_ROOTS[ci]), 0.4 * BEAT), at=t0 + 3.5 * BEAT, gain=0.3)
        # drums: kick on 1 and 3, snare on 2 and 4 (light), shaker on every eighth with an offbeat accent
        for b in range(4):
            if b % 2 == 0:
                tl.add(sa.kick(0.3), at=t0 + b * BEAT, gain=0.45)
            else:
                tl.add(sa.snare(0.18), at=t0 + b * BEAT, gain=0.16, pan=0.1)
        for e in range(8):
            tl.add(sa.hat(0.05), at=t0 + e * EIGHTH, gain=0.09 if e % 2 == 0 else 0.15, pan=0.35)

    # melody on its own track, with a little reverb, then mixed in
    lead = sa.Timeline(LOOP + TAIL)
    for rep in range(2):
        notes = PHRASE if rep == 0 else [n for n in PHRASE if n[0] != 7] + ENDING
        for bar, eighth, note, length in notes:
            at = (rep * 8 + bar) * 4 * BEAT + eighth * EIGHTH
            lead.add(steel(sa.hz(note), max(length * EIGHTH * 1.6, 0.35)), at=at, gain=0.3, pan=0.15)
    tl.left += sa.reverb(lead.left, seconds=1.6, mix=0.25)
    tl.right += sa.reverb(lead.right, seconds=1.6, mix=0.25, seed=7)

    # fold the tail onto the start so the loop is seamless, then write exactly LOOP seconds
    n = int(LOOP * sa.SR)
    out = sa.Timeline(LOOP)
    out.left[:] = tl.left[:n]
    out.right[:] = tl.right[:n]
    tail = tl.left.size - n
    out.left[:tail] += tl.left[n:]
    out.right[:tail] += tl.right[n:]
    out.write(path, peak_db=-2.0)
    print(f"wrote {path}: {LOOP:.2f} s, {BARS} bars at {BPM} bpm")


if __name__ == "__main__":
    make_music()
