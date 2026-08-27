local Grid = require("lua/game/grid")
local Car = require("lua/game/car")
local Building = require("lua/game/building")
local ForecastBar = require("lua/game/forecast_bar")

local GameState = {}
GameState.__index = GameState

-- Fixed 5-building layout: corners + center of the 128x68 grid.
local LAYOUT = {
    { letter = "A", col = 4,   row = 4,  color = { 0.9, 0.2, 0.2, 1 } },
    { letter = "B", col = 123, row = 4,  color = { 0.2, 0.4, 0.9, 1 } },
    { letter = "C", col = 4,   row = 63, color = { 0.2, 0.8, 0.3, 1 } },
    { letter = "D", col = 123, row = 63, color = { 0.9, 0.8, 0.2, 1 } },
    { letter = "E", col = 63,  row = 33, color = { 0.7, 0.3, 0.8, 1 } },
}

function GameState.new()
    local self = setmetatable({}, GameState)

    self.grid = Grid.new()
    self.buildings = {}
    self.buildings_by_letter = {}

    for _, entry in ipairs(LAYOUT) do
        self.grid:set_building(entry.col, entry.row, entry.letter)
        local building = Building.new(entry.letter, entry.col, entry.row, entry.color)
        table.insert(self.buildings, building)
        self.buildings_by_letter[entry.letter] = building
    end

    self.cars = {}
    self.forecast_bar = ForecastBar.new({ "A", "B", "C", "D", "E" })
    self.score = 0

    return self
end

function GameState:toggle_road_at_pixel(px, py)
    local col, row = self.grid:pixel_to_cell(px, py)
    if col == nil or row == nil then
        return
    end
    if self.grid:is_empty(col, row) then
        self.grid:set_road(col, row)
    end
end

function GameState:_is_subcell_free(sc)
    for _, car in ipairs(self.cars) do
        local cur = car:current_subcell()
        if cur and cur.col == sc.col and cur.row == sc.row then
            return false
        end
        if car.state == "moving" then
            local nxt = car:next_subcell()
            if nxt and nxt.col == sc.col and nxt.row == sc.row then
                return false
            end
        end
    end
    return true
end

function GameState:update(dt)
    -- 1. scroll/spawn forecast entries, enqueue cars into origin buildings
    self.forecast_bar:update(dt, self.buildings_by_letter)

    -- 2. per-building spawn attempts
    local is_free = function(sc)
        return self:_is_subcell_free(sc)
    end
    for _, building in ipairs(self.buildings) do
        local path = building:try_spawn(self.grid, self.buildings_by_letter, is_free)
        if path then
            local car = Car.new(path, self.grid)
            table.insert(self.cars, car)
            -- Do NOT call car:grant_move() here -- it starts "waiting" and
            -- is granted its first move through arbitration below, same as
            -- every other car. This ensures its second sub-cell also gets
            -- an occupancy check (try_spawn/_is_subcell_free only checked
            -- its first sub-cell, start_sc).
        end
    end

    -- 3. tick all cars
    for _, car in ipairs(self.cars) do
        car:tick(dt)
    end

    -- 4. arbitration: for each contested next_subcell requested by waiting
    -- cars, grant the move to whichever has waited longest, but only if
    -- that sub-cell is actually free.
    local contested = {}
    local order = {}
    for _, car in ipairs(self.cars) do
        if car.state == "waiting" then
            local nxt = car:next_subcell()
            if nxt then
                local key = nxt.col .. "," .. nxt.row
                if not contested[key] then
                    contested[key] = { sc = nxt, cars = {} }
                    table.insert(order, key)
                end
                table.insert(contested[key].cars, car)
            end
        end
    end

    for _, key in ipairs(order) do
        local group = contested[key]
        if self:_is_subcell_free(group.sc) then
            local best = nil
            for _, car in ipairs(group.cars) do
                if best == nil or car:wait_time() > best:wait_time() then
                    best = car
                end
            end
            if best then
                best:grant_move()
            end
        end
    end

    -- 5. remove arrived cars, increment score
    for i = #self.cars, 1, -1 do
        local car = self.cars[i]
        if car:is_arrived() then
            self.score = self.score + 1
            table.remove(self.cars, i)
        end
    end
end

function GameState:draw()
    -- Background (play area, below the forecast bar strip)
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", 0, Grid.FORECAST_BAR_H, 1280, 680)

    -- Roads
    love.graphics.setColor(0.35, 0.35, 0.35, 1)
    for col = 0, Grid.COLS - 1 do
        for row = 0, Grid.ROWS - 1 do
            if self.grid:is_road(col, row) then
                local x, y = self.grid:cell_to_pixel(col, row)
                love.graphics.rectangle("fill", x, y, Grid.CELL_SIZE, Grid.CELL_SIZE)
            end
        end
    end

    -- Buildings: colored cell + letter + queue-length badge
    for _, building in ipairs(self.buildings) do
        local x, y = self.grid:cell_to_pixel(building.col, building.row)
        love.graphics.setColor(building.color)
        love.graphics.rectangle("fill", x, y, Grid.CELL_SIZE, Grid.CELL_SIZE)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(building.letter, x, y)
        love.graphics.print(tostring(building:queue_length()), x, y + Grid.CELL_SIZE)
    end

    -- Cars
    for _, car in ipairs(self.cars) do
        car:draw()
    end

    -- Forecast bar strip (top 40px)
    love.graphics.setColor(0.05, 0.05, 0.15, 1)
    love.graphics.rectangle("fill", 0, 0, 1280, Grid.FORECAST_BAR_H)
    self.forecast_bar:draw()

    -- Score
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Delivered: " .. self.score, 16, 16)
end

return GameState
