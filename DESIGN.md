# LightweightStrategicalMarkers: design
Status 2026-10-13: 1.0.0 (unreleased), ModID `LightweightStrategicalMarkers`. Verified: static and offline (`tests/`); independent source review 2026-10-13; base markers confirmed in game by the user 2026-10-13, collectibles not yet.

Lightweight markers for ammo, grenade refills, medical crates, stimms, health stations and chests, built as a lean alternative to Markers Improved AIO (`referensmoddar/markers_aio`).

## Files
- `LightweightStrategicalMarkers.lua`: settings snapshot, discovery hook and seed, registry, 4 Hz sweep, HUD registration, lifecycle.
- `marker_template.lua`: the world-marker template (factory taking the shared config and state): visuals in `on_enter`, alpha and distance text in `update_function`, widget release in `on_exit`.
- `categories.lua`: pure data: pickup type and interaction type to kind, kind visuals, group settings.
- `LightweightStrategicalMarkers_data.lua`, `_localization.lua`: options and English text.
- `tests/`: offline harnesses (`tests/README.md`).

## Decisions
- 2026-10-13 (user): name "Lightweight Strategical Markers"; mark ammo, grenades, medical crates, stimms, health stations and chests; performance first.
- 2026-10-13 (user): "see through walls" is a setting, off by default.
- 2026-10-13 (user): icons are the game's own interaction icons; where vanilla shares one icon, size and tint tell items apart (large ammo bigger and white, stimms in their case colours, chests gold).
- 2026-10-13 (user): at close range our marker yields to vanilla's interaction marker for the same unit.
- 2026-10-13 (user): health station charges shown, empty stations dimmed, distance in metres (setting, on).
- 2026-10-13 (user): a marker distance setting so players can see further: 40 m default, 10-200 m.
- 2026-10-13 (user): plasteel, diamantine, grimoires, scriptures and heretical idols as options, off by default, as light as possible.
- 2026-10-13 (user, answered): chest contents cannot be shown online. Reserved items are decided on the server at mission start and never sent; the rest is rolled on opening from the team's needs (`pickup_system.lua`, `_populate_pickups`, `get_rubberband_pickup`). Only possible when the local machine is the server (Psykanium, SoloPlay); not built.
- 2026-10-13: not marked: luggables, expedition-only pickups except the large ammo crate, live-event items (including the nurgle totem Markers AIO lists under idols). The ignore list in `tests/test_categories.lua` names each pickup.

## Discovery
- `hook_safe` on `InteracteeExtension.set_interaction_context` (`scripts/extension_systems/interaction/interactee_extension.lua:99`). Spawned units reach it from `init` (`:47`): on a client the pickup husk already carries unit data `pickup_type` (`scripts/extension_systems/unit_templates/pickup_unit_template.lua:172`; extensions are created after `husk_init` returns, `scripts/foundation/managers/extension/extension_manager.lua:170-175`). Level chests and health stations reach it from the `Interactable` component (`scripts/components/interactable.lua:76`), which runs on clients too.
- Classification is one table lookup (`categories.lua`): a pickup by its pickup type only, anything else by interaction type. `deployable_marker` is used only by the deployed medical crate (`medical_crate_deployable_unit_template.lua:6-13`).
- On enable and hot reload the registry is seeded once from `interactee_system:unit_to_extension_map()`, reading every interaction type the unit was given (`_interactions`), since a chest that starts inactive has no active type.
- Registry: dense arrays with swap-remove plus unit to index. Only groups that are on are tracked; a settings change reseeds, so turned-off groups cost nothing.
- Heretical idols are destructibles, not interactables. `CollectiblesManager.on_gameplay_post_init` runs on every peer, picks one idol per section from the level seed and calls `DestructibleExtension:set_collectible_data` with a clone that has `id = 1` (`scripts/managers/collectibles/collectibles_manager.lua:28-66`; called from `gameplay_init_step_pacing.lua:20` without a server check). A `hook_safe` there tracks the idol; the seed takes destructibles whose `_collectible_data` has an `id`. Unpicked candidates keep component data without `id` and stay hidden. An idol is finished when its `_destruction_info.current_stage_index` is 0, which clients get through `rpc_destructible_last_destruction` (`destructible_extension.lua:338-395`).

## Markers near the player
- `mod.update` exists only while enabled; every 0.25 s, if anything is tracked, the sweep runs. It needs `ALIVE` (nil between game states, `scripts/managers/position_lookup/position_lookup_manager.lua:40,44`).
- When the world-markers element is not updating (menus, tactical overlay, cutscenes, dead: `scripts/managers/ui/ui_hud.lua:387`, visibility groups in `scripts/ui/hud/hud_elements_player.lua`), the sweep only purges dead units: a marker flagged `remove` is applied only by `_calculate_markers`, so adding or rebuilding then would pile up widgets.
- Otherwise: squared distance from the HUD camera to each unit (`Unit.world_position`, never `POSITION_LOOKUP` from `mod.update`). Add at marker distance + 5 m, remove beyond + 10 m. An opened chest (`ChestExtension:is_open`, client state through `rpc_chest_set_state`, `chest_system.lua:38-52`) loses its marker and leaves the registry. Health station charges come from `HealthStationExtension:charge_amount` (`health_station_extension.lua:175`, synced by `health_station_system.lua:195,224`); the text changes only when the count does.
- Markers are added with `add_world_marker_unit` (synchronous `on_enter`, `scripts/ui/hud/elements/world_markers/hud_element_world_markers.lua:106-135`) and removed by flagging `remove` (`:277,321-326,479-489`), after which the HUD calls `on_exit`.
- The icon is the interactee's own `interaction_icon()` (`interactee_extension.lua:411-422`), so level overrides match vanilla; the kind's icon is the fallback.
- Setting changes flag every marker for removal; the next sweep rebuilds them with the new settings.

## Template
- Passes: background, gold ring and icon as vanilla's interaction marker, a distance label and a charge count. One widget definition is cached and shared (`UIWidget.init` clones content, style and passes, `scripts/managers/ui/ui_widget.lua:14-33`).
- `on_enter` writes per-marker settings into the marker's own deep-copied template (`table.clone`, `scripts/foundation/utilities/table.lua:38-52`): position offset (0.8 m for pickups like vanilla's "pickup" visuals, 0 for chests and stations), max distance, line-of-sight check and edge fade (`easing_function` is required, `_get_fade` calls it unguarded).
- `update_function` runs every frame for each live marker after `draw` is decided (`hud_element_world_markers.lua:461-474`, call at `:470`). It allocates nothing and reads no settings. Alpha = line of sight x empty-station dim x (1 - vanilla's alpha); at about zero it sets `draw = false` so the widget is not drawn. Distance text comes from a prebuilt table and changes only when the whole metre does.
- Vanilla yield: vanilla's marker for the unit is found through `HudElementInteraction._interaction_units[unit].marker_id` (`scripts/ui/hud/elements/interaction/hud_element_interaction.lua:64-106`) and `_markers_by_id`; its alpha is its line-of-sight alpha times its distance fade unless tagged. While it is fully shown, ours is hidden and its line-of-sight check is off, so it takes no raycasts.
- Raycasts: the HUD runs 10 every 5th frame for all markers, longest-waiting first (`hud_element_world_markers_settings.lua`, `hud_element_world_markers.lua:11-23,441-447`). Our markers' wait ages at half speed so vanilla markers keep priority.
- `on_exit` releases the widget name in the element that created it (vanilla keeps every marker widget name for the element's lifetime).

## Lifecycle
- New HUD: `hook_safe` on `HudElementWorldMarkers.init` registers the template and forgets ids of the old HUD; `destroy` forgets them. Only one world-markers element exists at a time; the spectator HUD has none.
- Disable: detach `mod.update`, flag all markers, remove the template, clear the registry. Enable: snapshot settings, seed, register into the current HUD.
- Hot reload: the old instance's `on_unload(false)` does the same as disable; the new one's `on_enabled` seeds and registers.
- Leaving `StateGameplay`: flag markers and clear the registry.
- The template name is `<ModID>_marker`, so a renamed copy never removes this one's template.

## Source contracts
| Use | Source path:line |
|---|---|
| `InteracteeExtension.set_interaction_context(self, interaction_type, override_context, set_active)`, `_unit`, `_interactions`, `interaction_icon()` | `scripts/extension_systems/interaction/interactee_extension.lua:13-47,99-125,411-422` |
| Pickup unit data `pickup_type` set before extensions | `scripts/extension_systems/unit_templates/pickup_unit_template.lua:48,172`; `scripts/foundation/managers/extension/extension_manager.lua:170-175` |
| Level interactables get their type from the component | `scripts/components/interactable.lua:76` |
| Interaction templates and icons | `scripts/settings/interaction/interaction_templates.lua:18-125,261-269` |
| System names `interactee_system`, `chest_system`, `health_station_system` | `scripts/extension_systems/extension_system_configuration.lua:348,1251,1402` |
| `ChestExtension:is_open`, client state | `scripts/extension_systems/chest/chest_extension.lua:121`; `chest_system.lua:38-52` |
| `HealthStationExtension:charge_amount`, client sync | `scripts/extension_systems/health_station/health_station_extension.lua:175`; `health_station_system.lua:195,224` |
| World-marker events, template fields, update order, removal | `scripts/ui/hud/elements/world_markers/hud_element_world_markers.lua:27-75,106-135,168-226,246-490,492-577,795-799` |
| Raycast budget | `scripts/ui/hud/elements/world_markers/hud_element_world_markers_settings.lua` |
| Vanilla interaction marker (15 m, fade, offsets, LOS alpha) | `scripts/ui/hud/elements/world_markers/templates/world_marker_template_interaction.lua` |
| `HudElementInteraction._interaction_units` | `scripts/ui/hud/elements/interaction/hud_element_interaction.lua:14,64-106,108-120` |
| `UIHud:element`, visible elements | `scripts/managers/ui/ui_hud.lua:20,271,387` |
| `HudElementBase` `_parent`, `has_widget`, `_unregister_widget_name` | `scripts/ui/hud/elements/hud_element_base.lua:13,56-64` |
| Idol pick and destruction | `scripts/managers/collectibles/collectibles_manager.lua:28-66`; `scripts/extension_systems/destructible/destructible_extension.lua:125-133,338-395,434-436`; `gameplay_init_step_pacing.lua:20` |
| `ALIVE` lifetime | `scripts/managers/position_lookup/position_lookup_manager.lua:40,44` |
| `Camera.local_position`, `math.easeCubic` (LuaCATS added 2026-10-13) | `types/SOURCES.md` |
| DMF events, hooks, lifecycle | `dmf-source/scripts/mods/dmf/modules/core/events.lua:11-70`, `hooks.lua:181-185,318-333`, `toggling.lua:10-22`, `dmf_loader.lua:89-98` |

## Tests
- `tools/luajit/luajit mods/active/LightweightStrategicalMarkers/tests/test_categories.lua` -> 2026-10-13: 61 pickups, 17 marked, 44 ignored, 3 interaction types, 0 failures.
- `tools/luajit/luajit mods/active/LightweightStrategicalMarkers/tests/test_runtime.lua` -> 2026-10-13: 13672 checks, 0 failures (5 runs, identical).
- `bash tools/validate.sh mods/active/LightweightStrategicalMarkers` -> 2026-10-13: LuaLS 0 diagnostics, LuaJIT parse passed. `tools\validate.ps1` not run.

## Runtime status
Smallest in-game test:
1. Enable Lightweight Strategical Markers; turn off Markers Improved AIO's matching categories or disable it. Restart the game (first install).
2. Start a low-difficulty mission. Expected: markers with distances on ammo, grenades, medical crates, stimms, health stations and chests within 40 m, only for items in line of sight.
3. Walk up to a pickup. Expected: at about 15 m the marker hands over to the game's own marker; never two icons on one item.
4. Options: turn on "See markers through walls". Expected: items behind walls get markers. Set "Marker distance" to 150. Expected: far items appear.
5. Open a chest. Expected: its marker disappears and the items inside get their own.
6. Use a health station. Expected: the charge count drops; at 0 the marker dims.
7. Ctrl+Shift+R mid-mission. Expected: markers come back, no errors in the console log.

8. Options: turn on plasteel, diamantine, grimoires, scriptures and heretical idols. Expected: those items get markers; a destroyed idol loses its marker.

Confirmed in game 2026-10-13 (user): the base markers work. Runtime-pending: steps 3-8 individually; also hot-join, dedicated-server versus Psykanium, expedition ammo crates, frame cost compared with Markers Improved AIO.

## Open items
- 2026-10-13: confirm in game that chests and health stations are discovered on a client (their type comes from level data, which is not Lua and could not be checked).
- 2026-10-13: confirm that every vanilla icon used here renders at our size; tune ring and icon size after the first test.
