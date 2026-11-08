"""Build an immutable, checksummed release from the runtime sources."""
from pathlib import Path
import hashlib,json,zlib,shutil
root=Path(__file__).resolve().parents[1]
files=sorted(p for p in root.rglob('*.lua') if p.parts[len(root.parts)] not in ('tests','releases','tools') and p.name not in ('installer.lua','update.lua','updater.lua'))
h=hashlib.sha256()
for p in files:
 h.update(p.relative_to(root).as_posix().encode()+b'\0'+p.read_bytes())
release_id=h.hexdigest()[:24]
out=root/'releases'/release_id
entries=[]
for p in files:
 data=p.read_bytes();rel=p.relative_to(root).as_posix();target=out/rel
 if target.exists() and target.read_bytes()!=data:raise RuntimeError('Immutable release collision')
 target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
 entries.append(dict(path=rel,size=len(data),checksum=zlib.adler32(data)&0xffffffff))
commands=sorted(p.name for p in files if p.parent==root)
manifest=dict(format=1,id=release_id,files=entries,commands=commands)
(root/'release.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Release {release_id}: {len(entries)} files, {sum(e["size"] for e in entries)} bytes')
