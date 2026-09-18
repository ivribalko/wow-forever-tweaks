# Architecture

- `ForeverTweaks.toc` declares addon metadata and loads the Lua entry point.
- `ForeverTweaks.lua` creates a button parented to the native minimap, anchors it to the top-right corner, and calls the game's reload API directly from a mouse click.
- At login, `C_CVar.SetCVar` disables `GamepadShowAutoAuraTooltip`. Blizzard then skips its automatic aura-popup queue. No aura data is read or native queue mutated, and manual tooltip inspection remains available. The CVar persists in client settings.
- `Reload.tga` supplies the circular-arrow artwork for the normal and pressed states.
- The existing chat ticker hides regions listed by Blizzard's `CHAT_FRAME_TEXTURES`, covering new windows and hover backgrounds without calling chat-setting APIs or generating configuration events.
- The one-shot chat layout callback also anchors `ChatFrame1` to `UIParent` at bottom-left with offsets of 32 horizontally and 36 vertically, keeping native side controls and the input box on-screen.
- A single login-started 0.1-second ticker scans Blizzard's `CHAT_FRAMES` list and sets each tab's alpha from its hover state, matching UITweaks and covering newly created tabs without replacing native chat methods.
- A one-shot `PLAYER_ENTERING_WORLD` handler defers `ChatFrame1:SetHeight(360)` until the next timer tick, after initial layout. It installs no resize hooks and does not change chat background settings.
- `PlayerFrameXP.lua` adds event-driven XP percentage text to the player name row and reserves name width while XP is available. Player-art hooks refresh vehicle visibility. A container update script masks XP artwork and mouse input, including borders and dividers while XP is selected, without hooking bar assignment or animation methods.
- Addon-load and login events hide `PTR_IssueReporter`; an `OnShow` hook keeps the floating panel hidden if the beta UI reopens it.
- A post-hook on `PopFrameAttachedSurvey` hides the separate quest feedback survey, with an `OnShow` hook for subsequent openings. It does not submit feedback or hide the quest frame.
- Combat, login, world-entry, and addon-load events apply 0.4 or 0.7 alpha to `PlayerFrame`, `TargetFrame`, `GamepadMainActionBarFrame`, `PlayerCastingBarFrame`, and `GamepadPlayerCastingBarFrame`. Show hooks reapply the current alpha when these frames reopen; the gamepad parent covers its main and override bars. Guarded cast-bar `SetAlpha` post-hooks scale native opacity writes without compounding them. Native hold/fade animation endpoints use the same combat opacity because animation alpha bypasses `SetAlpha`.
- `AGENTS.md` contains project usage and repository rules; `README.md` is a relative symbolic link to it.

The button follows the minimap's position, scale, and visibility. Protected-action events retain bounded diagnostics in client-managed SavedVariables for investigating blocked quest and menu actions.
