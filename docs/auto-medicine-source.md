# Original automatic medicine and current adapter

Evidence: recovered `data/original/scripts/clt_script/item.lua`, `UseItemAuto`.
Four ordered lists are preserved in `AutoMedicine.PRIORITIES`:

| Resource | Original ordered item IDs |
|---|---|
| Player HP |30114,30842,30174,30193|
| Player MP |30162,30843,30189,30194|
| Summoned pet HP |30020,30021,30485,31130,31131,30729|
| Summoned pet MP |30754,30755,30756,30757,30758,30778|

The source checks HP above zero, a strictly lower resource percentage than the
configured threshold, positive inventory quantity and medicine cooldown <=0.
Pet branches address the summoned beast. Zero threshold disables the branch.
The present adapter additionally respects item locks and server authority.

Source text identifies pet potion tiers and HP/MP recipient semantics. Numeric
restoration quantities, rechargeable-bottle behavior, cooldown durations and
server grouping were not recovered. Current quantities and five-second category
cooldowns are explicit modern tuning. Dead pets require revival, not medicine.

Deadlines live in the authoritative profile and survive save/reconnect. Client
automation sends an ordinary use/pet_medicate intent without applying resources
or inventory optimistically; duplicate and forged-UID commands are rejected by
the same server paths as manual use. Pet MP has a playable effect: elemental
strikes spend mana, falling back to physical strikes when empty. Cost6 and
initial/growth MP values are provisional pending full pet-rule integration.
