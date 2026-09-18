# Forever Tweaks

A lightweight World of Warcraft Classic addon with a small icon-only reload button at the minimap's top-right corner. Left-click the circular arrow to reload the interface.

## Usage

- Enable Forever Tweaks in the character selection AddOns menu.
- Restart the game if the newly created addon is absent from the list.
- The button has no text, configuration, or external dependencies.
- The main chat window and its docked tabs are set to 360 UI units tall, three times the default, once after login or UI reload. Later native layout changes may override this height.
- Automatic gamepad aura popups are disabled through `GamepadShowAutoAuraTooltip`, including Plainsrunning stack popups. Manual buff inspection remains available. This client setting persists if the addon is disabled; restore it with `/console GamepadShowAutoAuraTooltip 1`.
- Player and target frames, the player cast bar, and the gamepad action bars are 40% visible outside combat and 70% visible in combat.
- XP progress appears as a gold percentage beside the player name, following UITweaks. The original XP artwork is hidden; other status bars remain available. The percentage hides when XP is disabled, at the level cap, or while the player frame shows a vehicle.
- The floating Issue Reporter panel is hidden.
- The automatic quest-reward feedback survey ("Did you experience any issues?") is hidden without submitting a report.
- Protected-action failures are captured in `ForeverTweaksDiagnostics` SavedVariables, with up to 20 records of addon attribution, action, UI state, and call stack. Reload after reproducing a failure to persist the capture in the client's WTF directory; keep these files outside the repository.

## UI Source Reference

- Search the [WoW UI source, Forever branch](https://github.com/Gethe/wow-ui-source/tree/forever) when investigating game UI behavior.
- [BuffFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua) implements automatic gamepad aura popups: `Update` queues added and updated aura instances through `AddAuraForTooltip`, then `ShowNextAuraForTooltip` displays `BuffFrameTooltip`. The setting is `GamepadShowAutoAuraTooltip`.
- [Blizzard_PTRFeedback_Frames.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_PTRFeedback/Blizzard_PTRFeedback_Frames.lua) creates the floating `PTR_IssueReporter` panel in `CreateMainView`.
- Quest reward feedback is registered in `Blizzard_Reports.lua` and displayed by `PopFrameAttachedSurvey` in `Blizzard_PTRFeedback.lua`. Its separate frame is stored in `PTR_IssueReporter.Data.FrameAttachedSurveyFrames[QuestFrame]`.
- Search for the visible behavior, frame, event, or setting, then trace its callers and load order before choosing a hook. Automatic popups can use a different frame from `GameTooltip`.

## Repository Rules

- Treat “my other addon” as a reference to [UITweaks](https://github.com/ivribalko/UITweaks).
- Require explicit manual confirmation before creating or amending commits and before pushing.
- Start commit messages with a lowercase past-tense verb.
- Keep secrets and personal configuration out of tracked files.
- Do not build, install, or launch applications for verification unless explicitly requested.
- Do not take screenshots without explicit approval.
- Keep the reload button small and icon-only.
- Check the WoW UI source on GitHub in the `forever` branch before implementing or debugging game UI changes.
- Do not read secret aura IDs or mutate Blizzard aura queues from addon hooks; use the native automatic-tooltip setting.
