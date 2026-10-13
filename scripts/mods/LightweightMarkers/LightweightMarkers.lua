local mod = get_mod("LightweightMarkers")

local PATH = "LightweightMarkers/scripts/mods/LightweightMarkers/"

local function load(name)
    local chunk = mod:io_dofile(PATH .. name)

    if not chunk then
        error("failed to load " .. name)
    end

    return chunk
end

local Categories = load("categories")

-- Named after the ModID so a renamed copy of the mod never shares (and removes) this template.
local TEMPLATE_NAME = mod:get_name() .. "_marker"
-- Registry pass that adds and removes markers by distance and refreshes chest and station state.
local SWEEP_INTERVAL = 0.25
-- Markers are added this far beyond the marker distance (so they fade in at the edge) and removed
-- only further out, so walking along the edge does not churn widgets.
local ADD_MARGIN = 5
local KEEP_MARGIN = 10
local EMPTY_STATION_ALPHA = 0.45

local COUNT_TEXT = {}

for charges = 0, 9 do
    COUNT_TEXT[charges] = tostring(charges)
end

local config = {
    group_enabled = {},
}
-- element: the HudElementWorldMarkers our template is registered in; marker ids belong to it.
-- interaction_units: that HUD's HudElementInteraction._interaction_units, refreshed every sweep.
local state = {
    element = nil,
    interaction_units = nil,
}
local marker_by_unit = {}

local template = load("marker_template")({
    config = config,
    state = state,
    marker_by_unit = marker_by_unit,
    template_name = TEMPLATE_NAME,
})

local function refresh_config()
    config.see_through_walls = mod:get("see_through_walls") == true
    config.max_distance = mod:get("max_distance") or 40
    config.marker_scale = (mod:get("marker_scale") or 100) / 100
    config.show_distance = mod:get("show_distance") == true

    for group, setting_id in pairs(Categories.group_settings) do
        config.group_enabled[group] = mod:get(setting_id) ~= false
    end
end

refresh_config()

-- Registry of marked interactables: dense arrays with swap-remove, filled when units spawn.
local units = {}
local kinds = {}
local index_of = {}
local count = 0

-- Only items whose group is on are tracked, so turned-off groups (most collectibles by default)
-- cost nothing; turning one on reseeds the registry.
local function track(unit, kind)
    if index_of[unit] or not config.group_enabled[kind.group] then
        return
    end

    count = count + 1
    units[count] = unit
    kinds[count] = kind
    index_of[unit] = count
end

local function untrack_at(i)
    local unit = units[i]
    local last = count

    index_of[unit] = nil

    if i ~= last then
        local moved = units[last]

        units[i] = moved
        kinds[i] = kinds[last]
        index_of[moved] = i
    end

    units[last] = nil
    kinds[last] = nil
    count = last - 1
end

local function clear_registry()
    table.clear(units)
    table.clear(kinds)
    table.clear(index_of)
    count = 0
end

-- Vanilla's interaction marker sets its icon colour only when its visual type changes, for example
-- on tagging (world_marker_template_interaction.lua, setup_marker_by_interaction_type). After each of
-- its updates a tracked item with its own colour gets that colour back, so it looks the same at every
-- distance. Each marker has its own template copy (hud_element_world_markers.lua,
-- _template_by_type), so the update is wrapped per marker with a plain call instead of a DMF hook,
-- which would allocate and xpcall every frame for every interaction marker.
local function recolored_update(parent, ui_renderer, widget, marker, template, dt, t)
    local animating = marker.lsm_vanilla_update(parent, ui_renderer, widget, marker, template, dt, t)
    local i = index_of[marker.unit]
    local kind = i and kinds[i]

    if kind and kind.recolor then
        local icon_color = widget.style.icon.color
        local color = kind.color

        icon_color[1], icon_color[2], icon_color[3], icon_color[4] = color[1], color[2], color[3], color[4]
    end

    return animating
end

local function wrap_vanilla(marker)
    local template = marker.template

    if template.update_function ~= recolored_update then
        marker.lsm_vanilla_update = template.update_function
        template.update_function = recolored_update
    end
end

local function unwrap_vanilla(element)
    local markers = element and element._markers_by_type.interaction

    if markers then
        for i = 1, #markers do
            local marker = markers[i]
            local template = marker.template

            if template.update_function == recolored_update then
                template.update_function = marker.lsm_vanilla_update
            end
        end
    end
end

local function wrap_all_vanilla(element)
    local markers = element._markers_by_type.interaction

    if markers then
        for i = 1, #markers do
            wrap_vanilla(markers[i])
        end
    end
end

-- The marker was just registered under the newest id (_register_marker).
mod:hook_safe("HudElementWorldMarkers", "event_add_world_marker_unit", function(self, marker_type)
    if marker_type == "interaction" then
        local marker = self._markers_by_id[self._id_counter]

        if marker then
            wrap_vanilla(marker)
        end
    end
end)

local function pickup_type(unit)
    if Unit.has_data(unit, "pickup_type") then
        return Unit.get_data(unit, "pickup_type")
    end
end

-- Runs once per interactable when it gets its interaction type: from InteracteeExtension.init for
-- spawned units (pickups, deployed crates) and from the Interactable component for level units
-- such as chests and health stations (scripts/components/interactable.lua).
mod:hook_safe("InteracteeExtension", "set_interaction_context", function(self, interaction_type)
    local unit = self._unit

    if not interaction_type or index_of[unit] then
        return
    end

    local kind = Categories.classify(pickup_type(unit), interaction_type)

    if kind then
        track(unit, kind)
    end
end)

-- The CollectiblesManager picks one idol per section from the level seed on every peer and hands
-- it its data (scripts/managers/collectibles/collectibles_manager.lua, on_gameplay_post_init).
-- Candidates it did not pick keep their component data, which has no `id`.
mod:hook_safe("DestructibleExtension", "set_collectible_data", function(self, data)
    track(data and data.unit or self._unit, Categories.kinds.heretical_idol)
end)

local function idol_destroyed(unit)
    local destructible = ScriptUnit.has_extension(unit, "destructible_system")
    local destruction_info = destructible and destructible._destruction_info

    -- Stage 0 is the last stage, also on clients (destructible_extension.lua, _dequeue_stage).
    return not destruction_info or destruction_info.current_stage_index == 0
end

-- A luggable can be picked up only in these locomotion states (luggable_interaction.lua,
-- interactor_condition_func); carried and socket_lock are not among them. The husk locomotion on
-- clients reports the synced state (projectile_husk_locomotion_extension.lua, current_state).
local LUGGABLE_FREE_STATES = require("scripts/settings/projectile_locomotion/projectile_locomotion_settings").valid_interaction_states

local function luggable_free(unit)
    local locomotion = ScriptUnit.has_extension(unit, "locomotion_system")

    return locomotion ~= nil and LUGGABLE_FREE_STATES[locomotion:current_state()] == true
end

-- After enabling or a hot reload the interactables already exist; collect them once.
local function seed()
    clear_registry()

    local state_managers = Managers.state
    local extension_manager = state_managers and state_managers.extension
    local interactee_system = extension_manager and extension_manager:system("interactee_system")

    -- ALIVE is the PositionLookupManager's unit table; it is nil between game states
    -- (scripts/managers/position_lookup/position_lookup_manager.lua, init and destroy).
    local ALIVE = ALIVE

    if not interactee_system or not ALIVE then
        return
    end

    for unit, extension in pairs(interactee_system:unit_to_extension_map()) do
        if ALIVE[unit] then
            local kind
            local unit_pickup_type = pickup_type(unit)

            if unit_pickup_type then
                kind = Categories.classify(unit_pickup_type)
            else
                -- Every interaction type the unit was given, active or not (interactee_extension.lua,
                -- set_interaction_context). PlayerInteracteeExtension has no such table.
                local interactions = rawget(extension, "_interactions")

                if interactions then
                    for interaction_type in pairs(interactions) do
                        kind = Categories.classify(nil, interaction_type)

                        if kind then
                            break
                        end
                    end
                end
            end

            if kind then
                track(unit, kind)
            end
        end
    end

    local destructible_system = config.group_enabled.heretical_idols and extension_manager:system("destructible_system")

    if destructible_system then
        for unit, extension in pairs(destructible_system:unit_to_extension_map()) do
            local collectible_data = rawget(extension, "_collectible_data")

            if collectible_data and collectible_data.id and ALIVE[unit] and not idol_destroyed(unit) then
                track(unit, Categories.kinds.heretical_idol)
            end
        end
    end
end

local function add_marker(unit, kind)
    -- Vanilla's own icon for this unit, including level overrides; the kind's icon otherwise.
    local interactee = ScriptUnit.has_extension(unit, "interactee_system")
    local icon = interactee and interactee:interaction_icon() or kind.icon

    -- on_enter runs synchronously inside the trigger and records the marker in marker_by_unit.
    Managers.event:trigger("add_world_marker_unit", TEMPLATE_NAME, unit, nil, {
        kind = kind,
        icon = icon,
    })
end

-- The HUD drops a marker flagged `remove` on its next update and then calls on_exit.
local function remove_marker(unit)
    local marker = marker_by_unit[unit]

    if marker then
        marker_by_unit[unit] = nil
        marker.remove = true
        marker.draw = false
    end
end

local function remove_all_markers()
    for _, marker in pairs(marker_by_unit) do
        marker.remove = true
        marker.draw = false
    end

    table.clear(marker_by_unit)
end

local function refresh_charges(unit, marker)
    local station = ScriptUnit.has_extension(unit, "health_station_system")
    local charges = station and station:charge_amount()

    if charges ~= marker.lsm_charges then
        marker.lsm_charges = charges
        marker.widget.content.count = charges and (COUNT_TEXT[charges] or tostring(charges)) or nil
        marker.lsm_dim = charges == 0 and EMPTY_STATION_ALPHA or 1
    end
end

-- The HUD updates (and so applies `remove` and runs on_exit) only elements in a visible group:
-- not while a menu, the tactical overlay or a cutscene is up, nor while dead
-- (scripts/managers/ui/ui_hud.lua, update; hud_elements_player.lua, HudElementWorldMarkers).
local function world_markers_updating(element)
    local hud = element._parent
    local visible_elements = hud and hud._currently_visible_elements

    return visible_elements == nil or visible_elements.HudElementWorldMarkers == true
end

local function purge_dead(ALIVE)
    local i = 1

    while i <= count do
        local unit = units[i]

        if ALIVE[unit] then
            i = i + 1
        else
            remove_marker(unit)
            untrack_at(i)
        end
    end
end

local function sweep()
    local ALIVE = ALIVE

    if not ALIVE then
        return
    end

    local element = state.element
    local camera = element and element:_get_camera()

    if not camera or not world_markers_updating(element) then
        -- No markers to manage now, but picked-up items still leave the registry.
        purge_dead(ALIVE)

        return
    end

    local hud = element._parent
    local interaction = hud and hud:element("HudElementInteraction")

    state.interaction_units = interaction and interaction._interaction_units or nil

    local camera_position = Camera.local_position(camera)
    local max_distance = config.max_distance
    local add_distance_sq = (max_distance + ADD_MARGIN) ^ 2
    local keep_distance_sq = (max_distance + KEEP_MARGIN) ^ 2
    local group_enabled = config.group_enabled
    local i = 1

    while i <= count do
        local unit = units[i]

        if not ALIVE[unit] then
            -- Picked up or despawned; the HUD removes its marker itself.
            remove_marker(unit)
            untrack_at(i)
        else
            local kind = kinds[i]
            local marker = marker_by_unit[unit]
            local wanted = group_enabled[kind.group]
            local finished = false

            if wanted and kind.chest then
                local chest = ScriptUnit.has_extension(unit, "chest_system")

                -- An opened chest never closes again.
                if chest and chest:is_open() then
                    wanted = false
                    finished = true
                end
            elseif wanted and kind.idol and idol_destroyed(unit) then
                wanted = false
                finished = true
            elseif wanted and kind.luggable and not luggable_free(unit) then
                -- Carried, thrown or delivered; it can be dropped again, so it stays tracked.
                wanted = false
            end

            if wanted then
                local distance_sq = Vector3.distance_squared(Unit.world_position(unit, 1), camera_position)

                wanted = distance_sq <= (marker and keep_distance_sq or add_distance_sq)
            end

            if wanted then
                if not marker then
                    add_marker(unit, kind)

                    marker = marker_by_unit[unit]
                end

                if marker and kind.charges then
                    refresh_charges(unit, marker)
                end
            elseif marker then
                remove_marker(unit)
            end

            if finished then
                untrack_at(i)
            else
                i = i + 1
            end
        end
    end
end

local sweep_timer = 0

local function update(dt)
    sweep_timer = sweep_timer + dt

    if sweep_timer < SWEEP_INTERVAL then
        return
    end

    sweep_timer = sweep_timer - SWEEP_INTERVAL

    if sweep_timer > SWEEP_INTERVAL then
        sweep_timer = 0
    end

    if count > 0 then
        sweep()
    end
end

local function register(element)
    element._marker_templates[TEMPLATE_NAME] = template

    if element ~= state.element then
        -- Ids issued by another HUD mean nothing here.
        table.clear(marker_by_unit)
        state.element = element
        state.interaction_units = nil
    end
end

local function unregister()
    local element = state.element

    if element then
        element._marker_templates[TEMPLATE_NAME] = nil
    end

    state.element = nil
    state.interaction_units = nil
end

local function current_element()
    local ui_manager = Managers.ui
    local hud = ui_manager and ui_manager:get_hud()

    return hud and hud:element("HudElementWorldMarkers")
end

mod:hook_safe("HudElementWorldMarkers", "init", register)

mod:hook_safe("HudElementWorldMarkers", "destroy", function(self)
    if self == state.element then
        table.clear(marker_by_unit)
        state.element = nil
        state.interaction_units = nil
    end
end)

mod.on_enabled = function()
    refresh_config()
    seed()

    local element = current_element()

    if element then
        register(element)
        wrap_all_vanilla(element)
    end

    sweep_timer = SWEEP_INTERVAL
    mod.update = update
end

mod.on_disabled = function()
    mod.update = nil
    remove_all_markers()
    unwrap_vanilla(state.element)
    unregister()
    clear_registry()
end

mod.on_unload = function(exit_game)
    mod.update = nil

    if exit_game then
        return
    end

    remove_all_markers()
    unwrap_vanilla(state.element)
    unregister()
    clear_registry()
end

mod.on_setting_changed = function()
    refresh_config()
    -- Markers take their settings in on_enter; the next sweep rebuilds them. The registry is rebuilt
    -- too, since it holds only the groups that are on.
    remove_all_markers()

    if mod.update then
        seed()
    end

    sweep_timer = SWEEP_INTERVAL
end

mod.on_game_state_changed = function(status, state_name)
    if status == "exit" and state_name == "StateGameplay" then
        remove_all_markers()
        clear_registry()
    end
end
