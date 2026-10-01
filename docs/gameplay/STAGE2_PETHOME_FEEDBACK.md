# Stage 2 PetHome Feedback

## Goal

PetHome must explain the Stage 2 state without revealing a deterministic evolution result before the player evolves.

The UI separates three concepts:

- what the pet already has;
- what current Gene Items are directing;
- when the Stage 2 lifecycle becomes READY.

## Info panel

The Info section shows:

```text
Đang có
  Mắt: ...
  Đuôi: ...
  ...

Gene Item
  1 / 2

Đang định hướng
  Mắt → Moon (+20)

Kết quả
  Chưa khóa • chốt khi tiến hóa
```

A Gene direction is never presented as a guaranteed final trait.

When Mythic Destiny is already known, the panel also shows:

```text
Thú thần thoại    Nekomata
```

## Gene item detail

Gene Item detail now exposes:

- target body part;
- direction;
- all stages where that locus is allowed;
- current stage Gene usage;
- remaining Gene uses or `ĐÃ HẾT LƯỢT`;
- a reminder that the Gene is only a direction until evolution resolves it.

Stage 2 remains capped at two Gene Item uses.

## Stage status

The evolution section distinguishes Growth from real Stage age.

It shows:

```text
Trưởng thành   75%
Tuổi stage     100%
Deadline       Đã tới hạn
Trạng thái     SẴN SÀNG TIẾN HÓA
```

The deadline uses `age_remaining_seconds`, not `growth_remaining_seconds`.

Therefore a junk item may reduce Growth without extending the 48-hour real Stage deadline.

Once READY, the evolution button becomes available and Growth items remain locked.

## Entertainment

Maze Hunt and Snake Hunt share four reward chests for the entire Stage 2.

UI wording is remaining-first:

```text
Maze + Snake: Rương chung còn 3/4
```

After all four rewards:

```text
Maze + Snake: Rương chung còn 0/4 • vẫn chơi tự do
```

The same counter is shown on both activity cards and inside each minigame.

READY does not end Stage 2. Until the player actually evolves, any unclaimed Stage 2 activity chests may still be earned.

Caro remains playable but Stage 1 rewards are not reopened.

## Test coverage

`tools/test_stage2_pethome_feedback.gd` covers:

- Stage 2 Gene detail starts at 0/2;
- one Gene leaves 1 use;
- two Genes mark the cap exhausted;
- allowed stages are exposed from `StageGenePolicy`;
- the independent Stage age starts at 48 hours;
- the age deadline can force READY while Growth remains below 100%;
- READY Stage 2 can still claim an unclaimed Maze/Snake reward;
- the shared activity snapshot reports the remaining chest count.
