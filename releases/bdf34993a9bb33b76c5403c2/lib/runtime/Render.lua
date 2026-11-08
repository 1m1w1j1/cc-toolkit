local Render={}
function Render.draw(draw)
 local parent=term.current()
 local width,height=parent.getSize()
 local canvas=window.create(parent,1,1,width,height,false)
 local previous=term.redirect(canvas)
 local ok,err=pcall(draw)
 term.redirect(previous)
 if not ok then Render.invalidate();error(err,0) end
 local cache=Render.parent==parent and Render.width==width and Render.height==height and Render.rows or {}
 local rows={}
 for row=1,height do
  local text,fg,bg=canvas.getLine(row)
  local signature=text..fg..bg
  rows[row]=signature
  if cache[row]~=signature then parent.setCursorPos(1,row);parent.blit(text,fg,bg) end
 end
 Render.parent,Render.width,Render.height,Render.rows=parent,width,height,rows
 parent.setCursorPos(canvas.getCursorPos())
 parent.setCursorBlink(canvas.getCursorBlink())
 parent.setTextColor(canvas.getTextColor());parent.setBackgroundColor(canvas.getBackgroundColor())
end
function Render.invalidate() Render.rows={} end
return Render
