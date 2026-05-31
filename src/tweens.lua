--[[
Purpose: Provide small reusable tween helpers for card movement.
]]

local Tween = {}

Tween.Easing = {
  Linear = "linear",
  EaseIn = "ease_in",
  EaseOut = "ease_out",
}

local ensure_tween_state
local apply_easing
local update_position

-- PUBLIC: Advance active tween state. Returns true when no tweens remain.
function Tween.Update(object, dt)
  local state = object._tween_state
  if state == nil then
    return true
  end

  if state.position ~= nil then
    update_position(object, state.position, dt)
  end

  return state.position == nil
end

-- PUBLIC: Start a position tween on a target object.
function Tween.Position(object, from_x, from_y, to_x, to_y, duration, easing)
  local state = ensure_tween_state(object)
  state.position = {
    from_x = from_x,
    from_y = from_y,
    to_x = to_x,
    to_y = to_y,
    duration = math.max(duration, 0),
    elapsed = 0,
    easing = easing or Tween.Easing.Linear,
  }

  object.x = from_x
  object.y = from_y
end

-- PUBLIC: Stop all active tweens on a target object.
function Tween.Clear(object)
  object._tween_state = nil
end

ensure_tween_state = function(object)
  if object._tween_state == nil then
    object._tween_state = {}
  end

  return object._tween_state
end

apply_easing = function(t, easing)
  if easing == Tween.Easing.EaseIn then
    return t * t
  end

  if easing == Tween.Easing.EaseOut then
    local inverse = 1 - t
    return 1 - (inverse * inverse)
  end

  return t
end

update_position = function(object, tween, dt)
  tween.elapsed = math.min(tween.elapsed + dt, tween.duration)

  local t = 1
  if tween.duration > 0 then
    t = tween.elapsed / tween.duration
  end

  local eased_t = apply_easing(t, tween.easing)
  object.x = tween.from_x + ((tween.to_x - tween.from_x) * eased_t)
  object.y = tween.from_y + ((tween.to_y - tween.from_y) * eased_t)

  if tween.elapsed >= tween.duration then
    object.x = tween.to_x
    object.y = tween.to_y
    object._tween_state.position = nil
  end
end

return Tween
