# Resolved form V2 — A/B test

Dùng nhánh `test/ai-image-gene-stages`, mở Godot và F5.

1. Bấm **Nạp mẫu Mộc vừa test (seed + Gene)**. Seed 1420288088, hệ Mộc. Bắt đầu Stage 1 như trước.
2. Khi chọn Stage 2, 3, 4, các Gene của mẫu tự điền; vẫn có thể sửa bằng tay.
3. Tạo ảnh bằng **Theo game: ảnh tham chiếu từ Stage 3**.
4. Giữ cùng stage và Gene, đổi sang **Thử dựng ảnh mới: cùng hình thái đích**, bấm xem câu lệnh rồi tạo lại.
5. So sánh PNG cùng stage trong thư mục ảnh; JSON ghi `experiment`, prompt, seed, request mode, ảnh nguồn và `morphology`.

Stage 1–2 vốn là text-to-image nên hai lựa chọn không khác ở đó. A/B bắt đầu từ Stage 3. Mỗi lần bấm tạo là một request AI thật; không tự gọi cả hai hay tạo hàng loạt.

Khi tạo lại thành công một stage, các snapshot stage sau bị loại để tránh dùng sai ảnh nguồn; PNG/JSON cũ vẫn còn. Để so sánh riêng một stage, tạo cả A và B trước khi chuyển sang stage tiếp theo. Hai nhánh thử dùng cùng seed và brief; bản dựng mới không có ảnh tham chiếu nên có thể lệch nhận diện cá thể.

## Code

- `resolved_form_prompt.gd` tạo một brief đích, ưu tiên góc nhìn và hình thể, ba đặc điểm quan trọng rồi tới đặc điểm phụ. Tai tròn + tai quạt được gộp thành một outline có mép quạt; không gửi hai bộ lệnh thay hình tai độc lập.
- Morphology V2 thêm độ rộng đuôi, độ tròn tai, độ xòe tai và độ rộng bờm. Điểm và stage tác động lên các thông số này.
- Producer và validator gọi cùng builder; schema pending 14 rebuild kế hoạch cũ, cache key mới tránh ảnh cũ.
- Stage 1 giữ pipeline ban đầu để làm baseline. Từ Stage 2 thay positive prompt dài/lặp bằng resolved brief. Negative guards và điều kiện Mythic vẫn dùng pipeline game.
- Chế độ dựng mới là override riêng Image Lab: cùng positive/negative prompt và seed, nhưng bỏ ảnh nguồn và chuyển request sang text-to-image. Không đổi provider hoặc model.

## Kiểm thử

`test_resolved_form.gd`: mẫu Mộc Stage 1–Final, kết hợp tai, ưu tiên đuôi, prompt xác định không phụ thuộc thứ tự dictionary, giữ phép Mythic, A/B đồng nhất prompt/seed và commit qua pipeline game.

`test_image_lab.gd`: 7 hệ tới Final, điểm Gene cộng dồn và kiểm tra plan canonical.

`test_lineage_morphology.gd`: 64 seed và catalog Gene.

Các kiểm thử không chứng minh AI tuân thủ hình dạng; cần xem ảnh thực tế.
