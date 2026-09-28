# Pet Vô Hạn — Evolution Core

Godot Android portrait project.

## M0 — Clean baseline

M0 removes the retired pet presentation experiments so the next implementation starts from a small, controlled base.

Kept:
- Core infrastructure and local save/load.
- Egg incubation v1.1.
- Hatch and naming flow.
- Main UI and Android project configuration.
- Independent feature branches remain untouched.

Removed from the M0 branch:
- 3D pet runtime, models, rigs and test tooling.
- 2D/2.5D pet actor/presentation code.
- Pet idle/expression/motion/interaction systems.
- Pet Home runtime and old room definitions.
- Old pet-specific runtime assets and implementation docs.

After hatching, the app currently routes to a static Evolution Core placeholder. M1 will replace that placeholder with the new evolution-domain foundation.
