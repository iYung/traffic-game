local Forecast = require("lua/game/forecast")

-- Test 1: construction stores origin/dest/count/x (default x = SPAWN_X)
do
    local f = Forecast.new("A", "B", 6)
    assert(f.origin == "A", "origin should be 'A', got " .. tostring(f.origin))
    assert(f.dest   == "B", "dest should be 'B', got " .. tostring(f.dest))
    assert(f.count  == 6,   "count should be 6, got " .. tostring(f.count))
    assert(f.x == Forecast.SPAWN_X, "x should default to SPAWN_X, got " .. tostring(f.x))
    print("PASS: forecast: construction stores origin/dest/count and defaults x to SPAWN_X")
end

-- Test 2: construction with explicit x stores that x
do
    local f = Forecast.new("C", "D", 6, 500)
    assert(f.x == 500, "x should be 500, got " .. tostring(f.x))
    print("PASS: forecast: construction stores explicit x")
end

-- Test 3: update(dt) moves x left by exactly SPEED * dt
do
    local f = Forecast.new("A", "B", 6, 1000)
    f:update(0.5)
    assert(f.x == 1000 - Forecast.SPEED * 0.5,
        "x should be " .. (1000 - Forecast.SPEED * 0.5) .. ", got " .. tostring(f.x))
    print("PASS: forecast: update(dt) moves x left by SPEED * dt")
end

-- Test 4: is_offscreen_left() is false when just spawned
do
    local f = Forecast.new("A", "B", 6)
    assert(f:is_offscreen_left() == false, "freshly spawned forecast should not be offscreen")
    print("PASS: forecast: is_offscreen_left() false when just spawned")
end

-- Test 5: is_offscreen_left() becomes true once x is moved past -WIDTH
do
    local f = Forecast.new("A", "B", 6, -Forecast.WIDTH + 1)
    assert(f:is_offscreen_left() == false, "should not be offscreen at x = -WIDTH + 1")

    f.x = -Forecast.WIDTH - 1
    assert(f:is_offscreen_left() == true, "should be offscreen at x = -WIDTH - 1")
    print("PASS: forecast: is_offscreen_left() true once x moves past -WIDTH")
end

-- Test 6: label() produces the exact "A -> B x6" format
do
    local f = Forecast.new("A", "B", 6)
    assert(f:label() == "A -> B x6", "label should be 'A -> B x6', got '" .. f:label() .. "'")
    print("PASS: forecast: label() produces exact 'A -> B x6' format")
end

-- Test 7: draw(y) does not error (headless stub no-ops love.graphics.print)
do
    local f = Forecast.new("A", "B", 6)
    f:draw(0)
    print("PASS: forecast: draw(y) runs without error")
end

-- Test 8: draw(y) sets an opaque white color before printing the label.
-- Regression test: this used to inherit whatever color the caller (the
-- forecast bar's dark background fill) last set, making the text
-- invisible against it.
do
    local set_calls = {}
    local orig_setColor = love.graphics.setColor
    love.graphics.setColor = function(...) table.insert(set_calls, { ... }) end

    local printed_color = nil
    local orig_print = love.graphics.print
    love.graphics.print = function(...)
        printed_color = set_calls[#set_calls]
    end

    -- simulate the caller having last set a dark color, as GameState:draw()
    -- does for the forecast bar's background rectangle
    love.graphics.setColor(0.05, 0.05, 0.15, 1)

    local f = Forecast.new("A", "B", 6)
    f:draw(0)

    love.graphics.setColor = orig_setColor
    love.graphics.print = orig_print

    assert(printed_color ~= nil, "draw() should call setColor before print")
    assert(printed_color[1] == 1 and printed_color[2] == 1 and printed_color[3] == 1 and printed_color[4] == 1,
        "draw() should set opaque white before printing, got " .. table.concat(printed_color, ","))
    print("PASS: forecast: draw() sets an opaque white color before printing (visibility fix)")
end

print("ALL TESTS PASSED")
