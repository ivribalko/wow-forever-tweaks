# Forever Tweaks

A lightweight quality-of-life addon for World of Warcraft Forever.

## Features

- Automatically sells junk and repairs items at merchants.
- Adds a small circular-arrow button at the minimap’s top-right corner to reload the interface.
- Automatically creates Quest Next and Quest Prev macros to cycle the active quest among visible tracker entries.
- Removes chat backgrounds and borders, shows chat tabs only on hover, and places a taller chat window at the bottom-left.
- Smoothly fades player and target frames, cast bars, and gamepad action bars between 40% opacity outside combat and 70% in combat.
- Shows XP progress as a gold percentage beside the player name and hides the original XP artwork.
- Binds controller inputs for the world map and inventory; PlayStation touchpad sides require the local mapping described below.
- Disables automatic gamepad buff popups while keeping manual buff inspection available.
- Hides the floating beta Issue Reporter and automatic quest-reward feedback surveys.
- Captures protected-action diagnostics in source and alpha packages for troubleshooting.

## Usage

- Opening a merchant sells gray-quality items with vendor value and repairs all items using personal gold when the merchant offers repairs and the full cost is affordable. Sale proceeds can fund repairs during the same visit. Guild funds are not used; locked stacks are skipped by the classic bag-selling fallback.
- Supports WoW Forever beta 1.60.1 (`16001`).
- Place the `ForeverTweaks` folder in the client’s `Interface/AddOns` directory and enable Forever Tweaks in the AddOns menu.
- The minimap reload button uses a native refresh symbol and the same circular rim as the day/night indicator. The AddOns list uses the bundled circular-arrow artwork.
- Restart the game if the newly created addon is absent from the list.
- The button has no text, configuration, or external dependencies.
- The PlayStation controller's left touchpad click toggles the world map through `PADPADDLE1`; its right touchpad click toggles inventory through `PAD6`. A local `WTF/GamePadConfig_*.json` mapping assigns the left-side input to `PADPADDLE1` and the right-side input to `PAD6`; restart the game after changing that mapping. The addon bindings last only while enabled.
- `Quest Next` and `Quest Prev` are account-wide macros created at login, using `/ftnextquest` and `/ftprevquest`. They cycle only quests currently visible in the native tracker, in displayed order, and wrap at either end. Hidden, collapsed, and overflow entries are skipped; an empty or hidden tracker leaves the active quest unchanged. Existing macros with those names are updated. Macro creation waits until combat ends and retries when space becomes available; no setup button is added.
- Chat backgrounds and decorative borders, including side-button backgrounds, are hidden even on hover. Chat text and controls remain visible; saved background settings are not changed.
- Chat is anchored at the bottom-left after login or UI reload, with space for its side buttons and input box.
- Chat tabs are invisible until individually hovered, matching UITweaks, including newly opened tabs. They remain clickable.
- The main chat window and its docked tabs are set to 360 UI units tall, three times the default, once after login or UI reload. Later native layout changes may override this height.
- Automatic gamepad aura popups are disabled through `GamepadShowAutoAuraTooltip`, including Plainsrunning stack popups. Manual buff inspection remains available. This client setting persists if the addon is disabled; restore it with `/console GamepadShowAutoAuraTooltip 1`.
- Player and target frames, the player cast bar, and the gamepad action bars are 40% visible outside combat and 70% visible in combat.
- Combat opacity transitions use a shared 0.45-second cosine ease.
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
- Complete in-game acceptance checks before a Release tag, including reload, quest macros, chat, combat fades, XP display, and controller shortcuts. Verify the published file’s game-version labels match Forever.
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
