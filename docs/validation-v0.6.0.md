# v0.6.0 functional checkpoint — 2026-11-05

- APK: `build/covenant_chronicles_v0.6.0.apk`, 49,540,642 bytes.
- Actual package `com.covenant.chronicles`, version code6 / name0.6.0.
- SHA256: `601ad2e562749987b19a9f5305e332b29e2081ab7088aaa11237f2bd1e800419`.
- Existing signing identity preserved; compiled quest/medicine runtime and both
  quest JSON archives present; ZIP CRC and development-asset exclusion passed.
- `python tools/run_checks.py`: **26 suites / 894 PASS checks**. The exact suite
  report is `build/checks-latest.json`. Two-process ENet world transport also PASS.
- GPU screenshots inspected: cooking dialogue, four medicine options, pet MP,
  and actual forest gathering. Tree crowns now obstruct the orbit camera on a
  separate layer while trunks obstruct characters; six gathering destinations
  pass A* reachability checks.

Runtime additions: source report items and title rewards, class-filtered gear
rewards, atomic quest inventory exchange, original Gourmand cooking chain,
spider ingredients and wild-vegetable gathering, schema6/pre-v6 backups, old
report migration credits, all four original medicine priority lists, persistent
shared manual/auto cooldowns, pet MP and mana-limited elemental strikes.

Archive recovery: all712 task footers decoded.709 reward byte lengths agree
with complete structure; three original zero-length fields are retained as
exceptions. Currency/experience field order is an inference from the purchase
tutorial and level progression, documented in `quest_rules.json`; quantities,
item/title IDs and next-task links are preserved. **Ten quests are playable;
the archive count is not a claim that712 quests are implemented.**

Medicine quantities, five-second category cooldowns and pet spell cost remain
modern tuning. The original Lua proves ordered selection, strict threshold,
alive/summoned checks and cooldown checks but omits server formulas. Gathering
placement/yield/regrowth are adaptations to the current3D zone.

Delivery is tracked separately in the APK's `.delivery.json`; at initial check
S24 FE was offline. No ADB installation or physical-device gameplay is claimed.
This remains an intermediate functional checkpoint, preceding the requested
complete parity and final UI/character/design production pass.
