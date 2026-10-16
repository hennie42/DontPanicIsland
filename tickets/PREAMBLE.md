# Ticket for Don't Panic Island (Godot 4.7, GDScript)

You are a worker on a small studio game. Read `AGENTS.md` first (Godot 4 rules, project layout, how to run things),
and `BRIEF.md` for what the game is. Then do exactly this ticket.

Rules for every ticket:
- GDScript only, Godot **4.7** syntax (not Godot 3). Look up APIs in `godot-ref/api/<Class>.txt` and recipes in
  `godot-ref/cookbook/`. Never guess an API from memory.
- After every edit run `studio godot-check` and fix every error it reports.
- Use the helpers that exist; don't re-derive them: `scripts/hex.gd` (class `Hex`: hex grid maths, world <-> hex,
  neighbours, picking) and `data/island.json` (the island). Use static typing (`var x: int`, `-> void`).
- The acceptance check is given at the end. Run it yourself before you finish. **Never edit files under
  `tests/`**: they are the specification; edited tests are restored before the director's check.
- Touch only the files the ticket names (plus new files it asks for). Do not commit; the director commits.
- Finish with a short report: what you changed, and the last output of the acceptance check.

## Game architecture (fixed by the director; build within it)
- `scripts/board.gd` (class `Board`): all rules and state, pure data. `scripts/solver.gd` (class `Solver`): the bot.
- `scripts/hex.gd` (class `Hex`): hex maths. `scripts/art.gd` (class `Art`): which asset for what and at what scale
  (`Art.tile("beach")`, `Art.prop("palm_a")`, `Art.TILE_TOP`). Never pick asset paths or scales yourself;
  `assets/INDEX.md` lists every asset.
- `scenes/main.tscn` + `scripts/main.gd`: the game controller. It creates, in code: `BoardView`
  (scripts/board_view.gd), `CameraRig` (scripts/camera_rig.gd), `Hud` (scripts/hud.gd), and later `Menu`, `Intro`,
  `Ending`, `Sfx`. Board changes go through main.gd: act on the Board, then `view.refresh(board)`,
  `hud.update_from(board)`.
- Game flags (after `--`): `--autopilot` (the Solver plays, one move every 0.1 s), `--seed=N` (board seed, default
  random; autopilot default 1), `--skip-intro`, `--force-lose` (autopilot test only: reveal mines until lost).
- Markers (`GameEvent.marker`): `START seed=N`, `MOVE <action> <q> <r>`, `END result=win|lose score=N turns=N`,
  `FINISH`, plus the ones a ticket names. Headless play check: `tools/play.sh SECONDS "MARKERS" --autopilot ...`.
