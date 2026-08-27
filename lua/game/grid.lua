local Grid = {}
Grid.__index = Grid

Grid.COLS = 128
Grid.ROWS = 68
Grid.CELL_SIZE = 10
Grid.FORECAST_BAR_H = 40
Grid.SUBCELLS_PER_CELL = 2
Grid.SUBCELL_SIZE = 5
Grid.SUB_COLS = 256
Grid.SUB_ROWS = 136

function Grid.new()
    local self = setmetatable({}, Grid)
    self.cells = {}
    self.building_at = {}
    for col = 0, Grid.COLS - 1 do
        self.cells[col] = {}
        self.building_at[col] = {}
        for row = 0, Grid.ROWS - 1 do
            self.cells[col][row] = "empty"
        end
    end
    return self
end

function Grid:in_bounds(col, row)
    return col >= 0 and col <= Grid.COLS - 1 and row >= 0 and row <= Grid.ROWS - 1
end

function Grid:get(col, row)
    if not self:in_bounds(col, row) then
        return nil
    end
    return self.cells[col][row]
end

function Grid:is_empty(col, row)
    return self:get(col, row) == "empty"
end

function Grid:is_road(col, row)
    return self:get(col, row) == "road"
end

function Grid:is_building(col, row)
    return self:get(col, row) == "building"
end

function Grid:is_passable(col, row)
    return self:is_road(col, row) or self:is_building(col, row)
end

function Grid:set_road(col, row)
    if not self:in_bounds(col, row) then
        return false
    end
    if self.cells[col][row] ~= "empty" then
        return false
    end
    self.cells[col][row] = "road"
    return true
end

function Grid:set_building(col, row, building_id)
    self.cells[col][row] = "building"
    self.building_at[col][row] = building_id
end

function Grid:cell_to_pixel(col, row)
    local x = col * Grid.CELL_SIZE
    local y = Grid.FORECAST_BAR_H + row * Grid.CELL_SIZE
    return x, y
end

function Grid:pixel_to_cell(px, py)
    if py < Grid.FORECAST_BAR_H then
        return nil, nil
    end
    local col = math.floor(px / Grid.CELL_SIZE)
    local row = math.floor((py - Grid.FORECAST_BAR_H) / Grid.CELL_SIZE)
    if not self:in_bounds(col, row) then
        return nil, nil
    end
    return col, row
end

function Grid:cell_subcells(col, row)
    local result = {}
    for dx = 0, 1 do
        for dy = 0, 1 do
            table.insert(result, { col = col * 2 + dx, row = row * 2 + dy })
        end
    end
    return result
end

function Grid:subcell_to_cell(scol, srow)
    return math.floor(scol / 2), math.floor(srow / 2)
end

function Grid:subcell_to_pixel(scol, srow)
    local x = scol * Grid.SUBCELL_SIZE + Grid.SUBCELL_SIZE / 2
    local y = Grid.FORECAST_BAR_H + srow * Grid.SUBCELL_SIZE + Grid.SUBCELL_SIZE / 2
    return x, y
end

function Grid:neighbors(col, row)
    local candidates = {
        { col = col + 1, row = row },
        { col = col - 1, row = row },
        { col = col, row = row + 1 },
        { col = col, row = row - 1 },
    }
    local result = {}
    for _, c in ipairs(candidates) do
        if self:in_bounds(c.col, c.row) then
            table.insert(result, c)
        end
    end
    return result
end

function Grid:subcell_neighbors(scol, srow)
    local col, row = self:subcell_to_cell(scol, srow)
    local result = {}

    -- 1. the other 3 sub-cells within the same parent cell
    local siblings = self:cell_subcells(col, row)
    for _, sc in ipairs(siblings) do
        if not (sc.col == scol and sc.row == srow) then
            table.insert(result, sc)
        end
    end

    -- 2. cross-cell neighbor, only if that neighbor cell is passable
    local lx = scol % 2
    local ly = srow % 2

    if lx == 1 then
        local ncol, nrow = col + 1, row
        if self:is_passable(ncol, nrow) then
            table.insert(result, { col = ncol * 2 + 0, row = nrow * 2 + ly })
        end
    else
        local ncol, nrow = col - 1, row
        if self:is_passable(ncol, nrow) then
            table.insert(result, { col = ncol * 2 + 1, row = nrow * 2 + ly })
        end
    end

    if ly == 1 then
        local ncol, nrow = col, row + 1
        if self:is_passable(ncol, nrow) then
            table.insert(result, { col = ncol * 2 + lx, row = nrow * 2 + 0 })
        end
    else
        local ncol, nrow = col, row - 1
        if self:is_passable(ncol, nrow) then
            table.insert(result, { col = ncol * 2 + lx, row = nrow * 2 + 1 })
        end
    end

    return result
end

return Grid
