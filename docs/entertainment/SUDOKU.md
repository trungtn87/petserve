# Sudoku

Giải trí → Sudoku. Bảng 9×9, số 1–9, hàng/cột/vùng 3×3 không trùng.

- Dễ / Vừa / Khó: mục tiêu 44 / 36 / 28 số cho sẵn; thưởng 1 / 2 / 3 mảnh rương.
- Độ khó hiện phân theo mật độ số cho sẵn, chưa xếp hạng theo kỹ thuật suy luận của người chơi.
- Sinh ngẫu nhiên số, hàng, cột, vùng từ bảng hợp lệ; chỉ bỏ số nếu bộ giải đếm được đúng một lời giải. Có thể giữ nhiều số hơn mục tiêu để bảo đảm tính duy nhất.
- Không giới hạn thời gian, không thua vì sai. Màu đỏ báo xung đột, không tiết lộ đáp án.
- Ghi chú nhiều số, xóa, hoàn tác tối đa 100 thao tác, tô hàng/cột/vùng và số giống nhau.
- Lưu qua InfantGameFacade / SaveManager trong meta_v1.json: đề, bảng, ghi chú, lịch sử, mức khó, match_id, run_id, settled. Backup hiện có đã bao gồm file này.
- Thoát Giải trí hoặc tắt ứng dụng giữ ván. Đời pet mới không tiếp tục ván của đời cũ.
- Đổi ván đang chơi có hộp xác nhận. Ván hoàn thành phải nhận thưởng trước khi đổi đề.
- Phần thưởng và cờ settled được ghi cùng lần lưu. Lưu thất bại khôi phục dữ liệu trước thao tác; có thể thử nhận lại. Kiểm tra bảng hoàn chỉnh tại tầng logic, UI không gửi số mảnh thưởng.
- Đủ 10 mảnh dùng cơ chế ghép rương hiện có; không chiếm hạn mức thưởng Caro/Stage 2.

## Kiểm tra

```sh
godot --headless --path . --editor --quit
godot --headless --path . res://tools/test_sudoku.tscn
```

Kiểm tra đề/đáp án, số cho sẵn, ghi chú/hoàn tác, JSON, lưu lỗi, thưởng/ghép rương, nhận lặp sau tải lại, UI và đóng màn hình. Có trong cả hai workflow Android/acceptance.
