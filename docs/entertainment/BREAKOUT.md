# Phá gạch

Giải trí → Phá gạch. Game đỡ bóng theo ảnh tham khảo, dùng sân dọc và thanh đỡ bằng kéo tay.

## Màn chơi

30 màn theo thứ tự, 6 kiểu bố cục kết hợp số hàng và lớp gạch khác nhau. Vượt màn để mở màn tiếp; có thể chọn lại màn đã mở. Ba mạng mỗi màn, thua có thể thử lại.

Bóng tăng từ 175 lên 291 đơn vị/giây. Thanh đỡ giảm từ 82 xuống 58,8 đơn vị trên sân rộng 300. Từ màn 7 có gạch hai lớp, từ màn 13 có gạch thép, từ màn 19 có gạch ba lớp. Không cần phá gạch thép để thắng. Độ khó tăng tổng thể; thời gian giải từng bố cục có thể khác nhau.

Mỗi 5 viên gạch bị phá rơi một vật phẩm luân phiên: W rộng thanh đỡ 12 giây, S chậm bóng 10 giây, + thêm mạng (tối đa 5). Mất mạng xóa các hiệu ứng đang có.

Kéo tay trong sân; chạm hoặc bấm Phóng bóng để bắt đầu. PC có chuột, phím trái/phải và Space. Dừng, mở chọn màn, hướng dẫn hoặc chuyển ứng dụng đều tạm dừng. Quay lại ván đang chạy cần bấm Tiếp tục.

## Lưu và thưởng

Lưu trong meta_v1.json, đã nằm trong backup hiện có. Lưu khi bắt đầu, mỗi 5 giây đang chơi, thay đổi trạng thái, tạm dừng và đóng game. Khi ứng dụng bị kill đột ngột có thể mất tối đa khoảng 5 giây chưa checkpoint. Lưu lại bóng, gạch, mạng, điểm, vật phẩm và thời gian hiệu ứng. Ván gắn run_id của đời pet.

Vượt màn lần đầu thưởng 1 mảnh rương. Màn chơi lại không thưởng lần đầu lần nữa. Tầng facade sở hữu ván và kiểm tra gạch đã phá hết. Cờ settled, danh sách đã vượt, mở màn mới và thưởng ghi cùng lần lưu. Lưu lỗi khôi phục thưởng/mở màn; người chơi có thể nhận lại. Dữ liệu danh sách màn đã vượt được chuẩn hóa số nguyên sau JSON.

## Kiểm tra

- test_breakout.tscn: 30 bố cục riêng, tốc độ/kích thước, JSON, va chạm, gạch thép/nhiều lớp, vật phẩm, mất mạng, lưu lỗi, thưởng/mở màn, nhận lặp, màn khóa, UI, tạm dừng, đóng ván.
- test_breakout_playthrough.gd: tự điều khiển thanh đỡ và phá hết toàn bộ 30 màn bằng mô phỏng thật. Kiểm tra khả năng hoàn thành, không chứng minh độ khó thực tế với người chơi.
- Có trong cả hai workflow Android hiện có.
