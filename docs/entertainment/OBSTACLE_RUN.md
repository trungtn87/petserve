# Ăn vật rơi

Giữ class/save key `ObstacleRun` để tương thích code cũ, nhưng gameplay đã chuyển từ **né vật rơi** sang **ăn vật rơi**.

## Gameplay

- Màn chơi dọc 320×420.
- Pet di chuyển trái/phải.
- Mobile: chạm/kéo trực tiếp trên playfield.
- Desktop: phím Trái/Phải.
- Không giới hạn thời gian; ván chỉ kết thúc khi mất đủ 3 mạng.
- Vật viền xanh là đồ ăn: chạm vào để ăn và cộng điểm.
- Vật viền đỏ là vật không ăn được: đá, lon, chất độc; chạm vào mất 1 mạng.
- Độ khó tăng dần theo thời gian rồi giữ ở mức trần.
- Đồ ăn có nhiều mức điểm; vật hiếm cho điểm cao hơn.

## Điểm và thưởng

- Điểm chỉ tăng khi ăn vật phẩm hợp lệ.
- 500 điểm = 1 mảnh rương.
- Tối đa 10 mảnh rương mỗi ván.
- Ván rất ngắn vẫn nhận 1 mảnh tham gia.
- Khi lập **Top 1 mới** trên bảng xếp hạng thiết bị: thưởng thêm 1 rương.
- Match ID được lưu để chống nhận thưởng trùng.

## Bảng xếp hạng

- Lưu Top 10 điểm cao nhất trên thiết bị.
- Xếp theo điểm giảm dần; nếu bằng điểm thì ván hoàn thành trước đứng trên.
- Dữ liệu có archive riêng để giữ qua vòng đời pet.

## Code boundaries

- `gameplay/entertainment/obstacle_run_game.gd`: simulation, spawn, collision, score.
- `gameplay/entertainment/obstacle_run_records.gd`: Top 10 và kỷ lục.
- `screens/entertainment/obstacle_run_board.gd`: hiển thị pet, đồ ăn, vật cấm.
- `screens/entertainment/obstacle_run_activity_ui.gd`: HUD, BXH, lifecycle và settle thưởng.
- `MiniGameRewardService`: thưởng theo điểm và chống claim trùng.
