-- test_game_scene.lua
-- Integration test for GameScene: verifies GameState wiring, the
-- love.mousepressed -> toggle_road_at_pixel click handler installed in
-- on_enter, and the camera identity-mapping fix (camera.x/y set so world
-- pixel coordinates map 1:1 to screen coordinates).

local runner = require("lua/headless/runner")

local ctx = runner.setup(function(input, sm)
    return require("game/scenes/game_scene").new()
end)

local scene = ctx.sm.current

-- Test 1: on_enter creates a GameState and sets the camera for 1:1 mapping.
do
    assert(scene.state ~= nil, "GameScene should create a GameState in on_enter")
    assert(scene.camera.x == 640, "camera.x should be set to w/2 (640) for identity mapping, got " .. tostring(scene.camera.x))
    assert(scene.camera.y == 360, "camera.y should be set to h/2 (360) for identity mapping, got " .. tostring(scene.camera.y))
    print("PASS: game_scene: on_enter creates GameState and sets identity-mapping camera")
end

-- Test 2: love.mousepressed on an empty cell toggles it to a road.
do
    local grid = scene.state.grid
    assert(grid:is_empty(10, 10), "cell (10,10) should start empty")
    local px, py = grid:cell_to_pixel(10, 10)
    love.mousepressed(px + 1, py + 1, 1)
    assert(grid:is_road(10, 10), "clicking an empty cell should turn it into a road")
    print("PASS: game_scene: left-click on an empty cell draws a road")
end

-- Test 3: clicking a building cell is a no-op (doesn't overwrite it).
do
    local grid = scene.state.grid
    assert(grid:is_building(4, 4), "cell (4,4) should be building A per the fixed layout")
    local px, py = grid:cell_to_pixel(4, 4)
    love.mousepressed(px + 1, py + 1, 1)
    assert(grid:is_building(4, 4), "clicking a building cell must not change its state")
    print("PASS: game_scene: left-click on a building cell is a no-op")
end

-- Test 4: clicking inside the forecast bar (y < 40) does not error and does nothing.
do
    local ok = pcall(function() love.mousepressed(500, 10, 1) end)
    assert(ok, "clicking the forecast bar strip should not error")
    print("PASS: game_scene: left-click in the forecast bar area does not error")
end

-- Test 5: a non-left click does not draw a road.
do
    local grid = scene.state.grid
    assert(grid:is_empty(20, 20), "cell (20,20) should start empty")
    local px, py = grid:cell_to_pixel(20, 20)
    love.mousepressed(px + 1, py + 1, 2)
    assert(grid:is_empty(20, 20), "a non-left click should not draw a road")
    print("PASS: game_scene: non-left-click does not draw a road")
end

print("ALL TESTS PASSED")
