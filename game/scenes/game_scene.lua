local Scene     = require("lua/core/scene")
local GameState = require("lua/game/game_state")

local GameScene = {}
GameScene.__index = GameScene

function GameScene.new()
    local self = Scene.new(1280, 720)
    setmetatable(self, GameScene)
    return self
end

function GameScene:on_enter()
    self.state = GameState.new()

    -- Camera:attach() computes screen = (w/2, h/2) + zoom*(world - camera_pos).
    -- The default camera.x, camera.y = 0, 0 would shift every draw call by
    -- (640, 360) off-canvas, so cancel that offset once here (not a per-frame
    -- follow) so world pixel coordinates map 1:1 to screen coordinates.
    self.camera.x = 640
    self.camera.y = 360

    -- main.lua stays unmodified, so the scene installs the mouse handler.
    local state = self.state
    love.mousepressed = function(x, y, button)
        if button == 1 then
            state:toggle_road_at_pixel(x, y)
        end
    end
end

function GameScene:update(dt)
    self.state:update(dt)
end

function GameScene:draw()
    self.camera:attach()
    self.state:draw()
    self.camera:detach()
end

return GameScene
