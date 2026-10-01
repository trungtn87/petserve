# Stage 3 — Food & Growth Item Expansion

Status: **FOUNDATION IMPLEMENTATION**

This is the first Stage 3 content expansion on top of the `pethome` baseline.

## Goal

Food and Growth items now use the same five rarity tiers already used by Gene items:

```text
Common
Uncommon
Rare
Epic
Legendary
```

The change is deliberately limited to resource-item content and value scaling. It does **not** change Gene score logic, evolution resolution, hunger thresholds, stage durations, or the existing quality/property/defect system.

## Catalog size

Each rarity has four named base definitions.

| Type | Common | Uncommon | Rare | Epic | Legendary | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Food | 4 | 4 | 4 | 4 | 4 | 20 |
| Growth | 4 | 4 | 4 | 4 | 4 | 20 |

An item instance still receives:

```text
base definition
+ rarity
+ quality
+ properties
+ defects
+ stage scaling
```

So 40 base definitions can still produce many instance variants without multiplying gameplay code.

## Food pool

### Common

- Cá nhỏ
- Thịt mềm
- Sữa ấm
- Quả mọng

### Uncommon

- Cá bạc
- Thịt giàu năng lượng
- Củ mật
- Sữa hạt tinh lực

### Rare

- Cá ánh trăng
- Thịt Linh Thú
- Quả sinh lực
- Sữa pha lê

### Epic

- Cá Tinh Vân
- Thịt Cổ Thú
- Quả Tăng Trưởng
- Mật Linh

### Legendary

- Cá Ngân Hà
- Thịt Thiên Thú
- Quả Sinh Mệnh
- Mật Trường Sinh

## Growth pool

### Common

- Gel vitamin
- Dịch dinh dưỡng
- Men chuyển hóa
- Thuốc bổ tăng trưởng

### Uncommon

- Tinh chất tăng trưởng
- Dung dịch tăng tốc
- Xúc tác sinh học
- Dịch hấp thu

### Rare

- Huyết thanh linh lực
- Tinh chất pha lê
- Enzyme thích nghi
- Lõi sinh lực

### Epic

- Huyết thanh Tinh Vân
- Xúc tác Cổ Đại
- Tinh chất Tiến Hóa
- Lõi Sao

### Legendary

- Lõi Sinh Mệnh
- Tinh chất Thiên Thể
- Huyết thanh Khởi Nguyên
- Lõi Trường Sinh

## Rarity value contract

The numbers below are **base Stage 1 ranges before quality, property, defect, and stage multipliers**.

| Rarity | Food fullness | Growth acceleration |
| --- | ---: | ---: |
| Common | 20–30 min | 6–12 min |
| Uncommon | 30–45 min | 10–16 min |
| Rare | 45–65 min | 15–25 min |
| Epic | 60–90 min | 25–40 min |
| Legendary | 90–120 min | 40–60 min |

Stage scaling remains unchanged:

```text
Stage 1 ×1
Stage 2 ×12
Stage 3 ×18
```

Quality, properties and defects are applied after the rarity base value is selected, so a bad high-rarity roll can still be damaged by defects. This preserves the existing design where junk/bad items are intentional rather than silently normalized away.

## Runtime contract

Every Food/Growth item now exposes:

- `definition_id` — stable base item identity;
- `base_display_name` — clean base name;
- `display_name` — instance name after quality/defect decoration;
- `rarity` — one of the five shared rarity tiers;
- the existing effect/property/defect/save fields.

The generator also exposes deterministic helpers for tests and future guaranteed-rarity chest rewards:

- `generate_resource_for_rarity()`
- `resource_definition_count()`
- `resource_base_range_for_rarity()`

## Acceptance

`tools/test_stage3_food_growth_items.tscn` verifies:

- five rarity tiers exist for Food and Growth;
- each tier contains four base definitions;
- total catalog is 20 Food + 20 Growth;
- forced-rarity generation preserves rarity and stable definition identity;
- base effect ranges increase with rarity;
- Stage scaling does not reroll definition or rarity.


## Graded secondary effects

Food and Growth items can now carry both positive and negative secondary effects.

Each rolled effect has one of four strength levels:

| Level | UI | Meaning |
| ---: | --- | --- |
| I | Nhẹ | noticeable but small |
| II | Vừa | meaningful |
| III | Mạnh | large impact |
| IV | Cực mạnh | run-shaping impact |

Positive effect level is biased by **rarity**:

- Common: level I only, when a positive property exists;
- Uncommon: mostly I, sometimes II;
- Rare: mainly II, with I/III possible;
- Epic: II–IV, mainly III;
- Legendary: III–IV only.

Negative effect level is biased by **quality**:

- Perfect: defects are very rare and level I;
- Good: mostly I, occasionally II;
- Normal: I–III;
- Poor: II–IV;
- Broken: III–IV.

This separation is intentional: rarity describes the potential power of the item, while quality describes how damaged or dangerous that particular instance is. A Legendary item with Broken quality can therefore contain very strong positive properties and very strong defects at the same time.

### Food positive effects

- Tươi
- Đậm đặc
- Dinh dưỡng
- Giàu tăng trưởng
- Dễ tiêu
- Bồi bổ

### Food negative effects

- Ôi
- Cũ
- Khó tiêu
- Hỏng nặng
- Đầy bụng
- Nhiễm tạp

### Growth positive effects

- Cô đặc
- Tác dụng nhanh
- Tinh khiết
- Bùng trưởng
- Ổn định
- Hấp thu cao

### Growth negative effects

- Pha loãng
- Hết hạn
- Hao thức ăn
- Phản tác dụng
- Bất ổn
- Dư chất

The generated item persists these effects in a `secondary_effects` array containing:

```text
id
polarity = positive | negative
level = 1..4
label
level_label
```

The current runtime remains simple: secondary effects are resolved into the existing Food/Growth delta fields at generation time, so StageLifecycle does not need a second effect engine and old save/use paths remain compatible.

PetHome item detail renders effects such as:

```text
+Bồi bổ III • Mạnh
-Hao thức ăn II • Vừa
```

This makes mixed-quality items readable before the player decides whether to use or salvage them.
