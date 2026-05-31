--[[
Purpose: Render the solid green table background.
]]

local World = {}

local COLOR_DARK_BORDER_GREEN <const> = 17
local TABLE_BORDER_THICKNESS <const> = 2
local TABLE_BORDER_COLOR <const> = COLOR_DARK_BORDER_GREEN

function World.Init()
end

-- PUBLIC: Draw the table background.
function World.Draw(dt)
  gfx.clear(gfx.COLOR_DARK_GREEN)
  gfx.rect_ex(0, 0, usagi.GAME_W, usagi.GAME_H, TABLE_BORDER_THICKNESS, TABLE_BORDER_COLOR)
end

return World
