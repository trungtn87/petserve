# Vượt chướng ngại vật

Replaces Maze Hunt/Pacman in the PetHome entertainment hub. Caro and Snake remain available.

- Tap the playfield or the large **NHẢY** button. Keyboard: Space / Enter / Up.
- The round waits for the first tap; the pet then runs automatically.
- Survive 40 seconds with 3 lives. Rocks appear every 2–2.6 seconds, with gradual speed increase.
- A collision consumes one life, removes that rock, and grants 1.5 seconds of protection.
- Taps just before landing are buffered for 0.14 seconds; no midair double jump.
- Replay creates a fresh match ID. Closing the activity stops its simulation.
- Free play is available at every stage. Winning in Stage 2 allows a chest, subject to the existing shared four-chest limit with Snake.
- Score: 10/second, 100/rock passed, plus 500 + 400 per remaining life on a win. Tiers use 1000 / 2000 / 3000 thresholds.

## Code boundaries

- `gameplay/entertainment/obstacle_run_game.gd`: fixed-step movement, generation, collisions, score and result.
- `screens/entertainment/obstacle_run_board.gd`: scalable drawing and playfield input.
- `screens/entertainment/obstacle_run_activity_ui.gd`: controls, round lifecycle and reward request.
- `MiniGameRewardService`: reward tiers, persistence, per-match deduplication and shared cap.

The internal saved reward key remains `maze_hunt` deliberately. Existing claimed rewards, match IDs and chest provenance remain valid; replacing a game must not reset the shared reward limit. Public code/UI now uses Obstacle Run names.

## Verification (Godot 4.6.1)

Use a fresh `XDG_DATA_HOME` for each test run to avoid touching real saves:

```sh
godot --headless --editor --path . --import
XDG_DATA_HOME=/tmp/petverse-runner-tests godot --headless --path . tools/test_obstacle_run.tscn
```

Runner regression covers ready/start/restart, collision/loss/frozen finish, twenty seeded clean wins at 30/60 FPS, old saved reward caps, hub layout at 360×640, closing the activity and duplicate reward clicks.

The broader `test_infant_home.tscn` still stops at its evolution preparation fixture (`prepare evolution`, then missing `data`); its minigame assertions pass before that point. The dedicated runner test covers reward persistence, duplicate claims and stage restrictions independently.
