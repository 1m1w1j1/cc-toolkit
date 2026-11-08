local source=assert(io.open('update.lua')):read('*a')
local function checksum(data)
 local a,b=1,0;for i=1,#data do a=(a+data:byte(i))%65521;b=(b+a)%65521 end;return b*65536+a
end
local function run(options)
 options=options or {}
 local files={['/home/.cc-toolkit/current']='abc',['/home/tk3.lua']='old launcher',['/home/user-data.txt']='keep'}
 local dirs={['/home']=true,['/home/.cc-toolkit']=true}
 local data='return true\n'
 local manifest={format=1,id='def',commands={'tk3.lua'},files={{path='tk3.lua',size=#data,checksum=checksum(data)}}}
 local env=setmetatable({}, {__index=_G})
 local function normalize(p) return p:gsub('/+','/'):gsub('/$','') end
 env.shell={dir=function() return '/home' end}
 env.print=function() end;env.printError=function() end
 env.textutils={unserializeJSON=function() return manifest end}
 env.http={get=function(url)
  if options.download and url:find('releases/',1,true) then return nil,'Offline' end
  return {readAll=function() if url:find('release.json',1,true) then return '{}' end;return options.corrupt and 'bad' or data end,close=function() end}
 end}
 env.load=function(text,name) return loadstring(text,name) end
 env.fs={
 combine=function(a,b) return normalize(a..'/'..b) end,
 getDir=function(p) return p:match('^(.*)/') or '' end,
 getFreeSpace=function() return options.full and 0 or 10000000 end,
 exists=function(p) return files[p]~=nil or dirs[p]~=nil end,
 makeDir=function(p) dirs[p]=true end,
 open=function(p,mode)
  if mode=='r' then if files[p]==nil then return nil end;return {readAll=function() return files[p] end,close=function() end} end
  if options.write and p:find('.staging/',1,true) then return nil,'Disk full' end
  local content='';return {write=function(s) content=content..s end,close=function() files[p]=content end}
 end,
 delete=function(p) files[p]=nil;dirs[p]=nil;for k in pairs(files) do if k:sub(1,#p+1)==p..'/' then files[k]=nil end end end,
 move=function(a,b)
  if options.activate and a=='/home/.cc-toolkit/current.pending' then error('Injected activation failure') end
  assert(files[b]==nil and not dirs[b],'Destination exists: '..b)
  if files[a] then files[b]=files[a];files[a]=nil
  else
   assert(dirs[a],a);dirs[b]=true;dirs[a]=nil
   local changed={};for k,v in pairs(files) do if k:sub(1,#a+1)==a..'/' then changed[k]=v end end
   for k,v in pairs(changed) do files[b..k:sub(#a+1)]=v;files[k]=nil end
  end
 end}
 local fn=assert(loadstring(source));setfenv(fn,env)
 local result=fn()
 assert(files['/home/user-data.txt']=='keep','User data changed')
 return result,files
end
local count=0
for _,case in ipairs({'download','corrupt','full','write','activate'}) do
 local ok,files=run({[case]=true})
 assert(ok==false and files['/home/.cc-toolkit/current']=='abc',case..' did not preserve prior release')
 count=count+1;print('PASS installer failure: '..case)
end
local ok,files=run()
assert(ok and files['/home/.cc-toolkit/current']=='def')
assert(files['/home/.cc-toolkit/current.previous']=='abc')
assert(files['/home/.cc-toolkit/releases/def/tk3.lua']=='return true\n')
assert(loadstring(files['/home/tk3.lua']))
count=count+1;print('PASS complete release activation and launcher syntax')
print(count..' installer checks passed')
