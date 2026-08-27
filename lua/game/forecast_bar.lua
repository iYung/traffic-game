local Timer = require("lua/core/timer")
local Forecast = require("lua/game/forecast")

local ForecastBar = {}
ForecastBar.__index = ForecastBar

ForecastBar.SPAWN_INTERVAL = 4 -- seconds between new forecast entries

function ForecastBar.new(letters)
    local self = setmetatable({}, ForecastBar)
    self.timer = Timer.new(ForecastBar.SPAWN_INTERVAL)
    self.entries = {}
    self.letters = letters
    return self
end

function ForecastBar:_pick_pair()
    local origin = self.letters[math.random(#self.letters)]
    local dest = self.letters[math.random(#self.letters)]
    while dest == origin do
        dest = self.letters[math.random(#self.letters)]
    end
    return origin, dest
end

function ForecastBar:update(dt, buildings_by_letter)
    if self.timer:update(dt) then
        local origin, dest = self:_pick_pair()
        table.insert(self.entries, Forecast.new(origin, dest, 6))
    end

    for i = #self.entries, 1, -1 do
        local entry = self.entries[i]
        entry:update(dt)
        if entry:is_offscreen_left() then
            local building = buildings_by_letter[entry.origin]
            for _ = 1, entry.count do
                building:enqueue(entry.dest)
            end
            table.remove(self.entries, i)
        end
    end
end

function ForecastBar:draw()
    for _, entry in ipairs(self.entries) do
        entry:draw(0)
    end
end

return ForecastBar
