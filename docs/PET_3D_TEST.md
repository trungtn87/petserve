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

## Nâng cấp 2 — Đứng sống động (mặc định khi F6)

- **Sống động**: nhịp thở nhẹ ở cổ/đầu, hít vào ngắn và thở ra dài; nhìn quanh có khoảng nghỉ.
- **Chạm / kéo trong khung 3D**: đặt mục tiêu nhìn. Chạm tạo phản ứng nghiêng đầu + tai/đuôi, kéo chỉ cập nhật mục tiêu. Sau 3 giây không cập nhật, đầu trở về hướng nghỉ.
- **Gọi pet**: nhìn về camera và phản ứng. Nếu camera ở sau model đã xoay, pet không vặn đầu ngược ra sau.
- **Tạm dừng**: giữ toàn bộ pose và đồng hồ chuyển động. **Tư thế gốc**: tắt cả animation lẫn chuyển động thủ tục và reset toàn bộ rig.
- Các clip cũ được giữ để so sánh/kiểm tra rig; chọn **Sống động** để trở lại chế độ mới.

### Phân chia code

`pet/presentation/motion/`:
- `pet_rig_profile.gd`: ánh xạ xương, giới hạn yaw 12°, pitch 8°, nghiêng 3°, tai 3°, mỗi đoạn đuôi 4°. Head rest frame của mẫu dùng +Z trước, +Y trên.
- `pet_look_controller.gd`: mục tiêu world → rest frame, giới hạn góc, smoothing theo delta, hết thời gian chú ý, bỏ mục tiêu phía sau.
- `pet_secondary_motion.gd`: phản ứng có nhịp tăng/giảm, cooldown chống spam, tai lệch thời điểm, đuôi trễ từng đoạn và dao động tắt dần. Đây là công thức chuyển động, chưa phải mô phỏng va chạm/vật lý đuôi.
- `pet_motion_controller.gd`: ghép chuyển động từ rest pose, fade 0,4 giây khi vào chế độ, chỉ ghi bone pose khi được kích hoạt. AnimationPlayer bị vô hiệu hóa trong chế độ này để không tranh quyền ghi xương.

Chỉ dùng RNG riêng cho trình diễn. Không gọi RNG gameplay hoặc ghi save. Giữ nguyên root/thân/chân và vị trí model; nhịp thở hiện chỉ biểu đạt nhẹ ở cổ/đầu, chưa có chest rig. Không tuyên bố đã có IK hoặc chân bám sàn.

### Phạm vi chưa hoàn thành của phương án dài hạn

GLB v3 chỉ có một mesh, không có morph target hoặc bone mí mắt. Vì vậy chưa làm chớp mắt; UI ghi rõ giới hạn này. Chưa thêm khớp chân, chest rig, chỉnh skin weights hay tạo clip Blender. Những việc đó cần bước sửa asset và duyệt hình ảnh riêng; bản nâng cấp này triển khai lớp điều khiển đứng tại chỗ trên rig hiện có.

### Kiểm chứng nâng cấp

Godot 4.6.1: test cũ và `tools/test_pet_living.gd` đều đạt. Test mới bao gồm tọa độ chạm, nhiều ngón tay, bone thực sự đổi pose, giới hạn góc, root/thân/chân giữ rest, pause/resume/reset, chuyển từ walk sang living, 600 bước không tích lũy pose lỗi, solver nhìn ở 30/60/120 FPS, model xoay, mục tiêu phía sau và cooldown. Scene chạy 180 frame headless không lỗi runtime.

Audit GLB: trọng số hữu hạn/không âm, chỉ số joint 0–13; sai số tổng trọng số lớn nhất khoảng 1,79e-7. Đây là kiểm tra số học, không thay thế kiểm tra biến dạng bằng mắt. Chưa test Android và Godot 4.7.

```bash
godot --headless --path . --script res://tools/test_pet_living.gd
```
