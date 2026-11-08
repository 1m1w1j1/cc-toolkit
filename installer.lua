-- Compatibility entry point. update.lua itself is the standalone installer.
shell.run('wget', 'https://raw.githubusercontent.com/1m1w1j1/cc-toolkit/main/update.lua', 'update.lua')
shell.run('update.lua')
