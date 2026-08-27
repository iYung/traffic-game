local Grid = require("lua/game/grid")
local Car = require("lua/game/car")

local function approx_eq(a, b, eps)
    eps = eps or 1e-6
    return math.abs(a - b) < eps
end

-- Test 1: construction positions the car at path[1]'s pixel center; a
-- multi-step path stays "waiting" until granted
do
    local grid = Grid.new()
    local path = {
        { col = 10, row = 10 },
        { col = 11, row = 10 },
        { col = 12, row = 10 },
    }
    local car = Car.new(path, grid)

    local ex, ey = grid:subcell_to_pixel(10, 10)
    assert(car.x == ex, "car.x should start at path[1]'s pixel center x")
    assert(car.y == ey, "car.y should start at path[1]'s pixel center y")
    assert(car.index == 1, "index should start at 1")
    assert(car.state == "waiting", "multi-step path should start 'waiting'")
    assert(car:wait_time() == 0, "wait_time should start at 0")

    -- current_subcell / next_subcell / is_arrived basics
    local cur = car:current_subcell()
    assert(cur.col == 10 and cur.row == 10, "current_subcell should be path[1]")
    local nxt = car:next_subcell()
    assert(nxt.col == 11 and nxt.row == 10, "next_subcell should be path[2]")
    assert(car:is_arrived() == false, "car should not be arrived yet")

    -- still waiting after a tick with no grant
    car:tick(1)
    assert(car.state == "waiting", "car should remain 'waiting' without grant_move()")
    assert(car.x == ex and car.y == ey, "car should not move while waiting")
    print("PASS: car: construction at path[1] center, waits until granted")
end

-- Test 2: grant_move() transitions "waiting" -> "moving"
do
    local grid = Grid.new()
    local path = {
        { col = 10, row = 10 },
        { col = 11, row = 10 },
    }
    local car = Car.new(path, grid)
    assert(car.state == "waiting")

    car:grant_move()
    assert(car.state == "moving", "grant_move() should transition to 'moving'")

    local tx, ty = grid:subcell_to_pixel(11, 10)
    assert(car.target_x == tx and car.target_y == ty, "grant_move() should set target pixel to next_subcell's center")
    print("PASS: car: grant_move() transitions waiting -> moving")
end

-- Test 3: tick(dt) partial movement interpolates without overshoot, and
-- enough tick(dt) calls advance exactly to the next sub-cell's center,
-- flipping back to "waiting" (mid-path) or "arrived" (final step)
do
    local grid = Grid.new()
    local path = {
        { col = 10, row = 10 },
        { col = 11, row = 10 },
        { col = 12, row = 10 },
    }
    local car = Car.new(path, grid)
    car:grant_move()

    local sx, sy = grid:subcell_to_pixel(10, 10)
    local tx, ty = grid:subcell_to_pixel(11, 10)
    local dist = tx - sx -- adjacent sub-cells in the same row: one SUBCELL_SIZE apart
    local full_dt = dist / Car.SPEED
    local half_dt = full_dt / 2

    -- partial tick: should move halfway, stay "moving"
    car:tick(half_dt)
    assert(car.state == "moving", "car should still be 'moving' mid-transit")
    assert(approx_eq(car.x, sx + dist / 2), "partial tick should move car halfway in x, got " .. tostring(car.x))
    assert(approx_eq(car.y, sy), "y should be unchanged along a same-row move")
    assert(car.index == 1, "index should not advance mid-transit")

    -- second half: should land exactly on target and flip to "waiting"
    -- (mid-path, more sub-cells remain)
    car:tick(half_dt)
    assert(car.x == tx and car.y == ty, "car should snap exactly to next sub-cell's center")
    assert(car.index == 2, "index should advance to 2 after reaching the sub-cell")
    assert(car.state == "waiting", "car should flip to 'waiting' after a mid-path arrival")
    assert(car:wait_time() == 0, "wait_time should reset to 0 on arrival at a new sub-cell")

    -- grant the final move and cover it in one big tick (clamped, not
    -- overshooting past the final target)
    car:grant_move()
    local fx, fy = grid:subcell_to_pixel(12, 10)
    car:tick(full_dt * 10) -- deliberately oversized dt
    assert(car.x == fx and car.y == fy, "car should clamp exactly to the final sub-cell center, not overshoot")
    assert(car.index == 3, "index should advance to 3 (last path entry) on final arrival")
    assert(car:is_arrived() == true, "car should report is_arrived() once index reaches #path")
    assert(car.state == "arrived", "car should flip to 'arrived' on reaching the final sub-cell")
    print("PASS: car: tick(dt) advances to next sub-cell center and flips state correctly")
end

-- Test 4: wait_time() accumulates correctly across multiple tick(dt) calls
-- while "waiting" and resets to 0 on grant_move()
do
    local grid = Grid.new()
    local path = {
        { col = 0, row = 0 },
        { col = 1, row = 0 },
        { col = 2, row = 0 },
    }
    local car = Car.new(path, grid)
    assert(car:wait_time() == 0, "wait_time starts at 0")

    car:tick(0.1)
    assert(approx_eq(car:wait_time(), 0.1), "wait_time should accumulate to 0.1")
    car:tick(0.25)
    assert(approx_eq(car:wait_time(), 0.35), "wait_time should accumulate to 0.35")
    car:tick(0.05)
    assert(approx_eq(car:wait_time(), 0.4), "wait_time should accumulate to 0.4")

    car:grant_move()
    assert(car:wait_time() == 0, "wait_time should reset to 0 on grant_move()")
    assert(car.state == "moving", "car should be 'moving' after grant_move()")

    -- ticking while moving should not touch wait_time
    car:tick(0.01)
    assert(car:wait_time() == 0, "wait_time should not accumulate while moving")
    print("PASS: car: wait_time() accumulates while waiting and resets on grant_move()")
end

-- Test 5: a single-sub-cell path (start == goal) is "arrived" immediately
do
    local grid = Grid.new()
    local path = { { col = 5, row = 5 } }
    local car = Car.new(path, grid)

    local ex, ey = grid:subcell_to_pixel(5, 5)
    assert(car.x == ex and car.y == ey, "single-subcell car should still be positioned at its subcell's center")
    assert(car.state == "arrived", "single-subcell path should be 'arrived' immediately")
    assert(car:is_arrived() == true, "is_arrived() should be true immediately")
    assert(car:next_subcell() == nil, "next_subcell() should be nil at the end of the path")

    -- grant_move() should be a no-op when already arrived
    car:grant_move()
    assert(car.state == "arrived", "grant_move() should not change an already-arrived car")

    -- tick() should be a no-op too
    car:tick(1)
    assert(car.x == ex and car.y == ey, "tick() should not move an arrived car")
    assert(car.state == "arrived", "tick() should not change an arrived car's state")
    print("PASS: car: single-sub-cell path is arrived immediately")
end

-- Test 6: grant_move() is a no-op when not "waiting" (e.g. already "moving"),
-- and a no-op at the final sub-cell (no next_subcell())
do
    local grid = Grid.new()
    local path = {
        { col = 0, row = 0 },
        { col = 1, row = 0 },
    }
    local car = Car.new(path, grid)
    car:grant_move()
    assert(car.state == "moving")
    local tx, ty = car.target_x, car.target_y

    -- calling grant_move() again while already moving should not reset it
    car:grant_move()
    assert(car.state == "moving", "grant_move() should be a no-op while already 'moving'")
    assert(car.target_x == tx and car.target_y == ty, "target should be unchanged")

    -- drive it to arrival, then grant_move() should no-op (no next_subcell)
    local dist = math.sqrt((tx - car.x) ^ 2 + (ty - car.y) ^ 2)
    car:tick(dist / Car.SPEED)
    assert(car.state == "arrived")
    car:grant_move()
    assert(car.state == "arrived", "grant_move() should no-op once arrived (no next_subcell())")
    print("PASS: car: grant_move() is a no-op unless 'waiting' with a next_subcell()")
end

print("ALL TESTS PASSED")
