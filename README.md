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

## Security boundary

The mobile APK only knows the proxy URL. Provider credentials remain on Cloudflare.

An optional `PETVERSE_PROXY_KEY` can gate a development Worker, but any key shipped in an APK must not be treated as a production secret.

A production release should add real server-side authentication, abuse controls and rate limiting.

## Provider replacement

M1–M4 do not know about Cloudflare. A later paid image provider can replace Workers AI inside the proxy while Godot keeps the same client contract.

## Test status

Local direct Workers AI generation was validated before switching the client to the proxy architecture. The next validation target is the same render flow through the deployed Worker, then Android APK.
