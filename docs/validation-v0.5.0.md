# v0.5.0 functional checkpoint — 2026-11-04

- `build/covenant_chronicles_v0.5.0.apk`, 48,868,938 bytes.
- Actual package `com.covenant.chronicles`, version code 5 / name 0.5.0.
- APK SHA-256: `00520d3877917735a81f0a64ed96dbdc82e4dd7584ec6741c915d518a8f63395`.
- Same signing certificate as v0.3/v0.4; ZIP CRC, compiled skill runtime/data and
  development-artifact exclusion checked by `python tools/verify_apk.py`.
- `python tools/run_checks.py`: 23 suites / 798 PASS checks. Adds all 44 skill
  plans, source character prerequisites/ranks/reset, shared/offline skill effects,
  per-skill cooldowns, aura expiration, magic shield, curse/duel safety, threat,
  four-slot dispatch and preserved v0.4 migration backups.
- Two-process ENet world test PASS, including actual remote source-skill damage
  through an additional hotbar slot. Social transport test remains covered by
  the preceding checkpoint and unchanged request transport.
- GPU captures inspected: `build/source-hotbar.png`, `build/source-skills.png`.
- Physical device gameplay remains unverified; phone has no ADB connection.

This is an intermediate logic checkpoint. It is not complete original parity or
the requested final product. Full quest/story logic, equipment systems, pet depth
and other audit gaps precede the final UI/character/design production pass.
