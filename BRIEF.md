# Don't Panic Island: brief

Settled in a `/grill-me` interview with the user on 2026-10-16. Decisions here are final for the pilot; change them
only with the user.

## Pitch
Minesweeper meets Civilization on a sunny cartoon desert island made of hexagons. A bureaucratic alien has mined
the island; you land a camp, push back the fog, gather wood, dig up treasure and clear every safe tile without
losing your crew. A homage to The Hitchhiker's Guide to the Galaxy runs through it.

## Platform and tech
- Godot 4.7, GDScript. Builds: Linux desktop and Web (browser; the Compatibility renderer: check the look there).
- Mouse and keyboard only (no touch, no gamepad). English only.
- Pilot scope: one island, one difficulty, intro, win and lose screens, help, Esc menu. A finished small game.

## Rules
- **Board:** a fixed, hand-shaped irregular island of about 200 land hexes, ringed by water hexes (water is not
  playable). Terrain: beach rim, palm groves, jungle middle, a few rock outcrops, 2-3 wrecks.
- **Mines:** 42 (about 21 % density). Mines and treasure are placed randomly each game, after the first click.
- **Classic Minesweeper on hexes:** 6 neighbours, numbers 0-6; left click reveals; zero tiles flood-fill; right
  click toggles a flag; clicking a number whose flags are all placed opens its other neighbours (chording).
- **Landing (first click):** chooses where the camp lands; that tile and its neighbours are guaranteed safe and
  open like a classic first click.
- **Territory:** after landing you can only reveal tiles adjacent to your revealed land **or to a flag** (you walk
  around a marked mine; without this, safe pockets enclosed by mines could never be reached). Flags can go on any
  visible tile. (Rule refined by the director on 2026-10-16 after the solver test found unwinnable boards.)
- **Crew:** 3 crewmates. A mine hit costs one crewmate (explosion, a skeleton stays on the tile as a gravestone,
  play continues). 0 crew = game over.
- **Resources:** wood from palm tiles (+1 each) buys tools. Gold is the score: 12 treasure chests on safe tiles
  (10-30 gold each), 3 wrecks (50 gold + 2 wood each). Beach, rock and jungle give nothing. Start with 3 wood.
- **Tools (wood):** metal detector (3): tests one hidden tile next to your land, no risk. Parrot scout (2): shows
  the number of any visible tile without opening it. Towel of safety (5): the next mine hit costs no crewmate (one
  charge held at a time).
- **Turns:** each reveal or tool use is one turn; a counter, no limit.
- **Win:** every safe tile revealed. **Score** = gold + crew left x 100 + a bonus for fewer turns. Best score saved
  locally.
- All numbers are first guesses; tune in playtesting.

## Look
- Sunny, cartoonish. Style lock: **Kenney low-poly** (Hexagon Kit, Pirate Kit, Nature Kit); KayKit props and the
  KayKit skeletons are allowed. Asset library proposals follow the lock.
- **Tile states:** *fog* (beyond reach): soft low drifting clouds. *Hidden* (next to your land): terrain visible
  (palm, beach, rock), contents unknown. *Revealed*: dug out, shows its number and anything on it.
- **Numbers:** chunky 3D digits lying on revealed tiles in classic colours (1 blue, 2 green, 3 red, 4 navy,
  5 maroon, 6 teal); they billboard to the camera when zoomed far out. Zero shows no number.
- **Flags:** small striped beach towels on sticks, flapping gently. Free and unlimited.
- **Crew:** small pirate figures at the camp; a lost one becomes a skeleton (KayKit).

## Camera
Orbits the island centre: Q/E or right-drag rotates, mouse wheel zooms (whole island to close-up), middle-drag pans
(clamped to the island), fixed tilt about 50 degrees.

## Story, intro and endings
- **Villain:** Commissioner Grumbleflox of the Galactic Planning Office, a grumpy alien bureaucrat in a wobbly UFO,
  clearing the island "for a hyperspace bypass" (a Vogon allusion; an original character).
- **Intro:** about 12 s, skippable with any key: the UFO wobbles in, Grumbleflox tosses bombs that vanish in sand
  puffs/clouds at decoy positions (the real placement is never shown), a sperm whale and a bowl of petunias fall
  out too, then the camera swoops to the island. First game of a session: full intro; Play again: a 3 s version.
- **Lose:** all mines pop up with a bounce; the UFO swoops back and gloats in a speech bubble.
- **Win:** confetti and a treasure pile at the camp; the UFO flees; "So long, and thanks for all the treasure".
- Both end screens show the score with Play again and Quit.

## Hitchhiker's Guide homage (allusions only: no long quotes, no characters reused by name)
42 mines; "DON'T PANIC" in large friendly letters on the help screen; towels as flags and the towel of safety;
the whale and the petunias in the intro; "So long, and thanks for all the treasure" on the win screen.

## UI
- Help screen ("DON'T PANIC") with the rules: H or a button. Three one-time tips in the first game (first reveal,
  first number, first tool).
- HUD: crew, wood, gold, turns, tool buttons.
- Esc menu: Resume, Restart, Help, Music volume, SFX volume, Quit.

## Audio
Procedural music loop in Python (cheerful steel drum and ukulele feel); sound effects from the Kenney library (dig,
flag, explosion, coins, UI).

## Testing (studio rule)
- `--autopilot`: a solver bot plays a seeded game to the end (win), logging GAME_ markers; also a seeded losing
  run. The check in the editor and in the exported builds.
- Logic tests: board generation (counts, safe landing, territory rule), numbers, flood fill, chording, tools,
  scoring.

## Assets
From the studio asset library (docs/assets.md), CC0, reviewed by the user. Known gaps: a low-poly sperm whale and a
bowl of petunias (offer a Blender model or a TRELLIS.2 generation in the asset review).
