# Pet Vô Hạn — Evolution Core

Godot Android portrait project.

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
