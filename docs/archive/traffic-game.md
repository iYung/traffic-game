## Traffic Game Checklist

Indexing convention used throughout: grid cells and sub-cells are
**0-indexed** (`col` in `0..127`, `row` in `0..67`; `scol`/`srow` in
`0..255`/`0..135`) so pixel math (`col * CELL_SIZE`) stays simple. Building
`id` and `letter` are the same value (a single-letter string `"A".."E"`) —
one field, no separate id/letter mapping needed. All new modules follow the
existing `Foo.new(...)` + `Foo.__index = Foo` class style used by
`lua/core/*.lua`.

Dependency waves (for scheduling parallel task agents):
- **Wave 1 (parallel, no deps):** Task A (Grid), Task B (Forecast)
- **Wave 2 (parallel, needs Wave 1):** Task C (Pathfinder, needs Grid), Task D (Car, needs Grid)
- **Wave 3 (needs Wave 2):** Task E (Building, needs Grid + Pathfinder)
- **Wave 4 (needs Wave 3):** Task F (ForecastBar, needs Forecast + Building)
- **Wave 5 (needs Wave 4):** Task G (GameState, needs Grid + Pathfinder + Car + Building + ForecastBar)
- **Wave 6 (needs everything):** Task H (game_scene.lua rewrite + demo removal, needs A–G)

---

- [x] **Task A — Grid module** — `lua/game/grid.lua`, `tests/test_grid.lua` — *(no dependencies — can start immediately, parallel with Task B)*

  Build the cell/sub-cell model. Constants on the `Grid` table:
  `Grid.COLS = 128`, `Grid.ROWS = 68`, `Grid.CELL_SIZE = 10`,
  `Grid.FORECAST_BAR_H = 40`, `Grid.SUBCELLS_PER_CELL = 2`,
  `Grid.SUBCELL_SIZE = 5`, `Grid.SUB_COLS = 256`, `Grid.SUB_ROWS = 136`.
  Canvas is 1280×720; the play area is 1280×680 starting at pixel y=40
  (below the forecast bar).

  Functions:
  - `Grid.new()` — allocates `self.cells[col][row]` for all `col in 0..127`,
    `row in 0..67`, each initialized to the string `"empty"`. Also
    `self.building_at[col][row]` (nil unless a building occupies that cell).
  - `Grid:in_bounds(col, row)` — bool.
  - `Grid:get(col, row)` — returns `"empty"|"road"|"building"` or `nil` if
    out of bounds.
  - `Grid:is_empty(col, row)`, `Grid:is_road(col, row)`,
    `Grid:is_building(col, row)`, `Grid:is_passable(col, row)` (road or
    building — the two states that carry a sub-cell graph).
  - `Grid:set_road(col, row)` — only changes state if currently `"empty"`;
    returns `true` if it changed the cell to `"road"`, `false` otherwise
    (already road/building, or out of bounds). Roads are permanent — no
    removal function.
  - `Grid:set_building(col, row, building_id)` — sets cell state to
    `"building"` and records `building_id` in `self.building_at[col][row]`.
  - `Grid:cell_to_pixel(col, row)` — returns `x, y` top-left pixel:
    `x = col * CELL_SIZE`, `y = FORECAST_BAR_H + row * CELL_SIZE`.
  - `Grid:pixel_to_cell(px, py)` — returns `col, row`, or `nil, nil` if
    `py < FORECAST_BAR_H` or the resulting cell is out of bounds (used for
    click handling — clicks in the forecast bar area are rejected).
  - `Grid:cell_subcells(col, row)` — returns an array of the 4
    `{col=, row=}` sub-cell tables inside that cell: for
    `dx, dy in {0,1}`, `scol = col*2 + dx`, `srow = row*2 + dy`.
  - `Grid:subcell_to_cell(scol, srow)` — `col = floor(scol/2)`,
    `row = floor(srow/2)`.
  - `Grid:subcell_to_pixel(scol, srow)` — returns the sub-cell's *center*
    pixel: `x = scol*SUBCELL_SIZE + SUBCELL_SIZE/2`,
    `y = FORECAST_BAR_H + srow*SUBCELL_SIZE + SUBCELL_SIZE/2`.
  - `Grid:neighbors(col, row)` — array of up to 4 orthogonal `{col=, row=}`
    neighbors that are `in_bounds` (N/S/E/W, no diagonals).
  - `Grid:subcell_neighbors(scol, srow)` — the adjacency function the
    pathfinder walks. Only defined meaningfully when
    `Grid:subcell_to_cell(scol,srow)` is passable; returns an array of
    adjacent **passable** sub-cells:
    1. The other 3 sub-cells within the same parent cell (a road/building
       cell's 2×2 sub-cells are fully connected to each other).
    2. For a sub-cell on an edge of its parent cell, the matching sub-cell
       across the border into an orthogonal neighbor cell, *only if that
       neighbor cell is passable*. Concretely, with local offset
       `(lx, ly)` where `lx = scol % 2`, `ly = srow % 2`: if `lx==1`, check
       neighbor cell `(col+1, row)` and connect to its local `(0, ly)`
       sub-cell; if `lx==0`, check `(col-1, row)` → local `(1, ly)`; if
       `ly==1`, check `(col, row+1)` → local `(lx, 0)`; if `ly==0`, check
       `(col, row-1)` → local `(lx, 1)`.

  Write `tests/test_grid.lua` in the `assert()` / `print("PASS: ...")` /
  final `print("ALL TESTS PASSED")` style of `tests/test_camera.lua`.
  Cover: default dimensions/constants, `cell_to_pixel`/`pixel_to_cell`
  round-trip, `pixel_to_cell` rejects forecast-bar-area clicks, `set_road`
  refuses to overwrite a building cell, `cell_subcells` returns the correct
  4 sub-cells for a cell, `subcell_neighbors` returns 3 same-cell neighbors
  plus correct cross-cell neighbors only when the adjacent cell is a road,
  and returns fewer neighbors at grid edges/against empty cells.

---

- [x] **Task B — Forecast module** — `lua/game/forecast.lua`, `tests/test_forecast.lua` — *(no dependencies — can start immediately, parallel with Task A)*

  A single scrolling forecast bar entry. No dependency on Grid — it only
  deals with a horizontal pixel position and a label string.

  Constants: `Forecast.SPEED = 60` (px/sec scroll speed),
  `Forecast.WIDTH = 80` (approx label width in px, used for the offscreen
  check), `Forecast.SPAWN_X = 1280` (starting x, just off the right edge).

  Functions:
  - `Forecast.new(origin_letter, dest_letter, count, x)` — stores
    `self.origin`, `self.dest`, `self.count` (always `6` per current
    design), `self.x` (defaults to `Forecast.SPAWN_X` if `x` is nil).
  - `Forecast:update(dt)` — `self.x = self.x - Forecast.SPEED * dt`.
  - `Forecast:is_offscreen_left()` — `true` once
    `self.x + Forecast.WIDTH < 0`.
  - `Forecast:label()` — returns `string.format("%s -> %s x%d", self.origin, self.dest, self.count)`.
  - `Forecast:draw(y)` — `love.graphics.print(self:label(), self.x, y)`.

  Write `tests/test_forecast.lua` in the established style. Cover:
  construction stores origin/dest/count/x, `update(dt)` moves x left by
  exactly `SPEED * dt`, `is_offscreen_left()` is false when just spawned
  and true once x is moved past `-WIDTH`, `label()` produces the exact
  `"A -> B x6"` format.

---

- [x] **Task C — Pathfinder module** — `lua/game/pathfinder.lua`, `tests/test_pathfinder.lua` — *(depends on Task A — Grid module — for `Grid:subcell_neighbors` and `Grid:subcell_to_cell`)*

  BFS over the sub-cell graph exposed by `Grid:subcell_neighbors`.

  - `Pathfinder.find_path(grid, start, goal)` — `start`/`goal` are
    `{col=, row=}` sub-cell tables. Standard BFS: a FIFO queue seeded with
    `start`, a `visited` set keyed by `"col,row"` strings, a `came_from`
    map for reconstruction. At each pop, if the popped sub-cell equals
    `goal` (by col/row), reconstruct and return the path as an array of
    `{col=, row=}` sub-cells from `start` to `goal` inclusive, in order.
    Expand neighbors via `grid:subcell_neighbors(node.col, node.row)` —
    passability is already enforced by that function, so Pathfinder does
    no separate passability check. If the queue empties without reaching
    `goal`, return `nil`. Handle `start == goal` as a length-1 path.

  Write `tests/test_pathfinder.lua`. Build small `Grid` instances by hand
  with `grid:set_road(...)` calls. Cover: a straight line of road cells
  produces a path of the expected sub-cell length; no road between two
  points returns `nil`; a path exists through a building cell endpoint
  (buildings are passable); `start == goal` returns a 1-element path;
  a detour is required when the direct route is blocked (verify BFS
  actually finds the longer valid route, not just "any" failure).

---

- [x] **Task D — Car module** — `lua/game/car.lua`, `tests/test_car.lua` — *(depends on Task A — Grid module — for `Grid:subcell_to_pixel` and `Grid.SUBCELL_SIZE`)*

  A car's path-following state machine. Does **not** depend on Pathfinder —
  tests construct path arrays by hand. Does **not** decide who wins
  contested sub-cells itself; that arbitration lives in `game_state.lua`
  (Task G), which calls `Car:grant_move()` once it has decided.

  Constant: `Car.SPEED = 60` (px/sec pixel-tween speed while moving).

  - `Car.new(path, grid)` — `path` is an array of `{col=, row=}` sub-cells
    (as returned by `Pathfinder.find_path`, inclusive of both endpoints).
    Stores `self.path`, `self.grid`, `self.index = 1` (current path
    position), `self.x, self.y = grid:subcell_to_pixel(path[1].col, path[1].row)`,
    `self.wait_time = 0`. `self.state = "arrived"` if `#path == 1`,
    else `"waiting"` (must be granted its first move like any other —
    game_state grants the initial move on spawn).
  - `Car:current_subcell()` — `self.path[self.index]`.
  - `Car:next_subcell()` — `self.path[self.index + 1]`, or `nil` if already
    at the end of the path.
  - `Car:is_arrived()` — `self.index >= #self.path`.
  - `Car:wait_time()` — `self.wait_time`.
  - `Car:grant_move()` — only valid when `state == "waiting"` and a
    `next_subcell()` exists: sets `self.state = "moving"`,
    `self.wait_time = 0`, computes and stores the target pixel via
    `grid:subcell_to_pixel` on `next_subcell()`.
  - `Car:tick(dt)`:
    - if `state == "moving"`: move `self.x, self.y` toward the stored
      target pixel by `Car.SPEED * dt`, clamped so it doesn't overshoot;
      once it reaches the target (within a small epsilon, then snapped
      exactly), `self.index = self.index + 1`; if `is_arrived()` then
      `state = "arrived"`, else `state = "waiting"` (and `wait_time`
      starts accumulating from 0).
    - if `state == "waiting"`: `self.wait_time = self.wait_time + dt`.
    - if `state == "arrived"`: no-op.
  - `Car:draw()` — `love.graphics.rectangle("fill", self.x - SUBCELL_SIZE/2, self.y - SUBCELL_SIZE/2, SUBCELL_SIZE, SUBCELL_SIZE)` (car color can be a plain fixed color, e.g. white, set via `love.graphics.setColor` before/after — matches the "primitive rectangles" convention).

  Write `tests/test_car.lua`. Cover: construction positions the car at
  `path[1]`'s pixel center; a car with a multi-step path stays `"waiting"`
  until `grant_move()` is called, then transitions to `"moving"`; enough
  `tick(dt)` calls at `Car.SPEED` advance it exactly to the next sub-cell's
  center and flip back to `"waiting"` (or `"arrived"` at the final step);
  `wait_time()` accumulates correctly across multiple `tick(dt)` calls
  while `"waiting"` and resets to 0 on `grant_move()`; a single-sub-cell
  path (`start == goal`) is `"arrived"` immediately.

---

- [x] **Task E — Building module** — `lua/game/building.lua`, `tests/test_building.lua` — *(depends on Task A — Grid — and Task C — Pathfinder)*

  A building's identity, spawn queue, and per-tick spawn attempt.
  `require("lua/game/pathfinder")` directly.

  - `Building.new(letter, col, row, color)` — stores `self.id = letter`
    (id and letter are the same value), `self.letter`, `self.col`,
    `self.row`, `self.color`, `self.queue = {}` (FIFO array of destination
    letters — one entry per pending car).
  - `Building:enqueue(dest_id)` — `table.insert(self.queue, dest_id)`.
  - `Building:queue_length()` — `#self.queue` (used for the HUD badge).
  - `Building:spawn_subcell(grid)` — returns the fixed
    `{col=, row=}` sub-cell used both as this building's pathfinding
    anchor and its cars' spawn/arrival point: `grid:cell_subcells(self.col, self.row)[1]`
    (the top-left of its 4 sub-cells).
  - `Building:try_spawn(grid, buildings_by_id, is_subcell_free)` — if
    `#self.queue == 0`, return `nil`. Otherwise peek (don't pop yet)
    `dest_id = self.queue[1]`; look up `dest = buildings_by_id[dest_id]`;
    compute `start_sc = self:spawn_subcell(grid)`,
    `goal_sc = dest:spawn_subcell(grid)`; call
    `Pathfinder.find_path(grid, start_sc, goal_sc)`. If no path, return
    `nil` (queue untouched — retried next tick by the caller). If a path
    exists but `is_subcell_free(start_sc)` is `false`, return `nil` (queue
    untouched). Otherwise `table.remove(self.queue, 1)` and return the
    path (the caller, `game_state.lua`, constructs the `Car` and registers
    occupancy — `Building` never touches `Car` or occupancy state).

  Write `tests/test_building.lua`. Cover: `enqueue`/`queue_length` FIFO
  behavior; `try_spawn` with a road connecting two buildings and
  `is_subcell_free` always `true` returns a path and drains the queue by
  one; `try_spawn` with no road returns `nil` and leaves the queue
  untouched; `try_spawn` with a valid road but `is_subcell_free` returning
  `false` returns `nil` and leaves the queue untouched; calling
  `try_spawn` repeatedly only ever removes one entry per successful call.

---

- [x] **Task F — ForecastBar module** — `lua/game/forecast_bar.lua` — *(depends on Task B — Forecast — and Task E — Building; no dedicated test file, per the design doc's file list — covered indirectly via Task G/H)*

  Spawns forecast entries on a timer, scrolls them, and enqueues cars into
  the origin building when an entry exits left. `require("lua/core/timer")`
  and `require("lua/game/forecast")`.

  Constant: `ForecastBar.SPAWN_INTERVAL = 4` (seconds between new forecast
  entries).

  - `ForecastBar.new(letters)` — `letters` is the array of the 5 building
    letters (`{"A","B","C","D","E"}`, supplied by `game_state.lua`).
    Stores `self.timer = Timer.new(ForecastBar.SPAWN_INTERVAL)`,
    `self.entries = {}`, `self.letters = letters`.
  - `ForecastBar:_pick_pair()` — picks two distinct random letters from
    `self.letters` via `math.random` (retry-until-distinct or index-then-
    remove; either is fine) and returns `origin, dest`.
  - `ForecastBar:update(dt, buildings_by_letter)`:
    - if `self.timer:update(dt)` returns `true`: pick `origin, dest` via
      `_pick_pair()`, `table.insert(self.entries, Forecast.new(origin, dest, 6))`.
    - iterate `self.entries` back-to-front (safe removal while iterating):
      call `entry:update(dt)`; if `entry:is_offscreen_left()`, look up
      `buildings_by_letter[entry.origin]` and call `:enqueue(entry.dest)`
      on it exactly `entry.count` times (6 separate queue entries, one per
      car), then `table.remove(self.entries, i)`.
  - `ForecastBar:draw()` — for each entry, `entry:draw(0)` (drawn inside
    the top 40px forecast bar strip).

  No dedicated test file for this module (matches the design doc's
  "Affected files" list, which only calls out `test_grid`, `test_pathfinder`,
  `test_building`, `test_car`, `test_forecast`). Its scroll/enqueue
  behavior is exercised indirectly by `game_state.lua` once wired up in
  Task H — do not add a `tests/test_forecast_bar.lua` file.

---

- [x] **Task G — GameState module** — `lua/game/game_state.lua` — *(depends on Task A — Grid, Task C — Pathfinder (transitively via Building), Task D — Car, Task E — Building, Task F — ForecastBar; no dedicated test file, per the design doc's file list)*

  Owns grid, buildings, cars, forecast bar, score; ties the per-frame
  update together. `require`s `grid`, `car`, `building`, `forecast_bar`
  (not `pathfinder` directly — that's `Building`'s dependency).

  Fixed 5-building layout (corners + center of the 128×68 grid, matching
  the design doc's "spread across the map" requirement):

  | Letter | col | row | color (r,g,b,a) |
  |---|---|---|---|
  | A | 4   | 4  | `{0.9, 0.2, 0.2, 1}` (red) |
  | B | 123 | 4  | `{0.2, 0.4, 0.9, 1}` (blue) |
  | C | 4   | 63 | `{0.2, 0.8, 0.3, 1}` (green) |
  | D | 123 | 63 | `{0.9, 0.8, 0.2, 1}` (yellow) |
  | E | 63  | 33 | `{0.7, 0.3, 0.8, 1}` (purple) |

  - `GameState.new()`:
    - `self.grid = Grid.new()`.
    - `self.buildings = {}` (array, in letter order A-E) and
      `self.buildings_by_letter = {}` (map). For each row of the table
      above: `self.grid:set_building(col, row, letter)`, then
      `Building.new(letter, col, row, color)`, store in both structures.
    - `self.cars = {}` (array of live `Car` instances).
    - `self.forecast_bar = ForecastBar.new({"A","B","C","D","E"})`.
    - `self.score = 0`.
  - `GameState:toggle_road_at_pixel(px, py)` — `col, row = self.grid:pixel_to_cell(px, py)`;
    if both non-nil and `self.grid:is_empty(col, row)`, call
    `self.grid:set_road(col, row)`. No-op on building cells, existing
    road cells, or out-of-bounds/forecast-bar clicks (this is the click
    handler `game_scene.lua` calls from `love.mousepressed`).
  - `GameState:_is_subcell_free(sc)` — helper: returns `false` if any car
    in `self.cars` has `car:current_subcell()` equal to `sc` (by col/row),
    **or** is `state == "moving"` and its `car:next_subcell()` (its
    in-flight target, already committed via `grant_move()`) equals `sc`;
    `true` otherwise. The second clause is required — without it, a
    subcell is only marked occupied once a car finishes tweening into it
    (`current_subcell()` doesn't update until arrival), leaving a window
    during the whole transit where a second car could also be granted
    that same subcell, violating "cars only enter an unoccupied tile."
    Used both by `Building:try_spawn` and by the arbitration step below.
  - `GameState:update(dt)`:
    1. `self.forecast_bar:update(dt, self.buildings_by_letter)`.
    2. For each building in `self.buildings`: call
       `building:try_spawn(self.grid, self.buildings_by_letter, function(sc) return self:_is_subcell_free(sc) end)`.
       If it returns a path, `local car = Car.new(path, self.grid)`,
       `table.insert(self.cars, car)`. Do **not** call `car:grant_move()`
       here — a freshly spawned car starts `"waiting"` like any other and
       is granted its first move through the normal arbitration in step 4
       below (it naturally wins immediately if nothing else contests its
       first target that tick). Calling `grant_move()` unconditionally
       here would skip the occupancy check on the car's *second* sub-cell
       (only `start_sc`, its first sub-cell, was checked by
       `try_spawn`/`_is_subcell_free`), which could let it collide with a
       car already inbound to that same sub-cell.
    3. For each car in `self.cars`: `car:tick(dt)`.
    4. Arbitration for contested sub-cells: build a table mapping each
       distinct `next_subcell()` (by `"col,row"` key) requested by a
       `"waiting"` car to the list of cars requesting it. For each
       contested sub-cell that `_is_subcell_free` still reports free,
       pick the requesting car with the largest `wait_time()` (ties broken
       by array order) and call `car:grant_move()` on it only — this is
       what implements "whichever car has been waiting longest moves
       first".
    5. Remove arrived cars: for each car with `car:is_arrived()`, increment
       `self.score` by 1 and remove it from `self.cars`.
  - `GameState:draw()` — primitive, direct `love.graphics` calls (no
    `Sprite`/`Drawer` — the per-frame car/road churn doesn't fit Drawer's
    add-only model, so this module draws directly instead, still matching
    the design doc's "primitive rectangles + print" rendering approach):
    - Background: one `love.graphics.rectangle("fill", 0, 40, 1280, 680)`
      in a dark/empty color.
    - Roads: for every cell with `grid:is_road(col,row)`, a lighter-colored
      rectangle at `grid:cell_to_pixel(col,row)`, size `CELL_SIZE x CELL_SIZE`.
    - Buildings: for each building, a `color`-filled rectangle at its cell
      plus its `letter` printed on top (`love.graphics.print`), plus its
      `queue_length()` printed as a small badge number near the cell.
    - Cars: `car:draw()` for each in `self.cars`.
    - Forecast bar: a background strip for the top 40px, then
      `self.forecast_bar:draw()`.
    - Score: `love.graphics.print("Delivered: " .. self.score, 16, 16)`
      or similar, positioned inside the forecast bar strip.

  No dedicated test file for this module (matches the design doc's file
  list — `game_state.lua` isn't paired with a `test_game_state.lua`). Its
  correctness is exercised end-to-end via `tests/test_basics.lua` (already
  existing, ticks a fresh `GameScene` for 10 frames without error) once
  Task H wires it in.

---

- [x] **Task H — game_scene.lua rewrite + demo removal** — `game/scenes/game_scene.lua`, `game/player.lua` (delete), `assets/player.png` (delete), `tests/test_basics.lua` (small comment cleanup) — *(depends on ALL of Tasks A–G — final integration task, must run last)*

  Rewrite `game/scenes/game_scene.lua` to replace the demo entirely:
  - Drop the `require("game/player")` line; add
    `local GameState = require("lua/game/game_state")`.
  - `GameScene.new()` stays parameterless: `Scene.new(1280, 720)` +
    `setmetatable(self, GameScene)` (unchanged shape — `tests/test_scene.lua`
    asserts `gs.drawer`/`gs.camera` exist and `camera._w/_h == 1280/720`,
    so don't break that).
  - `GameScene:on_enter()` — `self.state = GameState.new()`. Also set
    `self.camera.x = 640` and `self.camera.y = 360` (i.e. `w/2`, `h/2`).
    This is **required**, not cosmetic: `Camera:attach()` computes
    `screen = (w/2, h/2) + zoom*(world - camera_pos)`, so the *default*
    `camera.x, camera.y = 0, 0` from `Scene.new` shifts every draw call by
    `(640, 360)` — the grid (drawn at world pixels `0..1280, 0..720`)
    would render mostly off the visible 1280×720 canvas. Setting
    `camera.x, camera.y = w/2, h/2` cancels that offset so world pixel
    coordinates map 1:1 to screen coordinates, per the design doc's static
    1:1 camera requirement. Do not add any per-frame `camera:follow(...)`
    call — this is a one-time set in `on_enter`, not an update-loop thing.
    Also register the mouse handler here (main.lua stays unmodified per
    the design doc, so the scene installs the global Love2D callback
    itself):
    ```lua
    local state = self.state
    love.mousepressed = function(x, y, button)
        if button == 1 then
            state:toggle_road_at_pixel(x, y)
        end
    end
    ```
    Note: because `main.lua`'s canvas is letterboxed/scaled to the window
    (unchanged, per design doc scope), raw `love.mousepressed` window
    coordinates only line up 1:1 with grid pixels when the window is at
    the logical 1280×720 size — this matches the design doc's own
    "Flagged risk" section (click precision) and is not something to fix
    in this task; do not modify `main.lua`.
  - `GameScene:update(dt)` — `self.state:update(dt)`. No camera follow
    needed (camera is static per design doc — leave `self.camera` at its
    default `Camera.new(0,0,1280,720)` from `Scene.new`, zoom 1, untouched).
  - `GameScene:draw()`:
    ```lua
    self.camera:attach()
    self.state:draw()
    self.camera:detach()
    ```
  - No keyboard input remains anywhere in this file (WASD/arrows removed
    along with the demo `Player`).

  Delete `game/player.lua` and `assets/player.png` (nothing references
  them once the above lands — confirm with a repo-wide grep for `player`
  before deleting).

  In `tests/test_basics.lua`, update the stale top-of-file comment that
  explains `game/player.lua`'s internal `Input` instantiation (it no
  longer exists) — replace it with a one-line note that the scene has no
  keyboard input to script, or simply remove the outdated comment block.
  Do not change the test's logic; it should keep passing unmodified
  (`runner.setup` → `GameScene.new()` → `tick` 10 frames → assert
  `sm.current ~= nil`).

  When done, run `love . --headless` and confirm every test file in
  `tests/` (including the untouched `test_camera.lua`, `test_scene.lua`,
  `test_basics.lua`, and the new `test_grid.lua`/`test_pathfinder.lua`/
  `test_building.lua`/`test_car.lua`/`test_forecast.lua`) passes.
