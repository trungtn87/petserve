# PetVerse — Stage 2 Integration & Render Contract

Đồng bộ: 30/09/2026  
Nhánh chuẩn: `pethome`  
Mốc tích hợp Stage 2: `c81afa7`

## 1. Mục tiêu

Tài liệu này là contract kỹ thuật cho Stage 2 sau khi tích hợp các nhánh Stage 2 vào `pethome`. Mục tiêu là giữ một nguồn chuẩn để code, test và các lần phát triển sau không quay lại logic cũ.

## 2. Stage 1 — tạo identity gốc

- Stage 1 dùng `INITIAL_TEXT_TO_IMAGE`.
- Prompt bắt buộc dùng dữ liệu `stage_1_face` của hệ từ `data/evolution/visual/element_stage_profiles.json`.
- `stage_1_face` là lineage cue của hệ, không phải template cố định.
- AI vẫn được random các chi tiết cá thể như pattern lông, độ bông, biểu cảm, bất đối xứng nhỏ và pose tự nhiên để pet cùng hệ không giống hệt nhau.
- Bố cục PetHome là ảnh dọc 9:16, pet khoảng 35% chiều cao ảnh, có vùng trống UI phía trên.
- Nếu trứng Stage 4 khóa Mythic Destiny, Stage 1 chỉ được foreshadow nhẹ; không được thể hiện hình thái Mythic hoàn chỉnh.

Code chính:
- `features/evolution/visual/initial_pet_visual_spec_builder.gd`
- `features/evolution/visual/initial_pet_prompt_builder.gd`
- `features/evolution/service/initial_pet_render_coordinator.gd`

## 3. Stage 1 → Stage 2 — giữ đúng cùng một pet

Stage 1 → Stage 2 không còn full-regenerate/freestyle.

Contract hiện tại:

1. Luôn dùng `EVOLUTION_IMAGE_EDIT`.
2. Ảnh Stage 1 hiện tại là source image và là nguồn identity chuẩn.
3. Prompt phải có `[LINEAGE CONTINUITY]`.
4. Prompt phải dùng đúng `stage_2_morphology` của hệ trong `element_stage_profiles.json`.
5. Giữ nhận dạng cá thể: khuôn mặt, pattern lông, markings, palette family và các chi tiết nhận dạng đã hình thành ở Stage 1.
6. Stage 2 được thay đổi tỷ lệ cơ thể, độ trưởng thành, lông và morphology theo tuổi/hệ nhưng không được biến thành một cá thể khác.
7. PetHome vẫn giữ composition khóa: pet khoảng 28–32% chiều cao ảnh, phần lớn khung hình là môi trường.

Không được khôi phục `[STAGE 2 FREESTYLE]` hoặc `INITIAL_TEXT_TO_IMAGE` cho Stage 1 → 2.

Code chính:
- `features/evolution/service/evolution_edit_coordinator.gd`
- `features/evolution/service/stage_evolution_plan_validator.gd`

## 4. Gene trong Stage 1 → Stage 2

- Nếu không có Gene: dùng Natural Growth, giữ toàn bộ Gene locus hiện tại.
- Nếu có Gene: vẫn image-edit từ ảnh Stage 1 và thêm `[CODE-LOCKED GENE CHANGE]`.
- Gene do code resolve; AI chỉ thể hiện thay đổi đã khóa.
- AI không được tự thêm Gene, mutation hoặc đổi branch.
- Multi-Gene ở các tiến hóa sau dùng composite plan.
- Gene Growth bonus đã được tích hợp vào Stage 2 lifecycle.

## 5. Mythic Destiny và Mythic Mutation

- Mythic Destiny có thể được khóa từ trứng Stage 4 hoặc từ công thức Gene.
- Destiny được truyền xuyên suốt evolution plan.
- Khi Mythic active, prompt có `[CODE-LOCKED MYTHIC DESTINY]`.
- AI chỉ phát triển đúng branch Mythic do code chọn; không reroll, trộn hoặc đổi sang sinh vật Mythic khác.
- Species-specific Mythic definitions nằm trong `data/evolution/mutation/species_mythic_mutations.json`.

## 6. Stage 2 gameplay

- Stage 2 lifecycle chuẩn là 48 giờ.
- Food capacity cố định; độ no ảnh hưởng tốc độ Growth.
- Khi độ no về 0, pet vào hibernation và Growth dừng cho tới khi được cho ăn.
- Mốc tuổi/deadline không được bypass hibernation để tiến hóa.
- Gene có thể cộng Growth bonus theo policy hiện tại.
- Item rác làm giảm Growth là gameplay chủ ý, không tự động “sửa” thành chỉ số dương.

## 7. Reward và rương

- Rương Evolution I đảm bảo có ít nhất một Gene hợp lệ cho Stage 2.
- Obstacle Run và Snake dùng chung pool 4 Rương Hoạt động Stage 2.
- Trong 4 rương hoạt động Stage 2 có đúng một vị trí Gene bảo đảm theo life seed; vị trí thay đổi giữa các life.
- Reward counter phải sống qua reload trong cùng một life.
- Sau khi hết 4 rương, minigame vẫn chơi tự do nhưng không nhận thêm rương Stage 2.
- Cơ chế item decomposition của `pethome` được giữ nguyên: item có thể phân giải thành mảnh rương; 10 mảnh ghép thành rương tái chế.

Không được phục hồi gameplay Maze/Pacman. Legacy storage key `maze_hunt` chỉ được giữ khi cần tương thích dữ liệu cũ.

## 8. PetHome feedback

PetHome phải hiển thị được:
- Gene đang định hướng / Gene đã resolve.
- Multi-Gene khi có nhiều locus.
- Mythic Destiny/Mutation khi active.
- Hunger, Growth speed và hibernation.
- Số Rương Hoạt động Stage 2 còn lại.
- Obstacle Run + Snake là cặp minigame Stage 2 hiện hành.

## 9. Persistence và retry

- Pending evolution schema hiện tại: v9.
- Plan cũ dùng Stage 1 → 2 full-regenerate không được tái sử dụng.
- Retry phải tái sử dụng cùng canonical render request/seed.
- Commit evolution chỉ thành công khi render result khớp request đã khóa.
- Output key giữ chuẩn `_pethome_v11_stage_<n>`.

## 10. Acceptance bắt buộc

Workflow `.github/workflows/stage2-acceptance.yml` phải kiểm tra:
- Stage 1 prompt contract.
- Stage 1 → 2 identity continuity.
- Stage 2 lifecycle.
- Stage 2 reward contract.
- Stage 2 Gene resolver.
- Stage 2 Mythic contract.
- Mythic retry plan.
- Stage 2 PetHome feedback.
- Stage 2 → Stage 3 acceptance.
- Android debug APK smoke build.

Mốc đồng bộ này đã PASS toàn bộ acceptance và Android build trước khi merge vào `pethome`.

## 11. Các invariant không được regress

- Không đưa lại framework 2.5D cũ vào render path hiện tại.
- Không đưa lại Pacman/Maze thành gameplay.
- Không đổi Stage 1 → 2 về full-regenerate.
- Không bỏ `stage_1_face` khỏi prompt Stage 1.
- Không bỏ `stage_2_morphology` khỏi prompt Stage 2.
- Không cho AI quyết định Gene/Mythic branch.
- Không lùi output/render contract từ v11 về v8/v5.
- Không làm mất chest fragment/recycled chest hiện tại của `pethome`.
