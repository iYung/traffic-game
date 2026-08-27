# Traffic Game

## Goal

Replace the love-exemplar demo scene with a grid-based traffic simulation:
5 fixed buildings on a grid, the player draws permanent roads by clicking
cells, a scrolling forecast bar announces incoming car demand between
buildings, and cars pathfind and drive cell-by-cell (on a finer sub-cell
grid) from origin building to destination building, yielding right-of-way
to whichever car has been waiting longest.

## Affected files

New:
- `lua/game/grid.lua` — cell/sub-cell model: dimensions, road flags, pixel↔cell↔sub-cell conversion, neighbor/adjacency queries
- `lua/game/pathfinder.lua` — BFS over the sub-cell graph, building→building
- `lua/game/building.lua` — a building's position, spawn queue, per-tick spawn attempt
- `lua/game/car.lua` — a car's path, sub-cell position, movement/wait state
- `lua/game/forecast.lua` — a single scrolling forecast entry (origin, destination, count, x position)
- `lua/game/forecast_bar.lua` — spawns forecast entries on a timer, scrolls them, enqueues cars into the origin building when an entry exits left
- `lua/game/game_state.lua` — owns grid, buildings, cars, forecast bar, score; ties per-frame update together
- `lua/game/scenes/game_scene.lua` — rewritten: input (click→toggle road), draws grid/roads/buildings/cars/forecast bar/score
- `tests/test_grid.lua`, `tests/test_pathfinder.lua`, `tests/test_building.lua`, `tests/test_car.lua`, `tests/test_forecast.lua` — headless coverage per module, following the existing `tests/test_camera.lua` style

Removed (demo-only, superseded):
- `game/player.lua`
- `assets/player.png`
- existing `game/scenes/game_scene.lua` content (file path stays, contents replaced)

Unchanged (reused as-is):
- `main.lua`, `conf.lua`, `lua/core/*` (Scene, SceneManager, Camera, Drawer, Sprite, Input, Timer, Fonts), `lua/headless/*`

## What changes

**Grid & sub-cells.** Play area is a 128×68 grid of 10×10px cells
(1280×680px), occupying the bottom of the 1280×720 canvas. The top 40px is
reserved for the forecast bar. Each cell is internally divided into a 2×2
set of 5×5px sub-cells — the unit a car occupies and the unit pathfinding
operates on (256×136 sub-cells total). A cell is either empty, a road, or
a building.

**Buildings.** 5 buildings at fixed grid cells, spread across the map
(corners + center), each with a distinct color and a letter label (A–E)
used in forecasts. Each building has a FIFO spawn queue of pending car
requests (destination building). Every update, a building peeks its first
queued request and attempts to pathfind from itself to the destination; if
a route exists (through placed roads) and its own spawn sub-cell is free,
it dequeues and spawns a car. Otherwise it keeps waiting and retries later.
A building is only reachable once the player has placed at least one road
cell adjacent to it — until then its queue just backs up.

**Roads.** Clicking an empty grid cell (below the forecast bar) makes it a
road, permanently. Clicking a building or an existing road does nothing.
Roads form an undirected graph over sub-cells: the 4 sub-cells within a
road cell are fully connected to each other, and edge sub-cells connect to
the adjacent sub-cells of orthogonal neighboring road/building cells. No
lane discipline — a road cell is symmetric and can carry traffic either
direction.

**Forecast bar.** Every few seconds, a new forecast entry spawns just off
the right edge of the top bar: `<origin letter> → <destination letter> ×6`
with origin/destination chosen at random from the 5 buildings (never the
same one twice). It scrolls left at a constant speed. When it scrolls
fully past the left edge, 6 car requests (each targeting the destination
building) are pushed onto the origin building's spawn queue, and the entry
is removed.

**Cars.** A car holds a path (list of sub-cells) computed at spawn time.
Each tick it tries to advance into the next sub-cell on its path: if that
sub-cell is unoccupied, it claims it and animates its pixel position
across; if occupied, it waits. When two or more cars are blocked wanting
the same next sub-cell, the one that has been waiting longest moves first
(tracked via a wait-start timestamp per car, compared when the contested
sub-cell frees up). On reaching the destination building's cell, the car
despawns and the score (cars delivered) increments by one.

**Score / HUD.** Simple on-screen counter of cars delivered so far. No win
or lose condition — this is an endless sandbox; the queue at each building
is visible (a number badge) so the player can see demand building up
before they've connected a building to the network.

**Input.** Mouse click only. No keyboard movement (WASD/arrows are
removed along with the demo player).

**Camera.** Static — set once so world pixel coordinates map 1:1 to screen
coordinates (no follow behavior needed since the whole grid fits on
screen).

## What stays the same

- Scene/SceneManager/Drawer/Camera/Sprite/Input/Timer core classes are
  reused unmodified.
- Rendering stays primitive (colored rectangles via `Sprite`, plus
  `love.graphics.print` for text/labels) — no new image assets, matching
  the demo's existing coin/ground rectangles rather than introducing an
  art pipeline.
- Headless test infrastructure and per-class test file convention
  (`tests/test_<thing>.lua`) stay as-is.
- `love . --headless` remains the full test run; CI workflow unchanged.

## Open questions (resolved)

- Grid size / cell shape → user requires **square cells** and pushed for
  much higher cell density twice (rejected 16×8, then rejected 32×17);
  resolved as **10×10px cells**, a 128×68 grid (1280×680px), fitting under
  a 40px forecast bar on the 1280×720 canvas. Sub-cells are 5×5px (2×2 per
  cell) — that is also the car's rendered size.
- Building placement → **fixed layout** (same 5 cells every run).
- End condition → **endless sandbox + score**, no fail state.
- Forecast batch size → **fixed at 6** cars per forecast.

## Remaining open questions

- None blocking. Future ideas explicitly out of scope for this pass:
  difficulty scaling (faster/bigger forecasts over time), road removal,
  multiple lanes/one-way roads, non-square buildings, save/load.

## Flagged risk

At 10px cells, a single click target is roughly 1% of screen width —
clicking the intended cell precisely (especially near a building's edge)
will be difficult with a mouse, and 5px cars will read as barely-visible
dots at normal viewing distance. Not blocking implementation, but worth
a pass on zoom/precision (e.g. cursor cell-highlight snapping, or a
zoomed-in click mode) once the base sim is playable and this turns out to
be a real problem in practice.
