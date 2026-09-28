# M5/M6 — Cloudflare Free Development Renderer

## Decision

The paid OpenAI development adapter is replaced by Cloudflare Workers AI for the prototype.

Model:

```text
@cf/black-forest-labs/flux-2-klein-4b
```

The renderer contract itself is unchanged:

```text
PetRenderRequest
      ↓
PetRenderer
      ↓
PetRenderResult
```

This keeps the game independent from the image provider.

## Initial render

M6 sends a multipart REST request containing:

```text
prompt
width
height
```

to:

```text
/accounts/{ACCOUNT_ID}/ai/run/@cf/black-forest-labs/flux-2-klein-4b
```

The API token is sent as a Bearer token.

The response image may be returned in the Workers AI JSON envelope as base64. The adapter also accepts a raw PNG/JPEG response defensively.

Returned data is decoded into Godot `Image` and always cached locally as PNG.

## Development environment

Required:

```text
CLOUDFLARE_ACCOUNT_ID
CLOUDFLARE_API_TOKEN
```

No credential is committed.

## Future evolution edit

FLUX.2 Klein supports reference-image editing. The current M5 request enum already contains:

```text
EVOLUTION_IMAGE_EDIT
```

That mode is not enabled in this commit. The next image-edit milestone will attach the previous pet image as `input_image_0`.

## Provider replacement

If a later paid renderer is better, implement another `PetRenderer` adapter. Identity, genome, mutation rules and prompt builders must remain unchanged.
