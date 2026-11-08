-- Download this file and run it with CC: Tweaked. No libraries required.
local BASE='https://raw.githubusercontent.com/1m1w1j1/cc-toolkit/main/'
local root=shell.dir()
local state=fs.combine(root,'.cc-toolkit')
local function checksum(data)
 local a,b=1,0
 for i=1,#data do a=(a+data:byte(i))%65521; b=(b+a)%65521 end
 return b*65536+a
end
local function fetch(path)
 local response,err=http.get(BASE..path)
 if not response then error('Download failed: '..path..': '..tostring(err),0) end
 local ok,data=pcall(response.readAll); response.close()
 if not ok then error(data,0) end
 return data
end
local function write(path,data)
 local h,err=fs.open(path,'w'); if not h then error('Cannot save '..path..': '..tostring(err),0) end
 local ok,why=pcall(h.write,data); h.close(); if not ok then error(why,0) end
end
local function read(path)
 local h=fs.open(path,'r'); if not h then return nil end
 local data=h.readAll();h.close();return data
end
local function safe(path)
 return type(path)=='string' and path~='' and not path:find('..',1,true)
  and not path:find('\\',1,true) and path:sub(1,1)~='/' and not path:find(':',1,true)
end
local function replace(path,data)
 local backup=path..'.previous'
 -- Recover an interruption between moving the original and installing the replacement.
 if not fs.exists(path) and fs.exists(backup) then fs.move(backup,path) end
 write(path..'.pending',data)
 if fs.exists(backup) then fs.delete(backup) end
 if fs.exists(path) then fs.move(path,backup) end
 local ok,err=pcall(fs.move,path..'.pending',path)
 if not ok then
  if fs.exists(backup) then fs.move(backup,path) end
  error(err,0)
 end
end
local function main()
 if not http then error('Enable HTTP access in CC: Tweaked first',0) end
 local manifest=textutils.unserializeJSON(fetch('release.json'))
 assert(type(manifest)=='table' and manifest.format==1,'Unsupported release manifest')
 assert(type(manifest.id)=='string' and manifest.id:match('^%x+$'),'Invalid release ID')
 assert(type(manifest.files)=='table' and #manifest.files>0,'Empty release')
 fs.makeDir(state)
 fs.makeDir(fs.combine(root,"lib/data"))
 local release=fs.combine(state,'releases/'..manifest.id)
 local stage=release..'.staging'
 local bytes,seen=0,{}
 for _,file in ipairs(manifest.files) do
  assert(safe(file.path) and not seen[file.path],'Invalid or duplicate release path')
  assert(type(file.size)=='number' and file.size>=0 and type(file.checksum)=='number','Invalid file metadata')
  seen[file.path]=true;bytes=bytes+file.size
 end
 assert(seen['tk3.lua'],'Release has no application')
 local free=fs.getFreeSpace(root)
 if type(free)=='number' and free<bytes+32768 then
  error('Not enough disk space for a complete staged release. Need '..(bytes+32768)..' free bytes; available '..free,0)
 end
 -- A staging directory is never active and can safely be retried.
 if fs.exists(stage) then fs.delete(stage) end
 fs.makeDir(stage)
 for i,file in ipairs(manifest.files) do
  print('Downloading '..i..'/'..#manifest.files..': '..file.path)
  local data=fetch('releases/'..manifest.id..'/'..file.path)
  assert(#data==file.size and checksum(data)==file.checksum,'Integrity check failed: '..file.path)
  if file.path:sub(-4)=='.lua' then
   local fn,err=load(data,'@'..file.path,'t',{})
   assert(fn,err)
  end
  local target=fs.combine(stage,file.path)
  fs.makeDir(fs.getDir(target));write(target,data)
 end
 if fs.exists(release) then
  -- Do not overwrite a possibly running release. Validate it before reuse.
  for _,file in ipairs(manifest.files) do
   local data=read(fs.combine(release,file.path))
   assert(data and #data==file.size and checksum(data)==file.checksum,'Existing release is damaged: '..file.path)
  end
  fs.delete(stage)
 else fs.move(stage,release) end
 -- Stable launchers read the pointer at launch; pointer switch is last.
 for _,entry in ipairs(manifest.commands) do
  assert(safe(entry) and seen[entry],'Invalid launch command')
  local launcher=string.format([=[local args={...}
local root=%q
local state=fs.combine(root,'.cc-toolkit')
local h=fs.open(fs.combine(state,'current'),'r') or fs.open(fs.combine(state,'current.previous'),'r')
assert(h,'Run update.lua to install a release')
local id=h.readAll();h.close()
assert(id:match('^%%x+$'),'Invalid release pointer')
local directory=fs.combine(state,'releases/'..id)
local old=shell.dir()
local before={};for k,v in pairs(_G) do before[k]=v end
shell.setDir(root)
local ok,result=pcall(shell.run,fs.combine(directory,%q),unpack(args))
shell.setDir(old)
local added={};for k in pairs(_G) do if before[k]==nil then added[#added+1]=k end end
for _,k in ipairs(added) do _G[k]=nil end
for k,v in pairs(before) do _G[k]=v end
if not ok then error(result,0) end
return result
]=],root,entry)
  replace(fs.combine(root,entry),launcher)
 end
 replace(fs.combine(state,'current'),manifest.id)
 print('Installed cc-toolkit '..manifest.id..'. Run tk3 to start.')
 print('Previous releases and replaced files are retained for recovery.')
end
local ok,err=pcall(main)
if not ok then printError('Update stopped: '..tostring(err));return false end
return true
