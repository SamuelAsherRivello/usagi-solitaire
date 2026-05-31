--[[
Purpose: Render the small upper-left game UI.
]]

local UserInterface = {}

local SHARED_STATE_KEY <const> = "__USAGI_SOLITAIRE_SHARED_STATE"
local INPUT_TEXT <const> = "Input: Mouse, R, H"

---@type any
local state = nil

local ensure_state

-- PUBLIC: Initialize UI state bindings.
function UserInterface.Init(shared_state)
  state = shared_state
  _G[SHARED_STATE_KEY] = shared_state
end

-- PUBLIC: Draw all HUD text.
function UserInterface.Draw(dt)
  if not ensure_state() then
    return
  end

  gfx.text(state.game_title, 10, 10, gfx.COLOR_WHITE)
  gfx.text(INPUT_TEXT, 10, 22, gfx.COLOR_WHITE)

  if state.hint_button ~= nil then
    gfx.text(state.hint_button.text, state.hint_button.x, state.hint_button.y, gfx.COLOR_YELLOW)
  end

  if state.won then
    gfx.text("status: you won", 10, 46, gfx.COLOR_WHITE)
  end
end

ensure_state = function()
  if state == nil then
    state = _G[SHARED_STATE_KEY]
  end

  return state ~= nil
end

return UserInterface
