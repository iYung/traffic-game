local Forecast = {}
Forecast.__index = Forecast

Forecast.SPEED   = 60   -- px/sec scroll speed
Forecast.WIDTH   = 80   -- approx label width in px, used for offscreen check
Forecast.SPAWN_X = 1280 -- starting x, just off the right edge

function Forecast.new(origin_letter, dest_letter, count, x)
    local self = setmetatable({}, Forecast)
    self.origin = origin_letter
    self.dest   = dest_letter
    self.count  = count
    self.x      = x or Forecast.SPAWN_X
    return self
end

function Forecast:update(dt)
    self.x = self.x - Forecast.SPEED * dt
end

function Forecast:is_offscreen_left()
    return self.x + Forecast.WIDTH < 0
end

function Forecast:label()
    return string.format("%s -> %s x%d", self.origin, self.dest, self.count)
end

function Forecast:draw(y)
    -- Must set an explicit color here: love.graphics.print otherwise uses
    -- whatever color the caller last set, which was the forecast bar's dark
    -- background fill -- making this text invisible against it.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self:label(), self.x, y)
end

return Forecast
