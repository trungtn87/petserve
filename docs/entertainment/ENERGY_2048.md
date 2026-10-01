# 2048 — Ghép năng lượng

Implemented in PetHome → Giải trí → 2048. Available throughout the pet lifecycle;
fragment rewards do not consume the existing Stage 2 shared activity chest quota.

## Rules and rewards

- 4×4 board, two starting tiles, four-direction swipe (mouse drag / arrow keys on desktop).
- Slide toward the chosen edge; merge equal adjacent tiles once per move.
- Only a changed board spawns one tile: 90% 2, 10% 4.
- Score increases by the value of each merged tile. Best score persists across lives.
- Win and stop at 2048. Lose only when the full board has no horizontal/vertical pair.
- No timer, power-ups, undo, or daily cap.
- Highest tile 128 / 256 / 512 / 1024 / 2048 awards 1 / 2 / 3 / 5 / 10 fragments.
- Only the highest tier pays, including losses. Early finish asks for confirmation.
- Below 128 awards zero fragments but still settles the match and allows a new one.
- Existing ChestService combines these fragments with salvage fragments, automatically
  crafting each ten into the usual recycled chest at the pet's current stage.

## Ownership and persistence

`Energy2048Rules` is pure move/score/terminal/reward logic.
`Energy2048Session` owns the board, RNG state, score, match ID, terminal state and settlement.
`InfantGameFacade` commits each changed move using the existing atomic metadata save.
`MiniGameRewardService` validates the saved match/run, grants fragments and sets settlement;
all reward, chest and settlement changes share one save. Failure restores the prior metadata.
`Energy2048ActivityUI` handles actions and feedback; `Energy2048Board` draws and animates tiles.

Metadata: `energy_2048` stores the active session and `run_id`; `energy_2048_best` stores
best score. RNG state is a string to avoid JSON integer precision loss. Back/close,
backgrounding and restarting the app preserve the board. A new pet life starts a new
session. Only the current match is claimable; completed IDs do not accumulate unboundedly.

## Verification

Run after importing with Godot 4.6.3:

```sh
godot --headless --path . --editor --quit
godot --headless --path . res://tools/test_energy_2048.tscn
```

Coverage includes directional merges, no chain merges, no-op spawning/RNG, terminal
states, JSON reload, reward thresholds, duplicate/wrong-run claims, chest crafting,
save-failure rollback/retry, and hub/touch/reward UI integration at phone viewport size.
This scene is included in the existing acceptance CI workflow.

Manual Android check: swipe in all directions, background/resume, close/reopen app,
confirm/cancel early finish, reach a reward tier, claim and inspect Kho. Desktop
headless tests do not replace a physical Android touch/rendering check.
