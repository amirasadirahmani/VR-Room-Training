# VR Room Training — Meat Grinder Assembly

Current milestone: **Phase 6 — Complete Training Loop**

- OpenXR / Meta XR Simulator
- Mechanical assembly fit
- Training + Free Practice
- Easy / Normal / Hard
- Scoring, penalties, timer, accuracy, First Try
- Full reset and completion result
- Audio feedback + Quest haptic hooks
- PBR workshop materials

See `PHASE_6_TRAINING_LOOP_FA.md` for test flow.

Godot 4.7 + OpenXR training prototype for Meta Quest 3 / Meta XR Simulator.

## Core flow

1. Auger
2. Blade
3. Perforated plate
4. Lock ring
5. Hopper tray
6. Pusher

## Modes

- Guided Training
- Free Practice
- Reset Assembly

## Simulator controls used during development

- WASD: move
- Arrow keys: view rotation
- U: grip / grab
- Space: reset controller poses

## Snap tuning

Edit `scripts/assembly/assembly_settings.gd`.