# Xếp tinh thể (Ball Sort)

Mini game dùng luật Ball Sort: chọn tinh thể trên cùng của một ống và chuyển sang ống trống hoặc ống có tinh thể trên cùng cùng màu. Mỗi ống chứa tối đa 4 tinh thể.

## Tiến trình map

- Màn 1–5: 3 màu, 2 ống trống.
- Màn 6–10: 4 màu, 2 ống trống.
- Màn 11–30: 5 màu, 2 ống trống.
- Màn 31–60: 6 màu, 2 ống trống.
- Màn 61–100: 7 màu, 1 ống trống.
- Sau màn 100: tăng dần tới tối đa 10 màu, giữ 1 ống trống và tăng số bước xáo trộn.
- Mỗi 10 màn là HARD; mỗi 30 màn là EXPERT.

Map được sinh từ trạng thái đã giải bằng chuỗi bước đảo ngược có thể hoàn tác hợp lệ. Vì vậy mỗi map sinh ra luôn có ít nhất một lời giải. Generator thử nhiều ứng viên và dùng Difficulty Score để chọn bố cục phù hợp với giai đoạn.

Tiến trình lưu unlocked, last_level và kỷ lục số bước tốt nhất cho từng màn trong save metadata. Mini game hiện chơi tự do, chưa gắn thêm thưởng để không thay đổi economy hiện tại.
