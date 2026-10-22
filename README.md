# Don't Panic Island

**Minesweeper meets a sunny cartoon desert island made of hexagons.** A bureaucratic alien from the Galactic Planning
Office has mined the island: it is scheduled for demolition. Have a nice day. You land a camp, push back the fog, dig up treasure, put beach
towels on the mines and try to clear every safe tile without losing your crew. A homage to The Hitchhiker's Guide to
the Galaxy runs through it: bring a towel, and don't panic.

**▶ Play in the browser:** https://hennie42.github.io/DontPanicIsland/
(desktop browsers with mouse and keyboard work best; phones and tablets work with touch controls)

Made with Godot 4.7. A small, finished game, and an experiment in how much of a game **local AI models** running on
a home PC can build (see [How it was made](#how-it-was-made)).

## How to play
- **Your first click lands the camp.** That tile and its neighbours are always safe.
- **Numbers** count the mines on the six neighbouring tiles (0-6), like classic Minesweeper on hexes.
- **Towels** mark the mines you've found. Click a number whose towels are all placed to open the rest around it.
- **You can only dig next to your land or a towel**: the fog lifts as your territory grows.
- **3 crew.** A mine costs one crewmate (a skeleton marks the spot) and play goes on; lose all three and the game
  is over. **Win** by digging every safe tile.
- **Palms give wood, chests and wrecks give gold.** Spend wood on tools:
  - Metal detector (3 wood): tests one tile, no risk
  - Parrot scout (2 wood): shows a hidden number
  - Towel of safety (5 wood): the next mine costs no crewmate

25 islands: the hand-made original and 24 generated ones, each checked by a solver bot to be winnable. Every game
picks one at random; mines and treasure are placed after your first click.

### Controls
| | Mouse and keyboard | Touch |
|---|---|---|
| Dig | Left click | Tap |
| Towel | Right click | Hold |
| Move the map | Drag, WASD or arrow keys | Drag |
| Turn | Right-drag or Q/E | Twist |
| Zoom | Mouse wheel or +/- | Pinch |
| Help / menu | H / Esc (the menu has the leaderboard) | Buttons |

### Score and leaderboard
`score = gold + 100 × crew left + max(0, 400 − 2 × turns)`. Only won games count. After a win you can put a
1-5 character nickname (A-Z, 0-9) on the shared leaderboard: top 10 of all time and of this week.

The leaderboard runs on [Supabase](https://supabase.com). The game holds only the public key; every write goes
through database functions that check the nickname and that the score is plausible. Apart from a nickname you choose
to submit, the game sends only anonymous counters (game loaded / played / won / lost, per island) and nothing that
identifies you.

## How it was made
The game was built in about a week with
[local-studio](https://github.com/hennie42/local-studio), a set of tools for making small games and movie clips with
a **local-first** approach: a cloud model plans and reviews, and AI models running on the PC under the desk do as
much of the actual work as possible.

**The roles**
- **Henrik, The Executive Producer (human):** the idea, every design decision, art direction and lots of playtesting.
- **Claude (cloud, the director):** turned an interview with The Executive Producer into the design brief, cut the game into 19
  tickets, each with an automated acceptance test, and reviewed the results. It also made the playtest fixes and
  the polish passes.
- **Local models (the workers):** wrote the tickets, unattended. A dispatcher hands each ticket to a worker model
  running in [Claude Code](https://claude.com/claude-code) pointed at a local model server, runs the ticket's test
  and on failure retries with a different model family. Nobody wrote code by hand for these tickets.

**The local models**
- **Gemma 4 26B-A4B** for first attempts, and **Bonsai 2 27B** for retries.
- They ran on an RTX 5070 Ti (16 GB) and an RTX 2060 (6 GB), with 64 GB RAM.

**How much local AI**
| | |
|---|---|
| Tickets | 19 in total: 18 built by local models, 1 by Claude (the intro's whale and petunias, a Blender script) |
| Who passed them | Gemma 4: 12 tickets, all on the first attempt. Bonsai 2: 6 tickets, as the retry after Gemma failed |
| Worker runs | 27, about 13 hours of local GPU time |
| What they built | board rules, solver bot, board view, camera, HUD, game controller and autopilot, help and menus, intro, win/lose screens, music and sound, camp and crew, exports, ambient life and all the dig/mine/treasure effects |
| Share of the code | about two thirds of the game's script lines today were last written by a local model |

The rest came from the director: fixes found in playtesting (input, layout, camera framing), the colour scheme and
look, the sea shader, the 24 generated islands, the web build and the leaderboard. The local models were good at
well-specified tickets with a clear test, and still needed a human and a stronger model for "does this feel right?".

## Building it yourself
- **Engine:** Godot 4.7. Open `project.godot`; the main scene is `scenes/main.tscn`.
- **Web build:** uses the Compatibility renderer without threads, so it runs on plain static hosting.
  `tools/deploy_pages.sh` exports it and publishes it to the `gh-pages` branch.
- **Leaderboard:** the schema is in `supabase/migrations/` (deploy with `npx supabase db push`), and
  `supabase/tests/db_test.mjs` tests it locally. Without network the game simply shows "Leaderboard offline".
- **Tests:** unit tests with `tools/test.sh tests/test_*.gd`, and probes (scenes that drive the real game with
  real input events) with `tools/probe.sh tests/<probe>.tscn ...`. Every game also has an `--autopilot` mode that
  plays itself to the end.
- **The process:** `BRIEF.md` is the design brief, `tickets/` holds the ticket prompts the local models worked
  from, and `AGENTS.md` is the guide every AI agent read first.

## Credits and license
- Code: MIT (see [LICENSE](LICENSE)).
- 3D models, sounds and fonts: CC0 from [Kenney](https://kenney.nl) and [KayKit](https://kaylousberg.itch.io) (see
  [CREDITS.md](CREDITS.md)), thank you!
- The music (steel drum and ukulele) is synthesised in code by `tools/make_music.py`.
