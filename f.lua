local args={...}
local count=tonumber(args[1] or "1")
local option=args[2] or ""
local moved,err=require("lib.runtime.Movement").run(count, option~="", "forwards", option:find("+",1,true)~=nil, option:find("-",1,true)~=nil)
print("Moved "..moved.." / "..count)
if err then print(err) end
