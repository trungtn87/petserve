# Kết nối cục bộ 2 người — v1

## Người chơi

Mở **Cài đặt → Kết nối 2 người • Wi-Fi / Bluetooth**. Có lối mở nhanh tương tự trong Giải trí.

- Wi-Fi: cùng mạng, một máy Tạo phòng, máy kia Tìm phòng → chọn tên. Nếu mạng chặn broadcast, nhập IP hiện trên máy chủ. Điểm phát Wi-Fi cũng dùng đường kết nối LAN, cần kiểm thử từng thiết bị. Mạng khách cách ly thiết bị không thể dùng.
- Bluetooth Android: bật Bluetooth và ghép đôi hai điện thoại trong cài đặt hệ thống. Cho phép Bluetooth trong game. Một máy Tạo phòng, máy kia chọn tên máy chủ từ danh sách đã ghép đôi. Không yêu cầu vị trí hay quét thiết bị trong app.
- Kết nối xong có trạng thái tên đối phương và Sẵn sàng. Đóng bảng/chuyển màn hình vẫn giữ kết nối. Ngắt kết nối để đổi phương thức.
- Mất kết nối hoặc máy chủ thoát: đóng phiên và xóa trạng thái sẵn sàng. Tạo/vào phòng lại để chơi tiếp. Không tự chuyển máy chủ.

## Phạm vi

Đây là lớp kết nối chung, chưa chuyển các minigame solo thành chế độ hai người. Tạo phòng và Sẵn sàng không khởi chạy một trận. Mỗi game cần adapter xử lý luật, thao tác, trạng thái và kết quả riêng. Không thay đổi thưởng solo hay bảng xếp hạng.

## API cho game

Autoload `LocalConnection` tồn tại xuyên suốt scene. Các phương thức chính:

```gdscript
LocalConnection.connected()
LocalConnection.is_host
LocalConnection.ready_local
LocalConnection.ready_remote
LocalConnection.send_message("tank.input", {"direction": "left"})
LocalConnection.message_received.connect(_on_network_message)
LocalConnection.status_changed.connect(_on_connection_changed)
```

Máy chủ game phải kiểm tra thao tác của khách và quyết định kết quả. Gói tin truyền tải không tự xác nhận luật trò chơi. Dùng tên channel riêng và game version trong adapter. Giao thức kết nối `petverse-local-1` cần tăng khi thay đổi định dạng không tương thích.

Wi-Fi dùng ENet/UDP cổng 28411, tối đa một khách. Tìm phòng qua UDP 28412. Bluetooth dùng RFCOMM với UUID cố định của PetVerse, truyền UTF-8 JSON trong frame độ dài 32-bit big endian. Cả hai dùng hello/welcome, ping/pong, ready, data, bye. Gói tin tối đa 16 KiB. Hàng đợi Bluetooth giới hạn 128 gói, đọc/ghi/kết nối chạy trên worker thread, Godot chỉ poll tối đa 64 gói/frame. Timeout kết nối 12 giây, heartbeat 1 giây, timeout đang chơi 8 giây. Thiết kế dành cho chơi khi app ở foreground; không chạy trận dưới nền.

## Android build

Bật plugin `addons/petverse_bluetooth/plugin.cfg` và Gradle export trong preset. Trước khi export:

```sh
python3 tools/build_bluetooth_plugin.py --configure-export --templates "$HOME/.local/share/godot/export_templates/4.6.1.stable"
godot --headless --editor --path . --quit
godot --headless --path . --export-debug "com.PetVerse.game" builds/PetVerse_pethome_test.apk
```

Script yêu cầu JDK 17 và Android SDK platform 35, dùng Godot AAR chính trong export template để biên dịch plugin Java rồi tạo AAR. Cài source template và marker phiên bản tự động. AAR và source template là output sinh ra, không commit. Hai workflow Android đều gọi script trước export.

## Kiểm thử

`tools/test_local_connection.tscn` chạy hai endpoint ENet thật, discovery unicast, hello/welcome, tên tiếng Việt, ready hai chiều, truyền dữ liệu, giới hạn kích thước, khóa khách thứ ba, UI, đóng UI giữ phiên, heartbeat, ngắt/kết nối lại, timeout, sai protocol và fallback khi thiếu plugin Android.

Cần nghiệm thu trên hai điện thoại: Wi-Fi router, hotspot, tìm phòng tự động, IP thủ công, Bluetooth Android 12+ xin quyền/từ chối quyền, máy Android cũ, ghép đôi, tạo/vào phòng, ngắt và nối lại, tắt Bluetooth hoặc Wi-Fi giữa phiên. Kiểm thử headless và biên dịch plugin không chứng minh radio/hotspot hoạt động trên tất cả máy.
