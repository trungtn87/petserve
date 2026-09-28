# PetVerse Render Proxy

This Cloudflare Worker is the provider boundary used by Godot.

## Runtime flow

```text
Godot PC / Android
      ↓ HTTPS JSON
Cloudflare Worker
      ↓ AI binding
Workers AI
      ↓
FLUX.2 Klein 4B
```

The Godot client never receives the Cloudflare API token or Account ID.

## Routes

- `GET /health`
- `POST /v1/render/initial`

Initial request:

```json
{
  "prompt": "...",
  "width": 1024,
  "height": 1024
}
```

Successful response:

```json
{
  "ok": true,
  "image": "<base64>",
  "model": "@cf/black-forest-labs/flux-2-klein-4b",
  "width": 1024,
  "height": 1024
}
```

## Optional development gate

If the Worker secret `PETVERSE_PROXY_KEY` exists, requests must send the same value in `X-PetVerse-Key`.

This is only a lightweight development gate. A value shipped in an APK is not a production secret. Production authentication/rate limiting must be handled server-side.

## Deployment

The Worker requires the Workers AI binding named `AI`. The included `wrangler.jsonc` defines that binding.

After deployment, place the public Worker URL in:

`data/evolution/render/proxy_dev.json`

using the full endpoint:

`https://<worker>.workers.dev/v1/render/initial`
