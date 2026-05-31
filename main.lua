local Game = require("src.main")

function _config()
  if Game._config ~= nil then
    return Game._config()
  end
  return nil
end

function _init(forceFullReset)
  if Game._init ~= nil then
    Game._init(forceFullReset)
  end
end

function _update(dt)
  if Game._update ~= nil then
    Game._update(dt)
  end
end

function _draw(dt)
  if Game._draw ~= nil then
    Game._draw(dt)
  end
end
