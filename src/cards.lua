--[[
Purpose: Define the Solitaire deck, sprite sheet layout, and card rules.
]]

local Cards = {}

Cards.SHEET_COLS = 13
Cards.SHEET_ROWS = 5
Cards.CELL_W = 18
Cards.CELL_H = 22
Cards.SOURCE_W = 18
Cards.SOURCE_H = 22
Cards.TOTAL_SPRITES = Cards.SHEET_COLS * Cards.SHEET_ROWS

Cards.Sprite = {
  Back = Cards.TOTAL_SPRITES - 2,
  Empty = Cards.TOTAL_SPRITES - 1,
  Foundation = Cards.TOTAL_SPRITES,
}

Cards.Suits = {
  "spades",
  "clubs",
  "diamonds",
  "hearts",
}

local suit_colors = {
  spades = "black",
  clubs = "black",
  diamonds = "red",
  hearts = "red",
}

local suit_indexes = {
  spades = 1,
  clubs = 2,
  diamonds = 3,
  hearts = 4,
}

-- PUBLIC: Create a full ordered deck.
function Cards.NewDeck()
  local deck = {}

  for suit_index = 1, #Cards.Suits do
    local suit = Cards.Suits[suit_index]
    for rank = 1, 13 do
      table.insert(deck, {
        suit = suit,
        rank = rank,
        color = suit_colors[suit],
        sprite_index = Cards.SpriteIndex(suit, rank),
        face_up = false,
        visible = true,
        x = 0,
        y = 0,
      })
    end
  end

  return deck
end

-- PUBLIC: Shuffle a deck in place.
function Cards.Shuffle(deck)
  for index = #deck, 2, -1 do
    local swap_index = math.random(index)
    deck[index], deck[swap_index] = deck[swap_index], deck[index]
  end
end

-- PUBLIC: Return the one-based sprite index for a card face.
function Cards.SpriteIndex(suit, rank)
  return ((suit_indexes[suit] - 1) * 13) + rank
end

-- PUBLIC: Return the one-based foundation placeholder sprite for a slot.
function Cards.FoundationSprite()
  return Cards.Sprite.Foundation
end

-- PUBLIC: Return source rectangle coordinates for a card sprite.
function Cards.SourceRect(sprite_index)
  local zero_index = sprite_index - 1
  local cell_x = zero_index % Cards.SHEET_COLS
  local cell_y = math.floor(zero_index / Cards.SHEET_COLS)

  return
    cell_x * Cards.CELL_W,
    cell_y * Cards.CELL_H,
    Cards.SOURCE_W,
    Cards.SOURCE_H
end

-- PUBLIC: Report whether a moving card can stack on a tableau card.
function Cards.CanStackOnTableau(moving_card, target_card)
  if target_card == nil then
    return moving_card.rank == 13
  end

  if not target_card.face_up then
    return false
  end

  return moving_card.color ~= target_card.color and moving_card.rank == (target_card.rank - 1)
end

-- PUBLIC: Report whether a moving card can go to a foundation slot.
function Cards.CanMoveToFoundation(card, foundation_slot)
  if #foundation_slot.cards == 0 then
    return card.rank == 1
  end

  local top_card = foundation_slot.cards[#foundation_slot.cards]
  return foundation_slot.suit == card.suit and card.rank == (top_card.rank + 1)
end

return Cards
