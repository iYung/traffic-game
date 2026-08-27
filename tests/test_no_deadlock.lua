local Grid = require("lua/game/grid")
local Building = require("lua/game/building")
local Car = require("lua/game/car")

-- Regression test for a head-on deadlock bug: two cars traveling opposite
-- directions along the same straight corridor used to be routed onto the
-- exact same sub-cells (a building's spawn/despawn point is always the
-- same fixed corner, so the shortest path was identical both ways), so
-- opposite-direction cars would meet in the middle and permanently block
-- each other -- neither car's target sub-cell would ever free up, since
-- each was itself occupying the other's target. Lane discipline in
-- Grid:subcell_neighbors fixes this by keeping opposite directions on
-- physically disjoint sub-cell rows/columns for the length of a shared
-- corridor. This test floods a single corridor with bidirectional traffic
-- and asserts both directions keep making progress instead of stalling.

local function is_free(cars, sc)
    for _, car in ipairs(cars) do
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

-- Mirrors GameState:update's spawn/tick/arbitrate/despawn steps, without
-- pulling in the fixed 5-building GameState layout, so this can flood an
-- arbitrary two-building corridor.
local function step(buildings, buildings_by_id, grid, cars, dt)
    for _, b in ipairs(buildings) do
        local path = b:try_spawn(grid, buildings_by_id, function(sc) return is_free(cars, sc) end)
        if path then
            table.insert(cars, Car.new(path, grid))
        end
    end

    for _, car in ipairs(cars) do
        car:tick(dt)
    end

    local contested = {}
    local order = {}
    for _, car in ipairs(cars) do
        if car.state == "waiting" then
            local nxt = car:next_subcell()
            if nxt then
                local key = nxt.col .. "," .. nxt.row
                if not contested[key] then
                    contested[key] = { sc = nxt, list = {} }
                    table.insert(order, key)
                end
                table.insert(contested[key].list, car)
            end
        end
    end
    for _, key in ipairs(order) do
        local group = contested[key]
        if is_free(cars, group.sc) then
            local best = nil
            for _, car in ipairs(group.list) do
                if best == nil or car:wait_time() > best:wait_time() then
                    best = car
                end
            end
            if best then
                best:grant_move()
            end
        end
    end

    local delivered = 0
    for i = #cars, 1, -1 do
        if cars[i]:is_arrived() then
            delivered = delivered + 1
            table.remove(cars, i)
        end
    end
    return delivered
end

-- Runs the flood-a-corridor scenario against a given grid/building pair and
-- asserts both directions keep delivering instead of stalling.
local function assert_no_deadlock(label, grid, a, b)
    local buildings = { a, b }
    local buildings_by_id = { [a.id] = a, [b.id] = b }
    local cars = {}

    local total_delivered = 0
    local ticks = 0
    local MAX_TICKS = 20000 -- ~333 simulated seconds at dt=1/60

    while total_delivered < 40 and ticks < MAX_TICKS do
        if a:queue_length() < 3 then
            a:enqueue(b.id)
        end
        if b:queue_length() < 3 then
            b:enqueue(a.id)
        end

        total_delivered = total_delivered + step(buildings, buildings_by_id, grid, cars, 1 / 60)
        ticks = ticks + 1
    end

    assert(total_delivered >= 40,
        "[" .. label .. "] expected 40 deliveries across both directions without deadlocking, got "
        .. total_delivered .. " after " .. ticks .. " ticks")
    print("PASS: no_deadlock: " .. label .. " bidirectional traffic keeps flowing ("
        .. total_delivered .. " delivered in " .. ticks .. " ticks)")
end

-- Test 1: horizontal corridor (east/west traffic)
do
    local grid = Grid.new()
    grid:set_building(0, 0, "A")
    for c = 1, 8 do
        grid:set_road(c, 0)
    end
    grid:set_building(9, 0, "B")

    local a = Building.new("A", 0, 0, { 1, 0, 0, 1 })
    local b = Building.new("B", 9, 0, { 0, 0, 1, 1 })
    assert_no_deadlock("horizontal corridor", grid, a, b)
end

-- Test 2: vertical corridor (north/south traffic) -- exercises the
-- north=right/south=left lane assignment specifically.
do
    local grid = Grid.new()
    grid:set_building(0, 0, "C")
    for r = 1, 8 do
        grid:set_road(0, r)
    end
    grid:set_building(0, 9, "D")

    local c = Building.new("C", 0, 0, { 1, 0.5, 0, 1 })
    local d = Building.new("D", 0, 9, { 0, 0.5, 1, 1 })
    assert_no_deadlock("vertical corridor", grid, c, d)
end

print("ALL TESTS PASSED")
