# In-game acceptance checklist

Use a disposable test world before running valuable construction or farming jobs.

1. Fresh install with only `update.lua`; launch `tk3`, choose a task, exit and launch again.
2. Repeat on an advanced and a standard turtle; check keyboard and mouse input, Help/Back navigation, and changing inventory.
3. Test blocked forward/up/down movement, partial backward movement, exhausted fuel, unlimited fuel, and an unbreakable block. Confirm the shared movement failure stops the task before later placement.
4. Repeat a failed legacy backward move and confirm orientation is restored.
5. Put matching items in a chest and barrel; verify combined stock. Test a partially full target and remove a peripheral during transfer. Verify actual transferred counts and a readable failure message.
6. Run representative excavation, building, farming, and fluid jobs; compare positions, orientation, inventory, and outputs with the task descriptions.
7. Interrupt an update during downloads; rerun. The prior release should remain runnable until the complete replacement is activated.
8. Simulate a full disk and verify failed installation leaves the previous release selected and user data intact.
9. Reboot and verify existing startup scripts can invoke the installed launch commands from the install directory.
10. Check `last-error.txt` after a task failure. Do not replay an interrupted task until its physical state has been inspected.

Not yet executed against a Minecraft instance in this workspace.
