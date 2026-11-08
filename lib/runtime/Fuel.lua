local Fuel={}
function Fuel.level()
 local value=turtle.getFuelLevel()
 return value=='unlimited' and math.huge or value
end
function Fuel.limit()
 local value=turtle.getFuelLimit()
 return value=='unlimited' and math.huge or value
end
return Fuel
