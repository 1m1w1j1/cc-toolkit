local S={}
function S.call(name, method, ...)
 local ok,result=pcall(peripheral.call,name,method,...)
 if not ok then error('Storage '..tostring(name)..' '..method..' failed: '..tostring(result),0) end
 return result
end
function S.snapshot()
 local result={}
 for _,name in ipairs(peripheral.getNames()) do
  if peripheral.hasType(name,'inventory') then result[name]=S.call(name,'list') end
 end
 return result
end
function S.locations(item, exact, snapshot)
 local locations={}
 for name,contents in pairs(snapshot or S.snapshot()) do
  for _,stack in pairs(contents) do
   if (exact and stack.name==item) or (not exact and stack.name:find(item,1,true)) then
    locations[#locations+1]=name; break
   end
  end
 end
 table.sort(locations)
 return locations
end
function S.count(item, snapshot)
 local total=0
 for _,contents in pairs(snapshot or S.snapshot()) do
  for _,stack in pairs(contents) do if stack.name==item then total=total+stack.count end end
 end
 return total
end
function S.transfer(sources,target,item,requested)
 assert(type(requested)=='number' and requested>=0,'Invalid transfer quantity')
 local sent=0
 for _,name in ipairs(sources or {}) do
  for slot,stack in pairs(S.call(name,'list')) do
   if sent>=requested then return sent end
   if stack.name==item then
    local moved=S.call(name,'pushItems',target,slot,math.min(stack.count,requested-sent))
    assert(type(moved)=='number' and moved>=0,'Invalid transfer result from '..name)
    sent=sent+moved
   end
  end
 end
 return sent
end
return S
