# VR Room Training — Meat Grinder Assembly

Current milestone: **Phase 10 — Quest 3 Final Build & QA**

Validated training systems:
- Manual / Electric / Sausage / 90-second Challenge scenarios
- Sausage front order: Lock Ring before Sausage Attachment
- Immediate GREEN-zone Auto-Snap
- Mechanical fit and legal collision clearance
- Exclusive one-button hover + audible Hover/Click
- Training / Free Practice
- VR-fair assessment: PASS/FAIL, Grade A/B/C/F, Quality, Accuracy, First Try
- Deduplicated wrong-pick/drop assessment mistakes
- Baseline + Best Passing records per Scenario + Difficulty
- Multi-line RTL-safe result record layout
- PBR workshop and Phase 7 visual polish

Quest 3 build pipeline:
- Android Gradle Build
- ARM64 only
- minSdk 32 / targetSdk 34
- OpenXR + Meta OpenXR Vendors 5.1.0-stable
- Reproducible setup/preflight/debug-build scripts

Start here:

```bash
./tools/quest3_prepare.sh
./tools/quest3_preflight.sh
./tools/build_quest3_debug.sh
```

See `PHASE_10_QUEST3_BUILD_QA_FA.md` for the complete Phase 10 workflow and QA gates.

Phase overlays never replace `assets/textures/workshop/`; the Poly Haven downloader is not part of the normal update flow anymore.
