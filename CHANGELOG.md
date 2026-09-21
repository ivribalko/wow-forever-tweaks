# Changelog

## Unreleased

- Cleared unsent chat text when pressing gamepad Back while retaining the selected chat channel.

- Raised the bottom-left chat window to leave space for the gamepad button-hint panel.

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
- Simplified chat backgrounds and tabs, with a taller bottom-left chat layout.
- Added combat fades for player, target, casting, and action bars.
- Displayed XP percentage beside the player name.
- Added controller shortcuts for the map and inventory.
- Disabled automatic gamepad aura popups and hid beta feedback panels.
- Added an addon-list icon and tag-based CurseForge packaging.
- Kept protected-action diagnostics in source and alpha packages only.

In-game acceptance testing of the packaged addon on Forever beta is pending.
