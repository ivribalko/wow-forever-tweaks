# Forever Tweaks

A lightweight quality-of-life addon for World of Warcraft Forever.

## Features

- Sorts the full tracked-quest list by quest level, lowest first.

- Automatically sells junk and repairs items at merchants.
- Automatically replaces harmful spell actions with spell-casting macros that start autoattack in combat.
- Automatically upgrades action-bar spells and makes spell references in macros rankless to use the highest learned rank.
- Adds a small circular-arrow button at the minimap’s top-right corner to reload the interface.
- Removes chat backgrounds and borders, shows chat tabs only on hover, and places a taller chat window at the bottom-left.
- Smoothly fades player and target frames, cast bars, and gamepad action bars between 40% opacity outside combat and 70% in combat.
- Shows XP progress as a gold percentage beside the player name and hides the original XP artwork.
- Shows maximum HP beside the level in friendly and hostile unit tooltips.
- Binds controller inputs for the world map and inventory; PlayStation touchpad sides require the local mapping described below.
- Makes the player turn with the gamepad camera while moving, including autorun.
- Disables native gamepad touchpad cursor control for use with an external mouse mapper.
- Disables automatic gamepad buff popups while keeping manual buff inspection available.
- Hides the floating beta Issue Reporter and automatic quest-reward feedback surveys.
- Captures protected-action diagnostics in source and alpha packages for troubleshooting.

## Usage

- The full native watch list is reordered by ascending quest level before tracker layout chooses which quests fit. Equal levels keep their existing relative order; unavailable levels sort last. Reordering removes and immediately re-adds each watched quest through native APIs, preserving final membership and the super-tracked quest. It waits until combat ends. Native quest filters and special quest priorities still apply. The addon reports if the client rejects the requested order; in-game validation is pending.

- Attack macros are created at login and when action bars or spells change, outside combat with an empty cursor. They cover the ten persistent keyboard pages, standard controller pages, and the active controller stance bar. Other controller stance bars are processed when activated. Temporary vehicle, possession, and override states defer conversion.
- Spells on scanned keyboard and controller bars upgrade to their highest learned rank, including heals and buffs. Unedited generated attack macros upgrade in place without requiring a free macro slot. Updates run outside combat with an empty cursor after login, spell learning, and bar changes; inactive controller stance bars update when activated. Pet bars and flyouts are left alone. Ambiguous same-name abilities are skipped. Rank upgrades remain enabled when attack macro conversion is disabled.
- Generated macros omit ranks from their cast and tooltip lines so the game selects the highest learned rank automatically, with `/startattack [@target,combat,harm,nodead]` before `/cast`. The button must still be pressed. Harmful-action classification comes from Blizzard and can include crowd-control abilities; it is not a damage-only filter. Existing custom macros, items, flyouts, and autoattack/autorepeat spells are skipped by macro conversion.
- Conversion uses one character macro slot per distinct spell ID, reusing it across bars. Full character macro storage leaves remaining spells unchanged and prints a notice; freeing slots retries conversion. Generated attack macros are all named `+` and are identified by saved ownership and body, rather than by name alone. Existing unedited `FT <spellID>` attack macros are renamed automatically. Custom and edited macros retain their commands, names, and icons, with recognized spell-rank suffixes removed as described below.
- Character and account macros have explicit ranks removed from recognized learned player spells in `/cast`, `/use`, `/castsequence`, `/castrandom`, `/userandom`, `#show`, and `#showtooltip` lines, including localized slash aliases. Conditions, reset options, items, script lines, and chat text remain intact. Rankless casts automatically use the highest learned rank. Account macro edits are shared across characters. Unrecognized spell references remain unchanged.
- `/ftattack restore` disables conversion for this character and restores unedited generated macros on scanned bars to spells at their highest learned rank, including other controller stance bars when activated. Generated macros remain in macro storage for reuse or manual deletion. `/ftattack on` enables conversion again. Disabling the addon alone leaves the macros on the bars. Ownership and the enabled setting persist in character SavedVariables.
- Opening a merchant sells gray-quality items with vendor value and repairs all items using personal gold when the merchant offers repairs and the full cost is affordable. Sale proceeds can fund repairs during the same visit. Guild funds are not used; locked stacks are skipped by the classic bag-selling fallback.
- Supports WoW Forever beta 1.60.1 (`16001`).
- Place the `ForeverTweaks` folder in the client’s `Interface/AddOns` directory and enable Forever Tweaks in the AddOns menu.
- The minimap reload button uses a native refresh symbol and the same circular rim as the day/night indicator. The AddOns list uses the bundled circular-arrow artwork.
- Restart the game if the newly created addon is absent from the list.
- The button has no text, configuration, or external dependencies.
- The PlayStation controller's left touchpad click toggles the world map through `PADPADDLE1`; its right touchpad click toggles inventory through `PAD6`. A local `WTF/GamePadConfig_*.json` mapping assigns the left-side input to `PADPADDLE1` and the right-side input to `PAD6`; restart the game after changing that mapping. The addon bindings last only while enabled. Restore mappings for DualSense and DualSense Edge with the [controller restore tool](tools/CONTROLLERS.md).
- The local controller mapping assigns DualSense Share/Create to `PADBACK` for native menu actions, including Search in professions. Native prompts may still show the left-touchpad symbol. Restart the client after restoring mappings.
- Chat backgrounds and decorative borders, including side-button backgrounds, are hidden even on hover. Chat text and controls remain visible; saved background settings are not changed.
- Native touchpad cursor control is disabled at login and UI reload through `GamePadTouchCursorEnable`. Touchpad click bindings remain configured separately. The setting persists if the addon is disabled; restore it with `/console GamePadTouchCursorEnable 1`.
- Chat is anchored at the bottom-left after login or UI reload, with a 100-UI-unit bottom margin for the gamepad button-hint panel and space for its side buttons.
- Pressing gamepad Back while editing chat clears the unsent text as native chat focus closes. The selected channel remains the sticky chat type while gamepad UI is enabled; native availability checks still apply.
- Chat messages begin their native fade after 15 seconds. Native gamepad chat focus keeps messages visible and resets their fade timers when focus closes.
- Chat tabs are invisible until individually hovered, matching UITweaks, including newly opened tabs. They remain clickable.
- The main chat window and its docked tabs are set to 360 UI units tall, three times the default, once after login or UI reload. Later native layout changes may override this height.
- Automatic gamepad aura popups are disabled through `GamepadShowAutoAuraTooltip`, including Plainsrunning stack popups. Manual buff inspection remains available. This client setting persists if the addon is disabled; restore it with `/console GamepadShowAutoAuraTooltip 1`.
- Gamepad camera turning follows movement, including autorun, both in and out of combat. The addon manages `GamePadTurnWithCamera`: `2` (Always) while moving and `0` (While moving) when stopped, restored to `0` at logout or reload. The native dropdown reflects the temporary value; other dropdown choices are overridden while the addon is enabled. In-game autorun validation is pending.
- Player and target frames, the player cast bar, and the gamepad action bars are 40% visible outside combat and 70% visible in combat.
- Combat opacity transitions use a shared 0.45-second cosine ease.
- Friendly and hostile unit tooltips append maximum health to the native level line, such as `Level 10 - 100 HP`, including controller soft targets. Health is passed directly to Blizzard's text formatter, which supports secret values; frame status-text settings are not changed.
- XP progress appears as a gold percentage beside the player name, following UITweaks. The original XP artwork is hidden; other status bars remain available. The percentage hides when XP is disabled, at the level cap, or while the player frame shows a vehicle.
- The floating Issue Reporter panel is hidden.
- The automatic quest-reward feedback survey ("Did you experience any issues?") is hidden without submitting a report.
- In source and alpha packages, protected-action failures are captured in `ForeverTweaksDiagnostics` SavedVariables, with up to 20 records of addon attribution, action, UI state, and call stack. Reload after reproducing a failure to persist the capture in the client's WTF directory; keep these files outside the repository.

## UI Source Reference

- `Blizzard_Minimap/Camelot/Diel.lua` creates the day/night indicator as `MinimapCluster.DielFrame`, outside the Minimap widget, at frame level 5.

- Search the [WoW UI source, Forever branch](https://github.com/Gethe/wow-ui-source/tree/forever) when investigating game UI behavior.
- [BuffFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua) implements automatic gamepad aura popups: `Update` queues added and updated aura instances through `AddAuraForTooltip`, then `ShowNextAuraForTooltip` displays `BuffFrameTooltip`. The setting is `GamepadShowAutoAuraTooltip`.
- [Blizzard_PTRFeedback_Frames.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_PTRFeedback/Blizzard_PTRFeedback_Frames.lua) creates the floating `PTR_IssueReporter` panel in `CreateMainView`.
- Quest reward feedback is registered in `Blizzard_Reports.lua` and displayed by `PopFrameAttachedSurvey` in `Blizzard_PTRFeedback.lua`. Its separate frame is stored in `PTR_IssueReporter.Data.FrameAttachedSurveyFrames[QuestFrame]`.
- Search for the visible behavior, frame, event, or setting, then trace its callers and load order before choosing a hook. Automatic popups can use a different frame from `GameTooltip`.

## Releases

[`.pkgmeta`](.pkgmeta) configures CurseForge packaging as one `ForeverTweaks` folder. The manifest uses `@project-version@` for tag-based versions, and [CHANGELOG.md](CHANGELOG.md) supplies release notes. Repository documentation, tooling, and local captures are excluded.

- Connect the repository to a CurseForge project and select tag-only packaging using the [automatic packaging instructions](https://support.curseforge.com/support/solutions/articles/9000197281). Keep integration tokens in service settings, never in tracked files.
- Update the changelog before tagging. Use `MAJOR.MINOR.PATCH-beta.NUMBER` for Beta, `MAJOR.MINOR.PATCH` for Release, and tags containing `alpha` for Alpha.
- Complete in-game acceptance checks before a Release tag, including reload, chat, combat fades, XP display, and controller shortcuts. Verify the published file’s game-version labels match Forever.
- Commit and push the intended revision and tag only after manual confirmation. CurseForge packages that revision and substitutes the version.

Source and alpha packages retain protected-action diagnostics. Beta and release packages disable the diagnostic handler through `--@alpha@` markers. Zipping raw source retains diagnostics and does not substitute the version token. The aura-tooltip client setting persists after disabling the addon; restore it with `/console GamepadShowAutoAuraTooltip 1`.

## Maintenance and license

This is an owner-maintained project. External pull requests are not accepted.

The project is licensed under the [MIT License](LICENSE). World of Warcraft and third-party addon names belong to their respective owners. References to game-provided artwork and APIs do not grant rights to those external assets.

## Repository Rules

- Treat “my other addon” as a reference to [UITweaks](https://github.com/ivribalko/UITweaks).
- Require explicit manual confirmation before creating or amending commits and before pushing.
- Start commit messages with a lowercase past-tense verb.
- Keep secrets and personal configuration out of tracked files.
- Do not build, install, or launch applications for verification unless explicitly requested.
- Do not take screenshots without explicit approval.
- Keep the reload button small and icon-only.
- Check the WoW UI source on GitHub in the `forever` branch before implementing or debugging game UI changes.
- If a fix fails on the first attempt, consult the relevant WoW UI source in the `forever` branch again before attempting another fix.
- Do not read secret aura IDs or mutate Blizzard aura queues from addon hooks; use the native automatic-tooltip setting.
