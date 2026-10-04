# FHK Gear

Upgrade scores, quest reward choice and auto-equip for levelling, as a **Gear** section in the EllesmereUI sidebar. It replaces AutoGear: once you're happy, disable AutoGear (the Automation page has a button).

- **Mark Only by default.** You get a tooltip line on every piece of gear, and quest rewards that are upgrades get a border. When nothing is an upgrade, the best vendor value gets the greed colour instead.
- **Automatic actions, each with its own toggle:**
  - auto-equip upgrades;
  - auto-pick quest rewards;
  - auto-roll on loot (Need and Greed policies are separate).
  - A status line says what Gear is doing right now.
- **Pop-ups:** Ellesmere-style cards for what Gear did (equipped, quest reward, roll), and Upgrade Found cards with Equip and Never Equip. Move them in Ellesmere Unlock Mode.
- **Auto-Equip Up To:** a rarity cap from Grey to Legendary, in Blizzard's quality colours. The default is Green. Items above the cap are still marked as upgrades.
- **Bind on equip, as a pair:**
  - **Auto-Equip Bind-on-Equip** follows the rarity cap.
  - **Auto-Confirm Bind Prompt** accepts the prompt only for the item Gear is equipping. It is off by default.
- **Levelling Mode (on):** automatic actions only run at levels 1-59. From level 60, Gear only marks.
- **Hunter model (default for Hunters):** weights come from your live character: ranged AP, crit, hit, haste, weapon skill, pet and talents.
  - Weapon speed counts, through Aimed Shot.
  - So do ammo type and your skill with the weapon type.
  - Tooltips show the DPS gain.
  - `/fhkgear hunter` shows every input.
- **Stat weights:** built in per class and spec. You can set your own per spec and per phase (Levelling / Endgame), and import or export Pawn scales.
- **Markers:**
  - bag icons (Blizzard and Ellesmere bags), loot-roll marks and character-slot marks, all off by default;
  - styles, colour swatches, size, opacity and placement;
  - a live preview at the top of the page.
- **Bags:**
  - Empty bag slots are filled with bigger general bags, one each. Bags with items in them stay manual.
  - Reagent bags go only in the reagent slot.
  - Profession bags stay your choice.
- **Equipment Rules:** lock slots; add items (or one enchanted variant) to Never Equip.
- **Model:** proc and Use-effect assumptions, rating units, target creature, per-item proc rates, and learned-ability casts (experimental).
- **Optional integrations:**
  - ForeverGear appears as a score source only when its addon is ready.
  - MythicSim export appears only when its exporter is loaded.
  - With the FHK Ellesmere companion, Gear settings follow your Ellesmere profile.

Scores are estimates from stat weights plus a proc expected-value model, not simulated DPS. See [the scoring review](SCORING_REVIEW_2026-10-04.md).

`/fhkgear` opens the section.
- `/fhkgear scan` lists bag upgrades.
- `/fhkgear item` explains the hovered item.
- `/fhkgear status`, `/fhkgear context` and `/fhkgear errors` are diagnostics.

Licence: CC BY-NC-SA 4.0, adapted from AutoGear. See [LICENSE.md](LICENSE.md). Tests: `node Interface/AddOns/FHKGear/tests/run.js`.
