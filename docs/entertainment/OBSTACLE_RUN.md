# Né vật rơi

Thay gameplay chạy ngang cũ trong cùng slot `ObstacleRun` của PetHome. Tên class/save key được giữ để tương thích code và dữ liệu đã có.

## Gameplay

- Màn chơi dọc 320x420.
- Pet đứng ở vùng đáy và chỉ di chuyển trái/phải.
- Mobile: chạm/kéo trực tiếp trên playfield.
- Desktop: phím Trái/Phải.
- Ván bắt đầu ở lần điều khiển đầu tiên.
- Sống sót 40 giây với 3 mạng.
- Đá, thùng và quả cầu rơi từ trên xuống.
- Tốc độ rơi tăng dần từ 138 lên 228.
- Tần suất sinh tăng dần từ khoảng 0,88 giây xuống 0,48 giây.
- Nửa sau trận có thể xuất hiện 2 vật cùng hàng; cuối trận có thể có 3, nhưng hệ 5 lane luôn còn đường né.
- Va chạm mất 1 mạng và có 1,15 giây bảo vệ.
- Né một vật qua khỏi pet được cộng vào bộ đếm và điểm.

## Điểm

- 10 điểm mỗi giây sống.
- 60 điểm mỗi vật né được.
- Khi thắng: +500 và +400 cho mỗi mạng còn lại.
- Reward tier vẫn dùng ngưỡng cũ 1000 / 2000 / 3000 để không làm thay đổi kinh tế Stage 2.

## Tương thích save

- Reward service vẫn dùng storage key legacy `maze_hunt`.
- Claim cũ, match ID, shared cap 4 rương Stage 2 với Snake vẫn giữ nguyên.
- Chỉ tên hiển thị đổi thành **Né vật rơi**.

## Code boundaries

- `gameplay/entertainment/obstacle_run_game.gd`: fixed-step simulation, điều khiển ngang, spawn vật rơi, collision, score/result.
- `screens/entertainment/obstacle_run_board.gd`: board dọc, vẽ pet/vật rơi, touch/drag mapping.
- `screens/entertainment/obstacle_run_activity_ui.gd`: HUD, keyboard axis, round lifecycle, reward request.
- `MiniGameRewardService`: persistence, tier, dedup và shared reward cap.

## Verification

```sh
godot --headless --editor --path . --import
XDG_DATA_HOME=/tmp/petverse-falling-dodge godot --headless --path . tools/test_obstacle_run.tscn
```
