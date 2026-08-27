local Grid = require("lua/game/grid")

-- Test 1: default dimensions/constants
do
    assert(Grid.COLS == 64, "COLS should be 64, got " .. tostring(Grid.COLS))
    assert(Grid.ROWS == 34, "ROWS should be 34, got " .. tostring(Grid.ROWS))
    assert(Grid.CELL_SIZE == 20, "CELL_SIZE should be 20, got " .. tostring(Grid.CELL_SIZE))
    assert(Grid.FORECAST_BAR_H == 40, "FORECAST_BAR_H should be 40, got " .. tostring(Grid.FORECAST_BAR_H))
    assert(Grid.SUBCELLS_PER_CELL == 2, "SUBCELLS_PER_CELL should be 2, got " .. tostring(Grid.SUBCELLS_PER_CELL))
    assert(Grid.SUBCELL_SIZE == 10, "SUBCELL_SIZE should be 10, got " .. tostring(Grid.SUBCELL_SIZE))
    assert(Grid.SUB_COLS == 128, "SUB_COLS should be 128, got " .. tostring(Grid.SUB_COLS))
    assert(Grid.SUB_ROWS == 68, "SUB_ROWS should be 68, got " .. tostring(Grid.SUB_ROWS))

    local g = Grid.new()
    assert(g.cells[0][0] == "empty", "cell (0,0) should start empty")
    assert(g.cells[63][33] == "empty", "cell (63,33) should start empty")
    assert(g.building_at[0][0] == nil, "building_at (0,0) should start nil")
    print("PASS: grid: default dimensions/constants")
end

-- Test 2: cell_to_pixel / pixel_to_cell round-trip
do
    local g = Grid.new()
    local x, y = g:cell_to_pixel(5, 3)
    assert(x == 100, "cell_to_pixel x should be 100, got " .. tostring(x))
    assert(y == 100, "cell_to_pixel y should be 40 + 60 = 100, got " .. tostring(y))

    local col, row = g:pixel_to_cell(x, y)
    assert(col == 5, "round-trip col should be 5, got " .. tostring(col))
    assert(row == 3, "round-trip row should be 3, got " .. tostring(row))

    -- a pixel somewhere in the middle of the cell should still map back
    local col2, row2 = g:pixel_to_cell(x + 4, y + 4)
    assert(col2 == 5, "mid-cell pixel should map back to col 5, got " .. tostring(col2))
    assert(row2 == 3, "mid-cell pixel should map back to row 3, got " .. tostring(row2))
    print("PASS: grid: cell_to_pixel/pixel_to_cell round-trip")
end

-- Test 3: pixel_to_cell rejects forecast-bar-area clicks
do
    local g = Grid.new()
    local col, row = g:pixel_to_cell(100, 0)
    assert(col == nil and row == nil, "click in forecast bar (y=0) should return nil, nil")

    local col2, row2 = g:pixel_to_cell(100, 39)
    assert(col2 == nil and row2 == nil, "click at y=39 (still in bar) should return nil, nil")

    local col3, row3 = g:pixel_to_cell(100, 40)
    assert(col3 ~= nil and row3 ~= nil, "click at y=40 (just below bar) should be valid")

    -- out of bounds pixel (beyond canvas) also returns nil
    local col4, row4 = g:pixel_to_cell(999999, 999999)
    assert(col4 == nil and row4 == nil, "out-of-bounds click should return nil, nil")
    print("PASS: grid: pixel_to_cell rejects forecast-bar-area clicks")
end

-- Test 4: set_road refuses to overwrite a building cell
do
    local g = Grid.new()
    g:set_building(10, 10, "A")
    assert(g:is_building(10, 10), "cell should be a building")

    local changed = g:set_road(10, 10)
    assert(changed == false, "set_road on a building cell should return false")
    assert(g:is_building(10, 10), "cell should still be a building after failed set_road")

    -- sanity: set_road on empty succeeds
    local changed2 = g:set_road(11, 11)
    assert(changed2 == true, "set_road on empty cell should return true")
    assert(g:is_road(11, 11), "cell should now be a road")

    -- and set_road on an already-road cell fails
    local changed3 = g:set_road(11, 11)
    assert(changed3 == false, "set_road on an existing road cell should return false")

    -- out of bounds fails too
    local changed4 = g:set_road(-1, 0)
    assert(changed4 == false, "set_road out of bounds should return false")
    print("PASS: grid: set_road refuses to overwrite building/road/out-of-bounds cells")
end

-- Test 5: cell_subcells returns the correct 4 sub-cells for a cell
do
    local g = Grid.new()
    local subs = g:cell_subcells(3, 4)
    assert(#subs == 4, "cell_subcells should return 4 entries, got " .. tostring(#subs))

    local expected = {
        { col = 6, row = 8 },
        { col = 6, row = 9 },
        { col = 7, row = 8 },
        { col = 7, row = 9 },
    }
    for _, e in ipairs(expected) do
        local found = false
        for _, sc in ipairs(subs) do
            if sc.col == e.col and sc.row == e.row then
                found = true
            end
        end
        assert(found, "expected sub-cell (" .. e.col .. "," .. e.row .. ") to be present")
    end

    -- first sub-cell (top-left) should be the (dx=0, dy=0) one
    assert(subs[1].col == 6 and subs[1].row == 8, "first sub-cell should be top-left (6,8)")

    -- and subcell_to_cell inverts correctly for all 4
    for _, sc in ipairs(subs) do
        local col, row = g:subcell_to_cell(sc.col, sc.row)
        assert(col == 3 and row == 4, "subcell_to_cell should map back to (3,4)")
    end
    print("PASS: grid: cell_subcells returns correct 4 sub-cells")
end

-- Test 6: subcell_neighbors — 3 same-cell neighbors plus a cross-cell edge
-- only when the adjacent cell is a road AND the sub-cell is on the lane
-- assigned to that direction (lane discipline: eastbound/westbound are
-- separated by row (ly), southbound/northbound by column (lx), so
-- opposite-direction traffic never shares a sub-cell along a corridor).
do
    local g = Grid.new()
    g:set_road(5, 5)
    -- neighbor cell to the east is a road
    g:set_road(6, 5)
    -- neighbor cell to the west stays empty

    local subs = g:cell_subcells(5, 5)
    -- subs[1] = (10,10) local (0,0); subs[2] = (10,11) local (0,1);
    -- subs[3] = (11,10) local (1,0); subs[4] = (11,11) local (1,1)

    -- local (1,1) = east edge, bottom row (the eastbound lane) -> scol=11, srow=11, lx=1, ly=1
    local nbrs_east = g:subcell_neighbors(11, 11)
    local same_cell_count = 0
    local cross_cell_count = 0
    for _, n in ipairs(nbrs_east) do
        if n.col == 10 and n.row == 10 then same_cell_count = same_cell_count + 1 end
        if n.col == 10 and n.row == 11 then same_cell_count = same_cell_count + 1 end
        if n.col == 11 and n.row == 10 then same_cell_count = same_cell_count + 1 end
        -- cross-cell neighbor into cell (6,5)'s local (0,1) = (12, 11)
        if n.col == 12 and n.row == 11 then cross_cell_count = cross_cell_count + 1 end
    end
    assert(same_cell_count == 3, "expected 3 same-cell neighbors, matched " .. same_cell_count)
    assert(cross_cell_count == 1, "expected 1 cross-cell neighbor (eastbound lane) into road cell (6,5)")
    assert(#nbrs_east == 4, "eastbound-lane subcell of a cell with a road neighbor should have 4 neighbors, got " .. tostring(#nbrs_east))

    -- local (1,0) = east edge, top row (the *westbound* lane, not eastbound)
    -- -> lane discipline means this one must NOT cross east even though the
    -- neighbor cell is a passable road.
    local nbrs_wrong_lane = g:subcell_neighbors(11, 10)
    assert(#nbrs_wrong_lane == 3, "top-row east-edge subcell (westbound lane) must not cross east, got " .. tostring(#nbrs_wrong_lane))

    -- local (0,0) = west edge, top row (the westbound lane) -> scol=10, srow=10, lx=0, ly=0.
    -- west neighbor cell (4,5) is empty, so no cross-cell connection there.
    local nbrs_west = g:subcell_neighbors(10, 10)
    assert(#nbrs_west == 3, "west-edge subcell against an empty neighbor cell should have only 3 neighbors, got " .. tostring(#nbrs_west))
    print("PASS: grid: subcell_neighbors same-cell + lane-disciplined cross-cell edges")
end

-- Test 6b: lane discipline keeps opposite directions on disjoint sub-cells
-- along a shared corridor (the actual fix for the head-on deadlock bug).
do
    local g = Grid.new()
    g:set_road(5, 5)
    g:set_road(6, 5)
    g:set_road(7, 5)

    -- eastbound lane subcells run along the bottom row (ly==1)
    local e1 = g:subcell_neighbors(11, 11) -- cell (5,5) east edge, bottom row
    local crossed_to_6 = nil
    for _, n in ipairs(e1) do
        if n.col == 12 then crossed_to_6 = n end
    end
    assert(crossed_to_6 ~= nil, "eastbound lane should cross from cell (5,5) into cell (6,5)")
    assert(crossed_to_6.row == 11, "eastbound lane should stay on the bottom row (srow=11) crossing into cell (6,5)")

    -- westbound lane subcells run along the top row (ly==0), and must never
    -- visit the eastbound lane's sub-cells while traversing the same cells
    local w1 = g:subcell_neighbors(12, 10) -- cell (6,5) west edge, top row
    local crossed_to_5 = nil
    for _, n in ipairs(w1) do
        if n.col == 11 then crossed_to_5 = n end
    end
    assert(crossed_to_5 ~= nil, "westbound lane should cross from cell (6,5) into cell (5,5)")
    assert(crossed_to_5.row == 10, "westbound lane should stay on the top row (srow=10) crossing into cell (5,5)")
    assert(crossed_to_5.row ~= crossed_to_6.row, "eastbound and westbound lanes must use disjoint sub-cell rows")
    print("PASS: grid: eastbound/westbound lanes stay on disjoint sub-cell rows")
end

-- Test 6c: vertical lane discipline — northbound uses the right column
-- (lx==1), southbound uses the left column (lx==0), and they stay
-- disjoint along a shared vertical corridor.
do
    local g = Grid.new()
    g:set_road(5, 5)
    g:set_road(5, 6)

    -- southbound lane: left column, bottom row of cell (5,5) -> scol=10, srow=11
    local s1 = g:subcell_neighbors(10, 11)
    local crossed_south = nil
    for _, n in ipairs(s1) do
        if n.row == 12 then crossed_south = n end
    end
    assert(crossed_south ~= nil, "southbound lane should cross from cell (5,5) into cell (5,6)")
    assert(crossed_south.col == 10, "southbound lane should stay on the left column (scol=10) crossing into cell (5,6)")

    -- northbound lane: right column, top row of cell (5,6) -> scol=11, srow=12
    local n1 = g:subcell_neighbors(11, 12)
    local crossed_north = nil
    for _, n in ipairs(n1) do
        if n.row == 11 then crossed_north = n end
    end
    assert(crossed_north ~= nil, "northbound lane should cross from cell (5,6) into cell (5,5)")
    assert(crossed_north.col == 11, "northbound lane should stay on the right column (scol=11) crossing into cell (5,5)")
    assert(crossed_north.col ~= crossed_south.col, "northbound and southbound lanes must use disjoint sub-cell columns")

    -- the "wrong" corner (right column, bottom row -- the east/south-facing
    -- corner) must not itself be usable to cross south
    local wrong_south = g:subcell_neighbors(11, 11)
    for _, n in ipairs(wrong_south) do
        assert(n.row ~= 12, "right-column bottom-row subcell (not the southbound lane) must not cross south")
    end
    print("PASS: grid: northbound/southbound lanes stay on disjoint sub-cell columns (north=right, south=left)")
end

-- Test 7: subcell_neighbors returns fewer neighbors at grid edges / against empty cells
do
    local g = Grid.new()
    g:set_road(0, 0) -- top-left corner cell, no valid neighbors above/left

    -- local (0,0) of cell (0,0): scol=0, srow=0. lx=0 -> checks col-1 = -1 (out of bounds, not passable).
    -- ly=0 -> checks row-1 = -1 (out of bounds, not passable).
    local nbrs = g:subcell_neighbors(0, 0)
    assert(#nbrs == 3, "corner sub-cell with no passable neighbors beyond its own cell should have 3 neighbors, got " .. tostring(#nbrs))

    -- an isolated road cell surrounded by empty cells: every edge subcell has only 3 neighbors
    local g2 = Grid.new()
    g2:set_road(10, 10)
    local subs = g2:cell_subcells(10, 10)
    for _, sc in ipairs(subs) do
        local n = g2:subcell_neighbors(sc.col, sc.row)
        assert(#n == 3, "isolated road cell's sub-cells should each have exactly 3 neighbors (no passable adjacent cells), got " .. tostring(#n))
    end
    print("PASS: grid: subcell_neighbors returns fewer neighbors at edges/against empty cells")
end

print("ALL TESTS PASSED")
