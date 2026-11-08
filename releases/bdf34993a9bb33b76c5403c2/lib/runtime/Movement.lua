-- Non-destructive by default. Bounded retry and orientation restoration.
local M={}
function M.run(count, dig, direction, above, below)
 assert(type(count)=='number' and count>=0 and count%1==0,'Distance must be a non-negative integer')
 local moved, turned, reason=0,false,nil
 local Move=({forwards=turtle.forward,backwards=turtle.back,up=turtle.up,down=turtle.down})[direction]
 local Dig=({forwards=turtle.dig,backwards=turtle.dig,up=turtle.digUp,down=turtle.digDown})[direction]
 assert(Move,'Invalid movement direction')
 local ok,err=pcall(function()
  for step=1,count do
   if above then turtle.digUp() end
   if below then turtle.digDown() end
   local success; success,reason=Move()
   local tries=0
   while not success and dig and tries<30 and turtle.getFuelLevel()~=0 do
    if direction=='backwards' and not turned then
     assert(turtle.turnRight()); assert(turtle.turnRight()); turned=true; Move=turtle.forward
    end
    tries=tries+1
    local dug,why=Dig()
    if not dug and tostring(why):lower():find('unbreakable',1,true) then reason=why; break end
    sleep(0.1)
    success,reason=Move()
   end
   if not success then break end
   moved=moved+1
  end
 end)
 if turned then
  local first=turtle.turnRight(); local second=turtle.turnRight()
  if not first or not second then error('Could not restore orientation',0) end
 end
 if not ok then error(err,0) end
 return moved,reason
end
return M
