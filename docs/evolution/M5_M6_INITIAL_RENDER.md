# M5/M6 — Single-Image PetHome Renderer

## Goal

PC and Android use the same proxy renderer while each hatch/evolution spends only one image-generation request.

## Initial flow

```text
PetIdentity + PetSceneProfile + PetGenome
                 ↓
        InitialPetVisualSpec
                 ↓
     one unified PetHome prompt
                 ↓
          PetRenderRequest
                 ↓
         ProxyPetRenderer
                 ↓ HTTPS JSON
        Cloudflare Worker
                 ↓ Workers AI
         FLUX.2 Klein 4B
                 ↓
 one image containing pet + environment
                 ↓
    user://pet_renders/*.png
```

The first image is the visual origin of the pet and its PetHome world.

## Credit rule

There is no second background-render request.

```text
Hatch      → 1 request → pet + background
Evolution  → 1 request → evolved pet + evolved/continued background
```

## Save contract

`EvolutionSaveService` schema 2 stores:

- pet name;
- identity;
- genome;
- scene profile;
- current visual.

Legacy saves without a scene profile are not reused as a valid PetHome visual, so an old pet-only render is regenerated once using the new full-scene contract.

## Provider boundary

The APK only knows the proxy URL. Provider credentials remain outside the game client.

Evolution image-edit remains the next renderer milestone. It will use the previous full PetHome image as the reference while retaining the same scene profile.
