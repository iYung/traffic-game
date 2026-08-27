-- test_basics.lua
-- Minimal example demonstrating the headless test infrastructure.
--
-- NOTE: GameScene has no keyboard input to script (mouse-click-only via
-- love.mousepressed), so this test just ticks a fresh scene and checks it
-- doesn't error.

local runner = require("lua/headless/runner")

-- Test 1: a fresh GameScene can be ticked without error.
-- scene_factory receives (input, sm) from runner.setup but GameScene.new()
-- takes no arguments; simply ignore the args and return a new scene.
local ctx = runner.setup(function(input, sm)
    return require("game/scenes/game_scene").new()
end)

runner.tick(ctx.input, ctx.sm, 10)

assert(ctx.sm.current ~= nil, "sm.current should not be nil after tick")
print("PASS: scene ticks without error")

print("ALL TESTS PASSED")
