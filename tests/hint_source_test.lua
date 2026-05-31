package.path = "./?.lua;./?/init.lua;" .. package.path

usagi = {
  GAME_H = 144,
  GAME_W = 256,
}

local Solitaire = require("src.solitaire")

local function get_upvalue(fn, target_name)
  for index = 1, 80 do
    local name, value = debug.getupvalue(fn, index)
    if name == nil then
      return nil
    end

    if name == target_name then
      return value
    end
  end

  return nil
end

local function assert_equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
  end
end

local function card(rank, color, face_up)
  return {
    rank = rank,
    color = color,
    face_up = face_up ~= false,
    visible = true,
  }
end

local state = Solitaire.GetState()
state.tableau = {
  { card(9, "black"), card(8, "red") },
  { card(12, "black", false), card(7, "black"), card(6, "red") },
  {},
  {},
  {},
  {},
  {},
}
state.foundations = {
  { suit = nil, cards = {} },
  { suit = nil, cards = {} },
  { suit = nil, cards = {} },
  { suit = nil, cards = {} },
}
state.stock = {}
state.waste = {}

local handle_hint_input = get_upvalue(Solitaire.Update, "handle_hint_input")
local request_hint = get_upvalue(handle_hint_input, "request_hint")
local find_hint_source = get_upvalue(request_hint, "find_hint_source")
local draw_board = get_upvalue(Solitaire.Draw, "draw_board")
local draw_hint = get_upvalue(draw_board, "draw_hint")
local get_hint_source_rect = get_upvalue(draw_hint, "get_hint_source_rect")

local hint = find_hint_source()
assert_equal(hint.kind, "tableau", "hint kind")
assert_equal(hint.column, 2, "hint source column")
assert_equal(hint.index, 2, "hint source card index")

local _, y, _, h = get_hint_source_rect(hint)
assert_equal(y, 87, "hint source card y")
assert_equal(h, 22, "hint source card height")

print("hint_source_test: ok")
