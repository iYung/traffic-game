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

-- Test 6: subcell_neighbors — 3 same-cell neighbors plus cross-cell only when adjacent cell is road
do
    local g = Grid.new()
    g:set_road(5, 5)
    -- neighbor cell to the east is a road, so the east-edge subcell should connect across
    g:set_road(6, 5)
    -- neighbor cell to the west stays empty

    local subs = g:cell_subcells(5, 5)
    -- subs[1] = (10,10) local (0,0); subs[2] = (10,11) local (0,1);
    -- subs[3] = (11,10) local (1,0); subs[4] = (11,11) local (1,1)

    -- local (1,0) = east edge, top row -> scol=11, srow=10, lx=1, ly=0
    local nbrs_east = g:subcell_neighbors(11, 10)
    -- 3 same-cell neighbors: (10,10) (10,11) (11,11)
    local same_cell_count = 0
    local cross_cell_count = 0
    for _, n in ipairs(nbrs_east) do
        if n.col == 10 and n.row == 10 then same_cell_count = same_cell_count + 1 end
        if n.col == 10 and n.row == 11 then same_cell_count = same_cell_count + 1 end
        if n.col == 11 and n.row == 11 then same_cell_count = same_cell_count + 1 end
        -- cross-cell neighbor into cell (6,5)'s local (0,0) = (12, 10)
        if n.col == 12 and n.row == 10 then cross_cell_count = cross_cell_count + 1 end
    end
    assert(same_cell_count == 3, "expected 3 same-cell neighbors, matched " .. same_cell_count)
    assert(cross_cell_count == 1, "expected 1 cross-cell neighbor into road cell (6,5)")
    assert(#nbrs_east == 4, "east-edge subcell of a cell with a road neighbor should have 4 neighbors, got " .. tostring(#nbrs_east))

    -- local (0,0) = west edge, top row -> scol=10, srow=10, lx=0, ly=0.
    -- west neighbor cell (4,5) is empty, so no cross-cell connection there.
    local nbrs_west = g:subcell_neighbors(10, 10)
    assert(#nbrs_west == 3, "west-edge subcell against an empty neighbor cell should have only 3 neighbors, got " .. tostring(#nbrs_west))
    print("PASS: grid: subcell_neighbors same-cell + cross-cell-only-if-road")
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
