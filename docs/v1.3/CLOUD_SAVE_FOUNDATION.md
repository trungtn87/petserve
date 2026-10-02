# PetVerse v1.3 — Cloud Save Foundation

## Goal

Deleting app data, reinstalling the game, or changing device must not erase the player's long-term account.

v1.3 keeps the current local save system for fast/offline gameplay and adds a durable cloud layer.

## Current persistence found on pethome

The current branch stores gameplay in several local domains:

- SaveManager: run + meta
- Egg SaveService
- HatchSaveService
- EvolutionSaveService
- LegacyInheritanceService
- current generated pet visual referenced by current_visual.image_path

The visual file is required. Restoring only JSON is not enough because GameApp checks that the current visual file still exists.

## Locked architecture

LOCAL GAMEPLAY
-> existing local save services
-> CloudSaveBundle
-> Cloud sync adapter
-> Supabase

Supabase is split into two products:

1. Database
   - one durable account snapshot per authenticated user
   - revision / schema / snapshot JSON
2. Storage
   - current generated pet visual
   - later: optional gallery/history assets

Do not reuse the existing FINAL14-Autotrade Supabase project. PetVerse gets its own project.

## Identity

Cloud recovery requires a persistent account identity.

A temporary device ID or anonymous-only account is not sufficient because clearing app data also deletes that identity/session.

Initial v1.3 target:
- Supabase Auth account
- email/password first for the smallest Android implementation
- Google sign-in can be added later without changing the save schema

Guest/local play can remain possible, but it is explicitly non-recoverable until linked to an account.

## Snapshot v1

CloudSaveBundle schema 1 contains:

- run
- meta
- egg
- hatch
- evolution
- legacy
- visual manifest

The bundle intentionally mirrors current game persistence instead of normalizing all gameplay into database tables.

This keeps v1.3 additive and prevents a cloud feature from rewriting Stage 1–4 gameplay.

## Visual asset rule

Only the current visual is required for first release recovery.

Upload:
- the file referenced by evolution.current_visual.image_path

Restore order:
1. authenticate
2. fetch cloud snapshot
3. download current visual from Storage back to its local user:// path
4. apply CloudSaveBundle
5. restart/reload game state

Do not apply the evolution JSON before the image has been restored.

## Server table target

One row per auth user:

player_save_snapshots
- user_id uuid primary key -> auth.users.id
- schema_version int
- revision bigint
- snapshot jsonb
- visual_object_path text nullable
- updated_at timestamptz

RLS must be enabled.

Authenticated users may SELECT / INSERT / UPDATE only their own row:
auth.uid() = user_id.

The Android client receives only the Supabase publishable key.
Never ship a secret/service-role key in the game.

## Storage target

Private bucket:
pet-saves

Object convention:
<user_id>/current/<pet_id>_<visual_index>.png

The authenticated user may only access objects under their own <user_id>/ prefix.

## Sync behavior

Local-first:
- gameplay writes local save immediately
- cloud sync is asynchronous and never blocks a tap, chest open, item use, or evolution transaction

Important checkpoints trigger cloud dirty state:
- new life
- hatch
- chest/item mutation
- stage evolution
- legacy preparation/claim
- app shutdown

A short debounce can collapse frequent local writes into one cloud upload.

## Conflict model

Store a cloud revision locally.

Normal save:
- local known revision == remote revision
- push snapshot
- server revision increments

On startup:
- remote missing + local present -> upload local
- remote present + local missing -> restore remote
- both clean and same revision -> continue
- remote newer -> pull remote
- both changed from the same base -> conflict; never silently overwrite

v1.3 initially targets one active device at a time, but revision exists from day one so multi-device support does not require a schema rewrite.

## Milestones

C0 — CloudSaveBundle
- capture every existing local save domain
- restore every domain
- rollback on partial local restore failure
- test round-trip

C1 — Dedicated PetVerse Supabase project
- Auth
- player_save_snapshots table + RLS
- private pet-saves bucket + policies

C2 — Godot Supabase REST/Auth adapter
- sign up / sign in / refresh session
- fetch snapshot
- push snapshot

C3 — Storage adapter
- upload current pet visual
- download it before JSON restore

C4 — Recovery acceptance test
- create pet
- gain inventory/gene/legacy data
- sync
- delete Android app data
- reinstall/sign in
- restore same pet + inventory + progression + visual

C5 — offline/revision/conflict handling

C6 — Account + sync status UI

## v1.3 pass condition

The feature is not complete until the following works on Android:

create progress -> cloud sync -> clear all app data -> relaunch -> sign in -> restore -> same active life and long-term account data are present, including the current rendered pet image.
