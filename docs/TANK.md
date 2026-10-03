# Tank bảo vệ căn cứ

Trong Giải trí → Tank, chọn **1 người** để chơi ngay. Chơi đơn và chơi đôi dùng cùng luật gameplay:
mỗi xe người chơi có 5 mạng, súng cấp 1, khi chết mất một cấp súng nhưng giữ tối thiểu cấp 1.
Giữ bốn phím bên trái để di chuyển, giữ nút BẮN bên phải để bắn; hỗ trợ hai ngón đồng thời.
Bàn phím: phím mũi tên và Space.

## Bản đồ và độ khó

20 map 16×16 thiết kế sẵn trong `gameplay/entertainment/tank/tank_maps.json`:
4 Phố gạch, 4 Pháo đài, 4 Sông hồ, 4 Rừng, 4 Hỗn hợp.
Vào trận bốc ngẫu nhiên; mỗi lần qua màn bốc một map chưa dùng. Hết 20 map
thì xáo lại, tránh lặp ngay map vừa chơi.

Độ khó phụ thuộc số màn và **giống nhau ở 1 người và 2 người**; thêm người chơi thứ hai
không làm tăng số địch, tốc độ địch, nhịp bắn hay tốc độ xuất hiện.

Gạch phá được, thép cần súng cấp tối đa, nước chặn xe nhưng đạn đi qua,
bụi cây trong suốt một phần để dễ thấy xe. Căn cứ ★ có 3 HP; căn cứ có 2,5 giây
miễn sát thương sau mỗi phát trúng và được gia cố/bảo vệ 15 giây đầu mỗi màn.
Tất cả người chơi hết mạng hoặc căn cứ hết HP là kết thúc. Đạn người chơi không
gây sát thương cho căn cứ.

Xe địch có loại thường, nhanh, bắn và giáp 3 phát. Địch tìm đường tới căn cứ;
các đợt đầu có hành vi tuần tra hành lang giống nhau ở cả hai chế độ.
Mỗi xe địch thứ 3 mang vật phẩm.

## Thông số chung cho 1P và 2P

Màn đầu có 8 địch, tăng dần tối đa 14 địch tới màn 10 rồi giữ nguyên.
Tối đa trên sân là 2 địch đến hết màn 5, sau đó 3.
Chờ 4 giây trước xe đầu tiên. Nhịp xuất hiện bắt đầu 3,6 giây và giảm dần
đến 2,25 giây ở màn 10 rồi giữ nguyên. Tốc độ và nhịp bắn của địch cũng
giữ cùng cấu hình này trong cả 1P và 2P.

Hai chế độ cùng dùng bố cục phòng thủ: hai hàng 12–13 được dọn thành đường
ngang để chuyển cánh, thêm gạch ở ba đường bắn dọc tại hàng 11.
Khi qua màn, HP căn cứ và thời gian bảo vệ được đặt lại như nhau.

## Vật phẩm và súng

Vật phẩm: + nâng súng (3 cấp), S khiên 8 giây, F đóng băng 6 giây, B bom
hạ địch đang có trên sân, H gia cố tường quanh căn cứ 10 giây.

Súng cấp 1 đạn nhanh; cấp 2 bắn được 2 viên đồng thời; cấp 3 phá thép.
Khi chết xuất hiện lại với khiên 3 giây và giữ ít nhất súng cấp 1.
Bom, đóng băng và gia cố có hiệu lực cho cả đội trong chế độ đôi.

## Hai người

1. Kết nối ở Giải trí hoặc Cài đặt bằng Wi-Fi/hotspot hoặc Bluetooth Android.
2. Cả hai mở Tank; khách bấm **Sẵn sàng**.
3. Chủ bấm **Bắt đầu đôi**. Chủ vàng P1, khách xanh P2.

Hai người dùng chung map, căn cứ và đợt địch. P2 chỉ bổ sung thêm một người điều khiển
và đồng bộ mạng; **không có hệ số tăng độ khó theo số người**.
Mạng, súng, khiên và điểm là riêng từng người; điểm đội là tổng điểm.

Chủ chạy mô phỏng 60 bước/giây; khách gửi hướng và bắn 20 lần/giây; chủ gửi ảnh trạng thái
JSON 10 lần/giây qua kênh `tank-v1` dùng chung cho Wi-Fi/Bluetooth. ID trận ngăn dữ liệu
ván cũ lẫn ván mới. Khách phải sẵn sàng trước khi nhận trận mới.
Mất dữ liệu trận 4 giây, mất kết nối hoặc một người rời thì hủy trận và không tính thưởng.
Kết nối lại rồi bắt đầu ván mới; phiên bản này không phục hồi trận đang chơi.

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

Bộ kiểm tra cân bằng riêng `tools/test_tank_solo_balance.gd` xác nhận:
1P/2P cùng số địch, giới hạn địch, nhịp xuất hiện, tốc độ, loại địch, nhịp vật phẩm,
HP căn cứ, bảo vệ căn cứ và bố cục phòng thủ. Hai người chỉ khác số lượng người chơi
và lớp đồng bộ mạng.

Bluetooth dùng cùng kênh đã triển khai; cần kiểm tra thực tế trên hai điện thoại Android.
