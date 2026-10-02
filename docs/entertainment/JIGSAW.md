# Ghép hình pet

Trong Giải trí, dùng ảnh pet hiện tại và ảnh đã lưu trong `user://pet_renders` / `user://final_records`. Không gọi API tạo ảnh. Ảnh nguồn giữ nguyên tỉ lệ và đầy đủ nội dung, giới hạn cạnh dài 1200 px để giảm bộ nhớ trên Android.

- 20 mảnh: 4×5; 50 mảnh: 5×10; 100 mảnh: 10×10.
- Các mảnh có khớp lồi/lõm bù nhau, cạnh ngoài phẳng; không xoay mảnh.
- Khay xáo trộn, mỗi trang 3 mảnh lớn. Kéo thả hoặc chọn mảnh rồi chạm ô.
- Đúng vị trí tự bắt dính; sai vị trí giữ mảnh trong khay.
- Ảnh mẫu hiện mờ dưới khung. Zoom ×1/×2/×3; kéo khung để xem vùng khác. Bỏ chọn để dễ di chuyển khung.
- Không giới hạn thời gian. Mỗi mảnh đặt đúng lưu ngay qua AtomicJson, lỗi ghi thì hoàn tác thao tác. Ván dở giữ nguyên ảnh, khớp nối và tiến độ khi mở lại.
- Ván mới dùng ảnh và số mảnh đã chọn, có xác nhận trước khi bỏ ván dở.
- `jigsaw_v1.json` nằm trong danh sách backup, cùng các thư mục ảnh nguồn.
- Hoàn thành phát `match_finished(win)` theo giao diện chung. Chưa thêm phần thưởng riêng.

Kiểm tra: `godot --headless --path . res://tools/test_jigsaw.tscn` với user-data riêng. Bao phủ số lượng, polygon/UV, diện tích khớp bù nhau, lưu/khôi phục, dữ liệu lỗi, đặt sai/đúng, cảm ứng, zoom và lỗi ghi đĩa.
