local Grid = require("lua/game/grid")

local Car = {}
Car.__index = Car

Car.SPEED = 60 -- px/sec pixel-tween speed while moving

function Car.new(path, grid)
    local self = setmetatable({}, Car)
    self.path = path
    self.grid = grid
    self.index = 1
    self.x, self.y = grid:subcell_to_pixel(path[1].col, path[1].row)
    self._wait_time = 0
    self.target_x = nil
    self.target_y = nil

    if #path == 1 then
        self.state = "arrived"
    else
        self.state = "waiting"
    end

    return self
end

function Car:current_subcell()
    return self.path[self.index]
end

function Car:next_subcell()
    return self.path[self.index + 1]
end

function Car:is_arrived()
    return self.index >= #self.path
end

function Car:wait_time()
    return self._wait_time
end

-- Only valid when state == "waiting" and a next_subcell() exists. Arbitration
-- over *which* waiting car gets granted a contested sub-cell lives in
-- game_state.lua; this just carries out the grant once decided.
function Car:grant_move()
    if self.state ~= "waiting" then
        return
    end
    local nxt = self:next_subcell()
    if not nxt then
        return
    end
    self.state = "moving"
    self._wait_time = 0
    self.target_x, self.target_y = self.grid:subcell_to_pixel(nxt.col, nxt.row)
end

function Car:tick(dt)
    if self.state == "moving" then
        local dx = self.target_x - self.x
        local dy = self.target_y - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local step = Car.SPEED * dt
        local EPSILON = 1e-9

        if step + EPSILON >= dist then
            -- reached (or overshot) the target this tick: snap exactly
            self.x = self.target_x
            self.y = self.target_y
            self.index = self.index + 1
            if self:is_arrived() then
                self.state = "arrived"
            else
                self.state = "waiting"
                self._wait_time = 0
            end
        else
            self.x = self.x + dx / dist * step
            self.y = self.y + dy / dist * step
        end
    elseif self.state == "waiting" then
        self._wait_time = self._wait_time + dt
    end
    -- state == "arrived": no-op
end

function Car:draw()
    local size = Grid.SUBCELL_SIZE
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", self.x - size / 2, self.y - size / 2, size, size)
end

return Car
