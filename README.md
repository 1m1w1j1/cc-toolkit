# CC Toolkit

A consolidated ComputerCraft / CC: Tweaked turtle toolkit based on **Inksaver's Computercraft-GUI and Minecraft-Toolkit**. Includes the GUI, shared libraries, task modules, and command-line utilities in one release.

## Install or update

On your turtle, from the directory where you want the launch commands installed:

```lua
wget https://raw.githubusercontent.com/1m1w1j1/cc-toolkit/main/update.lua update.lua
update
```

If `update.lua` already exists, run `update` directly. This same file installs a fresh turtle or fetches a newer release. Start the GUI with:

```lua
tk3
```

HTTP must be enabled. The updater reports required free disk space before downloading the application. A staged release and the previous installed release must fit on the turtle; adjust the server's computer storage limit if necessary.

## How updates work

`update.lua` is self-contained. It fetches `release.json`, downloads the complete immutable release named in that manifest, checks byte counts and checksums, and compiles every Lua file before activation. Downloads use HTTPS; checksums detect incomplete or corrupted files, not malicious repository changes.

Files are staged under `.cc-toolkit/releases/`. The active-release pointer is switched only after every file passes. Failed downloads, writes, integrity checks, or activation leave the previous release selected. Old releases are retained. Launch commands and the active pointer retain a `.previous` recovery copy.

Application data stays in the install directory, outside release folders. Launchers run the selected program with that directory as its working directory, while CC: Tweaked resolves its modules relative to the selected program. Each launch restores the globals it changed when it exits. A task failure records `last-error.txt`; inspect the turtle's position before starting another task. Physical tasks are never automatically replayed.

To roll back, save the current pointer elsewhere, then replace `.cc-toolkit/current` with the contents of `.cc-toolkit/current.previous`. Do this while no toolkit task is running. Keep previous release directories until you are satisfied with the new version.

## Changes

- Fixed the `split` load-order failure and malformed `elselib` disposal branch.
- Fixed task callback typos, farm scan comparisons, GUI callbacks, input timers, and UI helpers.
- Extracted task implementations into farming, fluids, building, excavation, and utilities modules while retaining their public function names.
- Added a task execution boundary: failed shared movement stops the task and records partial progress.
- Consolidated `b`, `d`, `f`, and `u` into one bounded movement implementation with backward-orientation recovery.
- Added explicit storage discovery, stock totals across containers, contextual peripheral failures, and accounting for partial transfers.
- Indexed static recipe lookups and return recipe copies to avoid shared mutation. Inventory snapshots are scoped to one operation so transfers and peripheral changes cannot leave a long-lived stale cache.
- Added component-based version checks and unlimited-fuel handling.
- Buffered GUI frames and emit only changed rows.
- Replaced per-file live-branch updates with checked, immutable releases.

## Validation and limits

Local regression checks use simulated ComputerCraft APIs under LuaJIT. They cover failure handling and helper behavior, not Minecraft world physics. In-game acceptance remains necessary for task geometry, chunk unloading, server protection rules, mod recipes, and live peripherals. Some low-level turtle calls inside algorithms intentionally probe the world and can return false; the task boundary enforces failures reported by shared movement, not every individual probe.

```sh
python3 tests/audit.py
luajit tests/reliability.lua
luajit tests/runtime.lua
luajit tests/installer.lua
luajit tests/tasks.lua
python3 tools/build_release.py
```

Commit the generated `release.json` and new `releases/<id>/` directory together. A release ID is derived from its filenames and contents. Never modify an existing release directory.

## Attribution

Original toolkit, GUI, documentation, and task algorithms by **Inksaver**:

- https://github.com/Inksaver/Computercraft-GUI — baseline `4b6019a`
- https://github.com/Inksaver/Minecraft-Toolkit — baseline `88646b1`

Original attribution comments are preserved. This rebuild does not claim authorship of the original code or assign a new license to it.

API reference: https://tweaked.cc/
