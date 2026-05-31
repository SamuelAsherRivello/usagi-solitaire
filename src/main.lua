--[[
Purpose: Orchestrate the Solitaire game lifecycle.
]]

local Solitaire = require("src.solitaire")
local UserInterface = require("src.user_interface")
local World = require("src.world")

local GAME_TITLE <const> = "Usagi Solitaire"
local GAME_ID <const> = "com.usagiengine.USAGI_SOLITAIRE"
local MUSIC_TRACK <const> = "Lounge01"
local MUSIC_VOLUME <const> = 0.0125

function _config()
  return {
    name = GAME_TITLE,
    pixel_perfect = true,
    icon = 1,
    game_id = GAME_ID,
    sprite_size = 18,
  }
end

function _init(force_full_reset)
  World.Init()
  Solitaire.Init()
  UserInterface.Init(Solitaire.GetState())
  music.play_ex(MUSIC_TRACK, MUSIC_VOLUME, 1.0, 0.0, true)
end

function _update(dt)
  Solitaire.Update(dt)
end

function _draw(dt)
  World.Draw(dt)
  Solitaire.Draw(dt)
  UserInterface.Draw(dt)
end

return {
  _config = _config,
  _init = _init,
  _update = _update,
  _draw = _draw,
}
