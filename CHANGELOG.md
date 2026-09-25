# Changelog

## Unreleased

- Restricted the quest-order diagnostic and diagnostic SavedVariables declaration to source and alpha packages.
- Doubled chat height upward from its existing bottom edge and instantly showed/hid the original background and frame on native gamepad chat focus changes without easing, restoring the previous size and anchors on exit.
- Removed the forced chat window height and position.
- Hid the chat input channel label and its suffixes when focus closes, including after canceling a draft with gamepad Circle/Back.

- Made chat input expand to the right as drafts grow, shrinking when text is removed and stopping near the screen edge.
- Enabled item tooltips in controller menus at login and UI reload.
- Added automatic `GamePadFactionColor = 0` at login and UI reload.
- Added an attempt to remove the controller-to-mouse overlap delay for external touchpad mouse mappers. This currently does not work: the client retains `2000` despite successful writes.
- Added automatic selected-recipe output tooltips with equipped-item comparisons in the profession window; in-game validation is pending.
- Made chat input backgrounds show immediately on focus and hide on close, including IM-style input, while keeping colored focus borders hidden.
- Removed addon-driven classic chat activation and sticky-channel writes to address protected gamepad interact-target errors after sending chat. Input activation and channel retention follow native behavior; in-game verification is pending.
- Set chat messages to begin fading after 30 seconds.
- Cleared unsent chat text when pressing gamepad Back.
- Corrected native watch insertion order so quest levels display ascending, with equal-level order preserved.
- Applied quest-level ordering to the complete native watch list so lower-level quests can appear ahead of quests previously hidden by tracker overflow. Native watch APIs replace tracker-method overrides; reordering waits until combat ends and preserves final watch membership and the super-tracked quest. In-game validation is pending.
- Added automatic highest-learned-rank upgrades for action-bar spells, including heals and buffs. Generated macros use rankless spell names; recognized spell references in custom character and account macros also have explicit ranks removed.
- Disabled native gamepad touchpad cursor control for use with an external mouse mapper.
- Added movement-based gamepad camera turning for autorun, returning to the native While moving setting when stopped.
- Removed Quest Next and Quest Prev macros and their quest-cycling commands.
- Named generated attack macros `+`, with automatic renaming of existing unedited attack macros.
- Added maximum HP beside the level in friendly and hostile unit tooltips, including controller soft targets, using native formatting for secret health values.
- Added automatic harmful-spell macro conversion for keyboard and controller action bars, starting autoattack in combat on button presses, with `/ftattack restore` to restore original spells.
- Added automatic junk selling and repairs using personal gold at merchants.
- Matched the reload button to the minimap day/night indicator with a native circular rim and refresh symbol.
- Added a minimap reload button.
- Simplified chat backgrounds and tabs.
- Added combat fades for player, target, casting, and action bars.
- Displayed XP percentage beside the player name.
- Added controller shortcuts for the map and inventory.
- Disabled automatic gamepad aura popups and hid beta feedback panels.
- Added an addon-list icon and tag-based CurseForge packaging.
- Kept protected-action diagnostics in source and alpha packages only.

In-game acceptance testing of the packaged addon on Forever beta is pending.
