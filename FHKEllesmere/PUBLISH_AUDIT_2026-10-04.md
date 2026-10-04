# Publish audit: features, not personal setup; every visual customisable (2026-10-04, Claude)

Player direction:
- "It's the features we're trying to ship, not our layout/macros/keybinds."
- "Anything that uses a colour, shape, icon or whatever needs a toggle and the colour, correctly categorised in the Ellesmere UI."

Evidence: E1 (static) and E2 (mocked). No E3.

## 1. Personal setup no longer ships as behaviour

**Rule:** presets that change other parts of Ellesmere or WoW apply by themselves only alongside **ForeverHunterKeys**. That is the owner's keybind addon, which is not published. Everyone else gets each preset from its own button, or later from a shared "Forever Hunter - Default" Ellesmere profile.

**Check:** `_G.ForeverHunterKeysNS ~= nil`, the documented `NS.EllesmerePersonalSetup()` in `Bootstrap.lua`. Call sites use the global directly, so the rule holds even if `Bootstrap.lua` hasn't run.

| Preset (file) | What it did on first login | Now |
|---|---|---|
| Quest Bar (`QuestBar.lua`) | Created macros; bound U / Shift-U / I / Naga 12 to RestedXP's quest bar | Default off without FHK; the toggle shows the real state |
| Hunter Keyboard Layout (`ActionBarLayout.lua`) | Rearranged action bars to the FHK keymap | Already FHK-gated (unchanged) |
| Idle menu/bag bar (`ActionBarLayout.lua`) | Set Chrome visibility to mouseover | Gated |
| Hunter Polish (`HunterPolish.lua`) | Action bar look plus the `countdownForCooldowns` CVar | Already FHK-gated |
| Reviewed profile (`FinalPolish.lua`) | Owner's warning, pet-mood and cast-colour choices | Gated (re-sync of an applied profile unchanged) |
| Modern chrome (`ModernChrome.lua`) | Character sheet style, XP bar size, texture and position, all-game-text font, combat text font | Gated |
| Chat (`Companion.lua`) | Idle fade, hide in combat, quiet chat on | Gated; Quiet Chat defaults off without FHK |
| Nameplate range fade (`Companion.lua`) | Ellesmere out-of-range mode Auto at 50 % | Gated |
| Swing timer setup (`SwingIntegration.lua`) | Enabled and sized Ellesmere's swing timer, combined layout | Gated; the refinements still work on any enabled swing timer |

**Not bundled at all:** ForeverHunterKeys, which holds the keymap, macros, RestedXP automation, the personal `ScarRestore.lua` snapshot and Ksuper route data marked local only.

**Bug found while testing:** `/fhkeui chat restore` with nothing saved used to *set* a 10 s / 100 % fade. It now says there is nothing to restore.

**Tests:** each gated preset is checked both ways, published install (unchanged) and owner install (applied).

## 2. Every visual has a toggle and its colour/shape/size, in its own section

Colour swatches use Ellesmere's native `colorpicker` row (hex input, favourites). Colours are shared tokens changed in place, so every cached reference follows. Applying also rebuilds cached health colour curves, the range palette and the swing styling. Each section has its own **Reset**; Quality of Life > Hunter Colors > Reset Hunter Colors resets everything.

| Element | Section (page > section) | Toggle | Customisation |
|---|---|---|---|
| Range HUD / block, plate accent, attack squares | Resource Bars > Range Indicator, Auto Attack Indicators; Nameplates > Range Indicator Style | yes | Orientation, size, colour mode (custom swatch), position (Unlock), labels |
| Shooting / Melee / Cast / Retry / Danger / Caution identity | Quality of Life > Hunter Colors | n/a | Swatch each; bar fills follow at 73 % |
| Swing rows | Resource Bars > Swing Timer > Hunter Timing | Active Row Only, Latency Zone, Spark Colors, Clip Marker | Ranged / main / off-hand spark swatches; fills from Hunter Colors; Raptor queue uses Ellesmere's own queue colour |
| Cursor swing rings | Quality of Life > Cursor | yes | Mode, radius, readiness; colours from Hunter Colors |
| Aspect element | Unit Frames > Aspects | yes | Display (Icon / Bar / Current Only), size, spacing, orientation, dim, labels, eight edge swatches |
| Pet happiness icon / strip / bar | Unit Frames > Colour and Text Refinements | Icon, Hide When Happy, strip, bar colour | Square / Paw style, strip side, thickness, length, alignment, gap, opacity; **Happy / Content / Unhappy swatches (new)** |
| Health warning fills | Unit Frames > Colour and Text Refinements | Health Bar Colors | **Health 50 % / 25 % / Critical swatches (new)** |
| Pet auras, target, XP bar | Unit Frames > Pet Auras and Target | yes, each | Aura count; TP badge uses Caution and the Passive letter uses Danger |
| Pet Food row and button | Unit Frames > Pet Food | yes | Row / Row + Grey Out / Off; button size; Food Choice; Ellesmere accent |
| Elite / rare level colours, badge, quest count | Nameplates > Mob Rarity | yes, each | Badge size and position, level format; **Elite / Rare / Quest Count swatches (new)** |
| On-you / on-pet nameplate edges | Nameplates > Hunter Range and Corpses | yes, each | **On You / On Pet Edge swatches (new)** |
| Cue fades, damage trail | Nameplates > Hunter Range and Corpses | yes | Out-of-range opacity, trail duration |
| Warning lane | Quality of Life > Hunter Warnings | per warning | Position, size (follows Ellesmere's durability text), sounds; **Act-Now / Caution swatches (new)** |
| Hunter cues (Stop Attack, Feign, Growl, tracking, pet idle, trap, mark, auras, procs) | Quality of Life > Hunter Cues | per cue | Lane colours above; Mongoose / Counterattack glow uses Ellesmere's Proc Glow style and colour |
| Breath / fatigue / Feign Death bars | Quality of Life > Leveling Helpers | Skin toggle | **Breath / Fatigue / Feign swatches (new)**; position in Blizzard Edit Mode |
| Loot left behind, zone levels, range fade, gathering, mana reveal, NPC bag closing | Quality of Life > Leveling Helpers | yes, each | Rarity threshold; out-of-range opacity |
| Cooldown key labels | Cooldown Manager > Cooldown Key Labels | Macro labels | Manual labels per spell (`/fhkcdm`); styling stays Ellesmere's |
| XP bar refinements, key press flash, action history | Action Bars sections | yes, each | XP swatch, flash and history controls |

**Known follow-ups (not blocking):**
- The warning lane font size follows Ellesmere's durability warning by design.
- Pet aura borders use Blizzard's debuff-type colours.
- The zone level label uses the game's quest-difficulty colour.
- Loot-left-behind text uses the Caution colour.

## 3. Checks

- Validate.js: 51 files PASS. This includes static rules that every options builder sits on a page and every settings table is in `PROFILE_KEYS`.
- Integration: 2893 + 161 + 147 + 26 + 55 + 50 + 40 mocked checks PASS, including both-way preset tests and in-place colour tokens.
- Page-height assertions were updated on purpose: Mob Rarity gained two colour rows (+64).
