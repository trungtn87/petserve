# Infant Gameplay V1 — Item / Chest / Inventory

## Locked scope

Ấu thể là tutorial thật trong vòng đời, mục tiêu khoảng 2 giờ.

Core flow:

Egg hatch -> Hatch Chest -> Item -> Food/Growth -> Infant progress -> Ready to Evolve.

Không có minigame riêng ở stage này.

## Hatch Chest

6 slot cố định theo loại:
- 3 Food
- 2 Growth
- 1 Future Fragment

Loại slot cố định nhưng từng item roll độc lập theo:
- rarity;
- quality;
- main value;
- properties;
- defects;
- salvage value.

Rarity không đồng nghĩa item chắc chắn tốt. Legendary vẫn có thể roll chất lượng hỏng và defect xấu.

## Item types usable in Infant

### Food
Tăng Food Reserve. Một số roll có thể cộng hoặc trừ nhẹ Growth.

### Growth
Tác động trực tiếp thời gian trưởng thành còn lại. Roll xấu có thể rất yếu hoặc phản tác dụng.

### Future Fragment
Rơi trong Hatch Chest để giới thiệu chiều sâu hệ item nhưng bị khóa tới sau Evolution #1.

## Rarity V1

- Common 55%
- Uncommon 25%
- Rare 13%
- Epic 6%
- Legendary 1%

## Quality V1

- Broken 15%
- Poor 25%
- Normal 35%
- Good 20%
- Perfect 5%

Đây là balance test, chưa phải tỷ lệ final.

## Infant lifecycle

- Base duration: 2 giờ.
- Food khởi đầu: 15 phút.
- Khi có Food: Growth chạy 100%.
- Hết Food trong tutorial: Growth vẫn chạy 75%.
- Tutorial life chưa có Neglect Death.
- Food/Growth item có thể giúp gần như skip stage nếu người chơi tích đủ item về late game.

## UI

Pet Home có:
- Character Frame: Stage, Growth %, Food Reserve, time remaining.
- Chest button: hiển thị số rương pending.
- Inventory button: hiển thị số item.
- Inventory filters: All / Food / Growth / Other.
- Item card: name, rarity, quality, effect, properties, defects.
- Food/Growth có nút Use.
- Future Fragment bị khóa.

Menu cũ:
- Thức ăn -> mở Inventory lọc Food.
- Đồ dùng -> mở toàn bộ Inventory.

## Persistence

Account/meta data lưu riêng tại user://meta_v1.json:
- inventory;
- chest queue;
- infant lifecycle state.

Run save trứng hiện tại không bị thay schema.

## Architecture

gameplay/item/item_generator.gd
gameplay/chest/chest_service.gd
gameplay/inventory/inventory_service.gd
gameplay/infant/infant_lifecycle.gd
gameplay/infant/infant_game_facade.gd
screens/pet_home/pet_home_gameplay_ui.gd

PetHome3DScreen chỉ điều phối service + UI.

## Next

Sau khi test trên Godot/Android:
1. Chest reveal animation.
2. Item icon art.
3. Salvage.
4. Evolution #1 trigger.
5. Mở Element/Gene/Mutation từ Stage 2.
