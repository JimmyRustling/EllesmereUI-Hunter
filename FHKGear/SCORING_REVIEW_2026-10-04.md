# FHK Gear scoring review and next engine work

2026-10-04, Codex. E1 source/API review; E2 fixes in 0.2.1. No new in-game evidence.

## Player direction

- Compare complete main-hand/off-hand and two-handed setups, with abilities, talents and the levelling rotation taken into account. Item stat totals alone cannot establish a DPS improvement.
- Grey items remain eligible: better grey weapons can replace starter weapons and usable grey gear can fill empty slots.
- Auto-equip has a coloured rarity selector. Above the selected rarity, continue marking upgrades. Default: green or below. This limit applies to auto-equip; quest reward choice and loot rolls keep their separate toggles.
- Prefer MythicSim's own character exporter for external simulation. Show it only when MythicSim is loaded and its export command exists. Show the optional ForeverGear scoring source only when its addon and public API are available.

## What the current score means

Gear has a weighted item score and a rough proc expected-value calculation. It has **no rotation simulator**. A `+12` score is not `+12 DPS`, nor proof that an item improves the actual levelling rotation.

Built-in weights are adapted AutoGear tables plus authored heuristics. The tests establish that those formulas run as written; they do not validate the weights against combat. Custom phase storage exists, but the built-in defaults do not yet contain independently derived levelling and endgame models.

## Findings from the live code

| Finding | Consequence | State |
|---|---|---|
| No weapon min/max damage or speed in the item model | Two equal-DPS weapons look equal even when weapon-based attacks would differ | Open |
| The same item score prices either hand | No distinction between main-hand ability damage and off-hand autos, proc opportunities or off-hand abilities | Open |
| Two-hander compared with the sum of both item scores | Accounts for displaced stats, but not the change in attack tables, abilities and resources | Open |
| An off hand cannot be evaluated with a compatible bag main hand while wearing a two-hander | Misses upgrades that require a complete pair; equipping the first piece alone may be a downgrade | Open |
| Spec weapon styles forbid alternatives outright | Fury's two-hander alternatives can be excluded before any comparison; `dagger and any` is not actually enforced by the slot function | Open: separate player locks from model constraints |
| Fixed percent weights at every level and gear state | Hit caps, target level, dual-wield miss and current crit do not change marginal value | Open |
| Structured `*_RATING_*` keys are folded into percent stats | Ratings can be treated as whole percentage points; separate units and verify real payloads before conversion | Open, E3 required |
| Pawn `CritRating`/`HitRating` import/export shares those percent weight names | Portable format does not establish unit compatibility with another tool | Open |
| School weights are fixed spec guesses | A school can receive value before its spell is learned; rank coefficients, cast frequency and kill duration are absent | Open |
| Hunter Intellect has no Careful Aim adaptation | Learned talents do not alter stat conversion or priorities | Open |
| One proc/minute for almost every chance-on-hit effect | Not a verified per-item rate; weapon speed, eligible hand, trigger, internal cooldown and fight duration can change the result | Open |
| Use effects valued at 80% of cooldown uptime | Short pulls, one activation, cooldown between pulls, overlap and resource waste are absent | Open |
| Melee proc uptime is reduced by a ratio of DPS weights | A score-weight ratio is not measured melee participation | Open |
| Creature-specific AP text can match ordinary AP | A situational bonus was priced as always active | Fixed: retained as unscored text until scenario support exists |
| Structured block value mapped to block chance | Flat damage blocked was priced as percent block | Fixed: maps to `BlockValue` |
| Set thresholds, unique-equipped groups and weapon skill absent | Can lose a set bonus or misjudge a weapon/category change | Open |
| Levelling success measured by an additive score | Mana/drinking, survival, healing, pet threat and downtime are not evaluated as outcomes | Open |

## Source checks

The player's [ForeverDB spell directory](https://foreverdb.net/spells) is useful for rank and ability facts. Individual spell pages distinguish Forever from Classic. Examples that matter to the design:

- [Aimed Shot](https://foreverdb.net/spell/19434): a trainer ability from level 20, weapon damage plus a rank bonus, sharing cooldown with Multi-Shot. A model cannot award its weapon benefits before the character learns it.
- [Multi-Shot](https://foreverdb.net/spell/2643): shares that cooldown. Do not count independent casts of both on every cooldown.
- [Backstab](https://foreverdb.net/spell/53): requires a main-hand dagger and position behind the target. A solo pull cannot assume unrestricted Backstab uptime.
- [Whirlwind](https://foreverdb.net/spell/1680): the tooltip refers to both melee weapons. Its actual off-hand behaviour and talent interaction need client/server confirmation, not a universal half-value off hand.
- [Frostbolt](https://foreverdb.net/spell/116) and [Shadow Bolt](https://foreverdb.net/spell/686): rank coefficients change. One school percentage per spec cannot reproduce those changes.
- [Arcane Shot](https://foreverdb.net/spell/3044): the Forever coefficient is displayed as a dash. That is missing information, not proof of either zero scaling or the old Classic coefficient.

[ForeverDB's simulator](https://foreverdb.net/sim) documents which values come from client data and which combat rules are assumptions. It reports ratings separately from percentages. Its documented scope and assumptions are useful references; they do not prove the game behaves identically.

[MythicSim's Forever simulator](https://mythicsim.com/wow-forever/sim) supports character export, gear combinations and stat weights. Its documented default is a raid-boss encounter with raid buffs. Levelling comparisons need suitable target level, fight length, buffs and rotation. Healing is outside its documented supported simulation scope.

Integration: the official MythicSim 0.3.0 ZIP was inspected under its MIT licence, in `.dev/mythicsim-reference/`, without installation. Folder `MythicSim`, handler `SlashCmdList.MYTHICSIM`, command `export`. SHA256: `4DA1FB922A1F6A3FF00DF0D3910D922D2E5F1FFA25E9FE6D6FA6CF3168EFE51D`.

ForeverGear is a separate approximate score provider, not a simulator. Use its public API and callbacks from its README; do not read or copy its unlicensed implementation. MythicSim's character JSON and a Pawn weight string are distinct formats; keep them distinct in the UI.

## Model to build

1. **Character context:** class, level, actually learned spell ranks, talents, weapon proficiencies/skill, form/stance, current stats and full equipped setup. Refresh on relevant events. Treat unreadable/secret values as unknown; never invent a rank or conversion.
2. **Ability facts:** spell ID/rank, minimum level, school, weapon slot(s), weapon damage multiplier, AP/SP coefficients, cast/GCD/cooldown group, cost, duration/ticks, required weapon/form/position, talent modifiers and proc triggers. Pin source/build and mark each field as confirmed or assumed. Missing coefficients stay unknown.
3. **Levelling scenarios:** short solo pulls, longer elite fights, multiple targets and group roles. Describe movement/weaving, pet participation and mana recovery. Learn a normal spell mix from successful casts only when enabled and public events work; allow manual scenarios when observation is unavailable. The pending combat-log probe still matters.
4. **Complete setup comparison:** generate legal 2H and ordered MH/OH combinations from worn items plus candidates. Include displaced stats, off-hand rules, usable abilities, enchants, ammo/quiver effects, unique categories, set thresholds and locks. Evaluate both placements of an unrestricted one-hander. Do not multiply off-hand global stats by an off-hand damage penalty.
5. **Derived weights:** evaluate the same scenario with and without a small stat increment. School spell damage gains come from each affected learned spell's coefficient and actual cast/tick opportunities. Hit/crit/haste are state-dependent. Normalize for display only after calculating the change.
6. **Comparison explanations:** show scenario, affected abilities, weapon setup, confidence and assumptions. Separate estimated damage, survival and resource recovery. Unknown effects must be visible in the explanation and constrain automation when material.
7. **External checks:** use MythicSim Best Gear for complete combinations and retain its engine build/scenario with imported results. Any weight import needs explicit stat units, character level, spec/talents and scenario. Stale results must not silently control auto-equip after level, spell or talent changes.

## Class coverage required

| Class | Minimum model distinctions |
|---|---|
| Hunter | Ranged shots vs main-hand melee vs any verified off-hand attacks; learned Aimed/Multi shared cooldown; ammo, quiver, pet, weaving and talent conversions |
| Warrior | Ordered hands, 2H alternatives, rage generation, swing replacements, stance/shield requirements and off-hand abilities |
| Rogue | Main-hand damage and dagger requirements; solo positioning; off-hand attacks, poisons, proc rates and energy/combo points |
| Shaman | Spell/melee mixture, actual dual-wield availability, weapon imbues, eligible hand and talent-dependent triggers |
| Paladin | Weapon-based strikes, seals, swing timing, shield role and mana; distinguish raw weapon damage from school scaling |
| Druid | Caster, cat, bear and healer roles; establish form damage and weapon interactions before valuing humanoid weapon DPS |
| Mage | Learned spell ranks, school coefficients, casting/crit talents, movement and mana recovery |
| Warlock | Direct spells vs DoTs, kill duration, school coefficients, pet contribution and health/mana conversion |
| Priest | Damage vs healing role, learned rank/school mix, wand usage, mana and healing requirements |

## Acceptance cases before calling it an accurate levelling model

- Better grey versus starter grey; all rarity caps affect auto-equip only.
- Same weapon DPS with different speed/damage; changed abilities reverse the preference when appropriate.
- Two one-handers versus a two-hander in both directions, including a pair that improves only when complete.
- Main-hand and off-hand placements differ only where mechanics require it; global item stats remain global.
- Spell absent, learned, higher rank and talent changed; unknown API result never means "learned".
- Explicit percent Equip lines versus structured rating fields, including shared/specific keys and no double counting.
- Short fight truncates a DoT; shared cooldown prevents double counting; resource exhaustion changes the spell mix.
- Set threshold lost/gained; unique group conflict; conditional effect inactive/active; item proc rate known/unknown.
- Reference comparison per class/scenario plus E3 checks for available in-game mechanics. E2 arithmetic alone cannot validate combat accuracy.

The bag-slot arrows, loot-roll borders, character-sheet marks, installer and profile export remain separate unfinished features. Rarity-limited items currently retain the existing tooltip and quest-reward marks; no bag-icon support is claimed in 0.2.1.
