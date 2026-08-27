local Grid = require("lua/game/grid")
local Pathfinder = require("lua/game/pathfinder")

-- Test 1: a straight line of road cells produces a path of the expected
-- sub-cell length
do
    local g = Grid.new()
    g:set_road(0, 0)
    g:set_road(1, 0)
    g:set_road(2, 0)

    local start = { col = 0, row = 0 } -- top-left sub-cell of cell (0,0)
    local goal = { col = 4, row = 0 } -- top-left sub-cell of cell (2,0)

    local path = Pathfinder.find_path(g, start, goal)
    assert(path ~= nil, "expected a path along the straight line of roads")
    -- 6, not 5: lane discipline means eastbound travel must run along the
    -- bottom row (ly==1), so the path needs one intra-cell hop to shift off
    -- the top-row (0,0) start onto that lane, and one more at the very end
    -- to shift back onto the top-row (4,0) goal -- see Grid:subcell_neighbors.
    assert(#path == 6, "expected path length 6 (lane-shift + 3 eastbound hops + lane-shift), got " .. tostring(#path))
    assert(path[1].col == 0 and path[1].row == 0, "path should start at start sub-cell")
    assert(path[#path].col == 4 and path[#path].row == 0, "path should end at goal sub-cell")
    print("PASS: pathfinder: straight line of roads produces expected path length")
end

-- Test 2: no road between two points returns nil
do
    local g = Grid.new()
    local start = { col = 0, row = 0 }
    local goal = { col = 10, row = 10 }

    local path = Pathfinder.find_path(g, start, goal)
    assert(path == nil, "expected nil when no road connects start and goal")
    print("PASS: pathfinder: no road returns nil")
end

-- Test 3: a path exists through a building cell endpoint (buildings are
-- passable)
do
    local g = Grid.new()
    g:set_building(0, 0, "A")
    g:set_road(1, 0)

    local start = { col = 0, row = 0 } -- building's spawn sub-cell
    local goal = { col = 2, row = 0 } -- top-left sub-cell of road cell (1,0)

    local path = Pathfinder.find_path(g, start, goal)
    assert(path ~= nil, "expected a path from a building sub-cell into an adjacent road")
    -- 4, not 3: same lane-discipline lane-shift as the straight-line test.
    assert(#path == 4, "expected path length 4, got " .. tostring(#path))
    assert(path[1].col == 0 and path[1].row == 0, "path should start at the building sub-cell")
    assert(path[#path].col == 2 and path[#path].row == 0, "path should end at the goal sub-cell")
    print("PASS: pathfinder: path found through a building cell endpoint")
end

-- Test 4: start == goal returns a 1-element path
do
    local g = Grid.new()
    local sc = { col = 7, row = 9 }

    local path = Pathfinder.find_path(g, sc, sc)
    assert(path ~= nil, "expected a non-nil path when start == goal")
    assert(#path == 1, "expected a 1-element path, got " .. tostring(#path))
    assert(path[1].col == 7 and path[1].row == 9, "the single element should be the shared start/goal sub-cell")
    print("PASS: pathfinder: start == goal returns a 1-element path")
end

-- Test 5: a detour is required when the direct route is blocked — verify
-- BFS actually finds the longer valid route, not just "any" failure
do
    local g = Grid.new()
    -- Row 0: road, BLOCKED (empty), road
    g:set_road(0, 0)
    -- (1, 0) left empty on purpose -- blocks the direct route
    g:set_road(2, 0)
    -- Row 1: road, road, road -- the detour path
    g:set_road(0, 1)
    g:set_road(1, 1)
    g:set_road(2, 1)

    local start = { col = 0, row = 0 } -- top-left sub-cell of cell (0,0)
    local goal = { col = 4, row = 0 } -- top-left sub-cell of cell (2,0)

    local path = Pathfinder.find_path(g, start, goal)
    assert(path ~= nil, "expected a detour path to be found around the blocked cell")
    assert(path[1].col == 0 and path[1].row == 0, "detour path should start at start sub-cell")
    assert(path[#path].col == 4 and path[#path].row == 0, "detour path should end at goal sub-cell")

    -- the unobstructed straight-line distance between these two sub-cells
    -- would be 6 nodes (as in test 1); since the direct route is blocked,
    -- the real path must be strictly longer.
    assert(#path > 6, "expected detour path to be longer than the unobstructed straight-line path, got " .. tostring(#path))

    -- verify the path genuinely dips into row 1 (srow >= 2) to go around
    -- the blocker, rather than being some other invalid shortcut
    local visited_row1 = false
    for _, sub in ipairs(path) do
        if sub.row >= 2 then
            visited_row1 = true
        end
    end
    assert(visited_row1, "expected the detour path to pass through row 1's sub-cells")

    -- verify every consecutive pair in the returned path is actually an
    -- edge in the grid's adjacency graph (a real, walkable route)
    for i = 1, #path - 1 do
        local a, b = path[i], path[i + 1]
        local neighbors = g:subcell_neighbors(a.col, a.row)
        local found = false
        for _, n in ipairs(neighbors) do
            if n.col == b.col and n.row == b.row then
                found = true
            end
        end
        assert(found, "path step from (" .. a.col .. "," .. a.row .. ") to (" .. b.col .. "," .. b.row .. ") is not a valid graph edge")
    end
    print("PASS: pathfinder: detour required when direct route is blocked")
end

-- Test 6: a third-party building blocks through-traffic -- it is only
-- walkable as the trip's own start/goal, not as a shortcut for someone
-- else's trip, even though Grid:is_passable treats it as structurally
-- passable (buildings connect to their own adjacent roads).
do
    local g = Grid.new()
    g:set_road(0, 0)
    g:set_building(1, 0, "X") -- sits directly in the only row -- no detour
    g:set_road(2, 0)

    local start = { col = 0, row = 0 } -- top-left sub-cell of road cell (0,0)
    local goal = { col = 4, row = 0 } -- top-left sub-cell of road cell (2,0)

    local path = Pathfinder.find_path(g, start, goal)
    assert(path == nil,
        "a building with no road detour must block the route, not be driven through, got a path of length "
        .. tostring(path and #path))
    print("PASS: pathfinder: a building with no detour blocks through-traffic (not driven through)")
end

-- Test 7: when a detour around the building exists, the path takes it
-- instead of cutting through the building's sub-cells.
do
    local g = Grid.new()
    g:set_road(0, 0)
    g:set_building(1, 0, "X") -- blocks row 0 directly between start and goal
    g:set_road(2, 0)
    g:set_road(0, 1)
    g:set_road(1, 1)
    g:set_road(2, 1) -- detour row

    local start = { col = 0, row = 0 }
    local goal = { col = 4, row = 0 }

    local path = Pathfinder.find_path(g, start, goal)
    assert(path ~= nil, "expected a detour path around the building")

    for _, sub in ipairs(path) do
        local c, r = g:subcell_to_cell(sub.col, sub.row)
        assert(not (c == 1 and r == 0),
            "path must not pass through building cell (1,0), got sub-cell (" .. sub.col .. "," .. sub.row .. ")")
    end
    print("PASS: pathfinder: a detour route around a building never enters the building's sub-cells")
end

print("ALL TESTS PASSED")
