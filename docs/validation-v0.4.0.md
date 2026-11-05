# v0.4.0 checkpoint — 2026-11-04

- APK: `build/covenant_chronicles_v0.4.0.apk`, 48,814,867 bytes.
- Package: `com.covenant.chronicles`; actual manifest code 4 / name 0.4.0.
- APK SHA-256: `a5551b6b74d3e72a7f2b6709547ef5f548f0ce44107d021be857110a32122b56`.
- Signing certificate SHA-256 unchanged from v0.3:
  `0ef986d8b85c5d6b835f3ccfb9eccc5e636d5389bfc6705ae5745a41e9b40faa`.
- `python tools/run_checks.py`: 19 suites / 682 PASS checks, no script/runtime
  errors. Includes actual-world integration and durable multi-kill bounty payout.
- `python tools/check_transport.py`: ENET_TRANSPORT PASS.
- `python tools/check_world_transport.py`: ENET_WORLD_TRANSPORT PASS; two separate
  clients exchange movement, avatars, duel consent and authoritative PvP HP.
- `python tools/verify_apk.py`: metadata, certificate, runtime files, ZIP CRC and
  development-file exclusion PASS. Verification JSON is next to the APK.
- Actual GPU captures inspected: inventory, character, settings, pets, shared
  world and social controls. Review/test flags avoid real save/profile writes.
- `tailscale file cp --update-interval=0 ... s24-fe:` completed with exit 0.

Transfer is sender-side evidence. The phone was not connected through ADB;
installation, physical touch interaction and phone performance remain unverified.
The build is a functional checkpoint, not complete original-game parity. See
`original-feature-parity.md` for remaining systems and numerical fidelity gaps.
