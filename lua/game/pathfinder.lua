local Pathfinder = {}

-- BFS over the sub-cell graph exposed by Grid:subcell_neighbors.
-- start/goal are {col=, row=} sub-cell tables.
-- Returns an array of {col=, row=} sub-cells from start to goal inclusive,
-- in order, or nil if no path exists.
function Pathfinder.find_path(grid, start, goal)
    if start.col == goal.col and start.row == goal.row then
        return { { col = start.col, row = start.row } }
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
            if not visited[nkey] then
                visited[nkey] = true
                came_from[nkey] = node
                table.insert(queue, n)
            end
        end
    end

    return nil
end

return Pathfinder
