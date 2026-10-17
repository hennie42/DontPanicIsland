import sys
import os
import numpy as np
import studio_audio as sa

# Ensure studio_audio is importable if running from tools/
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def make_music():
	bpm = 110
	total_bars = 16
	beats_per_bar = 4
	total_beats = total_bars * beats_per_bar
	seconds = total_beats * 60.0 / bpm

	# We create a timeline slightly longer to allow for tail,
	# but we will cut it to exactly the 16-bar length for seamless looping.
	tl = sa.Timeline(seconds)

	# Progression: C, G, Am, F (I-V-vi-IV)
	# Each chord will last 4 bars to make it a 16-bar loop with 4 chords.
	# Wait, "16-bar procedural loop ... I-V-vi-IV".
	# Usually this means the progression is repeated.
	# If the progression is 4 chords, repeating it 4 times gives 16 bars.
	# So 1 chord per bar, repeated 4 times.

	prog_text = "C G Am F"
	all_chords = sa.progression(prog_text, octave=4)

	for bar_idx in range(total_bars):
		chord_idx = bar_idx % 4
		current_chord = all_chords[chord_idx]

		start_time = sa.bars(bar_idx, bpm=bpm)
		bar_duration = sa.bars(1, bpm=bpm)

		# --- Ukulele Feel (Plucked notes) ---
		# Strumming pattern: 4 beats per bar
		for beat_idx in range(4):
			beat_start = start_time + sa.bars(beat_idx, bpm=bpm)
			# Strumming effect: slightly offset notes
			for offset in [0.0, 0.02, 0.04, 0.06]:
				# Play the chord notes as plucks
				for i, freq in enumerate(current_chord):
					# Vary the amplitude and timing slightly for a natural feel
					gain = 0.3 * (1.0 - i * 0.1)
					tl.add(sa.pluck(freq, seconds=0.4), at=beat_start + offset, gain=gain)

		# --- Steel Drum Feel (Bright Pads) ---
		# A bright pad that changes with the chord
		tl.add(sa.pad(current_chord, bar_duration, attack=0.2, release=0.2, brightness=3000.0, detune=5.0),
			   at=start_time, gain=0.2)
		# Another layer for the steel drum - maybe a higher pitch pluck
		for freq in current_chord:
			tl.add(sa.pluck(freq * 2, seconds=0.1), at=start_time, gain=0.15)

	# --- Percussion ---
	# Kick on 1 and 3
	for beat_idx in range(total_beats):
		b_time = sa.bars(beat_idx, bpm=bpm)
		if beat_idx % 2 == 0: # 1, 3, 5... (0, 2, 4 in 0-indexed)
			tl.add(sa.kick(0.3), at=b_time, gain=0.5)

		# Snare on 2 and 4
		if beat_idx % 2 == 1: # 2, 4, 6... (1, 3, 5 in 0-indexed)
			tl.add(sa.snare(0.2), at=b_time, gain=0.3)

	# Hi-hats on 8th notes
	for beat_idx_half in range(total_beats * 2):
		b_time = sa.bars(beat_idx_half / 2, bpm=bpm)
		tl.add(sa.hat(0.05), at=b_time, gain=0.2)

	# Add some global reverb for "cheerful" atmosphere
	# We can't easily apply reverb to the whole timeline in studio_audio.py
	# without modifying it, so we'll add it to individual clips or just rely on the pads.
	# Actually, let's just write it.

	tl.write("audio/music_loop.wav", peak_db=-1.5, fade_in=0.0, fade_out=0.0)
	print("Music loop generated successfully at audio/music_loop.wav")

if __name__ == "__main__":
	make_music()
