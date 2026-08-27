local Pathfinder = require("lua/game/pathfinder")

local Building = {}
Building.__index = Building

function Building.new(letter, col, row, color)
    local self = setmetatable({}, Building)
    self.id = letter
    self.letter = letter
    self.col = col
    self.row = row
    self.color = color
    self.queue = {}
    return self
end

function Building:enqueue(dest_id)
    table.insert(self.queue, dest_id)
end

function Building:queue_length()
    return #self.queue
end

function Building:spawn_subcell(grid)
    return grid:cell_subcells(self.col, self.row)[1]
end

function Building:try_spawn(grid, buildings_by_id, is_subcell_free)
    if #self.queue == 0 then
        return nil
    end

    local dest_id = self.queue[1]
    local dest = buildings_by_id[dest_id]

    local start_sc = self:spawn_subcell(grid)
    local goal_sc = dest:spawn_subcell(grid)

    local path = Pathfinder.find_path(grid, start_sc, goal_sc)
    if not path then
        return nil
    end

    if not is_subcell_free(start_sc) then
        return nil
    end

    table.remove(self.queue, 1)
    return path
end

return Building
