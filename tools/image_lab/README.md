# PetVerse AI Image Lab

Nhánh test: `test/ai-image-gene-stages`, tách từ `pethome` tại `909ba51`.

Phần tạo ảnh đã tích hợp vào `pethome`: F5 chạy game bình thường; F6 tại scene Image Lab dùng để thử riêng. Stage 1 dùng dáng bẩm sinh theo seed; Stage 2–Final dùng resolved form, Stage 3 trở đi giữ ảnh trước làm tham chiếu. Chế độ dựng ảnh mới A/B chỉ dành cho Image Lab.

## Chạy

Mở project bằng Godot 4.6.1+ và bấm **F6** tại `tools/image_lab/image_lab.tscn`, hoặc **F5** (nhánh này đặt Image Lab làm màn hình khởi động).

```bash
git fetch origin
git switch test/ai-image-gene-stages
```

1. Chọn hệ và seed. Thay hệ/seed bắt đầu một lượt test mới.
2. Chọn **Stage 1**, bấm **Xem câu lệnh của game**, rồi **Tạo ảnh AI**.
3. Chọn **Stage 2**, thêm Gene dùng ở Stage 1. Mỗi dòng chọn loại Gene, độ hiếm và số lượng. Bỏ trống để tiến hóa tự nhiên.
4. Xem câu lệnh rồi tạo ảnh. Tiếp tục tương tự với Stage 3, Stage 4 và Final.
5. Có thể quay lại stage cũ, đổi Gene, xem prompt và tạo lại. Khi tạo lại thành công, các stage phía sau bị xóa khỏi lượt test vì ảnh nguồn đã thay đổi. File ảnh đã tạo vẫn giữ lại.

Danh sách Gene lấy trực tiếp từ `GeneCatalog`, lọc bằng `StageGenePolicy`, khóa hệ và `next_expression` của phenotype nguồn. Gene đã đạt biểu hiện tối đa không hiện trong danh sách. Điểm/độ hiếm và ảnh hưởng tag lấy từ `ItemGenerator` và `GeneDefinition`; điểm được cộng dồn qua các stage. Không tự viết prompt thay thế.

Stage 1 dùng `InitialPetRenderCoordinator`; các bước tiến hóa dùng `StageEvolutionService.prepare/build_request/commit`. Stage 2 hiện dùng text-to-image; Stage 3 trở đi dùng ảnh stage trước làm tham chiếu theo code production. Final là kết quả tiến hóa từ Stage 4, không có Gene đầu vào sau Final.

## Kết quả

- Ảnh trước tiến hóa và ảnh AI kết quả hiển thị trong màn hình.
- Prompt hiển thị đúng chuỗi gửi cho proxy, gồm cả phần `STRICTLY AVOID`.
- PNG và JSON cùng tên trong `user://pet_renders`; JSON lưu prompt, seed, mode, source, điểm Gene và model do proxy trả về.
- Mỗi lần chuẩn bị prompt có output key riêng để không lấy nhầm ảnh cache của thử nghiệm trước.
- Mỗi lần bấm tạo gửi một yêu cầu tạo ảnh thật; lỗi kết nối có thể retry theo renderer của game.
- Cấu hình proxy/model/kích thước dùng nguyên `data/evolution/render/proxy_dev.json`.
- Lượt test giữ trong RAM, không khôi phục sau khi đóng ứng dụng. Ảnh và JSON vẫn được giữ.
- Save tiến hóa được tiêm bằng adapter RAM. Tên ứng dụng riêng `PetVerse Image Lab` cũng tách thư mục user data khỏi game chính. Không tiêu hao inventory hoặc thay pet đang chơi.

## Kiểm tra

```bash
godot --headless --editor --path . --import
godot --headless --path . --script tools/image_lab/test_image_lab.gd
godot --headless --path . --quit-after 5
```

Kiểm tra integration tự chọn, gọi AI thật đúng **một ảnh Stage 1**, sau đó dựng prompt Stage 2 qua UI:

```bash
godot --headless --path . --script tools/image_lab/smoke_live.gd -- --live
```

Contract tests không gọi AI. Chúng kiểm tra 7 hệ, chuỗi tới Final, prompt/mode/seed/reference khớp production, điểm cộng dồn, cache key mới, rerender và tính độc lập của save.
