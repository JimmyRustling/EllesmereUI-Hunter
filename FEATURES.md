# Forever Companion and FHK Gear: feature list

Two plugins for [EllesmereUI](https://github.com/EllesmereGaming/EllesmereUI) on WoW Forever. They load next to EllesmereUI, never edit its files, and put their settings inside Ellesmere's own options:
- **Forever Companion** (`FHKEllesmere`): Hunter, class and Forever refinements across the suite. It has its own Forever Companion entry in the options sidebar. The first page is named after your class and gathers its features; the others match Ellesmere's modules. Options follow the logged-in class.
- **FHK Gear** (`FHKGear`): an AutoGear replacement, on its own Gear entry.

**How they behave:**
- Settings use Ellesmere's own controls: toggles, dropdowns, sliders, cogs, move arrows, preview eyes and hex color swatches. Options under a switch grey out and explain why until it is on. Each section has a Reset.
- Settings are saved per Ellesmere profile and follow profile switches.
- Nothing changes your keybinds, macros or game settings by itself.
- Most features are off until you turn them on.
- Requires EllesmereUI. Tested against EllesmereUI 9.3.5 and 9.3.8; no other addons needed.

Status: verified by mocked tests and a standalone load test. In-game verification is in progress.

---

## Forever Companion

### Hunter range and the dead zone

- **Range Indicator** (Resource Bars):
  - A bar, block or weapon icon whose color says where you stand: shooting range, approaching the dead zone, dead zone, melee, too far, or out of range.
  - Optional range text.
  - Style, length, size, thickness, opacity, font size and color mode (theme or custom swatch).
  - Moves in Ellesmere Unlock Mode.
- **Facing and line-of-sight cues:**
  - FACE TARGET, NO LINE OF SIGHT or STOP MOVING on the range indicator after a confirmed client error.
  - Each clears on a successful cast, a target change or a short timeout.
- **Auto Attack Indicators:**
  - Squares or icons for Auto Shot / Shoot / Throw and melee, lit while each is active.
  - Labels; class or combat artwork; orientation (including either side of the range block).
  - Gap, size and opacity; Unlock Mode position.
- **Unit Frame Range Bar** on the target, focus and target-of-target frames: position, placement and thickness.
- **Nameplate range cues** (Nameplates > Hunter Range and Corpses):
  - Presets: Minimal, Weaving, Detailed or Custom.
  - Range text and yard units; range-colored names; a tinted target glow; a non-target range mark.
  - Range Indicator Style: stripe position, thickness, gap, opacity, style and color; range text color and size; Range / Range State values for any native text slot.
- **Range-aware nameplate opacity:**
  - Opacity Priority: target, then focus, then mouseover, then in-range idle, then out-of-range idle, each with its own percentage.
  - The Hunter dead zone is recognised by Ellesmere's own out-of-range fade.
- **Sniper Shot:** the range cue counts the talent's +10 yards while its buff is up.

### Swing timer and weaving (Resource Bars > Swing Timer)

- **Hunter timing on Ellesmere's swing timer:**
  - Show Melee Ready; Auto Shot cast and retry states; Active Row Only.
  - An Auto Shot latency zone and weapon spark colors.
  - An **Auto Shot clip marker** while Aimed Shot or Multi-Shot casts.
- **Raptor Strike queue:** the melee row reads MELEE - Raptor Strike in Ellesmere's queue color while it is queued.
- **Hunter Timing Compatibility:** plant time, aim window and melee lockout estimates, and Restart Bow After Melee. Measured events always win.
- **Cursor swing rings** (Quality of Life > Cursor):
  - Auto Shot and melee readiness as rings around the cursor.
  - Four modes; radius, ring texture and opacity.
  - Readiness colors; keep clear of the GCD and cast rings.
  - Attack pulses with an icon size; combat only.

### Aspects (Unit Frames > Aspects)

- **Aspect Element:**
  - Your current aspect as an icon, a bar of every **learned** aspect, or Current Only (hover for the bar).
  - Size, spacing, orientation and dimming in the cog.
  - Key labels and the aspect name.
- **Advice:**
  - Suggests Hawk for shooting, Monkey when a mob is on you (optional), Beast for melee style, and Cheetah while travelling out of combat.
  - Melee Style: Auto, Ranged, Ranged + Weave or Melee.
  - Click Advice Out of Combat casts the suggestion.
- **Cheetah / Pack in combat:** the wrong aspect pulses red, and the one to switch to gets a gold edge, on the icon and on the bar.
- **Visibility:**
  - Always, In Combat, Mouseover, or **Only When Wrong**: hidden out of combat and while the right aspect is up; shows Cheetah when it is wrong in combat, or Hawk when you have no aspect.
- **Colors:** advice and danger edges, plus a color per aspect. Preview eye; Unlock Mode position.

### Pet

- **Pet Auras** under the pet frame: buffs and debuffs, harmful first with red borders, stacks and a `+` when they overflow. Size, slots and offset.
- **Mend Pet Cleanse Edge:** gold on a debuff that Improved Mend Pet can remove.
- **Pet Target:** the mob your pet is attacking, its name and health, with width, height and gap.
- **Pet XP Bar:**
  - Pet XP with height and offset; the loyalty name and training points in its tooltip.
  - A gold TP badge for unspent training points.
  - A stance letter (Passive in red), and a tooltip listing the pet's abilities with autocast state.
- **Pet happiness:**
  - A square or paw icon in your happy, content and unhappy colors.
  - Hide When Happy; a happiness strip (position, thickness, length, alignment, gap, opacity); optional happiness bar color.
- **Pet Combat Icon:** beside the pet frame while the pet fights, with size and X/Y position.
- **Pet Food** (Unit Frames > Pet Food):
  - **Food Only:** casting Feed Pet opens your bags showing only what your pet eats, raw meat included, in one Pet Food section. Click to feed. Your normal layout returns afterwards, and bags it opened close again.
  - Or a Pet Food Row beside your bags, or the row plus greyed-out bags.
  - **Pet Food Button:** one click feeds your chosen food; right click lists every food your pet eats. The border shows happiness, and a sweep shows the feeding timer. Size and Unlock Mode position.
  - Food Choice: Closest To Pet Level, or Cheapest that still pleases the pet.
  - **Auto-Buy Pet Food:** tops up to your amount at a vendor, at most two stacks per visit and a tenth of your money, and prints every purchase.

### Warnings (a warning lane at the top of the screen)

- **Ammo:** low, critical, empty slot, wrong ammo for your weapon. Thresholds in the cog.
- **Pet:**
  - Mend Pet at a health percentage; pet too far to Mend; missing or dead pet in combat.
  - Feed Pet reminder (content and unhappy).
  - No or low pet food.
- **Combat:**
  - Cheetah / Pack in combat.
  - Frenzy: Tranquilizing Shot.
  - Unspent talent points.
- **Error line:**
  - **Top Alert Lane:** the red game error line moves to the top of the screen with the warnings beneath it, with a position and a preview eye.
  - **Hide Spam Errors** (not ready, out of range, not enough mana) and **Hide Errors A Warning Shows**.
- **Combat Warnings Above Character:** act-now warnings move above you in combat; height adjustable.
- **Sounds:** separate act-now and other warning sounds.
- **Colors:** act-now and caution swatches.

### Hunter cues (Warnings > Hunter Cues), each on its own switch

- **Stop Attack** while your own Freezing Trap, Scatter Shot, Scare Beast or Wyvern Sting holds the target.
- **Feign Death:** Resisted, and a countdown before Forever's 6-minute limit (start time in the cog).
- **Growl:** a reminder in groups, and optionally when it is off while solo.
- **Tracking:** with Improved Tracking, names the Track spell for your target's type.
- **Pet Idle:** in combat, your pet has had no target for 1.5 seconds.
- **Trap Broken:** your Freezing Trap came off early.
- **Mongoose Bite / Counterattack Glow:** their buttons glow, in your Action Bars Proc Glow style, while usable.
- **Hunter's Mark** missing on elites, rare elites and bosses.
- **Trueshot Aura** missing (with the talent).
- **Rapid Killing** proc shown.
- **Beast tooltip:** family, attack speed (fast in gold) and whether the beast's level allows taming.

### Leveling helpers (Warnings > Leveling Helpers)

- **Breath, fatigue and Feign Death bars** skinned in the Ellesmere style, a color each.
- **Loot Left Behind:** when a loot window closes with items in it, lists them in chat, warns, and says if your bags are full. Rarity threshold.
- **Zone Levels On Map:** each zone's level range on the world map, colored for your level.
- **Target Range Fade:** the target frame fades while the target is out of range. Opacity in the cog.
- **Close Bags Opened By NPCs** when a vendor, mailbox, auction house or trade window closes.
- **Show When Mana Missing:** Ellesmere's Show When Health Missing also shows the player frame while you drink.
- **Gathering Tracking Reminder:** names Find Herbs or Find Minerals when no tracking is on.

### Unit frames (Unit Frames > Colour and Text Refinements)

- **Health and resource colors:**
  - Health fills warn at 50%, 25% and critical, each with its own swatch.
  - Resource bar and text colors.
  - Readable colored fills and a dark mode health line.
- **Text:**
  - Player resource text format; aligned power and health text.
  - **Health and resource text slots** (Resource Bars): left, center and right content on both bars, with X/Y cogs.
- **Combat and status icons:**
  - Status icons on the frame edge.
  - White block or Ellesmere combat icons (block size in the cog).
  - A gold target-of-target bar when the target is attacking you (green when it is attacking your pet).
- **Combat feedback:**
  - **Flee Mark:** a mark at 20% on the target bar where an NPC may run; learns each creature that runs.
  - **Loot Icon Replaces 0%** on lootable or skinnable corpses.
  - **Damage Flash and Instant Health Feedback:** lost health drains in red while the real fill updates at once.

### Nameplates

- **Aggro edges:** gold when an enemy is attacking you, green when it is attacking your pet, each with a color.
- **Icons:** loot icons, skinning icons (ready or not), the object interact icon, soft-target sword icons, extra combat icons.
- **Smooth Cue Fades** for guide, rarity and raid markers, with a marker opacity.
- **Damage Flash** on nameplates, with duration, opacity and color.
- **Mob Rarity:**
  - Elite and rare level markers and gold / silver level colors.
  - Native elite / rare badges with size and position; a skull for skull-ranked mobs.
  - The quest count beside the bar corner, with its color.
  - A level format such as 13E, 13R, 13RE.

### Action bars

- **XP Bar Refinements:**
  - Completed quest XP on the bar. It stands down while Ellesmere's own Quest XP Overlay is on.
  - Smooth fill, gain glow, 10% ticks, and a session XP tooltip (XP per hour, time to level).
  - **XP Number Format:** Ellesmere (17.6K), Full (17,600) or Rounded (18K).
  - Quest XP color.
- **Key Press and Action History:**
  - Flash Every Action Press (opacity, duration).
  - **Recent Action History:**
    - a movable strip of what you pressed, with keys;
    - count, size, spacing, zoom, direction, idle hide and opacities;
    - key presses or successful casts, fold repeats, mouse clicks;
    - Naga button labels; a preview eye.
- **Key Labels And Menu:**
  - Keyboard-First Key Labels: the keyboard key wins over a Naga output (SG, not SF12); Ins and Del shortened.
  - Menu And Bags Visibility: on hover, or in combat or on hover.

### Cooldown Manager

- **Manual key labels** on cooldown icons: `/fhkcdm label <spell> = <text>`. Bindings never change.

### Look and feel (General)

- **Forever Theme Presets:** Colored, Dark and Afterglow for the whole suite, with a Restore.
  - Strong outlines, readable colored fills, pixel icon edges, a health / power separator.
- **Forever Motion:**
  - Reduce Companion Motion: one switch that steadies every companion animation.
  - Show Advanced Companion Options.
  - Preview Scenario: fixed states for comparing styles, such as in range, dead zone, melee, warnings and history.
- **Forever Chat:** Hide Chat In Combat; Show Chat Only When Typing Or Hovered (whispers still show).
- **Hunter Colors:**
  - Shooting, melee, cast, retry, danger and caution: the shared colors behind every cue.
  - Every other cue color sits in its own section with a Reset.
- **Forever Class HUD** (Resource Bars):
  - Native power, Rogue / Cat combo points, shifted Druid mana and Shaman totems for this character.
  - A Warlock shard counter.
  - Shortcuts to the matching Ellesmere tools.

### Class kits (every class; each feature off until you turn it on)

- **Class page:** named after your class, with each class feature's own row and a link to all of its settings, plus shared Vendor Restock, Training and Alerts groups.
- **Class Buffs** (Unit Frames > Class Buffs): click-to-cast buttons for:
  - paladin auras, seals and blessings (preferred blessing; NO SEAL only while you auto-attack, with a short grace after Judgement);
  - priest Inner Fire, Fortitude and Shadowform (out of combat only);
  - mage armors and Intellect;
  - warlock armor;
  - shaman shields with charges;
  - druid Mark, Thorns and Omen (caster form);
  - warrior Battle Shout.

  Every rank is matched by name. The current buff is highlighted. Missing and expiring warnings are quiet while dead, mounted, on a taxi or resting (your choice).
- **Weapon Enchants** (Unit Frames > Weapon Enchants): a pod per weapon with the poison, imbue, stone or oil, its timer, charges and bag count.
  - Click to re-apply out of combat.
  - Rogues choose a poison per hand; shamans a preferred imbue.
  - One warning line, and "none in bags" only at a vendor or while resting.
- **Class Supplies** (Warnings > Class Supplies): counts for shards, healthstones, soulstones, Ankh, powders, conjured water, food and gems, runes, symbols, candles and seeds.
  - Click to create stones and conjures.
  - Soul bag full, and a Soulstone-on-someone timer.
  - Smart warnings: a bought reagent is named only at a vendor that sells it ("Buy Flash Powder here"). Each reagent has its own Warn Below.
- **Behind Indicator** (Resource Bars, rogue and druid): two colors, behind or in front of your target.
  - The evidence is the target targeting you, the "must be behind" error, and a Backstab or Shred landing.
  - A stunned target reads unknown, not in front.
- **Energy Tick** (Resource Bars, rogue and cat druid): a spark for the next energy tick.
- **Class Cues** (Warnings > Class Cues):
  - Stealth or Prowl First, Must Be Behind, Leave Form, and the warrior stance you need.
  - A stealth opener.
  - Reactive glows: Overpower, Revenge, Execute, Victory Rush, Riposte.
  - A stance hint, never telling a grouped tank to leave Defensive.
  - Slice and Dice missing or expiring.
- **New Spells** (Warnings > New Spells): on level-up, at login and on a Poisons skill-up, "New: Instant Poison III" or "N new spells at your trainer".
  - Mage teleports count at the portal trainer.
  - An ignore list; at a trainer, how many you can afford.
  - Data from Forever's own client tables.
- **Vendor Restock** (Warnings > Vendor Restock), with one budget per visit (repair bill first, Max Spend Per Visit) and one chat line. Shift skips a visit. Categories:
  - **Ammo:** Fill Quiver by default; buys only 200 just before better ammo unlocks.
  - **Food**, and **Drink** for mana users. Never for a mage who conjures unless you choose Buy Anyway; water from a party mage counts.
  - **Class Reagents** up to Keep. Thieves' Tools is bought once.
  - **Pet Food:** never eats your own food; works with the pet dismissed.
- **Pets** (hunters and warlocks):
  - Pet On Passive.
  - Missing / Dead Pet out of combat; warlocks see Summon Demon, quiet after Demonic Sacrifice.
  - Health Funnel reminder, pet level notice, Pet Idle.
- **Training** (Warnings > Training):
  - **Auto Train:** trains at your class trainer, upgrades first. Weapon masters and new professions are left to you.
  - **Talent Planner** (`/fhktalentplan`): plan your talents by level and learn them in order.

### Commands

- `/fhkeui`: companion commands.
- `/fhkpreview <scenario>`: show a preview state.
- `/fhkcdm`: cooldown labels.
- `/fhkxp`: XP diagnostics.
- `/fhkopacity`: nameplate opacity layers under the mouse.
- `/fhkperf`: the companion's CPU use, from the game's profiler.
- Diagnostics: `/fhkfacing`, `/fhkprobe`, `/fhktalents`, `/fhktiming`, `/fhkswingdebug`, `/fhktheme`, `/fhkclasshud`.

---

## FHK Gear (AutoGear replacement)

### Automation (each on its own switch)

- **Auto-Equip Upgrades** out of combat, up to a rarity you choose (Grey to Legendary). Higher rarities are still marked.
  - A slot you change by hand is left as you set it until your next level.
  - An item that fails twice, or whose bind prompt you decline, is left alone for the session.
- **Auto-Pick Quest Rewards:** the best upgrade, or the highest vendor value when nothing is one. Choices with non-gear items stay yours.
- **Auto-Roll on Loot:** Need on upgrades and Greed on the rest, each policy separate, with an optional roll-prompt confirm. Need follows the auto-equip rules; works in combat.
  - Roll etiquette: Minimum Need Gain, and Need Only My Armor Type and Main Stat.
  - **Non-Gear Loot Rolls:** Player Roll (default), Greed or Need, up to a rarity. Mounts, pets, recipes, quest items, keys and anything you can't use are always your roll.
  - Hold Shift as a quest reward window opens to choose yourself.
- **Levelling Mode:** automation runs at levels 1-59. From 60, Gear only marks.
- **Bags and ammo:**
  - Empty bag slots get bigger general bags, one each; occupied bags stay manual.
  - Better ammo for your ranged weapon goes in, including a new tier at the level it unlocks, once you have a real stack of it (200, or as many as you wear).
- **Bind on equip:** Auto-Equip Bind-on-Equip has its own **Bind on Equip Up To** rarity (default Uncommon). Auto-Confirm Bind Prompt confirms only the item Gear is equipping. Rarity choices are shown in their quality colors.
- **Profiles:** looks and scoring follow your Ellesmere profile. What Gear does by itself (Auto-Equip, Auto-Roll, Need and the confirmations) stays with each character, so an imported profile never turns it on.
- **Feedback:**
  - Ellesmere-style action pop-ups (equipped, quest reward, roll).
  - Upgrade Found cards with Equip and Never Equip. Duration and preview; Unlock Mode position.
  - Chat lines, and a Weapon Skill Maxed notice.
- **AutoGear:** while it is enabled, Gear only marks; one button disables it.

### Scoring

- **Hunter model** (default for Hunters): weights from your live character. It uses:
  - ranged attack power, crit, hit, haste;
  - weapon speed (through Aimed Shot), ammo type and weapon skill;
  - pet and talents.

  Tooltips show the DPS gain; `/fhkgear hunter` shows every input.
- **Stat weights:**
  - Built in per class and spec, with Levelling and Endgame phases (switching by level if you like).
  - Your own weights per spec and phase.
  - Pawn scale import, lossless sharing, reset to built-in.
- **Score sources:** automatic, Hunter model, stat weights, or ForeverGear at levels 1-20 when that addon is installed.
- **Model assumptions:** comparison model, weapon preference, fight length, melee share, Use-effect availability, hits taken per second, target creature type, rating units and conversions.
- **Procs:** per-item proc rates (PPM or chance, internal cooldown); procs are counted as an expected value. Automation only uses estimated procs when you allow it.

### Markers

- A **tooltip score** line on gear.
- **Quest reward borders:** upgrade color, or greed color on the best vendor value.
- **Bag upgrade icons** in Blizzard and Ellesmere bags; loot roll marks; character slot marks.
- **Appearance:** marker styles, color swatches, size, opacity and placement, with a live preview.

### Equipment rules

- Lock any slot, including each bag slot.
- **Never Equip** an item, or just one enchanted or random-suffix variant.
- Import AutoGear's slot locks.

### Commands

`/fhkgear` opens Gear. `scan` lists bag upgrades; `item` explains the hovered item; `hunter` shows the Hunter model; `status`, `context` and `errors` are diagnostics.

Licence: FHK Gear adapts AutoGear and is shared under CC BY-NC-SA 4.0.
