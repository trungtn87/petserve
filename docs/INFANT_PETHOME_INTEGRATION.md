# PetHome / Ấu thể → Stage 2

Baseline: `pethome` at `ec2ba4a`, integrating gameplay commit `0e0495a`.
Preserves V5 framing/cache, illustrated right-side drawer, pet logo and cinematic transition.
Selectively imports gameplay, inventory/chest, Caro and gameplay UI from
`feat/infant-caro-entertainment`; does not merge the deferred localization or
retired 2.5D/3D presentation branches.

## Playable flow

Egg/name → initial scene render → image PetHome → hatch chest → inventory →
Food/Growth → ready → one persisted mutation roll → reference-image render →
atomic genome/visual/history commit → stage-2 PetHome.

- 2-hour fed growth target, 15-minute starting food, 75% hungry growth.
- Tutorial infant has no neglect death. Offline food/growth use the same split.
- Hatch chest: 3 Food, 2 Growth, 1 future fragment. One per run.
- Caro: up to four common Food/Growth reward chests per infant run.
- Inventory and reward saves roll back in memory on write failure.
- Ready infant cannot spend more infant items. Stage 2 retains inventory and
  allows Caro without awarding more infant rewards.
- Existing weighted mutation catalog is retained. Food/Growth affect growth
  as in the imported V1; no new element-influence balance is invented.
- Stage-2 timing, subsequent evolution conditions, fragment crafting and
  legacy remain outside this infant milestone; no automatic stage-2 timer.

## Presentation

PetHome uses the saved complete pet/background image. HUD, chest, inventory,
Caro and transition share dark translucent panels, element-specific text/accent colors, rounded controls. Gameplay opens through
the existing right-side menu; the compact HUD stays in place. Stage, growth,
food reserve, readiness, inventory and chest counts are visible.

## Persistence and retry

An evolution plan is persisted before sending the render request. Retry uses
that plan and the previous image, preserving identity, scene and inventory.
Only a decoded image permits the stage/genome/visual/history commit. Locally
cached render output avoids regeneration after a local save failure.

Render failures expose explicit Retry/Back controls. There are no automatic
unbounded render retries. A network timeout after the remote provider completed
can still result in a paid retry: this Worker has no durable remote job cache.

## Worker update required

Deploy `infrastructure/cloudflare/pet-render-proxy/src/index.js` to the existing
Worker with its existing AI binding/key. New route:
`POST /v1/render/evolution`, with `source_image` PNG base64. The client resizes
its reference below 512px and the Worker forwards `input_image_0` multipart.
The initial route remains compatible.

Cloudflare reference:
https://developers.cloudflare.com/changelog/post/2026-01-15-flux-2-klein-4b-workers-ai/

From the Worker directory, with an already authenticated Cloudflare CLI:
`npx wrangler deploy`.
This task does not contain a connected Cloudflare deployment capability;
production Worker deployment and real paid render are not verified.

## Validation

Godot 4.6.1 headless: existing M1/M2/M3/M4/M5-M6/scene-profile suites pass.
`tools/test_infant_home.tscn`: online/offline growth boundary, negative delta,
chest duplication, item duplication, reward caps and reload, evolution gating,
stable retry plan, failed render, commit, identity preservation, duplicate commit,
and PetHome/inventory/Caro instantiation plus existing drawer toggle and navigation.

Run in an isolated save directory:
`XDG_DATA_HOME=/tmp/petverse-test-unique godot --headless --path . tools/test_infant_home.tscn`
Use a fresh directory for each run; this test creates test saves.

Worker contract:
`node infrastructure/cloudflare/pet-render-proxy/test.mjs`.
Mocks provider; validates authentication, reference input, size checks, and calls.

Visual screenshot verification could not run because the local display could
not be opened. Android SDK is unavailable; no APK or device-test claim is made.
