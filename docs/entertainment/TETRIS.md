# Tetris — endless entertainment

Available in PetHome → Giải trí at every pet stage. Board: 10 × 20;
seven-bag randomization, two next previews, one hold, ghost landing preview.
No time limit, victory target, revive or reward cap. A blocked spawn loses.

## Difficulty and score

Start level 1; +1 level per six cleared rows, capped at level 10.
Gravity by level: 0.65 / 0.55 / 0.45 / 0.37 / 0.30 / 0.25 / 0.20 /
0.17 / 0.14 / 0.12 seconds per cell. Lock delay: 0.45 seconds initially,
0.25 at the cap. At most eight movement/rotation lock-delay resets per piece.
Clock, level and gravity stop while help, ranking, exit confirmation or pause
is visible. App background/focus loss pauses; resume is explicit.

Clear 1/2/3/4 rows: 100/300/500/800 × level before that clear.
Combo (consecutive pieces clearing rows): +50 × combo index × level,
with index zero for the first clear. A four-row clear following the previous
four-row clear gets +400 × level; intervening non-clearing pieces preserve
that chain but reset combo. A one/two/three-row clear breaks the chain.
Soft/hard drop give no points. Score and rows continue indefinitely while
speed and score multiplier remain capped at level 10. No elapsed-time ranking.

## Rewards and records

On loss, floor(score / 2000) fragments enter the existing shared fragment pool.
Every ten fragments automatically create a recycled chest for the current
stage; no per-match fragment limit. A score strictly above the previous top
receives one additional recycled chest, at most once per local device day.
Initial top to beat: 5000. Ties do not break top. Further same-day records
still update the leaderboard and earn score fragments. Reversing the device
date cannot reopen an already rewarded day; this is offline, not server time.

Top ten completed matches are stored with score, rows, capped level and date.
Rankings are local to the device, not an online shared leaderboard.
Unfinished/abandoned games do not rank or reward. Closing the activity/hub
forfeits the active match; the activity back button confirms that decision.
The live match is in memory and does not resume after app termination.

The facade owns the session: settlement never accepts a UI-supplied score.
Records, daily bonus and inventory changes share one AtomicJson metadata save.
A failed save restores all changes and allows reward retry. Settlement marks
the live match only after a successful save; repeated settlement is rejected.
When per-life metadata is deleted, SaveManager first archives tetris_records
in user://tetris_records_v1.json. If archival fails, it refuses deletion so
PetHome's existing reset failure handling runs. The next life restores that
archive, preserving both top scores and the daily bonus date.

## Controls and validation

Touch: hold left/right for repeat (180 ms delay, 70 ms repeat), rotate, hold,
hold down for soft drop (35 ms repeat), separate hard drop button.
Keyboard: arrows, Space hard drop, C hold, P pause.

Run import first, then:

```sh
godot --headless --path . res://tools/test_tetris.tscn
```

Tests cover bag fairness, collision/ghost/hold, clears/combo/chain, endless
level cap, lock reset limit, score reward, top-ten/daily rules, failed save
rollback, duplicate rejection, life reset continuity and 360×640 mobile UI.
Both existing acceptance/build workflows include this test.
