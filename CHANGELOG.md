# Changelog

- Kept the native Bind-panel Quick Menu hint visible while Share is held and the binding picker is open.

- Restored the Quick Menu hint inside the native Bind bottom panel as an unprotected visual-only child, with polling for background bounds and no native layout hooks.

- Re-enabled the quick wheel with secure visibility flags instead of protected proxy children attached to native panels.

- Replaced the Bind hint’s native prompt template with plain addon-owned artwork and screen-coordinate placement, removing native icon callback registration and footer anchor dependencies.

- Added bounded native-field taint ownership captures for protected Bind/interact failures in source and alpha packages.

- Removed native focus-manager, controller-panel diagnostic, and stance-update method hooks from the Bind/interact call path; existing sampling and events observe changes.

- Removed the Quick Menu hint’s native footer layout hook and resizing; its independent panel sits beside the Bind footer.

- Removed instance hooks on native Bind entry and exit methods to avoid taint when reopening the picker.

- Moved Square removal into the normal quick wheel and removed standalone edit mode; native Bind remains the assignment path.

- Fixed native confirmation dialogs stretching toward the screen bottom by excluding quick-wheel visibility blockers from native layout sizing.

- Gave the empty reserved quest slot a dimmed native quest exclamation icon, distinct from empty custom slots.

- Simplified the normal quick-wheel hint to the native triangle-button icon and Edit, dimmed during combat; edit mode uses the native square-button icon and Remove.

- Fixed quick-wheel combat errors from restricted spell cooldown values by using native duration objects for spell and resolved spell-macro countdowns.

- Reserved the top quick-wheel slot for the selected tracked quest’s usable item, with native quest cooldowns and seven custom slots. Item changes wait until combat ends; existing top bindings are preserved.

- Preserved the Share click binding throughout slot assignment so releasing the opening hold assigns and closes the picker.

- Changed quick-wheel binding to hold Share, aim at a slot, and release Share to assign without X; recentering retains selection and Circle cancels.

- Added native cooldown fill and countdown text to quick-wheel item, ability, and resolved macro slots.

- Fixed the protected SetID error with a secure selection sampler shared by combat and normal use. The last highlighted slot remains selected after recentering and activates on Share release in both modes.

- Fixed combat quick-wheel blocking from idle IM chat by tracking native chat-focus footers instead of persistent chat windows and edit boxes.

- Added hold-Share activation: hold Share to open, aim the right stick, and release Share to activate in or out of combat; the last selected slot stays highlighted after recentering and activates on release. Removed X activation from the normal wheel; X remains available for slot assignment in edit mode.

- Removed stick-recenter activation after the client rejected its protected item-use call outside combat; retained physical X confirmation.

- Added right-stick recenter activation outside combat; combat activation and slot assignment retain button confirmation.

- Enabled quick-wheel opening, closing, and item/spell/macro activation in combat through secure handlers; hold the right stick toward a slot while confirming. Editing remains outside combat.

- Moved the Share quick-menu hint inside the native bottom button-hints panel, including its background and row layout.

- Added Share-to-wheel binding for native macros, with macro icons, secure activation, and saved identity resolution after macro index changes.

- Added a Share quick-wheel destination to the native item/spell Bind menu, with right-stick slot selection, X assignment, Square removal, and controller editing from the wheel.

- Excluded the quick wheel from fullscreen-menu discovery by replacing its special-frame registration with temporary Escape bindings in normal and edit modes.

- Positioned the quick wheel on the left as a mirror of the native right-hand radial menu.

- Fixed quick-wheel initialization by anchoring secure buttons to the wheel frame and preventing callbacks or repeated construction after incomplete setup.

- Added a customizable eight-slot item and ability wheel using native gamepad menu artwork, opened by unused Share input outside combat, with per-character saved entries and drag-and-drop editing.

- Changed action-button cooldown timers to native single-value units instead of minutes and seconds together.
- Positioned the reload and compact action-bar buttons side by side below the minimap.
- Restored the minimap reload button beside the compact action-bar toggle.
- Removed automatic repairs and junk selling at merchants.
- Replaced the minimap reload button with an icon to toggle the native compact gamepad action-bar setting outside combat.
- Changed L1+R1+X to Invite Target for a selected friendly player, with a matching helper label; retained leave-group confirmation otherwise.

- Removed maximum HP from unit tooltips.

- Isolated the leave-group helper prompt from native legend tables and removed writes to native targeting state to address controller interact-target taint.

- Added L1+R1+X leave-group confirmation and a matching entry in the top-left controller shortcuts helper.
- Expanded gamepad-focused chat upward to match its top screen margin to its bottom margin.

- Removed addon touchpad click bindings for the world map and inventory.

- Separated L2/R2 click targets to avoid overlapping trigger presses sharing button release tracking.

- Removed combat-panel button sizing, positioning, frame-level changes, background highlighting, and action-button click hooks; retained secure panel routing and compact visibility.

- Changed level-badge XP to a hollow gold and blue progress ring inset beneath the outer rim.

- Used the native standalone circular mask to clip XP fills inside the level badge.

- Replaced player XP text with gold earned-XP and blue rested-XP radial fills with a sharp start boundary at the top inside the circular level badge and restored the native name line.

- Excluded helpful spells from attack-macro conversion and restored their unedited generated macros to spell buttons before freeing the macro slots.

- Consolidated duplicate generated attack macros while preserving action-bar assignments, recovered missing generated-macro ownership, and reused identical commands across ranks and normalized line endings before allocating slots.

- Restored open regular and Battle.net friend whisper tabs across UI reloads, excluding closed tabs and clearing history on fresh login.

- Added an Instance chat tab with party, raid, and instance messages, including leaders and raid warnings, creating it only when missing.
- Restored combat panel routing after R1/L1 targeting panels close, with guards for overlapping native overrides.

- Stopped addon geometry updates in multi-panel mode to prevent scale oscillation against native focus updates; multi-panel enlargement follows native focus.

- Fixed restricted button anchoring by using explicitly protected child anchors instead of native bar handles.

- Added native-size active-panel scaling in compact mode and selected-panel background highlighting through secure geometry updates and texture-only changes, preserving native spell-button methods. Multi-panel scaling of the combat-swapped selection is unsupported because native focus resizing conflicts with addon geometry.

- Moved combat visibility handling to explicitly protected child frames so native bar refreshes retain the selected panel.
- Added bounded source/alpha controller-panel diagnostics for native refreshes, secure trigger state, and visibility before/after corrections.
- Reapplied compact-panel visibility after native refreshes in combat without changing spell-button functions or styles.
- Preserved the remaining held trigger when releasing one side of L2+R2, so releasing R2 leaves L2 active.
- Removed calls to native active-panel styling methods after they tainted button functions called before `UseAction`; compact scaling and background highlighting use separate geometry/texture updates.
- Refreshed controller panels after native form-bar updates outside combat, using the active native stance override.
- Swapped the default and held-R2 controller panels during combat using secure click bindings; in-game validation is pending.
- Added chat message restoration after UI reload, retaining up to 120 messages per permanent tab.
- Show all addon-hidden native chat artwork during gamepad expansion, including every tab in the expanded dock and input focus borders.
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
