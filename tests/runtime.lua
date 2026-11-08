package.path='./?.lua;'..package.path
local n=0
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local Version=require('lib.runtime.Version')
test('integer version comparison handles 1.9, 1.20, and 26.1',function()
 assert(not Version.atLeast(Version.parse('1.9.4'),1,18))
 assert(Version.atLeast(Version.parse('1.20.1'),1,18))
 assert(Version.atLeast(Version.parse('26.1'),1,18))
end)
local Storage=require('lib.runtime.Storage')
local inventories={chest={[1]={name='stone',count=3}},barrel={[2]={name='stone',count=5}}}
peripheral={getNames=function() return {'chest','barrel'} end,hasType=function() return true end,
call=function(name,method) if method=='list' then return inventories[name] end;return 2 end}
test('storage count includes chest and barrel',function() assert(Storage.count('stone')==8) end)
test('partial transfers return actual count',function() assert(Storage.transfer({'chest','barrel'},'target','stone',7)==4) end)
test('detached peripheral yields contextual failure',function()
 local original=peripheral.call;peripheral.call=function() error('Detached') end
 local ok,err=pcall(Storage.count,'stone');peripheral.call=original
 assert(not ok and tostring(err):find('Storage',1,true))
end)
local Movement=require('lib.runtime.Movement')
test('legacy backwards failure restores orientation',function()
 local turns=0
 turtle={back=function() return false,'Blocked' end,forward=function() return false,'Blocked' end,
 dig=function() return false,'Unbreakable block detected' end,getFuelLevel=function() return 100 end,
 turnRight=function() turns=turns+1;return true end}
 sleep=function() end
 local moved=Movement.run(4,true,'backwards');assert(moved==0 and turns==4)
end)
_HOST='ComputerCraft 1.120.2 (Minecraft 1.20.1)';os.version=function() return 'test' end
local T=require('lib.clsTurtle');local Task=require('lib.runtime.Task')
fs={open=function() return {write=function() end,close=function() end} end}
test('failed movement stops the task before later actions',function()
 local continued=false
 turtle={select=function() end,forward=function() return false,'Out of fuel' end,
 detect=function() return false end,getFuelLevel=function() return 0 end}
 local t=T(false);t.refuel=function() end
 local result=Task.run('blocked',function() t:forward(1);continued=true end)
 assert(not continued and not Task.active and result[1]:find('stopped',1,true))
end)
local Render=require('lib.runtime.Render')
test('renderer skips unchanged rows and redraws changed rows',function()
 local writes=0;local text='hello'
 local parent={getSize=function() return 5,1 end,setCursorPos=function() end,
 blit=function() writes=writes+1 end,setCursorBlink=function() end,
 setTextColor=function() end,setBackgroundColor=function() end}
 local current=parent
 term={current=function() return current end,redirect=function(next) local old=current;current=next;return old end}
 window={create=function() return {getLine=function() return text,'00000','fffff' end,
 getCursorPos=function() return 1,1 end,getCursorBlink=function() return false end,
 getTextColor=function() return 1 end,getBackgroundColor=function() return 32768 end} end}
 Render.draw(function() end);Render.draw(function() end);assert(writes==1)
 text='world';Render.draw(function() end);assert(writes==2 and current==parent)
 local ok=pcall(Render.draw,function() error('draw failed') end)
 assert(not ok and current==parent)
end)
print(n..' runtime checks passed')
