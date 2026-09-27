# Setup — Pet Vô Hạn V1.0

## Chuẩn môi trường

- Godot 4.7.2 stable, bản Standard (GDScript).
- OpenJDK 17.
- Android SDK theo Godot 4.7.
- Git.
- Một điện thoại Android + cáp USB data để test thật.

## 1. Mở project

1. Mở Godot Project Manager.
2. Import file `project.godot` trong thư mục gốc.
3. Chạy project.
4. Màn hình phải hiện `PET VÔ HẠN — V1.0 FOUNDATION`.

## 2. Kiểm tra chức năng nền

- Bấm `NEW LIFE`.
- App tạo `run_seed`.
- Seed xuất hiện trên màn hình.
- Đóng app rồi mở lại: seed cũ vẫn còn.

Đây chỉ là test nền save + deterministic seed; chưa phải gameplay.

## 3. Android

Trong Godot:

- Editor Settings > Export > Android.
- Cấu hình Java SDK Path trỏ tới JDK 17.
- Cấu hình Android SDK Path.
- Cài Godot Export Templates 4.7.2.
- Project > Export > Android Debug.

Package mặc định của project: `com.petvohan.game`.

## 4. Nguyên tắc kiến trúc đã khóa cho V1

- Gameplay data không hard-code trong UI.
- Mọi random của một đời phải xuất phát từ `run_seed`.
- Save local; không cloud, không account, không server.
- Android portrait 720×1280 logical resolution.
- Renderer: Compatibility để ưu tiên thiết bị Android rộng.
- Không thêm Bluetooth trước khi core solo hoàn thành.

## 5. Bước tiếp theo

V1.0.1: tạo `EggGenerator` và màn hình nhận một quả trứng random từ seed của run.
