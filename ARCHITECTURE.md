# Architecture

- `ForeverTweaks.toc` declares addon metadata and loads the Lua entry point.
- `ForeverTweaks.lua` creates a button parented to the native minimap, anchors it to the top-right corner, and calls the game's reload API directly from a mouse click.
- At login, `C_CVar.SetCVar` disables `GamepadShowAutoAuraTooltip`. Blizzard then skips its automatic aura-popup queue. No aura data is read or native queue mutated, and manual tooltip inspection remains available. The CVar persists in client settings.
- `Reload.tga` supplies the circular-arrow artwork for the normal and pressed states.
- Addon-load and login events hide `PTR_IssueReporter`; an `OnShow` hook keeps the floating panel hidden if the beta UI reopens it.
- A post-hook on `PopFrameAttachedSurvey` hides the separate quest feedback survey, with an `OnShow` hook for subsequent openings. It does not submit feedback or hide the quest frame.
- Combat, login, world-entry, and addon-load events apply 0.4 or 0.7 alpha to `PlayerFrame`, `TargetFrame`, `GamepadMainActionBarFrame`, `PlayerCastingBarFrame`, and `GamepadPlayerCastingBarFrame`. Show hooks reapply the current alpha when these frames reopen; the gamepad parent covers its main and override bars. Guarded cast-bar `SetAlpha` post-hooks scale native opacity writes without compounding them. Native hold/fade animation endpoints use the same combat opacity because animation alpha bypasses `SetAlpha`.
- `AGENTS.md` contains project usage and repository rules; `README.md` is a relative symbolic link to it.

The button follows the minimap's position, scale, and visibility. No background updates are needed. Protected-action events retain bounded diagnostics in client-managed SavedVariables for investigating blocked quest and menu actions.
