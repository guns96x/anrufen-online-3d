# Balance model

The Anrufen client archives hold only a few combat constants; base stats, growth,
monster numbers and the damage formula lived on the original server, which is not
available. This file records what comes from the original and what is our model.

## From the original (`data/balance/script_5003.lua`, `script_5005.lua`)

| Constant | Value | Used in |
|---|---|---|
| `FATAL_RATE` | critical hit ×2 | `CombatFormulas.calculate_damage` |
| `HIT_MODIFY_VALUE` | ±3 % hit per level of difference, capped at 10 levels (±30 %) | `Balance.level_hit_bonus` |
| `MAGIC_SHIELD_RESIST_PER` | magic shield absorbs 100 % | status effects |
| `SKILL_CONST_*` | per-rank skill numbers, cooldowns, caps | `SkillRules` |
| attribute enum (`attribute_const.lua`) | strength, agility, constitution, intellect, resistances | naming only |

## Our model

**Hit chance** = accuracy − evasion + level bonus, clamped to 20–100 %.

**Damage** = attack × skill multiplier × (1 − mitigation) × 0.95–1.05, then ×2 on a crit.
Mitigation = defense / (defense + 40 + 10 × attacker level). Armour therefore removes a
share of the hit instead of a flat amount, so it neither makes low-level enemies immune
nor becomes worthless at higher levels.

**Monsters** (`shared/combat/balance.gd`), level L and role multipliers:

| | formula |
|---|---|
| HP | 45 × 1.2^(L−1) |
| Attack | 8 + 3 L |
| Defense | 3 + 1.8 L |
| Experience | 20 + 14 L^1.3 |

| Role | HP | Attack | Defense | Evasion | Exp | Who |
|---|---|---|---|---|---|---|
| beast | 1.00 | 1.00 | 1.00 | 4 % | 1.00 | wild boar |
| swarm | 0.75 | 0.90 | 0.70 | 10 % | 0.85 | forest spider |
| hunter | 0.85 | 1.15 | 0.80 | 12 % | 1.00 | scavenger jackal |
| bandit | 1.00 | 1.10 | 1.10 | 8 % | 1.15 | Viper Gang rogue |
| brute | 1.45 | 1.25 | 1.40 | 3 % | 1.40 | Viper Gang axe brute |

**Player** growth stays as in `CharacterSystem.rebuild_stats` (warrior 100 HP / 22 attack at
level 1, +15 HP, +3 attack, +2 defense per level) and experience to the next level is
100 × 1.35^(L−1). Reaching level 8 takes about 2 050 experience: the 30 witness kills at
levels 1–4 give roughly 1 800 and the opening quests the rest.

Prices, loot tables and the later zones still use provisional values.
