# M5/M6 — Proxy Renderer

## Goal

Make PC and Android use the same renderer path without shipping provider credentials in the game.

## Flow

```text
PetRenderRequest
      ↓
ProxyPetRenderer
      ↓ HTTPS JSON
Cloudflare Worker
      ↓ env.AI.run()
FLUX.2 Klein 4B
      ↓
base64 image
      ↓
PetRenderResult
```

## Why this boundary exists

The APK must not contain Cloudflare Account ID/API token credentials. The Worker owns the provider call.

The client sends only:
- generated prompt;
- requested width;
- requested height.

The Worker owns:
- model selection;
- Workers AI binding;
- provider errors;
- future provider replacement.

## Current scope

M6 initial text-to-image is active.

Evolution image-edit remains reserved for the next milestone. FLUX.2 Klein accepts reference image inputs, so the Worker can later add `input_image_0` while keeping the Godot domain model unchanged.

## Client configuration

`data/evolution/render/proxy_dev.json`

The `proxy_url` must be the deployed Worker endpoint:

`https://<worker>.workers.dev/v1/render/initial`

No Cloudflare provider token belongs in Godot or the APK.
