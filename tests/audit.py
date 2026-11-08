"""Compile every Lua source without executing it and check task callback names.
Run from any directory: python3 tests/audit.py. Requires LuaJIT in PATH.
"""
import json
from pathlib import Path
import re
import subprocess
import sys
root = Path(__file__).resolve().parents[1]
roots = [root]
errors = []
files = sorted(p for folder in roots for p in folder.rglob('*.lua'))
for path in files:
    code = 'local f,e=loadfile(' + json.dumps(str(path)) + '); if not f then io.stderr:write(e); os.exit(1) end'
    result = subprocess.run(['luajit', '-e', code], capture_output=True, text=True)
    if result.returncode:
        errors.append(result.stderr)
main = (root / 'tk3.lua').read_text() + '\n' + '\n'.join(p.read_text() for p in (root/'tasks').glob('*.lua'))
definitions = set(re.findall(r'^function\s+(\w+)\s*\(', main, re.M))
callbacks = re.findall(r'\bcall\s*=\s*(\w+)', (root / 'lib/data/taskInventory.lua').read_text())
for name in callbacks:
    if name not in definitions:
        errors.append('Undefined task callback: ' + name)
for err in errors:
    print(err)
print(f'{len(files)} Lua files compiled; {len(callbacks)} task callback references checked; {len(errors)} errors')
sys.exit(bool(errors))
