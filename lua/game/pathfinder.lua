local Pathfinder = {}

-- BFS over the sub-cell graph exposed by Grid:subcell_neighbors.
-- start/goal are {col=, row=} sub-cell tables.
-- Returns an array of {col=, row=} sub-cells from start to goal inclusive,
-- in order, or nil if no path exists.
--
-- Buildings are only walkable as the trip's own endpoints. Grid:is_passable
-- treats every building cell as structurally passable (so a building's own
-- sub-cells connect to an adjacent road), but that makes every OTHER
-- building a valid shortcut for unrelated traffic too -- cars would drive
-- straight through a third building's cell if that happened to be the
-- shortest route. Since "passable" here depends on whose trip this is (not
-- a fixed grid property), the filter lives here rather than in Grid: a
-- sub-cell belonging to a building cell is only enterable if that building
-- cell is the start's or the goal's own cell.
function Pathfinder.find_path(grid, start, goal)
    if start.col == goal.col and start.row == goal.row then
        return { { col = start.col, row = start.row } }
    end

    local start_col, start_row = grid:subcell_to_cell(start.col, start.row)
    local goal_col, goal_row = grid:subcell_to_cell(goal.col, goal.row)

    local function is_own_endpoint_cell(c, r)
        return (c == start_col and r == start_row) or (c == goal_col and r == goal_row)
    end

    local function enterable(sc)
        local c, r = grid:subcell_to_cell(sc.col, sc.row)
        if grid:is_building(c, r) then
            return is_own_endpoint_cell(c, r)
        end
        return true
    end

    local function key(sc)
        return sc.col .. "," .. sc.row
    end

    local queue = { start }
    local head = 1
    local visited = { [key(start)] = true }
    local came_from = {}

    while head <= #queue do
        local node = queue[head]
        head = head + 1

        if node.col == goal.col and node.row == goal.row then
            local path = {}
            local cur = node
            while cur do
                table.insert(path, 1, { col = cur.col, row = cur.row })
                cur = came_from[key(cur)]
            end
            return path
        end

        local neighbors = grid:subcell_neighbors(node.col, node.row)
        for _, n in ipairs(neighbors) do
            local nkey = key(n)
            if not visited[nkey] and enterable(n) then
                visited[nkey] = true
                came_from[nkey] = node
                table.insert(queue, n)
            end
        end
    end

    return nil
end

return Pathfinder
