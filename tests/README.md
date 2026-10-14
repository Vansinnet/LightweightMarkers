# LightweightMarkers offline tests

Run from the workspace root with the bundled LuaJIT. Both are offline evidence only, not in-game results.

| Harness | What it checks |
| --- | --- |
| `test_categories.lua` | Loads the game's own `scripts/settings/pickup/pickups.lua` and `interaction_templates.lua` from `darktide-source/`. Every pickup in the game is either marked or on an explicit ignore list (a game update that adds pickups fails the test), every marked pickup and interaction type exists, each kind's fallback icon is the icon vanilla shows, every kind has a group setting, and every option has localized title and tooltip text that survives DMF's `string.format`. |
| `test_chest_prediction.lua` | Runs the chest prediction solver (`chest_prediction.lua`) against two real online missions recorded on a client at mission start (`fixtures/`: spawners, floor pickups, pool), with the game's `pickup_settings.lua` and stand-ins for `math.next_random` (the identified LCG) and `table.shuffle`. Checks that every floor pickup is explained, the chest contents confirmed in game on hm_cartel, that tied and ambiguous chests are not shown, that a wrong seed, an unexplained floor pickup or too few floor pickups block the prediction, and that the solver yields. |
| `test_runtime.lua` | Runs the real mod files against a fake HUD that follows `hud_element_world_markers.lua` (synchronous `on_enter`, `draw` decided before `update_function`, `remove`-flagged markers unregistered with `on_exit`) and a fake world. Covers discovery, icons with vanilla's colour, frame and hand-over size, health station charges and dimming, distance text reuse, add and keep distances, opened chests, picked-up items, line of sight and through walls, yielding to vanilla's marker (no raycasts meanwhile), half-speed raycast ageing, category toggles, collectibles off by default and tracked only once on, picked versus unpicked and destroyed heretical idols, a 200 m marker distance, disable and enable, a new HUD, a hidden HUD (menu open), chest prediction end to end on the hm_cartel fixture (off by default, start delay, time-sliced solver, labels on chest markers, labels kept above vanilla's marker, option off, unconfirmed missions), mission exit, and 3,000 random spawn, pickup and movement steps with invariants (marker present within 45 m, absent beyond 50 m, no leaked widget names). Engine natives are stand-ins: no engine contract is proven here. |

Commands:

    tools/luajit/luajit mods/active/LightweightMarkers/tests/test_categories.lua
    tools/luajit/luajit mods/active/LightweightMarkers/tests/test_chest_prediction.lua
    tools/luajit/luajit mods/active/LightweightMarkers/tests/test_runtime.lua

Last results (2026-10-14, Windows bundled LuaJIT, Darktide source 1.13.1):

- `test_categories.lua`: `61 pickups in the game, 22 marked, 39 ignored, 3 interaction types: 0 failures`
- `test_chest_prediction.lua`: `20 checks, 0 failures` (also with `-joff`, as the game runs)
- `test_runtime.lua`: `13727 checks, 0 failures`
