# Xếp tinh thể (Ball Sort)

Mini game dùng luật Ball Sort: kéo tinh thể trên cùng của một ống sang ống trống hoặc ống có tinh thể trên cùng cùng màu. Mỗi ống chứa tối đa 4 tinh thể.

## Cơ chế số bước

- Không giới hạn thời gian; mỗi màn dùng **số bước còn lại**.
- Chỉ một lần di chuyển tinh thể hợp lệ mới trừ 1 bước. Kéo sai, thả sai vị trí hoặc chọn thao tác không làm đổi bàn chơi không trừ bước.
- Gợi ý không trừ bước.
- Hoàn tác trả lại bước vừa đi vì bàn chơi được khôi phục đúng trạng thái trước đó.
- Hoàn thành ở bước cuối cùng vẫn tính thắng.
- Nếu về 0 bước mà bàn chưa hoàn thành, màn chuyển sang **Thất bại** và người chơi phải chọn **Chơi lại màn**.
- Khi thắng, tiến trình vẫn tự chuyển sang màn tiếp theo như trước.

Giới hạn bước được tính từ số bước của lời giải bảo đảm do generator tạo ra cộng thêm biên sai số. Màn đầu có biên rộng hơn; càng về sau biên càng chặt. Màn HARD và EXPERT được siết thêm, nhưng giới hạn luôn lớn hơn số bước của lời giải bảo đảm nên map không bị tạo ở trạng thái bất khả thi do giới hạn bước.

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
