# Test nhân vật 3D — Dark Pet

## Chạy trong dự án

1. Checkout nhánh `feat/dark-pet-3d-test`, mở `project.godot`, chờ import xong.
2. Mở `scenes/tests/pet_3d_test.tscn`.
3. Nhấn **F6 / Run Current Scene**. F5 vẫn chạy luồng trứng hiện tại.
4. Thử bốn nút động tác; kéo thanh xoay để xem mặt trước/sau; dùng Tạm dừng và Tư thế gốc để đối chiếu mesh.

Trên Android: tạo bản export test riêng và tạm chọn scene test làm Main Scene trong bản sao dự án. Nhánh này không thay main scene hoặc cấu hình export hiện hành.

## Kết quả kiểm tra chéo

- Baseline GitHub: `a4e1034`, Godot project khai báo 4.7, Compatibility renderer, màn hình dọc 360 × 640.
- Main chỉ gọi GameApp; kiến trúc yêu cầu pet presentation độc lập, chưa tích hợp Egg → PetHome.
- Trước thay đổi: chưa có code hoặc asset 3D trong repo.
- Model nguồn: `dark_pet_rigged_v3.glb`, 12.002 vertex, 24.000 triangle, 14 xương, không có clip animation nhúng.
- Các node `Rig_*` là node phụ, không phải các joint được skin sử dụng. Track điều khiển các bone thật của Skeleton3D.

## Giải pháp hiện tại

`pet/presentation/pet_3d_test_actor.gd` nạp model, tìm skeleton và quản lý AnimationPlayer.
`pet/presentation/dark_pet_test_clips.gd` tạo clip dựa trên rest pose của rig Dark Pet.
`scenes/tests/pet_3d_test.gd` ghép môi trường, camera, SubViewport 3D và UI test.

Bốn clip lặp: idle, curious, happy, walk_test. Chuyển clip có crossfade 0,2 giây.
Mỗi clip chứa cùng tập track để tránh xương bị giữ ở pose của clip trước.
RESET dừng animation và trả toàn bộ bone pose về rest pose.

Dùng AnimationPlayer trước vì model chưa có clip để AnimationTree phối hợp. Khi có bộ idle/walk/run đã kiểm tra chất lượng, thêm AnimationTree vào actor wrapper; dùng CharacterBody3D riêng khi cần di chuyển/va chạm trong phòng. Không retarget humanoid cho rig thú bốn chân này.

## Giới hạn cần kiểm tra trực quan

Đây là bản test rig, không phải animation thành phẩm. Bước tại chỗ chỉ xoay chân với biên độ nhỏ, chưa có IK, foot locking, root motion hoặc di chuyển thật. Chưa có blink vì chưa xác nhận rig mí mắt/blend shapes. Rig và skin weights chưa được sửa trong thay đổi này.

Kiểm tra đầu/tai/đuôi có kéo méo mặt không, chân có kéo bụng không, vòng lặp có giật không. Nếu có méo, cần sửa skin weights/rest pose trong công cụ 3D; AnimationTree không sửa lỗi rig.

## Kiểm chứng

Đã import và chạy headless bằng Godot 4.6.1 (runtime có thể tải trong môi trường kiểm tra; không đổi khai báo 4.7 của dự án). Scene chạy 120 frame không có lỗi runtime. Test tự động xác nhận 14 bone, cả bốn clip tác động lên bone, pause/resume, xoay và reset pose.

```bash
godot --headless --path . --editor --import
godot --headless --path . --script res://tools/test_pet_3d.gd
godot --headless --path . res://scenes/tests/pet_3d_test.tscn --quit-after 120
```

Chưa kiểm chứng hình ảnh render và chưa test trên thiết bị Android/Godot 4.7. Import editor báo lỗi có sẵn trong export_presets.cfg về preset.0 thiếu runnable; nằm ngoài phạm vi test scene này.

## Tài liệu Godot đối chiếu

- https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html
