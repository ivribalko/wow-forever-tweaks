# Controller touchpad restore

Run from the repository root, supplying your client's WTF directory:

```sh
python3 tools/restore-touchpad-config.py /path/to/client/WTF
```

The tool backs up and updates `GamePadConfig_ForeverTweaks.json`, preserving unrelated device settings. It maps the left touchpad click to `PADPADDLE1` and the right to `PAD6` for both DualSense (1356:3302) and DualSense Edge (1356:3570). Restart the client afterward.

ForeverTweaks binds `PADPADDLE1` to `TOGGLEWORLDMAP` and `PAD6` to `OPENALLBAGS`. These bindings must also be present to open the map and inventory. The tool restores device mappings only; the addon does not install them automatically.

Controller settings and backups stay outside Git. The `tools` folder is excluded from packaged addon downloads.
