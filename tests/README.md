# LightweightMarkers offline tests

Run from the workspace root with the bundled LuaJIT. They are offline evidence only, not in-game results.

| Harness | What it checks |
| --- | --- |
| `test_categories.lua` | Loads the game's own `scripts/settings/pickup/pickups.lua` and `interaction_templates.lua` from `darktide-source/`. Every pickup in the game is either marked or on an explicit ignore list (a game update that adds pickups fails the test), every marked pickup and interaction type exists, each kind's fallback icon is the icon vanilla shows, every kind has a group setting, and every option has localized title and tooltip text that survives DMF's `string.format`. |
| `test_runtime.lua` | Runs the real mod files against a fake HUD that follows `hud_element_world_markers.lua` (synchronous `on_enter`, `draw` decided before `update_function`, `remove`-flagged markers unregistered with `on_exit`) and a fake world. Covers discovery, icons with vanilla's colour, frame and hand-over size, health station charges, their colours and dimming, deployed ammo crate charges kept under vanilla's marker, the deployed medical crate's healing estimate (the server's formula, radius, corruption floor and flat health under corruption, knock-down speed and cost, improved-crate talent, sampling out of range and with the HUD hidden), the large ammo icon on both markers once its package has loaded (requested once, released on disable), stimm colours in the own slot and on teammates' panels with restore on disable, distance text reuse, add and keep distances, opened chests, picked-up items, line of sight and through walls, yielding to vanilla's marker (no raycasts meanwhile), half-speed raycast ageing, category toggles, collectibles off by default and tracked only once on, picked versus unpicked and destroyed heretical idols and their frame, a 200 m marker distance, disable and enable, a new HUD, a hidden HUD (menu open), mission exit, and 3,000 random spawn, pickup and movement steps with invariants (marker present within 45 m, absent beyond 50 m, no leaked widget names). Engine natives are stand-ins: no engine contract is proven here. |

Commands:

    tools/luajit/luajit mods/active/LightweightMarkers/tests/test_categories.lua
    tools/luajit/luajit mods/active/LightweightMarkers/tests/test_runtime.lua

Last results (2026-10-14, Windows bundled LuaJIT, Darktide source 1.13.1):

- `test_categories.lua`: `61 pickups in the game, 24 marked, 37 ignored, 3 interaction types: 0 failures`
- `test_runtime.lua`: `13775 checks, 0 failures`
