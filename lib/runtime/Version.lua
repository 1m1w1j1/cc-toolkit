local V = {}
function V.parse(text)
 local parts = {}
 for n in tostring(text or ''):gmatch('%d+') do parts[#parts+1] = tonumber(n) end
 return parts
end
function V.atLeast(parts, major, minor, patch)
 local target = {major, minor or 0, patch or 0}
 for i=1,3 do
  local n=parts[i] or 0
  if n ~= target[i] then return n > target[i] end
 end
 return true
end
function V.host(host)
 local mc = V.parse(tostring(host):match('Minecraft%s+([%d.]+)'))
 local cc = V.parse(tostring(host):match('ComputerCraft%s+([%d.]+)'))
 assert(#mc >= 2, 'Cannot determine Minecraft version from _HOST')
 return mc, cc
end
return V
