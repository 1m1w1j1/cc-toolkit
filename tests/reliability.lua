-- Run from Computercraft-GUI: luajit tests/reliability.lua
package.path = './?.lua;' .. package.path
local passed = 0
local function test(name, fn)
 local ok, err = pcall(fn)
 if not ok then error(name .. ': ' .. tostring(err), 0) end
 passed = passed + 1
 print('PASS ' .. name)
end
colors = setmetatable({}, {__index = function() return 1 end})
colours = colors
_HOST = 'ComputerCraft 1.120.2 (Minecraft 1.20.1)'
os.version = function() return 'CraftOS 1.9' end
local Turtle = require('lib.clsTurtle')
test('standalone library splits literal dots before GUI loads', function()
 assert(mcMajorVersion == 1.2 and mcMinorVersion == 1)
 local parts = Turtle:split('a.b.c', '.')
 assert(#parts == 3 and parts[2] == 'b')
end)
test('refuse respects all three drop directions', function()
 for _, direction in ipairs({'forward','up','down'}) do
  local calls = {}
  turtle = {drop=function() calls.forward=true end, dropUp=function() calls.up=true end,
   dropDown=function() calls.down=true end, select=function() end}
  local t = Turtle(false)
  t.getSlotContains = function(_, slot) if slot == 1 then return 'minecraft:gravel', 1 end return '',0 end
  t:dumpRefuse(direction, 0)
  assert(calls[direction])
  calls[direction] = nil
  assert(next(calls) == nil)
 end
end)
local Events = require('lib.Events')
test('callbacks can unhook themselves without skipping the next callback', function()
 local e, calls = Events(false), {}
 local first
 first = function() calls[#calls+1]='a'; e:unhook('click',first) end
 e:hook('click',first)
 e:hook('click',function() calls[#calls+1]='b' end)
 e:invoke('click'); e:invoke('click')
 assert(table.concat(calls) == 'abb')
end)
local V = require('lib.Vector2')
test('zero vector stays finite', function() local v=V(); v:normalise(); assert(v.x==0 and v.y==0) end)
local U = require('lib.TurtleUtils')
_G.U = U
keys = {getName=function(code) return code end}
test('timeout starts before waiting and ignores unrelated timers', function()
 local starts=0; local queue={{'timer',99},{'timer',42}}
 os.startTimer=function() starts=starts+1; return 42 end
 os.pullEvent=function() assert(starts==1); return unpack(table.remove(queue,1)) end
 assert(U.getInput(true,3)==nil and #queue==0 and starts==1)
end)
test('inventory input cancels owned timeout', function()
 local cancelled
 os.startTimer=function() return 42 end
 os.cancelTimer=function(id) cancelled=id end
 os.pullEvent=function() return 'turtle_inventory' end
 assert(U.getInput(true,3,true)[1]=='turtle_inventory' and cancelled==42)
end)
test('farm scans compare values and order', function()
 assert(U.sameSequence({'s','s','',''},{'s','s','',''}))
 assert(not U.sameSequence({'s','','s',''},{'s','s','',''}))
end)
local P = require('lib.Project')
test('craft quantities round up to recipe output', function()
 local p=setmetatable({ratio=4},P); p:setQuantity(7); assert(p.quantity==8)
end)
local Textbox = require('lib.ui.Textbox')
test('deleting past beginning empties textbox',function()
 local t=setmetatable({text='abc'},Textbox); t:removeEndChars(5); assert(t.text=='')
end)
local Log = require('lib.Log')
test('trace logging passes text rather than the logger object',function()
 local log=setmetatable({},Log); local lines={}
 log.appendLine=function(_,line) assert(type(line)=='string'); lines[#lines+1]=line end
 log:writeTraceTable('trace',7); assert(lines[1]=='trace' and lines[2]=='    7')
end)
local EM = require('lib.EntityMgr')
test('removed entity does not receive another update',function()
 local em=EM(); local removed=false
 em.entities={{remove=true, enabled=true, started=true,onRemove=function() removed=true end,
 update=function() error('removed entity updated') end}}
 em:update(); assert(removed and #em.entities==0)
end)
test('backward fallback moves only remaining distance',function()
 local backward, forward, turns = 0,0,0
 turtle={select=function() end, back=function() backward=backward+1; return backward==1 end,
 forward=function() forward=forward+1; return true end, dig=function() return true end,
 turnRight=function() turns=turns+1 end}
 local t=Turtle(false); t.refuel=function(_,n) assert(n==3) end
 local moved=t:doMoves(3,'back')
 assert(moved==3 and forward==2 and turns==4)
end)
test('out of fuel stops movement retries',function()
 turtle={select=function() end,forward=function() return false,'Out of fuel' end,
 detect=function() return false end,getFuelLevel=function() return 0 end}
 local t=Turtle(false); t.refuel=function() end
 local moved,err=t:doMoves(1,'forward'); assert(moved==0 and err=='Out of fuel')
end)
test('persistent blockage has a retry limit',function()
 local tries=0
 turtle={select=function() end,forward=function() tries=tries+1; return false,'Blocked' end,
 detect=function() return false end,dig=function() return false,'Nothing to dig' end,
 getFuelLevel=function() return 100 end}
 local t=Turtle(false); t.refuel=function() end; t.attack=function() end
 local moved,err=t:doMoves(1,'forward'); assert(moved==0 and err=='Blocked' and tries==31)
end)
test('unlimited fuel does not compare a string with a number',function()
 turtle={getFuelLevel=function() return 'unlimited' end}
 assert(Turtle:refuel(15)==false)
end)
local Bar = require('lib.ui.ContentBar')
test('inventory bar uses supplied height rather than screen position',function()
 local bar=Bar('inventory',2,10,9,3)
 assert(bar.size.y==3 and #bar.slots==27)
end)
print(passed .. ' reliability checks passed')
