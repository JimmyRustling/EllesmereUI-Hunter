# Suite review: Ellesmere core and options framework vs our integration layer (2026-10-06)

Scope: Forever Companion (`Interface/AddOns/FHKEllesmere`, 1.9.5) and FHK Gear (`Interface/AddOns/FHKGear`, 0.5.3)
against EllesmereUI main 9.3.9 (commit 14245494), laid out at `.dev/staged-main-939/Interface/AddOns/`.
Read-only review. Evidence: **E1 (static reading) only**. Nothing here was run in the client; items marked
**probe** need the client.

Paths: `EUI/` = `.dev/staged-main-939/Interface/AddOns/EllesmereUI/`, `EUIO/` = `.../EllesmereUIOptions/`,
`FHKE/` = `Interface/AddOns/FHKEllesmere/`, `FHKG/` = `Interface/AddOns/FHKGear/`.

## Summary

| ID | Sev | Area | One line |
|---|---|---|---|
| SC-1 | must | Profiles / Reset | Per-character, profile-name-keyed restore snapshots outlive Reset ALL, same-name imports and other characters' renames; chrome visibility writes stale values into Ellesmere's ActionBars profile at login by itself |
| SC-2 | should | Profiles / exports | `W.DualRow` wrapper injects `fhk_*` text-content keys into Ellesmere's own UF dropdowns; the choice is saved in Ellesmere's UF profile and exported; main renders unknown keys as a blank slot |
| SC-3 | should | Unlock Mode | Three movers are stamped with a suite folder; their anchors ride that module's export and are dropped on importing that module |
| SC-4 | should | Navigation | Class HUD "Go" buttons navigate to suite modules without checking they are loaded; on main this builds an empty page on our plugin module |
| SC-5 | should | Global Search | FHK Gear prebuild registers every row under a section named after the page; first-wins indexing means search results never scroll or highlight |
| SC-6 | should | Reset | Plugin Reset misses two profile keys; suite module Reset no longer resets companion keys on main (WrapResets is dead) |
| SC-7 | should (probe) | Combat | Profile keybind switches in combat; our Resync then runs every sync function in combat |
| SC-8 | nice | Exports | Our store rides every export, including subset strings, and is applied even when the importer unticks Global Settings |
| SC-9 | nice | API contract | Hooks on Ellesmere functions and private fields that PLUGINS_API rules out; switch detection rides an undocumented call |
| SC-10 | nice | Cost / dead code | ShowModule hook and native-extension path are dead on main; Install re-runs on every ADDON_LOADED |
| SC-11 | nice | Cost | Hub harvest rebuilds the same sections many times per page build; Gear rebuilds on every cached-page revisit |
| SC-12 | nice | Private writes | `_colorCacheDirty` and `_anchorLinksStamp` written directly |
| SC-13 | nice | Unlock Mode | Gear pop-up position is per character (all other movers per profile); unlock order 622 used twice |
| SC-14 | probe | Registration | Class page and section gating read `UnitClass` at file load; the plugin registration is a one-time snapshot |

No call into the Ellesmere core was found whose name or signature differs on main. Every API we call exists on
main with the signature we use (checked below). The older-core paths (`EUI._modules`, `RegisterOptionsExtension`)
are inert on main, not harmful.

---

## Q1. Ellesmere APIs we call: names, signatures, private internals

Verified present on main with matching call style:

- `RegisterPlugin(id, spec)` dot call, `EUI/EllesmereUI_Panel.lua:5139`; our call `FHKE/RefinementOptions.lua:455` (pcall, checks `registered==true`), `FHKG/Options.lua:597` (unchecked return; spec valid).
- `GetPluginModuleKey(id,key)` dot `Panel.lua:5200`; `OpenPlugin(id,key,page)` dot `Panel.lua:5207` (returns false in combat / unknown page); `IsSearchPrebuild()` dot `Panel.lua:5193`.
- `EllesmereUI:NavigateToElementSettings(module,page,section,preSelectFn,highlightText)` `Panel.lua:3311`, wrapped (same signature) by `EUIO/EUI_Fonts_Options.lua:1218`, `EUI_BlizzardSkin_Options.lua:3913`, Glows, Textures. Our calls: `RefinementOptions.lua:401` (`key,page,section,nil,row`), `:538`, `:702` all match.
- `RefreshPage(force)` `Panel.lua:4254`, `InvalidatePageCache()` `:4009`, `InvalidateModulePageCache(key)` `:4027`, `GetActiveModule()` `:4390`, `GetActivePage()` `:4768`.
- Widgets: `SectionHeader(parent,text,y)` `EUIO/EllesmereUI_Widgets.lua:1823`, `DualRow(parent,y,l,r)` `EUIO/EllesmereUI_Widgets_Rows.lua:322`, `BlankRowCfg()` `EUIO/EllesmereUI_Widgets_PageParts.lua:177`, `BuildInlineCog(rgn,opts)` / `BuildInlineSwatches(region,swatches,opts)` `EUIO/EllesmereUI_Widgets_RowAddons.lua:50,392`; `RegisterWidgetRefresh(fn)` `EUI/EllesmereUI.lua:1050`; `ShowWidgetTooltip`, `HideWidgetTooltip`, `DisabledTooltip` `EllesmereUI_UICore.lua:87,284`; icons `DIRECTIONS_ICON`, `EYE_VISIBLE_ICON` `EllesmereUI.lua:1229-1231`; `media/icons/eui-open.png` exists.
- Profiles: `ImportProfile(importStr|payload, profileName)` `EllesmereUI_Profiles.lua:3200`, `DecodeImportString` `:2802`, `OnProfileRenamed/Deleted` `:1671,1686`, `RegisterDarkModeRefresh(fn)` `EllesmereUI_Colors.lua:394`.
- Unlock: `MakeUnlockElement(opts)` `EllesmereUI.lua:2433` (whitelist: all fields we pass are kept), `EllesmereUI:RegisterUnlockElements(elements, folder)` `EUI_UnlockMode.lua:31` wrapped `EUI_UnlockMode_Anchors.lua:1587`, `NotifyElementResized(key)` `Anchors.lua:1144`.
- Fonts / sounds: `GetFontPath(key)` `EllesmereUI_Fonts.lua:311`, `ApplyModuleFont(fs,path,size,moduleKey,flags)` `:582` (our 5-arg call `FHKE/Warnings.lua:437` matches), `BuildAlertSoundTables()` returns `paths,names,order` `EllesmereUI.lua:1317` (our pcall `Warnings.lua:29` matches).
- Gear helpers: `ShowInputPopup(opts)` `EllesmereUI_Popups.lua:963`, `ShowCopyPopup(title,subtitle,str)` `EllesmereUI_Profiles.lua:4639`, `ShowConfirmPopup`, `MakeFont`.

Private internals we read or write (all present on main 9.3.9; each can change without notice per `EUI/PLUGINS_API.md:74-78`):
`EUI._ModuleNS` (115 reads), `_unlockActive` (15), `_applySavedPositions` (8), `_anchorLinksStamp` (6, **writes**), `_modules` (4), `_prebuilding` (3), `_darkModeToggles` (3), `_bagsDB` (3), `_applyTargetDistance`, `_contentHeader`, `_colorCacheDirty` (**write**), hooked `_applyDurWarn` / `_durWarnApplySettings` / `_durWarnPreview` (`FHKE/Warnings.lua:85-88`; defined `EllesmereUIQoL.lua:3261-3267`). Private globals: `_G._ECL_AceDB`, `_ECL_ApplyCastCircle`, `_EAB_UpdateKeybinds`, `_EBS_BuildCursorPage`, `_EBS_ResetCursor`, `_EUI_AbbrevDecimalCfg`, `_EUI_ResolvedPowerType`, `EUI_CategoryManager`, `EllesmereNameplates_NS`: all defined on main. UF module internals replaced or hooked: `ns.ContentToZone` (`FHKE/UnitRefinements.lua:1046`), `ns.UF_PaintPowerText` (`:1036`); see SC-2.

On main `EllesmereUI._modules` is a proxy whose `__index` returns only an outside addon's own pages (`Panel.lua:5396-5402`), so our reads of suite keys return nil. Reading does not trigger the update notice (only writes / RegisterModule hooks do: `EllesmereUI.lua:922-928`, `Panel.lua:5379-5392`). We never write `_modules` in plugin mode (`RefinementOptions.lua:551-554`).

## Q2. Profiles

Storage: `EllesmereUIDB.profiles[name].fhkEllesmere` (`FHKE/Profiles.lua:10,61-71`), read through a metatable on our own SV `FHKEllesmereDB` (`:74-79`). Ellesmere never iterates or prunes profile root keys (checked `Profiles.lua`, `Migration.lua`, `Lite.lua`, `SpecOverrides.lua`, `SnapProfilePositions` `Migration.lua:290-329`), and its serializer handles any plain table (`Profiles.lua:243-285`; DeepCopy drops functions/userdata `:367-380`; our store holds none).

| Operation (main) | Survives? | Evidence |
|---|---|---|
| Switch | yes; detected through `RefreshDarkMode()` at the end of `RepointAllDBs` | `Profiles.lua:3830-3911`, `:916`; ours `FHKE/Profiles.lua:116-122,202` |
| Copy (Save Current As) | yes, deep copy of the root | `Profiles.lua:3682-3690` |
| Rename | yes, same table moves; our hook fires | `Profiles.lua:3786-3828` -> `OnProfileRenamed` `:3827`; ours `:172-181,200` |
| Delete | store goes with the profile; our hook clears this character's name-keyed tables | `Profiles.lua:3736-3784` (`OnProfileDeleted` `:3770`); ours `:182-190,201` |
| Export (full and subset) | included: `exportData = DeepCopy(profileData)`, never stripped | `Profiles.lua:2191-2334` |
| Import full | base is a deep copy of the active profile (keeps the recipient's store), then our post-hook overlays the payload's store | `Profiles.lua:3308-3309,3451`; ours `FHKE/Profiles.lua:127-137,198` |
| Import partial | recipient's store kept (we skip `partialImport`) | `EUIO/EUI_Profiles_Options.lua:1228-1232`; ours `:130` |
| Silent / interactive API import | both call the `EllesmereUI.ImportProfile` field, so the hook fires; both pass a decoded table, so our re-decode branch never runs | `Profiles.lua:5009`, `EUI_Profiles_Options.lua:1282` |
| Full-account import | profile copied wholesale incl. our store; no hook needed | `Profiles.lua:2519-2531` |
| First install | Ellesmere creates `Default` at PLAYER_LOGIN (`Profiles.lua:4300-4335`); before that our `Store()` uses `fallback` and copies it in on first read | ours `:61-71` |
| Reset ALL | store wiped with `EllesmereUIDB` (correct), **but per-character snapshots survive: SC-1** | `EUIO/EUI__General_Options.lua:1841-1897` |

Can our proxy or `AfterImport` corrupt Ellesmere data? `AfterImport` is a `hooksecurefunc` post-hook inside `pcall`, keeps the original return values, and writes only `profiles[name].fhkEllesmere`. The proxy sits only on `FHKEllesmereDB`. Neither touches Ellesmere's own keys. The real corruption paths are elsewhere: SC-1 (snapshot restores write into Ellesmere's ActionBars / colour data) and SC-2 (our keys inside Ellesmere's UF profile).

Should exports include our keys? For full strings, yes (it is how the look follows the profile). See SC-8 for the subset / Global-Settings edge.

## Q3. Unlock Mode

- Key collisions: none. Our keys `FHKEllesmere*`, `ForeverRangeIndicator`, `ForeverAttackIndicators`, `ForeverActionHistory`, `FHKGear_PopUps`; no suite key uses them (grep of all `EllesmereUI*`).
- Field names: we pass `savePos/loadPos/clearPos/applyPos`, which `MakeUnlockElement` maps (`EllesmereUI.lua:2441-2444`); `savePosition` is called with `(key, point, relPoint, x, y, prePoint, preRelPoint)` (`EUI_UnlockMode_Positions.lua:2404`); our validators accept the first five.
- Where positions live: in our profile store (aspect, warnings, indicators, class kits), so they follow the Ellesmere profile. Spec / condition unlock layers bank every registered element through `loadPosition` / `savePosition` regardless of folder (`EllesmereUI_SpecOverrides.lua:1872-1900`), which works with our pairs. Exceptions: SC-3 (folder stamps), SC-13 (Gear per character).
- Frames that do not exist yet: every registration creates or receives its frame first (`AspectBar.lua:233`, `RangeIntegration.lua:258-263`, `Warnings.lua:1342-1344` places proxies first, `FHKG/Notify.lua:333` creates lazily). Ellesmere's size-hook installer waits 0.1 s (`Anchors.lua:1590-1596`).
- Session: on main `_unlockActive` is cleared on combat suspension and set again on resume (`EUI_UnlockMode.lua:806,850`, `Session.lua:1202,1957`), which is the meaning our previews want. The public `IsUnlockModeActive()` (`EUI_UnlockMode.lua:77`) stays true through suspension, so it is not a drop-in replacement.
- Protected frames: Ellesmere defers positioning of protected frames in combat (`Positions.lua` ~2380 `_UnlockCombatQueue`, `Anchors.lua:1864`); our `applyPos` functions defer in combat (e.g. `AspectBar.lua:203-204`). **probe**: anchor one of our secure-bearing movers (Aspects, Summons, Class Buffs) to a CDM bar that resizes in combat.

## Q4. Global Search

- Plugin and class pages index correctly: `RenderSection` reads `EUI.Widgets` at build time, so the prebuild absorber is used (`GlobalSearch.lua:715-719`); headers register the real section titles; `Extras` skips on `_prebuilding` (`RefinementOptions.lua:123`), and `BuildInlineCog` itself returns on prebuild (`RowAddons.lua:51`). Unguarded builders (Warnings, Indicators, XP, Theme...) create no frames (static scan). No prebuild risk found for the companion.
- Hub links: `OpenEllesmereCompanionSection` (`RefinementOptions.lua:397-403`) passes `(pluginKey, page, sectionTitle, nil, rowLabel)`; main matches `header._sectionName == sectionName` (`Panel.lua:3361`, set verbatim `Widgets.lua:1855`) and plain-finds the label (`:3368`). Correct on main. Navigation is blocked during an override edit session (`Panel.lua:4407-4413`), as for every plugin.
- Advanced rows hidden at prebuild are not indexed until shown (nice).
- FHK Gear: SC-5.

## Q5. Reset

- Plugin footer Reset: `onReset` is wrapped by Ellesmere's Guard (`Panel.lua:5097`) and runs before the reload (`Panel.lua:2750-2769`). Ours resets every `RESET_KEYS` list on the active profile (`RefinementOptions.lua:461-466`). Gap: SC-6.
- Suite module Reset: no longer reaches companion keys on main (SC-6); Ellesmere resets only `addons[folder]` (`EllesmereUI_Lite.lua:320`).
- Reset ALL: SC-1.

## Q6. Taint and combat

- Options are never built in combat: the panel hides on PLAYER_REGEN_DISABLED (`EllesmereUI.lua:3548-3555`); `ShowModule` and `OpenPlugin` refuse in combat (`Panel.lua:4918,5213`); the search prebuild only runs while the panel is open.
- Our `RefreshPage` calls while the panel is hidden only run widget refresh closures or set a pending flag (`Panel.lua:4256-4270`).
- `hooksecurefunc` on Ellesmere table fields (ImportProfile, OnProfileRenamed/Deleted, ShowModule, ApplyModuleFont, ApplyColorsToOUF, `_applyDurWarn`...) adds no secure-path taint (Ellesmere code is already insecure) but moves blame for any later blocked action in those paths to FHKEllesmere (SC-9).
- Combat profile switch: SC-7.

## Q7. Cost

- `ShowModule` post-hook: one early return per panel open on main (dead, SC-10).
- `Live` wrapper: one `RefreshPage()` fast path per user change (`RefinementOptions.lua:42-63`); no per-frame cost.
- `W.DualRow` wrapper (`UnitRefinements.lua:1210-1218`): runs on every DualRow of every Ellesmere page; `ExtendConfig` returns at once for non-dropdowns; `ExtendPreview` walks the header only for four labels. Cheap, but see SC-2.
- `ApplyModuleFont` hook (`Bootstrap.lua:323-333`): per Ellesmere font apply (nameplate setup, UF, etc.); one `GetFont` and an early return while Vivid text is off.
- Hub harvest and Gear rebuilds: SC-11.

---

## Findings

### SC-1 (must): name-keyed per-character snapshots outlive Ellesmere's profile replacements

- Ours: `FHKE/Profiles.lua:171-190` (`NAME_KEYED = themePresets, classHUD, chromeVisibilityBefore, combatLayout`, plus `reviewedProfileBefore`); `FHKE/ActionBarLayout.lua:108-149` and `:265-272` (login sync); `FHKE/ThemePresets.lua:13-23,459-521`.
- Ellesmere: Reset ALL replaces the store (`EUIO/EUI__General_Options.lua:1841-1897`); API overwrite import keeps the name and replaces the table (`EUIO/EUI_Profiles_Options.lua:1156-1159`, `EUI/EllesmereUI_Profiles.lua:3451`); full-account import replaces a same-named profile (`:2521-2530`); rename / delete hooks reach only the current character's SV.
- Failure: a player used Menu And Bags Visibility "Show On Hover" on `Default`, then runs Reset ALL. After the reload the profile store is gone, so the mode reads `native`; `chromeVisibilityBefore.Default` still exists, so `Initial()` at login (`ActionBarLayout.lua:272`) runs the `native` branch (`:137-145`) and writes the pre-reset bar visibility into the fresh Ellesmere ActionBars profile, then `_eabApplyAll()`. Part of Reset ALL is undone with no click. The same happens after a same-name import, or on an alt after another character renamed and re-created the profile. The theme dropdown also reports the old preset, and Restore Original Look writes the pre-reset palette back.
- Fix (ours): give each profile store an id (`store._id`, created once in `Store()`); save it with every snapshot; treat a snapshot whose id differs from the active store's as absent and drop it. One helper in `Profiles.lua` used by the four owners.
- Test: yes (E2 mock: wipe `EllesmereUIDB`, keep `FHKEllesmereDB`, run `SyncEllesmereChromeVisibility`, assert no write). **probe** in game after the fix.

### SC-2 (should): companion text keys stored in Ellesmere's own UF profile and exports

- Ours: `FHKE/UnitRefinements.lua:1141-1168` (mutates `cfg.values` / `cfg.order` of Ellesmere's UF text dropdowns, adds `fhk_manaboth`, `fhk_manaperfirst`), `:1210-1218` (replaces `EUI.Widgets.DualRow`), `:824-825,1046` (renders them by replacing `ns.ContentToZone`).
- Ellesmere: unknown content keys resolve to nil, i.e. an empty zone (`EllesmereUIUnitFrames/EUI_UnitFrames_Text.lua:964-985`); `addons.EllesmereUIUnitFrames` rides every export (`Profiles.lua:2220-2228`). PLUGINS_API forbids replacing EUI functions (`PLUGINS_API.md:74-78`).
- Failure: a player picks "Resource # | %" (`fhk_manaboth`) on the player frame and shares the profile; recipients without the companion, or the player after disabling it, get a blank text slot with no message.
- Fix (ours): keep a native key in Ellesmere's profile (`curpp` / `perpp` / `both`) and store the companion variant in our profile store keyed by unit and slot; render the variant from our store. Offer it on our Unit Frames plugin page instead of inside Ellesmere's dropdown, and drop the `W.DualRow` replacement.
- Test: yes (E2: exported UF table contains only native keys).

### SC-3 (should): movers stamped with a suite folder

- Ours: `FHKE/RangeIntegration.lua:263` (`'EllesmereUIResourceBars'`), `FHKE/ActionPressFeedback.lua:232` (`'EllesmereUIActionBars'`), `FHKE/PetFood.lua:337` (`'EllesmereUIUnitFrames'`); every other mover uses `'FHKEllesmere'`.
- Ellesmere: the stamp classifies anchor and size-match edges (`Profiles.lua:405-416`); export keeps edges whose ends are in exported modules (`:461-500,634-650`); import drops the recipient's base edges whose child belongs to an imported module (`:586-608`).
- Failure: the player anchors Range Indicator under the player frame, then imports a friend's profile with Resource Bars ticked; our anchor is removed and the indicator jumps to its saved free position. The same edges also travel to people without the companion as dead keys.
- Fix (ours): pass `'FHKEllesmere'` in all three registrations.
- Test: no (static); **probe** export/import round trip.

### SC-4 (should): Class HUD "Go" buttons into modules that may be absent

- Ours: `FHKE/RefinementOptions.lua:700-710` (`NavigateToElementSettings(module,page)` for Cooldown Manager, Aura Buff Reminders, Unit Frames, QoL, Resource Bars).
- Ellesmere: `SelectModule` returns silently for an unregistered module (`Panel.lua:4399-4400`); `NavigateToElementSettings` then calls `SelectPage(page)` on the current module (`:3338-3339`), and `SelectPage` does not check the name against the module's pages (`:4048-4110`).
- Failure: with Cooldown Manager disabled, "Track Cooldowns And Procs" asks our plugin module to build a page named "CDM Bars"; `BuildPluginPage` returns an empty page that no tab matches.
- Fix (ours): give each Go row `disabled=function() return not C_AddOns.IsAddOnLoaded(module) end` plus a `disabledTooltip`, and return early in `onClick`.
- Test: E2 mock optional; **probe** for the visual.

### SC-5 (should): FHK Gear search entries carry the wrong section

- Ours: `FHKG/Options.lua:584-595,605-611` (prebuild registers `Header(page)` and every label under it).
- Ellesmere: the index is first-wins per module/page/label (`GlobalSearch.lua:56-58`), so live builds never replace these entries; a result calls `NavigateToElementSettings(module,page,entry.section,...,label)` (`:936`), which only scrolls and highlights when a header named `entry.section` exists (`Panel.lua:3359-3386`).
- Failure: searching "auto-roll" opens Gear > Automation but never scrolls to or highlights the row; a phantom "Section: Automation" result appears. Hunter-only labels (Model Report, Pet, Multi-Shot Targets, Talent Ranks) are found for every class.
- Fix (ours): make `PREBUILD_LABELS` a list of `{section, labels}` using the real headers (`AUTOMATIC ACTIONS`, `POP-UPS`, `BIND ON EQUIP`, `LOOT ROLLS`, ...) and gate the hunter labels on `ns.HunterModel.Available()`.
- Test: yes (mock prebuild; assert every prebuild section exists in the live build's headers).

### SC-6 (should): Reset coverage

- Ours: `FHKE/Profiles.lua:12-29` vs `:142-155`: `combatFadeGuides` and `extraCombatIcons` are profile keys in no `RESET_KEYS` list, so the plugin Reset leaves them. `FHKE/RefinementOptions.lua:606-619` (`WrapResets`) reads `EUI._modules[folder]`, which is always nil for suite folders on main (`Panel.lua:5396-5402`), so a suite module's own Reset no longer resets the companion keys on its pages (audit F02 behaviour is gone; DEVELOPMENT.md line 229 already notes there is no contract).
- Fix (ours): add both keys (Unit Frames / Nameplates lists); add a validator asserting every `PROFILE_KEYS` entry appears in `RESET_KEYS`; mark `WrapResets` as older-core only (or remove it) so nobody relies on it.
- Test: yes (static validator).

### SC-7 (should, probe): profile switch in combat runs every companion sync

- Ellesmere: the profile keybind button switches with no combat check (`Profiles.lua:1608-1633`) -> `RepointAllDBs` -> `RefreshDarkMode()` (`:916`).
- Ours: `CheckSwitch` (`FHKE/Profiles.lua:116-122`, registered `:202`) -> `Resync` (`:106-114`) calls about 35 sync functions, several of which touch secure buttons or other modules' frames (class buffs, summons, pet food, aspects, action bar layout).
- Failure: possible ADDON_ACTION_BLOCKED blamed on FHKEllesmere when switching profile by key in combat; not every sync was checked for a combat deferral.
- Fix (ours): in `CheckSwitch`, if `InCombatLockdown()`, set a pending flag and run `Resync` on PLAYER_REGEN_ENABLED.
- Test: E2 mock (combat flag defers); **probe** in game.

### SC-8 (nice): what exports carry

`fhkEllesmere` rides every export (`Profiles.lua:2191`) and full-account export (`:2420`). Subset strings carry it for nothing (we skip `partialImport`). A full import applies it even when the importer unticked "Global Settings" (`EUIO/EUI_Profiles_Options.lua:1220-1227`), so the exporter's colour tokens (`hunterColors`, theme keys) replace the importer's. Deselecting any one module makes the import partial, and the whole companion store is then kept. Fix: in `AfterImport`, when `data.fonts==nil and data.customColors==nil and data.darkMode==nil`, overlay only non-look keys. No test needed beyond a mock.

### SC-9 (nice): API contract

Hooks: `ImportProfile`, `OnProfileRenamed`, `OnProfileDeleted` (`FHKE/Profiles.lua:198-201`), `ShowModule` (`RefinementOptions.lua:1141`), `ApplyModuleFont` (`Bootstrap.lua:328`), `ApplyColorsToOUF` (`Companion.lua:1305`), `_applyDurWarn` and two siblings (`Warnings.lua:85-88`). Main does not reclaim them (only `RegisterModule`, `EllesmereUI.lua:922-928`), so they work, but PLUGINS_API rules them out and they shift blame for blocked actions to us. Switch detection depends on `RepointAllDBs` calling `RefreshDarkMode()` (`Profiles.lua:916`); a refactor there would silently stop our resync. Fix: also hook `RefreshAllAddons` (called after every manual switch) as a second trigger; list every hook in DEVELOPMENT.md Hazards with the main line numbers.

### SC-10 (nice): dead paths on main

`RegisterOptionsExtension` does not exist on main, so `RegisterNative` (`RefinementOptions.lua:488-546`), its `ShowModule` hook (`:1141`) and Gear's `TryQoLLink` (`FHKG/Options.lua:622-630`) never act. `Install` stays registered for every ADDON_LOADED (`RefinementOptions.lua:1139-1143`) and re-runs all `Append` calls each time. Fix: install the hook only when `RegisterOptionsExtension` exists; unregister ADDON_LOADED once the plugin is registered.

### SC-11 (nice): page-build cost

`HubRows` creates its cache per call (`RefinementOptions.lua:349-354`) and each hub group calls it, so e.g. `Warnings|HUNTER WARNINGS` runs its builder about six times per Hunter page build (and again in the search prebuild and in `SetRecommended`). Fix: one cache per `BuildPluginPage` call. Gear's `onPageCacheRestore` calls `RefreshPage(true)` (`FHKG/Options.lua:618`, `:20-23`), so every return to a Gear tab is a full rebuild; use the fast `RefreshPage()` unless a list changed.

### SC-12 (nice): private writes

`EUI._colorCacheDirty=true` (`FHKE/ThemePresets.lua:405`); public `EllesmereUI.InvalidateColorCache()` exists (`EUI/EllesmereUI_Colors.lua:341`). `EUI._anchorLinksStamp` increments (`FHKE/ActionBarLayout.lua:208,240,257`, owner-only paths).

### SC-13 (nice): Unlock Mode details

Gear pop-up position is saved per character (`FHKG/Notify.lua:335`) while every companion mover follows the Ellesmere profile. Unlock order 622 is used by both Class Buffs (`FHKE/ClassBuffs.lua:394`) and Weapon Enchants (`FHKE/WeaponEnchants.lua:350`). Our movers sit in Ellesmere's own group names ("Unit Frames", "Quality of Life"...), so players cannot tell them from suite elements.

### SC-14 (probe): class read at file load

`RegisterPluginPages` runs from the file-load `Install()` (`RefinementOptions.lua:1143`) and fixes the page list once (`PLUGINS_API.md:72`: registration is a snapshot). `ClassPage()` and `SectionAllowed()` read `UnitClass('player')` at that moment (`:188,437-445`). If it is nil there, the class page is missing for the session and every class's sections show. Probe: print `UnitClass('player')` from a file-scope chunk at load on Forever.
