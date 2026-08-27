# traffic-game

A grid-based traffic simulation built on the love-exemplar Love2D architecture.
Five fixed buildings sit on a 128×68 grid of 10×10px cells; the player draws
permanent roads by clicking empty cells to connect them. A scrolling forecast
bar along the top announces incoming demand (`A -> B x6`) between buildings,
and once a building is connected to the network, cars pathfind across the
road graph and drive sub-cell by sub-cell toward their destination, yielding
right-of-way to whichever car has waited longest at a contested cell. Each
delivered car increments an on-screen score. No win/lose condition — it's an
endless sandbox.

## Structure

```
lua/core/       Engine classes — no game knowledge (Camera, Drawer, Input, Scene,
                SceneManager, Sprite, SpriteSet, Timer, Fonts)
lua/game/       Traffic game logic (Grid, Pathfinder, Building, Car, Forecast,
                ForecastBar, GameState) — no rendering/engine knowledge
game/           Game-specific scene (GameScene, in game/scenes/)
lua/headless/   Headless test infrastructure (stubs, HeadlessInput, runner)
tests/          Test files — run with: love . --headless
assets/         Images and other assets
conf.lua        Window config; suppresses graphics/audio modules under --headless
main.lua        Entry point — canvas rendering with letterboxing, pixel-art filter
```

See [`core/lua/README.md`](core/lua/README.md) for API docs on each engine class.

## Running

```bash
love .                  # normal window
love . --headless       # run tests and exit
```

## Web build

```bash
npm install
bash scripts/build_web.sh   # outputs to web/
```

`APP_TITLE` env var overrides the browser tab title (default: `"Love Exemplar"`).

## CI / Cloudflare Pages

Two GitHub Actions workflows are included:

- **`ci.yml`** — runs `love . --headless` on every push and PR
- **`web.yml`** — builds the web output and deploys to Cloudflare Pages

To activate the web deploy, see [`docs/setup-cloudflare.md`](docs/setup-cloudflare.md). In short, set these in your GitHub repository settings:

| Type | Name | Value |
|------|------|-------|
| Secret | `CLOUDFLARE_API_TOKEN` | your Cloudflare API token |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | your Cloudflare account ID |
| Variable | `CLOUDFLARE_PROJECT_NAME` | your Cloudflare Pages project name |
| Variable | `APP_TITLE` | browser tab title (optional) |

PR previews are deployed automatically and linked in a PR comment. Production deploys on push to `master`.

## Architecture notes

- **Fixed logical resolution** — game renders to a `1280×720` canvas; `main.lua` scales it to the window with letterboxing. Works with any window size.
- **Scene transitions** — `SceneManager` fades through black (0.3 s) between scene switches.
- **Headless tests** — `lua/headless/stubs.lua` installs no-op love API replacements so test files run without a window. `HeadlessInput` lets tests script action presses frame-by-frame. See `tests/test_basics.lua` for a minimal example.
