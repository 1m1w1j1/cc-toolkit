> Historical initial audit of the upstream clones. The subsequent consolidated rebuild addresses the listed implementation work; see README.md for current behavior and ACCEPTANCE.md for outstanding in-game validation. References below describe the pre-rebuild state.

# Toolkit reliability review — 2026-11-08

## Scope and evidence

Baseline: Computercraft-GUI `4b6019a`; Minecraft-Toolkit `88646b1`.
All 45 application Lua files in both repositories were included in the syntax survey. All 93 GUI task callback references were checked against their definitions. Focused manual review covered startup/update code, shared turtle movement and inventory helpers, task dispatch, farm recovery, events, scene/entity management, UI helpers, and legacy commands. This is a repository-wide static survey plus targeted repairs, not a claim that every building/farming algorithm or mod recipe has been validated in Minecraft.

Validation: 19 regression checks pass with simulated ComputerCraft APIs under LuaJIT. The syntax survey, including the regression file, checks 46 Lua files. These checks do not simulate Minecraft geometry, chunk unloading, server protections, modded peripherals, or the complete CraftOS runtime.

Run from this directory:

```sh
python3 tests/audit.py
luajit tests/reliability.lua
```

## Repairs

| Area | Defect and correction |
| --- | --- |
| Standalone turtle library | Lowercase `split` depended on a different module loading first. A private splitter is now defined before version parsing. |
| Refuse disposal | `elselib.setLocation()` was an undefined global call inside a malformed branch. Forward/up/down now select the corresponding drop operation. This matches the supplied screenshot. |
| Bootstrap | Required `TurtleUtils` before downloading missing dependencies. Dependency loading now follows successful file installation; startup stops if required files could not be obtained. |
| Bootstrap writes | Failed `fs.open` was followed by a write through nil. The write now occurs only with a valid handle. |
| Task dispatch | `convertTeeefarm` and `convertTreeFarm` callbacks did not exist. Both now refer to the defined `convertTreefarm`. |
| Farm recovery | Comparing a scan table with a new table literal always failed. Ordered values are now compared. This fixes branch selection, but real-world route geometry remains unverified. |
| Farm detection | `~= nil ~= nil` made a barrel check always true. Removed the second comparison. |
| Backward movement | After partial success, fallback repeated the entire requested distance. It now moves only the remaining distance. |
| Movement contract | Zero-step `doMoves` returned a boolean where callers expect a count. It now returns zero. Refuelling now receives the requested distance instead of an undefined `steps` global. |
| Movement retries | Forward/up/down obstruction recovery could retry forever. It now returns a failure after 30 retries or zero fuel. Callers must still handle that failure; see remaining work below. |
| Fuel | `refuel` now handles the API's `unlimited` fuel value without comparing a string to a number. |
| Timers | Input timeout starts before waiting, matches only its own timer ID, and cancels the timer on accepted input. It no longer starts another timer for each unrelated event. |
| Events | Dispatch takes a callback snapshot so self-unhooking cannot skip the next handler or call a missing array entry. Changes take effect on subsequent dispatches. |
| Scene/entity lifecycle | Scene pop clears the instance's previous-scene field; removed entities do not receive another update. |
| UI/math | Corrected inventory-bar height, text deletion past the start, and zero-vector normalisation. |
| Craft quantity | Rounding to the recipe output now multiplies by the recipe ratio, not the requested quantity. |
| Logging | Trace logging no longer passes the logger object as the text argument. |
| Manual movement | Two-digit slot selection no longer uses undefined `offset`; placement calls `getSelectedSlot()` instead of passing the function itself. |
| Cobble utility | Inspect failures are checked, chest-emptying result has the correct polarity, and upward mining counts successful digs and yields while waiting. |
| Syntax portability | Replaced invalid string escapes in GetItems and the legacy toolkit. |
| Updates | Download/open failures are reported; files are preserved during replacement; failed rollback stops before cleanup; malformed version strings are handled. A dedicated staging directory replaces the generic `tmp` directory, and recovery leftovers are retained. Removed artificial per-file update delays. |

## Remaining improvements and concrete risks

1. **Propagate movement failures through whole tasks.** `T:go` and many task routines ignore returned movement failures and may continue placing/digging after a blocked move. Bounded retries prevent one hang but do not make those tasks recover safely. Define a task failure result, carry it through nested helpers, stop the task, and record the operation and completed distance. Do not automatically retry whole physical tasks: operations are not generally safe to repeat.
2. **Legacy movement utilities duplicate retry logic.** `b.lua`, `d.lua`, `f.lua`, and `u.lua` retain their own obstruction loops. In particular, failure during backward digging can return before restoring orientation. Consolidate these behind a small shared movement implementation, with orientation and partial-progress tests.
3. **Crafting Project references a missing helper.** `lib/Project.lua` calls `U.findItemInStorage`, which is not defined. Available helpers use separate chest/barrel inventories and have different contracts. Establish the intended storage aggregation behavior before replacing this call. This code also mixes older recipe formats with the current named-field format.
4. **Peripheral changes need explicit recovery.** Storage helpers call wrapped inventories directly and assume they remain attached. Add bounded handling of detach/full-container/partial-transfer results. `U.getItemStock` checks barrels only when no chest matches, so totals can omit stock spread across both types.
5. **Updates still are not transactional releases.** Each file is fetched from a live upstream branch and compared by its first-line numeric version. Successful per-file replacement does not guarantee a compatible complete set after download failures or branch changes. Build one manifest from pinned revisions, validate all staged source, then switch releases with rollback. Disk-full writes and power loss need dedicated failure-injection tests.
6. **Installation paths still fetch upstream.** These local fixes are not published to Inksaver's repositories. Running the unchanged upstream installer does not distribute this local rebuild. Local files must be copied to the turtle or a separate release destination configured.
7. **Avoid shared mutable globals.** `R`, `U`, `T`, events, and task functions have broad shared state. Extract tasks by domain, pass a task context explicitly, and reset task state between runs. Preserve public interfaces while extracting; a wholesale rewrite without behavior coverage would introduce new uncertainty.
8. **Version parsing is brittle.** Minecraft and ComputerCraft versions are parsed using fixed string positions and decimal numbers. Use integer version components and explicit capability detection, including old and newly renamed Minecraft versions.
9. **Efficiency opportunities.** Inventory searches repeatedly scan peripheral contents; item/recipe lookups repeatedly traverse a large static database; GUI redraw clears the entire terminal. Cache static item indexes, reuse inventory snapshots within a single operation, and redraw changed controls. Invalidate inventory snapshots on transfer/inventory/peripheral events rather than keeping stale caches.
10. **World-dependent loops and recipes need in-game coverage.** Long-running farms, fluid work, falling blocks, multi-step structures, protected blocks, and mod-specific recipes cannot be certified by local mocks. Validate representative tasks in a disposable world with blocked movement, empty fuel, full inventory, removed peripherals, and interrupted updates.

## Using the local changes

Both source clones remain in their original directories, with uncommitted changes for review. Nothing has been pushed or installed into Minecraft. Copy changed application files to matching paths in the turtle's computer directory, or prepare a separate release source before using an installer. Keep the two `tests` files and this report on the development machine; they are not runtime dependencies.

API reference used to check fuel and timer behavior: [CC: Tweaked turtle API](https://tweaked.cc/module/turtle.html), [OS API](https://tweaked.cc/module/os.html).
