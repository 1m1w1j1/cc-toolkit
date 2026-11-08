package.path='./?.lua;'..package.path
colors=setmetatable({}, {__index=function() return 1 end});colours=colors
for _,group in ipairs({'farming','fluids','building','excavation','utilities'}) do
 require('tasks.'..group)({}, {}, false, 0, false, 'minecraft:nether_bricks')
end
local registry=require('lib.data.taskInventory')
local count=0
for name,task in pairs(registry) do
 assert(type(task.call)=='function','Missing callable task: '..name)
 count=count+1
end
assert(count>90)
print('PASS '..count..' task registrations after module extraction')
