# Tank bảo vệ căn cứ

Trong Giải trí → Tank, chọn **1 người** để chơi ngay. Mỗi ván bắt đầu với
3 mạng. Giữ bốn phím bên trái để di chuyển, giữ nút BẮN bên phải để bắn;
hỗ trợ hai ngón đồng thời. Bàn phím: phím mũi tên và Space.

## Bản đồ và độ khó

20 map 13×13 thiết kế sẵn trong `gameplay/entertainment/tank/tank_maps.json`:
4 Phố gạch, 4 Pháo đài, 4 Sông hồ, 4 Rừng, 4 Hỗn hợp.
Vào trận bốc ngẫu nhiên; mỗi lần qua màn bốc một map chưa dùng. Hết 20 map
thì xáo lại, tránh lặp ngay map vừa chơi. Độ khó phụ thuộc số màn, không phụ
thuộc map bốc trúng; số địch, tốc độ và nhịp xuất hiện tăng tới màn 10 rồi giữ
nguyên. Không giới hạn số màn hoặc thời gian.

Gạch phá được, thép cần súng cấp tối đa, nước chặn xe nhưng đạn đi qua,
bụi cây trong suốt một phần để dễ thấy xe. Căn cứ ★ bị bắn trúng hoặc tất cả
người chơi hết mạng là kết thúc. Đạn người chơi cũng có thể phá căn cứ.
Xe địch có loại thường, nhanh, bắn và giáp 3 phát. Địch tìm đường tới căn cứ
và bắn xuyên tường gạch. Mỗi xe địch thứ 5 mang vật phẩm.

Vật phẩm: + nâng súng (3 cấp), S khiên 8 giây, F đóng băng 6 giây, B bom
hạ địch đang có trên sân, H gia cố tường quanh căn cứ 10 giây. Súng cấp 1
đạn nhanh; cấp 2 bắn được 2 viên đồng thời; cấp 3 phá thép. Khi chết mất
nâng súng và xuất hiện lại với khiên 3 giây.

## Hai người

1. Kết nối ở Giải trí hoặc Cài đặt bằng Wi-Fi/hotspot hoặc Bluetooth Android.
2. Cả hai mở Tank; khách bấm **Sẵn sàng**.
3. Chủ bấm **Bắt đầu đôi**. Chủ vàng P1, khách xanh P2.

Dùng chung map, căn cứ và đợt địch; mạng, súng, khiên, điểm riêng.
Xe đồng đội không chặn nhau; đạn không gây sát thương đồng đội. Bom,
đóng băng và gia cố có lợi cho cả đội. Trận đôi tăng 6 địch/màn và tối đa
6 địch trên sân (chơi đơn tối đa 4).

Chủ chạy mô phỏng 60 bước/giây; khách gửi hướng và bắn 20 lần/giây;
chủ gửi ảnh trạng thái JSON 10 lần/giây qua kênh `tank-v1` dùng chung cho
Wi-Fi/Bluetooth. ID trận ngăn dữ liệu ván cũ lẫn ván mới. Khách phải sẵn sàng
trước khi nhận trận mới. Chủ điều khiển tạm dừng; mở hộp thoại ở chủ cũng
ngừng mô phỏng. Mất dữ liệu trận 4 giây, mất kết nối hoặc một người rời
thì hủy trận và không tính thưởng. Kết nối lại rồi bắt đầu ván mới; phiên
bản này không phục hồi trận đang chơi.

## Thưởng và bảng xếp hạng

100/200/300/400 điểm tùy loại xe bị hạ. Bom tính điểm cho người nhặt.
Mỗi 1.000 điểm riêng = 1 mảnh rương, làm tròn xuống; không giới hạn thưởng.
Thưởng khi trận kết thúc, lưu thất bại cho thử lại, chặn nhận trùng kể cả
sau mở lại ứng dụng. Rời/hủy trận không thưởng.

Top 10 lưu trên thiết bị, tách chơi đơn/đôi; đôi dùng tổng điểm đội.
Vượt mốc top 1 ban đầu 5.000 điểm nhận thêm 1 rương (10 mảnh), tối đa một
lần mỗi ngày mỗi chế độ trên từng thiết bị. Kỷ lục và giới hạn ngày được
giữ qua đời pet. Chưa có bảng xếp hạng Internet hoặc chống gian lận máy chủ
bên ngoài; trận LAN tin cậy máy chủ phòng.

## Kiểm tra

`godot --headless --path . res://tools/test_tank.tscn`

Kiểm tra 20 map và đường đi, bốc không trùng, va chạm, vật phẩm, mạng,
chuyển màn, thưởng/rollback/nhận trùng, hai ENet peer thực sự, thao tác
P2, đồng bộ map/tạm dừng/kết thúc và mất kết nối. Bluetooth dùng cùng
kênh đã triển khai; cần kiểm tra thực tế trên hai điện thoại Android.
