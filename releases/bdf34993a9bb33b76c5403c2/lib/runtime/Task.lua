-- One execution boundary: fail closed on movement errors and never replay a task.
local Task = {active=false, name='', operation='', completed=0}
function Task.run(name, fn)
 assert(not Task.active, 'A task is already running')
 Task.active, Task.name, Task.operation, Task.completed = true, name, '', 0
 local ok, result = pcall(fn)
 Task.active = false
 if not ok then
  local message = 'Task '..name..' stopped: '..tostring(result)
  if Task.operation ~= '' then message=message..' ['..Task.operation..', completed '..Task.completed..']' end
  local h = fs.open('last-error.txt', 'w')
  if h then h.write(message); h.close() end
  if tostring(result):find('Terminated',1,true) then error(result,0) end
  return {message, 'Check turtle position before starting another task. See last-error.txt.'}
 end
 return type(result)=='table' and result or {tostring(result or 'Task completed')}
end
return Task
