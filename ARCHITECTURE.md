# Architecture

- `ForeverTweaks.toc` declares addon metadata and loads the Lua entry point.
- `ForeverTweaks.lua` creates a button parented to the native minimap, anchors it to the top-right corner, and calls the game's reload API directly from a mouse click.
- `Reload.tga` supplies the circular-arrow artwork for the normal and pressed states.
- `AGENTS.md` contains project usage and repository rules; `README.md` is a relative symbolic link to it.

The button follows the minimap's position, scale, and visibility. No background updates or persisted settings are needed.
