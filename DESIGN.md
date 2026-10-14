# LightweightMarkers: design
Status 2026-10-14: 1.0.1 released on GitHub and Nexus (page 1450); 1.0.0 was the first release as Lightweight Markers (0.99.0 and the first 1.0.0 were LightweightStrategicalMarkers), ModID `LightweightMarkers`. 1.0.1 adds "Power cells and containers"; power cells confirmed in game, containers not (no mission found). Verified: static and offline (`tests/`); independent source review 2026-10-13; all features confirmed in game by the user 2026-10-13. Tagging through our markers and item colours (new in 1.0.0) confirmed in game by the user 2026-10-13.

Lightweight markers for ammo, grenade refills, medical crates, stimms, health stations and chests, built as a lean alternative to Markers Improved AIO (`referensmoddar/markers_aio`).

## Files
- `LightweightMarkers.lua`: settings snapshot, discovery hook and seed, registry, 4 Hz sweep, HUD registration, lifecycle.
- `marker_template.lua`: the world-marker template (factory taking the shared config and state): visuals in `on_enter`, alpha and distance text in `update_function`, widget release in `on_exit`.
- `categories.lua`: pure data: pickup type and interaction type to kind, kind visuals, group settings.
- `LightweightMarkers_data.lua`, `_localization.lua`: options and English text.
- `tests/`: offline harnesses (`tests/README.md`).

## Decisions
- 2026-10-13 (user): name "Lightweight Strategical Markers"; mark ammo, grenades, medical crates, stimms, health stations and chests; performance first.
- 2026-10-13 (user): renamed to "Lightweight Markers": ModID, folder, files and repository `LightweightMarkers`. The ModID is the DMF settings key, so settings from 0.99.0 and 1.0.0 do not carry over, and players replace the old folder and its `mod_load_order.txt` line.
- 2026-10-13 (user): "see through walls" is a setting, off by default.
- 2026-10-13 (user): icons are the game's own interaction icons.
- 2026-10-13 (user, option 1 of 2): markers copy vanilla's interaction marker at the 15 m hand-over (icon colour, frame textures and size at vanilla's distance scale 0.4; the larger point-of-interest frame for health stations), so the hand-over is seamless. This replaced the earlier tints and size bumps, so small and large ammo and plasteel and diamantine look alike, as in vanilla. Idols keep their own tint. Rejected: hiding vanilla's marker (extra hook, loses its tag and interaction visuals).
- 2026-10-13 (user): at close range our marker yields to vanilla's interaction marker for the same unit.
- 2026-10-13 (user): health station charges shown, empty stations dimmed, distance in metres (setting, on).
- 2026-10-13 (user): a marker distance setting so players can see further: 40 m default, 10-200 m.
- 2026-10-13 (user): plasteel, diamantine, grimoires, scriptures and heretical idols as options, off by default, as light as possible.
- 2026-10-13 (user): "Show distance" off by default.
- 2026-10-13 (user): stimms get Markers Improved AIO's default colours (medical green, power red, speed blue, concentration yellow), health stations the medical stimm's green, plasteel and diamantine light blue. Vanilla's interaction marker for those items gets the same colour, so an item keeps one colour at every distance and with any setting. Done by recolouring vanilla's icon, not by hiding its marker (that keeps tags and the interaction prompt).
- 2026-10-13, revised 2026-10-14 after research (`analysis/chest-prediction/README.md`, not tracked): chest contents are never sent to clients, but the reserved part is likely computable online on linear missions. The server's `_populate_pickups` is a deterministic function of the level seed (the session seed the client receives; confirmed in the user's log), static pools and client-visible spawner data, and the non-chest placements of the same pass are visible to the client as a check. 2026-10-14 first online test (km_station, client): an offline replay with the identified `math.next_random` (Numerical Recipes LCG), a search over the per-process `pairs()` orders and a branch for the last-section rounding edge explained all 54 floor pickups with 0 contradictions and matched the one opened chest; details in the analysis report. Open: more missions, checking predictions against chest openings, in-game search cost. Slots rolled on opening are only predictable as "if opened now". Horde and Expeditions are not replayable. Not built.
- 2026-10-13 (user): our markers can be tagged, with and without "See markers through walls", at the marker distance. Vanilla allows tagging only through its own interaction marker (15 m, line of sight) or a crosshair ray that stops at walls.
- 2026-10-13 (user): Nexus page 1450, published by the user 2026-10-14 with 1.0.1 as its Main file. `NEXUS_DESCRIPTION.bbcode` is the page description, published by `.github/workflows/nexus-description.yml` (copied from AnotherScoreboard; Nexus API v3 `PATCH /mods/{id}`, repository secret `NEXUSMODS_APIKEY`). Its comparison with an all-in-one marker mod (measured on Markers Improved AIO: about 18,000 Lua lines in 28 files, replaced world-marker HUD functions, per-frame hooks, about 380 setting ids) never names that mod.
- 2026-10-13 (user): mission containers (luggable `container_01/02/03_luggable`) as an option, off by default; merged with power cells into one option on 2026-10-14 (below). Hidden while not in a pick-up state: the sweep reads `locomotion_system:current_state()` against `ProjectileLocomotionSettings.valid_interaction_states`, the luggable interaction's own condition (`luggable_interaction.lua:17-46`); carried and `socket_lock` are excluded, and the client husk reports the synced state (`projectile_husk_locomotion_extension.lua:73-75,220-253`). They stay tracked, so a dropped container is marked again. Control rods and prismata cases stay unmarked.
- 2026-10-14 (user): power cells (`battery_01/02_luggable`) marked, confirmed in game by the user; merged with mission containers into one option, "Power cells and containers" (`show_carry_items`, kind `carry_item`), off by default, because which missions place containers could not be found (not in Lua source, Markers Improved AIO or the web). Mainly mainly for the medicae stations' cells that spawn hidden in the level (`health_station_extension.lua:339-357,390-400`). Objective cells are the same pickup types and are marked too; telling them apart needs server-only state. Same pick-up-state check as mission containers; a plugged-in cell is `socket_lock` (`luggable_socket_extension.lua:125-167`). Tooltips say exactly which items each option covers.
- 2026-10-13: not marked: luggables other than mission containers and power cells, expedition-only pickups except the large ammo crate, live-event items (including the nurgle totem Markers AIO lists under idols). The ignore list in `tests/test_categories.lua` names each pickup.

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
- Passes: background, ring and icon with vanilla's textures, colours and hand-over sizes (`marker_template.lua`, FRAMES), a distance label and a charge count. One widget definition is cached and shared (`UIWidget.init` clones content, style and passes, `scripts/managers/ui/ui_widget.lua:14-33`).
- `on_enter` writes per-marker settings into the marker's own deep-copied template (`table.clone`, `scripts/foundation/utilities/table.lua:38-52`): position offset (0.8 m for pickups like vanilla's "pickup" visuals, 0 for chests and stations), max distance, line-of-sight check and edge fade (`easing_function` is required, `_get_fade` calls it unguarded).
- `update_function` runs every frame for each live marker after `draw` is decided (`hud_element_world_markers.lua:461-474`, call at `:470`). It allocates nothing and reads no settings. Alpha = line of sight x empty-station dim x (1 - vanilla's alpha); at about zero it sets `draw = false` so the widget is not drawn. Distance text comes from a prebuilt table and changes only when the whole metre does.
- Vanilla recolour: a `hook_safe` on `HudElementWorldMarkers.event_add_world_marker_unit` (once per added marker) finds a new `interaction` marker under the newest id (`_register_marker`, `hud_element_world_markers.lua:168-188`) and swaps the update function in its own template copy (`_template_by_type` clones per marker) for a plain wrapper. The wrapper calls vanilla's update (`world_marker_template_interaction.lua:673-799`), keeps its return value and writes the kind's colour into the icon when the unit is tracked and the kind has its own colour (`recolor`). Vanilla sets that colour only in `setup_marker_by_interaction_type` (`:480-518`, on a visual-type change such as tagging), and a template it re-clones there keeps the wrapper. A per-frame DMF hook was rejected: it allocates a return table and runs xpcall for every interaction marker every frame. Enable wraps existing interaction markers; disable and unload restore the original function. Items of a group that is off are not tracked and keep vanilla's colour.
- Vanilla yield: vanilla's marker for the unit is found through `HudElementInteraction._interaction_units[unit].marker_id` (`scripts/ui/hud/elements/interaction/hud_element_interaction.lua:64-106`) and `_markers_by_id`; its alpha is its line-of-sight alpha times its distance fade unless tagged. While it is fully shown, ours is hidden and its line-of-sight check is off, so it takes no raycasts.
- Tagging: the template sets `using_smart_tag_system`, `size` (the ring box, set per marker in `on_enter`) and `get_smart_tag_id` (`SmartTagSystem:unit_tag_id`). The tagging HUD then picks the nearest such marker under the crosshair (`hud_element_smart_tagging.lua:599-682`): in line of sight means `not marker.raycast_result`, so with "See markers through walls" (no line-of-sight check) a marker behind a wall is taggable and with it off only a visible one; within the marker's `max_distance`; and only for units with a smart tag extension that `can_tag` (chests and idols have none). The server checks aim and line of sight only for breeds (`smart_tag_system.lua:63-107,739-780`), so pickup tags at any distance are accepted. No per-frame cost: the HUD reads these only while scanning for a tag target.
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
| Vanilla icon colour set on visual-type change; update return | `world_marker_template_interaction.lua:480-518,673-799` |
| Marker registration under the newest id, per-marker template clone | `hud_element_world_markers.lua:106-135,168-188` |
| Tag target selection from smart-tag markers; server tag validation | `scripts/ui/hud/elements/smart_tagging/hud_element_smart_tagging.lua:210-232,599-682,846-857`; `scripts/extension_systems/smart_tag/smart_tag_system.lua:37-107,449-454,739-780` |
| `HudElementInteraction._interaction_units` | `scripts/ui/hud/elements/interaction/hud_element_interaction.lua:14,64-106,108-120` |
| `UIHud:element`, visible elements | `scripts/managers/ui/ui_hud.lua:20,271,387` |
| `HudElementBase` `_parent`, `has_widget`, `_unregister_widget_name` | `scripts/ui/hud/elements/hud_element_base.lua:13,56-64` |
| Idol pick and destruction | `scripts/managers/collectibles/collectibles_manager.lua:28-66`; `scripts/extension_systems/destructible/destructible_extension.lua:125-133,338-395,434-436`; `gameplay_init_step_pacing.lua:20` |
| Luggable pick-up states, client state | `scripts/extension_systems/interaction/interactions/luggable_interaction.lua:17-46`; `scripts/settings/projectile_locomotion/projectile_locomotion_settings.lua:7,15-19`; `scripts/extension_systems/locomotion/projectile_husk_locomotion_extension.lua:73-75`; `scripts/extension_systems/unit_templates/pickup_unit_template.lua:186-197` |
| `ALIVE` lifetime | `scripts/managers/position_lookup/position_lookup_manager.lua:40,44` |
| `Camera.local_position`, `math.easeCubic` (LuaCATS added 2026-10-13) | `types/SOURCES.md` |
| DMF events, hooks, lifecycle | `dmf-source/scripts/mods/dmf/modules/core/events.lua:11-70`, `hooks.lua:181-185,318-333`, `toggling.lua:10-22`, `dmf_loader.lua:89-98` |

## Tests
- `tools/luajit/luajit mods/active/LightweightMarkers/tests/test_categories.lua` -> 2026-10-13: 61 pickups, 22 marked, 39 ignored, 3 interaction types, 0 failures.
- `tools/luajit/luajit mods/active/LightweightMarkers/tests/test_runtime.lua` -> 2026-10-13: 13704 checks, 0 failures.
- `tools\validate.ps1 mods\active\LightweightMarkers` -> 2026-10-13: LuaLS 0 diagnostics, LuaJIT load passed.

## Runtime status
Smallest in-game test:
1. Enable Lightweight Markers; turn off Markers Improved AIO's matching categories or disable it. Restart the game (first install).
2. Start a low-difficulty mission. Expected: markers on ammo, grenades, medical crates, stimms, health stations and chests within 40 m, only for items in line of sight, without distance text ("Show distance" is off by default).
3. Walk up to a pickup. Expected: at about 15 m the marker hands over to the game's own marker; never two icons on one item.
4. Options: turn on "See markers through walls". Expected: items behind walls get markers. Set "Marker distance" to 150. Expected: far items appear. Turn on "Show distance". Expected: distance in metres appears below the markers.
5. Open a chest. Expected: its marker disappears and the items inside get their own.
6. Use a health station. Expected: the charge count drops; at 0 the marker dims.
7. Ctrl+Shift+R mid-mission. Expected: markers come back, no errors in the console log.

8. Options: turn on plasteel, diamantine, grimoires, scriptures and heretical idols. Expected: those items get markers; a destroyed idol loses its marker.
9. Colours: stimms are green, red, blue or yellow, health stations green, plasteel and diamantine light blue, both far away and within 15 m (vanilla's marker), also when tagged.
10. Tagging: aim at a marker 20-40 m away and tag. Expected: the item is tagged. Turn on "See markers through walls" and tag a marker behind a wall. Expected: it is tagged. With it off, a marker behind a wall is not shown and cannot be tagged.

Confirmed in game 2026-10-13 (user): everything tested works, including the 15 m hand-over and the material and collectible options.

## Open items
- 2026-10-13: confirm in game that chests and health stations are discovered on a client (their type comes from level data, which is not Lua and could not be checked).
- 2026-10-13: confirm that every vanilla icon used here renders at our size; tune ring and icon size after the first test.
