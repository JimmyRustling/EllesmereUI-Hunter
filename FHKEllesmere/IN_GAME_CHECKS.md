# In-game checks (E3), consolidated 2026-10-05

This is the one current list. It replaces the scattered "E3 owed" lists in HANDOVER, the continuation audit and the changelog. Type `/reload` first; the companion has had a full restart since its last new file.

**Already confirmed by the player (2026-10-05):**
- the aspect bar works;
- the pet auras show;
- "everything else seems great so far".

**Fixed after the player's report:** switching on Aspect Element or Pet Auras left the options under it greyed out until another tab was opened. Companion toggles now refresh the page at once (see check 1).

Tick each one, or note what you saw.

## Options and feeding

| # | Do | Expect |
|---|---|---|
| 1 | Forever Companion > Unit Frames: turn **Aspect Element** off and on, then **Pet Auras** and **Pet Target** | The rows under each one grey out and light up at once, with no tab switch |
| 2 | Bags closed: cast **Feed Pet** | The bags open with one **Pet Food (n)** section: raw meat and food only. No Pinned, Recent or empty sections |
| 3 | Click a stack | The pet eats it, and the bags close again |
| 4 | Bags open on another tab (for example Trade Goods): cast Feed Pet, then right-click to cancel | Food only while targeting. Your tab and full layout come back, and the window regains its size |

## Combat cues

| # | Do | Expect |
|---|---|---|
| 5 | Turn on Hunter Cues > **Pet Idle**. Pull a mob with your pet on Passive (or recalled) | "Pet Idle - Send It In" after about 1.5 s. It clears when the pet attacks |
| 6 | Melee a mob until you dodge, or it parries | **Mongoose Bite** / **Counterattack** buttons glow in your Action Bars Proc Glow style while usable, also after paging bars |
| 7 | Queue **Raptor Strike** with the swing timer on | The melee row reads "MELEE - Raptor Strike" in Ellesmere's queue colour |
| 8 | Trap a mob, then hit it (Trap Broken on) | "Trap Broken". Killing a trapped mob shows nothing |

## Bars, labels and helpers

| # | Do | Expect |
|---|---|---|
| 9 | Cooldown Manager: put Aspect of the Hawk on a bar | Its icon reads **C-X** (your Ctrl+X macro branch), not X |
| 10 | Swim until the breath bar shows | A flat, Ellesmere-style bar in your Breath colour. Turning the skin off restores Blizzard's |
| 11 | Open a vendor with the bags closed, then close it | The bags close with it. Bags you had open stay open |
| 12 | Unit Frames > Show When Health Missing, plus Leveling Helpers > **Show When Mana Missing**: drink at full health | The player frame stays visible until your mana is full |
| 13 | With the Sniper Shot talent: proc it, then stand at 36-45 yd | The range cue counts you in range while the buff is up |
| 14 | Hunter Warnings > Preview Warnings with sounds set | Your chosen danger and warning sounds play |
| 15 | Aspects in **Bar** mode: enter combat in Cheetah (or Pack) | The Cheetah button pulses red; Hawk gets a steady gold edge. Switch to Hawk and both clear. Only learned aspects are on the bar |
| 16 | Standalone: at the character select AddOns list, turn everything off except EllesmereUI (and its modules), FHK - Ellesmere Companion and FHK Gear. Log in, open Forever Companion and the Gear tab, fight once, then turn the addons back on | No Lua errors (/console scriptErrors 1). Hunter features work; Forever Hunter Keys-only presets (keybinds, macros, chat, quest bar) stay off and offer their buttons |
| 17 | Aspects: **Aspect Visibility: Only When Wrong** (Icon). Out of combat; then fight with Hawk; with Cheetah; with no aspect | Hidden out of combat and with Hawk up. Cheetah shows with a red edge. No aspect shows the Hawk icon. Turn Monkey When Mob Is On You off for Ksuper's exact rule |
| 18 | Open the companion pages: Aspects, Pet Auras, Warnings, Action History, Unit Frames colours, Mob Rarity | Cogs, move arrows, eye previews and inline swatches look and behave like Ellesmere's own (popup, hex picker, greyed with a reason when the feature is off) |
| 19 | Unit Frames > Pet Combat Icon: move arrows and cog; Combat Icon Style cog | The pet icon moves and resizes; the white block resizes |
| 20 | XP Bar: XP Number Format: Ellesmere / Full / Rounded | 17.6K / 17,600 / 18K in the XP text |
| 21 | With Forever Hunter Keys disabled: Action Bars and General pages | No Hunter Keyboard Layout, Reviewed Hunter Cues or Combat Layout; Key Labels And Menu shows instead |

## Still owed from earlier lists (unchanged)

- **Gear:** disable AutoGear, run `/fhkgear hunter`, paste the report (FHKGear `AUDIT_STATUS_2026-10-04.md` §6).
- **Aspects:** `ASPECT_ACCEPTANCE_2026-10-04.md` steps 2-4 (travel and combat advice) and 7-11 (visibility, click advice, colours, warnings), if not already seen.
- **Pet:** `PET_ACCEPTANCE_2026-10-04.md` steps 3 (Mend Pet cleanse edge), 5 (XP readout) and 8-9 (Feed Pet Reminder).

Report anything that differs. A screenshot is enough.
