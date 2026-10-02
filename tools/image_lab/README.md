# PetVerse AI Image Lab

Nhánh test: `test/ai-image-gene-stages`.

Nhánh này đã được đồng bộ với runtime/prompt mới nhất của `pethome`. Image Lab chỉ thay cách cấp đầu vào test; phần tạo `PetIdentity`, Genome, Gene resolution, VisualSpec, prompt và render request đều dùng code production.

## Flow mặc định: random 4 stage

Mở project bằng Godot 4.6.1+ rồi chạy F5. Nhánh này đặt `tools/image_lab/image_lab.tscn` làm màn hình khởi động.

Bấm **Tạo tự động Stage 1 → 4 (random Gene)**:

1. Tạo `run_seed` mới bằng `RandomService.create_run_seed()`.
2. Random hệ đúng logic trứng bằng `EggGenerator(RandomService).create(run_seed)`.
3. Random loài đúng logic PetHome bằng `PetSpeciesCatalog.pick_for_seed(run_seed)`.
4. Stage 1 gọi nguyên `InitialPetRenderCoordinator` của PetHome.
5. Stage 2, 3, 4 lấy Gene trực tiếp từ `GeneCatalog`, lọc bằng `StageGenePolicy`, element lock và `next_expression` của phenotype hiện tại.
6. Mỗi stage random 2–3 Gene ở các locus khác nhau; rarity random Rare/Epic/Legendary. Đây chỉ là dữ liệu đầu vào test.
7. Request tiến hóa đi nguyên `StageEvolutionService.prepare() -> build_request() -> commit()`. Image Lab không tự viết prompt thay thế và không ép render mode riêng.
8. Auto run dừng ở Stage 4 đúng mục tiêu test hiện tại.

Do toàn bộ random dùng run seed/stream xác định, cùng một seed + cùng state sẽ cho lại cùng species, element và bộ Gene test.

## Manual mode

Vẫn giữ flow manual để soi prompt riêng:

- Chọn hệ/seed rồi bấm **Manual: dùng hệ + seed hiện tại**. Species vẫn được chọn bằng `PetSpeciesCatalog.pick_for_seed(seed)`.
- Chọn stage, thêm Gene, rarity, count.
- Bấm **Xem câu lệnh của game** để xem đúng wire prompt trước khi gọi AI.
- Có thể dùng chế độ A/B cũ để so production reference với text-to-image thử nghiệm. Chế độ này không được dùng trong auto run.

## Kết quả

- PNG và JSON được lưu trong `user://pet_renders`.
- JSON của auto run lưu Identity, random Gene items, morphology, gene state, render request, wire prompt và metadata model.
- Stage 2–4 luôn dùng ảnh/stage trước theo đúng mode mà production `StageEvolutionService` quyết định.
- Lượt test dùng save adapter RAM, không thay pet hoặc inventory của người chơi.

## Contract test

```bash
godot --headless --editor --path . --import
godot --headless --path . --script tools/image_lab/test_image_lab.gd
godot --headless --path . --script tools/image_lab/test_random_four_stage.gd
godot --headless --path . --script tools/image_lab/test_lineage_morphology.gd
godot --headless --path . --script tools/image_lab/test_resolved_form.gd
godot --headless --path . --quit-after 5
```

`test_random_four_stage.gd` kiểm tra:

- species khớp đúng `PetSpeciesCatalog`;
- element khớp đúng `EggGenerator`;
- Gene random deterministic theo seed;
- Gene luôn hợp stage/hệ/phenotype và không trùng locus trong cùng stage;
- tạo/commit được snapshot Stage 1 → 4;
- Identity, species, element giữ nguyên suốt lineage;
- auto flow dừng ở Stage 4.

Contract test không gọi AI thật.
