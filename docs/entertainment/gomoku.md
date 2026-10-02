# Gomoku 15×15

Giải trí → Gomoku. Luật freestyle: Đen đi trước, ít nhất 5 quân liên tiếp theo ngang/dọc/hai đường chéo thắng, kể cả bị chặn hai đầu. Không dùng luật cấm Renju. Bàn đầy không người thắng thì hòa.

Chạm chọn ô rồi bấm Đặt quân. Phóng chuyển giữa bàn 270 và 450 đơn vị; kéo vùng bàn để xem khi phóng. Chấm đỏ đánh dấu nước đi mới nhất, vòng xanh đánh dấu chuỗi thắng.

- 1 người: đấu với pet. AI ưu tiên thắng ngay, chặn nước thắng, đánh giá chuỗi và đầu mở quanh quân đã đặt. Giữ thưởng Caro/Stage 1 cũ; class TicTacToeGame và các signal cũ được giữ để tương thích.
- 2 người cùng máy: thay phiên Đen/Trắng trên một bàn.
- 2 máy: dùng kết nối chung trong Giải trí/Cài đặt qua Wi-Fi hoặc Bluetooth. Cả hai chọn chế độ qua mạng; khách bấm Sẵn sàng, chủ bấm Ván mới. Chủ là Đen, khách là Trắng. Ván tiếp theo cũng cần khách sẵn sàng.

Chủ phòng kiểm tra và xác nhận mỗi nước đi. Hai bên dùng ID ván và số thứ tự nước đi để loại gói trùng/cũ/sai lượt. Rời game hoặc mất kết nối dừng ván; kết nối chung vẫn giữ khi chỉ rời game. Ván không lưu qua đóng màn hình. Chế độ 2 người không nhận phần thưởng solo.

Kiểm thử: tools/test_gomoku.tscn, luật 4 hướng, không nối qua biên hàng, AI thắng/chặn, touch/chọn/xác nhận/phóng, luân phiên cùng máy, phiên Wi-Fi ENet thật, đồng bộ thắng, chơi lại, rời/rejoin, mất kết nối, hủy timer AI. Bluetooth dùng cùng giao thức, cần kiểm tra trên hai Android thật.
