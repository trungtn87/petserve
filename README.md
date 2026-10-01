# Pet Vô Hạn — Evolution Core

Godot Android portrait project.

## Development runtime

The project baseline is **Godot 4.6.1**. Keep `project.godot` on the 4.6 feature level so editor, headless tests and Android exports use the same minor-version contract. Do not resave the project as a newer Godot feature level unless the whole repository is migrated and re-tested together.

## Current visual direction

Base art direction:

```text
MYTHIC ELEMENTAL CHIBI
```

M1–M4 remain provider-independent:
- PetIdentity
- PetGenome
- deterministic evolution rules
- Mythic visual/prompt specification

## M5/M6 renderer architecture

The active client renderer now uses a proxy:

```text
Godot PC / Android
        ↓ HTTPS
PetVerse Cloudflare Worker
        ↓ Workers AI binding
@cf/black-forest-labs/flux-2-klein-4b
        ↓
base64 image
        ↓
PNG cached in user://pet_renders
```

Cloudflare Account ID and API token are no longer required by the Godot client.

The Worker implementation lives under:

`infrastructure/cloudflare/pet-render-proxy/`

The client endpoint is configured in:

`data/evolution/render/proxy_dev.json`

The first image uses no reference image and becomes the visual origin for later evolution edits.

## M7 evolution image-edit

M7 reuses the previous complete PetHome PNG as the visual source of truth.

`EvolutionEditCoordinator` builds one controlled `EVOLUTION_IMAGE_EDIT` request from:

- the same immutable PetIdentity;
- the previous genome;
- one deterministic EvolutionDelta;
- the previous PetHome visual;
- the stable PetHome scene profile;
- the explicit next stage.

The complete render request is persisted inside `pending_evolution` before network rendering. Retry restores that exact request instead of rerolling mutation or rebuilding a different prompt.

Stage 1 → 2 now uses this contract. Future Stage 2 → 3 and Stage 3 → 4 must reuse it.

See:

`docs/evolution/M7_EVOLUTION_IMAGE_EDIT.md`

## Security boundary

The mobile APK only knows the proxy URL. Provider credentials remain on Cloudflare.

An optional `PETVERSE_PROXY_KEY` can gate a development Worker, but any key shipped in an APK must not be treated as a production secret.

A production release should add real server-side authentication, abuse controls and rate limiting.

## Provider replacement

M1–M4 do not know about Cloudflare. A later paid image provider can replace Workers AI inside the proxy while Godot keeps the same client contract.

## Test status

Repository contract tests cover M1–M7 and the infant PetHome integration.

M7 adds:

`tools/test_m7_evolution_edit.tscn`

The remaining runtime validation is the deployed `/v1/render/evolution` Worker route with a real Stage 1 → 2 image edit, followed by Android device verification.


## M8 stage lifecycle

M8 extends the playable life from the infant milestone through all three evolutions:

```text
Stage 1 → Evolution I → Stage 2 → Evolution II → Stage 3 → Evolution III → Stage 4
```

Stage timing is loaded from `data/gameplay/lifecycle/stages.json`.
Stage 2 and Stage 3 use the provisional 2-day / 3-day design baselines; Stage 1 preserves the existing 2-hour tutorial target.

`StageEvolutionService` reuses the M7 image-edit contract for all three evolution transactions. Stage 4 is the M8 final-form boundary; aging, death and legacy are deferred.

See `docs/evolution/M8_STAGE_LIFECYCLE.md`.


## Development test talent

During stage-by-stage gameplay testing, every pet is temporarily assigned the talent `dev_instant_evolution`.

This talent does not complete growth and does not consume the stage timer. It only exposes the evolution action immediately through `can_evolve`, so Food, Growth items, chests and other stage interactions remain testable before choosing to evolve.

This is a development-only shortcut. The real Talent system and production talent balance are intentionally deferred.
