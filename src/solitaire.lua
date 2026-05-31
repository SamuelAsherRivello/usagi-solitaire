--[[
Purpose: Manage Klondike Solitaire state, dealing, drag/drop, and rendering.
]]

local Cards = require("src.cards")
local Tween = require("src.tweens")

local Solitaire = {}

local CARD_W <const> = 18
local CARD_H <const> = 22
local LAYOUT_SHIFT_X <const> = CARD_W * 2
local TOP_ROW_Y <const> = 28 + CARD_H
local TABLEAU_X <const> = 91 + LAYOUT_SHIFT_X
local TABLEAU_Y <const> = 66 + (CARD_H / 2)
local COLUMN_GAP <const> = 6
local TABLEAU_STEP <const> = 10
local TABLEAU_STEP_MIN <const> = 5
local TABLEAU_BOTTOM_MARGIN <const> = 4
local STOCK_X <const> = TABLEAU_X
local STOCK_Y <const> = TOP_ROW_Y
local WASTE_X <const> = STOCK_X + CARD_W + COLUMN_GAP
local WASTE_Y <const> = STOCK_Y
local FOUNDATION_X <const> = 160 + LAYOUT_SHIFT_X
local FOUNDATION_Y <const> = STOCK_Y
local FOUNDATION_GAP <const> = 7
local DEAL_DELAY <const> = 0.25 / 9
local DEAL_DURATION <const> = DEAL_DELAY / 2
local COLOR_DARK_BORDER_GREEN <const> = 17
local GAME_BORDER_PADDING <const> = 8
local GAME_BORDER_COLOR <const> = COLOR_DARK_BORDER_GREEN
local DRAG_OFFSET_X <const> = 8
local DRAG_OFFSET_Y <const> = 10
local SHADOW_OFFSET_X <const> = 1
local SHADOW_OFFSET_Y <const> = 1
local SHADOW_ALPHA <const> = 0.3
local GAME_TITLE <const> = "Usagi Solitaire"
local SFX_DEAL_CARD <const> = "CardDraw01"
local SFX_DRAG_START <const> = "CardDragStart"
local SFX_DRAG_STOP <const> = "CardDragStop"
local SFX_DRAG_REJECTED <const> = "CardDragRejected"
local SFX_DRAG_REJECTED_VOLUME <const> = 0.7
local SFX_FOUNDATION_DROP <const> = "CardReveal01"
local SFX_GAME_OVER_WIN <const> = "GameOverWin"
local SFX_HINT_ACCEPTED <const> = "CardPoint01"
local HINT_COUNT_START <const> = 3
local HINT_BUTTON_X <const> = 10
local HINT_BUTTON_Y <const> = 34
local HINT_BUTTON_W <const> = 66
local HINT_BUTTON_H <const> = 12
local HINT_ARROW_GAP <const> = 3
local HINT_ARROW_HEIGHT <const> = 12
local HINT_ARROW_HEAD_HALF_W <const> = 4
local HINT_ARROW_HEAD_H <const> = 5
local HINT_ARROW_SCREEN_MARGIN <const> = 4

local state = {
  game_title = GAME_TITLE,
  won = false,
  stock_visible = false,
  dealing = false,
  deal_elapsed = 0,
  reset_counter = 0,
  tableau = {},
  stock = {},
  waste = {},
  foundations = {},
  drag = nil,
  hint = nil,
  hints_remaining = HINT_COUNT_START,
  hint_button = {
    text = "Hints: 003",
    x = HINT_BUTTON_X,
    y = HINT_BUTTON_Y,
    w = HINT_BUTTON_W,
    h = HINT_BUTTON_H,
  },
  stock_proxy = nil,
}

local reset_foundations
local reset_tableau
local build_deal
local update_deal
local update_deal_card
local update_stock_proxy
local update_loose_tweens
local handle_hint_input
local request_hint
local clear_hint
local update_hint_button_text
local find_hint_source
local find_tableau_move_source
local find_waste_move_source
local can_move_card_to_foundation
local can_move_card_to_tableau
local handle_mouse
local draw_from_stock
local begin_drag
local begin_drag_from_foundation
local begin_drag_from_waste
local begin_drag_from_tableau
local update_drag_position
local finish_drag
local try_drop_on_foundation
local try_drop_on_tableau
local remove_drag_cards_from_source
local flip_source_top_card
local check_win
local layout_all_cards
local layout_waste
local layout_foundations
local layout_tableau
local get_tableau_step
local get_tableau_position
local get_column_x
local get_foundation_position
local find_tableau_hit
local find_tableau_drop_column
local find_foundation_drop_slot
local is_point_in_rect
local draw_board
local draw_game_border
local draw_tableau
local draw_stock_and_waste
local draw_foundations
local draw_drag
local draw_hint
local draw_hint_arrow
local get_hint_source_rect
local draw_sprite
local draw_card
local draw_card_shadow
local draw_sprite_shadow
local is_tweening
local should_skip_card

-- PUBLIC: Initialize a fresh game.
function Solitaire.Init()
  input.set_mouse_visible(true)
  Solitaire.Reset()
end

-- PUBLIC: Reset and deal a new game.
function Solitaire.Reset()
  state.reset_counter = state.reset_counter + 1
  math.randomseed(os.time() + (state.reset_counter * 7919))

  state.won = false
  state.stock_visible = false
  state.dealing = true
  state.deal_elapsed = 0
  state.drag = nil
  state.hint = nil
  state.hints_remaining = HINT_COUNT_START
  state.stock = {}
  state.waste = {}
  state.stock_proxy = nil
  update_hint_button_text()

  reset_tableau()
  reset_foundations()

  local deck = Cards.NewDeck()
  Cards.Shuffle(deck)
  build_deal(deck)
end

-- PUBLIC: Update the solitaire simulation.
function Solitaire.Update(dt)
  if input.key_pressed(input.KEY_R) then
    Solitaire.Reset()
    return
  end

  if state.dealing then
    update_deal(dt)
    return
  end

  update_loose_tweens(dt)
  if handle_hint_input() then
    return
  end

  handle_mouse()
end

-- PUBLIC: Draw the solitaire board.
function Solitaire.Draw(dt)
  draw_board()
end

-- PUBLIC: Return shared game state for the UI.
function Solitaire.GetState()
  return state
end

reset_tableau = function()
  state.tableau = {}
  for column = 1, 7 do
    state.tableau[column] = {}
  end
end

reset_foundations = function()
  state.foundations = {}
  for slot = 1, 4 do
    state.foundations[slot] = {
      suit = nil,
      cards = {},
    }
  end
end

build_deal = function(deck)
  local deal_index = 0
  local start_x = usagi.GAME_W / 2
  local start_y = -50

  for row = 1, 7 do
    for column = row, 7 do
      local card = table.remove(deck, 1)
      local pile = state.tableau[column]
      card.face_up = column == row
      card.visible = false
      card.location = { kind = "tableau", column = column }
      card.deal_delay = deal_index * DEAL_DELAY
      card.deal_started = false
      card.deal_done = false

      table.insert(pile, card)

      local target_x, target_y = get_tableau_position(column, #pile, #pile)
      card.deal_from_x = start_x
      card.deal_from_y = start_y
      card.deal_to_x = target_x
      card.deal_to_y = target_y
      card.x = start_x
      card.y = start_y
      deal_index = deal_index + 1
    end
  end

  for index = 1, #deck do
    local card = deck[index]
    card.face_up = false
    card.visible = false
    card.location = { kind = "stock" }
    card.x = STOCK_X
    card.y = STOCK_Y
    table.insert(state.stock, card)
  end

  state.stock_proxy = {
    visible = false,
    started = false,
    done = false,
    delay = deal_index * DEAL_DELAY,
    x = start_x,
    y = start_y,
    target_x = STOCK_X,
    target_y = STOCK_Y,
  }
end

update_deal = function(dt)
  state.deal_elapsed = state.deal_elapsed + dt
  local all_cards_done = true

  for column = 1, 7 do
    local pile = state.tableau[column]
    for index = 1, #pile do
      local card = pile[index]
      update_deal_card(card, dt)
      if not card.deal_done then
        all_cards_done = false
      end
    end
  end

  local proxy_done = update_stock_proxy(dt)
  if all_cards_done and proxy_done then
    state.dealing = false
    state.stock_visible = true
    layout_all_cards()
  end
end

update_deal_card = function(card, dt)
  if card.deal_done then
    return
  end

  if (not card.deal_started) and state.deal_elapsed >= card.deal_delay then
    card.deal_started = true
    card.visible = true
    Tween.Position(
      card,
      card.deal_from_x,
      card.deal_from_y,
      card.deal_to_x,
      card.deal_to_y,
      DEAL_DURATION,
      Tween.Easing.EaseOut
    )
  end

  if card.deal_started and Tween.Update(card, dt) then
    card.deal_done = true
    card.x = card.deal_to_x
    card.y = card.deal_to_y
    Tween.Clear(card)
    if card.face_up then
      sfx.play(SFX_DEAL_CARD)
    end
  end
end

update_stock_proxy = function(dt)
  local proxy = state.stock_proxy
  if proxy == nil then
    return true
  end

  if proxy.done then
    return true
  end

  if (not proxy.started) and state.deal_elapsed >= proxy.delay then
    proxy.started = true
    proxy.visible = true
    Tween.Position(
      proxy,
      proxy.x,
      proxy.y,
      proxy.target_x,
      proxy.target_y,
      DEAL_DURATION,
      Tween.Easing.EaseOut
    )
  end

  if proxy.started and Tween.Update(proxy, dt) then
    proxy.done = true
    proxy.visible = false
    Tween.Clear(proxy)
    return true
  end

  return false
end

update_loose_tweens = function(dt)
  for index = 1, #state.waste do
    Tween.Update(state.waste[index], dt)
  end
end

handle_hint_input = function()
  if state.drag ~= nil then
    return false
  end

  if input.key_pressed(input.KEY_H) then
    request_hint()
    return true
  end

  local mouse_x, mouse_y = input.mouse()
  local button = state.hint_button
  if input.mouse_pressed(input.MOUSE_LEFT)
    and is_point_in_rect(mouse_x, mouse_y, button.x, button.y, button.w, button.h)
  then
    request_hint()
    return true
  end

  return false
end

request_hint = function()
  if state.hint ~= nil then
    return
  end

  if state.hints_remaining <= 0 then
    sfx.play_ex(SFX_DRAG_REJECTED, SFX_DRAG_REJECTED_VOLUME, 1.0, 0.0)
    return
  end

  state.hint = find_hint_source()
  state.hints_remaining = state.hints_remaining - 1
  update_hint_button_text()
  sfx.play(SFX_HINT_ACCEPTED)
end

clear_hint = function()
  state.hint = nil
end

update_hint_button_text = function()
  state.hint_button.text = string.format("Hints: %03d", state.hints_remaining)
end

find_hint_source = function()
  local source = find_tableau_move_source()
  if source ~= nil then
    return source
  end

  source = find_waste_move_source()
  if source ~= nil then
    return source
  end

  return { kind = "stock" }
end

find_tableau_move_source = function()
  for column = 1, 7 do
    local pile = state.tableau[column]
    local top_card = pile[#pile]
    if top_card ~= nil and top_card.face_up and can_move_card_to_foundation(top_card) then
      return { kind = "tableau", column = column, index = #pile }
    end

    for index = 1, #pile do
      local card = pile[index]
      if card.face_up and card.visible and card.rank ~= 13 and can_move_card_to_tableau(card, column) then
        return { kind = "tableau", column = column, index = index }
      end
    end
  end

  return nil
end

find_waste_move_source = function()
  local card = state.waste[#state.waste]
  if card == nil then
    return nil
  end

  if can_move_card_to_foundation(card) or can_move_card_to_tableau(card, nil) then
    return { kind = "waste" }
  end

  return nil
end

can_move_card_to_foundation = function(card)
  for slot_index = 1, #state.foundations do
    if Cards.CanMoveToFoundation(card, state.foundations[slot_index]) then
      return true
    end
  end

  return false
end

can_move_card_to_tableau = function(card, source_column)
  for column = 1, 7 do
    if source_column == nil or column ~= source_column then
      local pile = state.tableau[column]
      if Cards.CanStackOnTableau(card, pile[#pile]) then
        return true
      end
    end
  end

  return false
end

handle_mouse = function()
  local mouse_x, mouse_y = input.mouse()

  if state.drag ~= nil then
    update_drag_position(mouse_x, mouse_y)

    if input.mouse_released(input.MOUSE_LEFT) then
      finish_drag()
    end

    return
  end

  if not input.mouse_pressed(input.MOUSE_LEFT) then
    return
  end

  if is_point_in_rect(mouse_x, mouse_y, STOCK_X, STOCK_Y, CARD_W, CARD_H) then
    draw_from_stock()
    return
  end

  if begin_drag_from_waste(mouse_x, mouse_y) then
    return
  end

  if begin_drag_from_foundation(mouse_x, mouse_y) then
    return
  end

  begin_drag_from_tableau(mouse_x, mouse_y)
end

draw_from_stock = function()
  if #state.stock > 0 then
    local card = table.remove(state.stock)
    card.face_up = true
    card.visible = true
    card.location = { kind = "waste" }
    card.x = WASTE_X
    card.y = WASTE_Y
    Tween.Clear(card)
    table.insert(state.waste, card)

    clear_hint()
    sfx.play(SFX_DEAL_CARD)
    return
  end
end

begin_drag_from_waste = function(mouse_x, mouse_y)
  if #state.waste == 0 then
    return false
  end

  local card = state.waste[#state.waste]
  if is_point_in_rect(mouse_x, mouse_y, card.x, card.y, CARD_W, CARD_H) then
    begin_drag({ card }, { kind = "waste" }, mouse_x, mouse_y)
    sfx.play(SFX_DRAG_START)
    return true
  end

  return false
end

begin_drag_from_foundation = function(mouse_x, mouse_y)
  for slot_index = 1, #state.foundations do
    local slot = state.foundations[slot_index]
    if #slot.cards > 0 then
      local card = slot.cards[#slot.cards]
      if is_point_in_rect(mouse_x, mouse_y, card.x, card.y, CARD_W, CARD_H) then
        begin_drag({ card }, { kind = "foundation", slot = slot_index }, mouse_x, mouse_y)
        sfx.play(SFX_DRAG_START)
        return true
      end
    end
  end

  return false
end

begin_drag_from_tableau = function(mouse_x, mouse_y)
  local hit = find_tableau_hit(mouse_x, mouse_y)
  if hit == nil then
    return false
  end

  local cards = {}
  local pile = state.tableau[hit.column]
  for index = hit.index, #pile do
    table.insert(cards, pile[index])
  end

  begin_drag(cards, { kind = "tableau", column = hit.column, index = hit.index }, mouse_x, mouse_y)
  sfx.play(SFX_DRAG_START)
  return true
end

begin_drag = function(cards, source, mouse_x, mouse_y)
  local origins = {}
  local card_set = {}
  local base_x = cards[1].x
  local base_y = cards[1].y

  for index = 1, #cards do
    local card = cards[index]
    Tween.Clear(card)
    origins[index] = { x = card.x, y = card.y }
    card_set[card] = true
  end

  state.drag = {
    cards = cards,
    card_set = card_set,
    source = source,
    origins = origins,
    offset_x = mouse_x - base_x,
    offset_y = mouse_y - base_y,
  }

  if state.drag.offset_x < 0 or state.drag.offset_x > CARD_W then
    state.drag.offset_x = DRAG_OFFSET_X
  end

  if state.drag.offset_y < 0 or state.drag.offset_y > CARD_H then
    state.drag.offset_y = DRAG_OFFSET_Y
  end

  update_drag_position(mouse_x, mouse_y)
end

update_drag_position = function(mouse_x, mouse_y)
  local drag = state.drag
  local base_x = mouse_x - drag.offset_x
  local base_y = mouse_y - drag.offset_y

  for index = 1, #drag.cards do
    local card = drag.cards[index]
    card.x = base_x
    card.y = base_y + ((index - 1) * TABLEAU_STEP)
  end
end

finish_drag = function()
  local drag = state.drag
  if drag == nil then
    return
  end

  local lead_card = drag.cards[1]
  local drop_x = lead_card.x + (CARD_W / 2)
  local drop_y = lead_card.y + (CARD_H / 2)
  local drop_result = try_drop_on_foundation(drop_x, drop_y) or try_drop_on_tableau(drop_x, drop_y)

  if not drop_result then
    for index = 1, #drag.cards do
      local card = drag.cards[index]
      local origin = drag.origins[index]
      card.x = origin.x
      card.y = origin.y
    end
    sfx.play_ex(SFX_DRAG_REJECTED, SFX_DRAG_REJECTED_VOLUME, 1.0, 0.0)
  elseif drop_result == "foundation" then
    clear_hint()
    sfx.play(SFX_FOUNDATION_DROP)
  else
    clear_hint()
    sfx.play(SFX_DRAG_STOP)
  end

  state.drag = nil
  layout_all_cards()
  check_win()
end

try_drop_on_foundation = function(drop_x, drop_y)
  local drag = state.drag
  if #drag.cards ~= 1 then
    return false
  end

  local slot_index = find_foundation_drop_slot(drop_x, drop_y)
  if slot_index == nil then
    return false
  end

  if drag.source.kind == "foundation" and drag.source.slot == slot_index then
    return false
  end

  local card = drag.cards[1]
  local slot = state.foundations[slot_index]
  if not Cards.CanMoveToFoundation(card, slot) then
    return false
  end

  remove_drag_cards_from_source()

  if slot.suit == nil then
    slot.suit = card.suit
  end

  card.location = { kind = "foundation", slot = slot_index }
  card.face_up = true
  table.insert(slot.cards, card)
  flip_source_top_card(drag.source)
  return "foundation"
end

try_drop_on_tableau = function(drop_x, drop_y)
  local drag = state.drag
  local target_column = find_tableau_drop_column(drop_x, drop_y)
  if target_column == nil then
    return false
  end

  if drag.source.kind == "tableau" and drag.source.column == target_column then
    return false
  end

  local target_pile = state.tableau[target_column]
  local target_card = target_pile[#target_pile]
  local moving_card = drag.cards[1]
  if not Cards.CanStackOnTableau(moving_card, target_card) then
    return false
  end

  remove_drag_cards_from_source()

  for index = 1, #drag.cards do
    local card = drag.cards[index]
    card.location = { kind = "tableau", column = target_column }
    card.face_up = true
    table.insert(target_pile, card)
  end

  flip_source_top_card(drag.source)
  return "tableau"
end

remove_drag_cards_from_source = function()
  local drag = state.drag

  if drag.source.kind == "waste" then
    table.remove(state.waste)
    return
  end

  if drag.source.kind == "foundation" then
    local slot = state.foundations[drag.source.slot]
    table.remove(slot.cards)
    if #slot.cards == 0 then
      slot.suit = nil
    end
    return
  end

  local pile = state.tableau[drag.source.column]
  for index = #pile, drag.source.index, -1 do
    table.remove(pile, index)
  end
end

flip_source_top_card = function(source)
  if source.kind ~= "tableau" then
    return
  end

  local pile = state.tableau[source.column]
  local top_card = pile[#pile]
  if top_card ~= nil and not top_card.face_up then
    top_card.face_up = true
  end
end

check_win = function()
  local foundation_total = 0
  for slot_index = 1, #state.foundations do
    foundation_total = foundation_total + #state.foundations[slot_index].cards
  end

  local won = foundation_total == 52
  if won and not state.won then
    sfx.play(SFX_GAME_OVER_WIN)
  end

  state.won = won
end

layout_all_cards = function()
  layout_tableau()
  layout_waste()
  layout_foundations()
end

layout_waste = function()
  for index = 1, #state.waste do
    local card = state.waste[index]
    if not should_skip_card(card) then
      card.x = WASTE_X
      card.y = WASTE_Y
    end
  end
end

layout_foundations = function()
  for slot_index = 1, #state.foundations do
    local x, y = get_foundation_position(slot_index)
    local slot = state.foundations[slot_index]
    for card_index = 1, #slot.cards do
      local card = slot.cards[card_index]
      if not should_skip_card(card) then
        card.x = x
        card.y = y
      end
    end
  end
end

layout_tableau = function()
  for column = 1, 7 do
    local pile = state.tableau[column]
    for index = 1, #pile do
      local card = pile[index]
      if not should_skip_card(card) then
        card.x, card.y = get_tableau_position(column, index, #pile)
      end
    end
  end
end

get_tableau_step = function(card_count)
  if card_count <= 1 then
    return TABLEAU_STEP
  end

  local available = usagi.GAME_H - TABLEAU_BOTTOM_MARGIN - TABLEAU_Y - CARD_H
  local desired_total = TABLEAU_STEP * (card_count - 1)
  if desired_total <= available then
    return TABLEAU_STEP
  end

  return math.max(TABLEAU_STEP_MIN, math.floor(available / (card_count - 1)))
end

get_tableau_position = function(column, index, card_count)
  local step = get_tableau_step(card_count)
  return get_column_x(column), TABLEAU_Y + ((index - 1) * step)
end

get_column_x = function(column)
  return TABLEAU_X + ((column - 1) * (CARD_W + COLUMN_GAP))
end

get_foundation_position = function(slot_index)
  return FOUNDATION_X + ((slot_index - 1) * (CARD_W + FOUNDATION_GAP)), FOUNDATION_Y
end

find_tableau_hit = function(mouse_x, mouse_y)
  for column = 1, 7 do
    local pile = state.tableau[column]
    local step = get_tableau_step(#pile)
    for index = #pile, 1, -1 do
      local card = pile[index]
      if card.face_up and card.visible then
        local hit_h = CARD_H
        if index < #pile then
          hit_h = step
        end

        if is_point_in_rect(mouse_x, mouse_y, card.x, card.y, CARD_W, hit_h) then
          return { column = column, index = index }
        end
      end
    end
  end

  return nil
end

find_tableau_drop_column = function(drop_x, drop_y)
  for column = 1, 7 do
    local x = get_column_x(column)
    local top_y = TABLEAU_Y - 8
    local bottom_y = usagi.GAME_H
    if is_point_in_rect(drop_x, drop_y, x - 4, top_y, CARD_W + 8, bottom_y - top_y) then
      return column
    end
  end

  return nil
end

find_foundation_drop_slot = function(drop_x, drop_y)
  for slot_index = 1, 4 do
    local x, y = get_foundation_position(slot_index)
    if is_point_in_rect(drop_x, drop_y, x - 4, y - 4, CARD_W + 8, CARD_H + 8) then
      return slot_index
    end
  end

  return nil
end

is_point_in_rect = function(px, py, x, y, w, h)
  return px >= x and px < (x + w) and py >= y and py < (y + h)
end

draw_board = function()
  draw_game_border()
  draw_foundations()
  draw_stock_and_waste()
  draw_tableau()
  draw_hint()
  draw_drag()
end

draw_game_border = function()
  local left = STOCK_X - GAME_BORDER_PADDING
  local top = STOCK_Y - GAME_BORDER_PADDING
  local right = get_column_x(7) + CARD_W + GAME_BORDER_PADDING
  local bottom = TABLEAU_Y + (6 * TABLEAU_STEP) + CARD_H + GAME_BORDER_PADDING

  gfx.rect(left, top, right - left, bottom - top, GAME_BORDER_COLOR)
end

draw_foundations = function()
  for slot_index = 1, #state.foundations do
    local x, y = get_foundation_position(slot_index)
    draw_sprite(Cards.FoundationSprite(), x, y)

    local slot = state.foundations[slot_index]
    if #slot.cards > 0 then
      draw_card(slot.cards[#slot.cards])
    end
  end
end

draw_stock_and_waste = function()
  draw_sprite(Cards.Sprite.Empty, STOCK_X, STOCK_Y)
  draw_sprite(Cards.Sprite.Empty, WASTE_X, WASTE_Y)

  if state.stock_proxy ~= nil and state.stock_proxy.visible then
    if is_tweening(state.stock_proxy) then
      draw_sprite_shadow(Cards.Sprite.Back, state.stock_proxy.x, state.stock_proxy.y)
    end

    draw_sprite(Cards.Sprite.Back, state.stock_proxy.x, state.stock_proxy.y)
  elseif state.stock_visible and #state.stock > 0 then
    draw_sprite(Cards.Sprite.Back, STOCK_X, STOCK_Y)
  end

  if #state.waste > 0 then
    local card = state.waste[#state.waste]
    if not should_skip_card(card) then
      draw_card(card)
    end
  end
end

draw_tableau = function()
  for column = 1, 7 do
    local pile = state.tableau[column]
    draw_sprite(Cards.Sprite.Empty, get_column_x(column), TABLEAU_Y)

    for index = 1, #pile do
      local card = pile[index]
      if card.visible and not should_skip_card(card) then
        draw_card(card)
      end
    end
  end
end

draw_drag = function()
  if state.drag == nil then
    return
  end

  for index = 1, #state.drag.cards do
    draw_card_shadow(state.drag.cards[index])
  end

  for index = 1, #state.drag.cards do
    draw_card(state.drag.cards[index])
  end
end

draw_hint = function()
  local hint = state.hint
  if hint == nil then
    return
  end

  local x, y, w, h = get_hint_source_rect(hint)
  if x == nil then
    return
  end

  local arrow_x = math.floor(x + (w / 2) + 0.5)
  local tip_y = y + h + HINT_ARROW_GAP
  local tail_y = tip_y + HINT_ARROW_HEIGHT
  local max_tail_y = usagi.GAME_H - HINT_ARROW_SCREEN_MARGIN
  if tail_y > max_tail_y then
    local shift_y = tail_y - max_tail_y
    tip_y = tip_y - shift_y
    tail_y = tail_y - shift_y
  end

  draw_hint_arrow(arrow_x, tip_y, tail_y)
end

draw_hint_arrow = function(x, tip_y, tail_y)
  gfx.line_ex(x, tail_y, x, tip_y, 2, gfx.COLOR_YELLOW)
  gfx.tri_fill(
    x,
    tip_y,
    x - HINT_ARROW_HEAD_HALF_W,
    tip_y + HINT_ARROW_HEAD_H,
    x + HINT_ARROW_HEAD_HALF_W,
    tip_y + HINT_ARROW_HEAD_H,
    gfx.COLOR_YELLOW
  )
end

get_hint_source_rect = function(hint)
  if hint.kind == "tableau" then
    local x = get_column_x(hint.column)
    local pile = state.tableau[hint.column]
    if pile == nil or #pile == 0 then
      return x, TABLEAU_Y, CARD_W, CARD_H
    end

    if hint.index == nil or hint.index < 1 or hint.index > #pile then
      local _, last_card_y = get_tableau_position(hint.column, #pile, #pile)
      return x, TABLEAU_Y, CARD_W, (last_card_y + CARD_H) - TABLEAU_Y
    end

    local _, card_y = get_tableau_position(hint.column, hint.index, #pile)
    return x, card_y, CARD_W, CARD_H
  end

  if hint.kind == "waste" then
    return WASTE_X, WASTE_Y, CARD_W, CARD_H
  end

  if hint.kind == "foundation" then
    local x, y = get_foundation_position(hint.slot)
    return x, y, CARD_W, CARD_H
  end

  if hint.kind == "stock" then
    return STOCK_X, STOCK_Y, CARD_W, CARD_H
  end

  return nil, nil, nil, nil
end

draw_card = function(card)
  local sprite_index = card.sprite_index
  if not card.face_up then
    sprite_index = Cards.Sprite.Back
  end

  if is_tweening(card) then
    draw_sprite_shadow(sprite_index, card.x, card.y)
  end

  draw_sprite(sprite_index, card.x, card.y)
end

draw_card_shadow = function(card)
  local sprite_index = card.sprite_index
  if not card.face_up then
    sprite_index = Cards.Sprite.Back
  end

  draw_sprite_shadow(sprite_index, card.x, card.y)
end

draw_sprite_shadow = function(sprite_index, x, y)
  local source_x, source_y, source_w, source_h = Cards.SourceRect(sprite_index)
  gfx.sspr_ex(
    source_x, source_y, source_w, source_h,
    x + SHADOW_OFFSET_X, y + SHADOW_OFFSET_Y, CARD_W, CARD_H,
    false, false, 0, gfx.COLOR_BLACK, SHADOW_ALPHA
  )
end

draw_sprite = function(sprite_index, x, y)
  local source_x, source_y, source_w, source_h = Cards.SourceRect(sprite_index)
  gfx.sspr_ex(
    source_x, source_y, source_w, source_h,
    x, y, CARD_W, CARD_H,
    false, false, 0, gfx.COLOR_WHITE, 1.0
  )
end

is_tweening = function(object)
  return object._tween_state ~= nil and object._tween_state.position ~= nil
end

should_skip_card = function(card)
  return state.drag ~= nil and state.drag.card_set[card] == true
end

return Solitaire
