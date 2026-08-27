local Scene     = require("lua/core/scene")
local GameState = require("lua/game/game_state")

local GameScene = {}
GameScene.__index = GameScene

-- Bresenham line between two grid cells, inclusive of both endpoints, so a
-- fast mouse drag still draws a continuous road instead of skipping cells
-- between two mousemoved samples.
local function bresenham_cells(c0, r0, c1, r1)
    local cells = {}
    local dcol  = math.abs(c1 - c0)
    local drow  = -math.abs(r1 - r0)
    local scol  = (c0 < c1) and 1 or -1
    local srow  = (r0 < r1) and 1 or -1
    local err   = dcol + drow
    local col, row = c0, r0

    while true do
        table.insert(cells, { col = col, row = row })
        if col == c1 and row == r1 then break end
        local e2 = 2 * err
        if e2 >= drow then
            err = err + drow
            col = col + scol
        end
        if e2 <= dcol then
            err = err + dcol
            row = row + srow
        end
    end

    return cells
end

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

    -- main.lua stays unmodified, so the scene installs the mouse handlers.
    -- Click-and-drag: mousepressed starts a drag and draws the cell under
    -- the cursor; mousemoved, while dragging, draws a continuous line of
    -- roads from the last visited cell to the current one (bresenham,
    -- so a fast drag doesn't leave gaps between sampled positions);
    -- mousereleased ends the drag.
    local state = self.state
    local grid  = state.grid
    self._dragging  = false
    self._last_cell = nil

    local function drag_to(x, y)
        local col, row = grid:pixel_to_cell(x, y)
        if col == nil then
            return
        end
        if self._last_cell then
            for _, c in ipairs(bresenham_cells(self._last_cell.col, self._last_cell.row, col, row)) do
                state:toggle_road_at_cell(c.col, c.row)
            end
        else
            state:toggle_road_at_cell(col, row)
        end
        self._last_cell = { col = col, row = row }
    end

    love.mousepressed = function(x, y, button)
        if button == 1 then
            self._dragging  = true
            self._last_cell = nil
            drag_to(x, y)
        end
    end

    love.mousemoved = function(x, y, dx, dy, istouch)
        if self._dragging then
            drag_to(x, y)
        end
    end

    love.mousereleased = function(x, y, button)
        if button == 1 then
            self._dragging  = false
            self._last_cell = nil
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
