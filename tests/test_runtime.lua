-- Offline harness: drives the real mod files through a fake HUD and world, and checks which
-- markers exist and how they look. The fake HUD follows the order of
-- darktide-source/scripts/ui/hud/elements/world_markers/hud_element_world_markers.lua
-- (event_add_world_marker_unit clones the template and runs on_enter synchronously;
-- _calculate_markers decides `draw` for every marker, then runs update_functions, then
-- unregisters markers flagged `remove` or whose unit died, calling on_exit). Engine natives are
-- plain-table stand-ins, so this proves the mod's own logic only, never an engine contract.
-- Run from the workspace root:
--   tools/luajit/luajit mods/active/LightweightStrategicalMarkers/tests/test_runtime.lua

local MODS = "mods/active/"

local failures = 0
local checks = 0

local function check(condition, fmt, ...)
    checks = checks + 1

    if not condition then
        failures = failures + 1
        print("FAIL: " .. string.format(fmt, ...))
    end
end

-- Engine stand-ins -------------------------------------------------------------------------------

local function deep_clone(t)
    if type(t) ~= "table" then
        return t
    end

    local copy = {}

    for k, v in pairs(t) do
        copy[k] = deep_clone(v)
    end

    return copy
end

table.clear = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
end
math.easeCubic = function(t)
    return t
end

ALIVE = {}

Unit = {
    has_data = function(unit, key)
        return unit.data[key] ~= nil
    end,
    get_data = function(unit, key)
        return unit.data[key]
    end,
    world_position = function(unit)
        return unit.pos
    end,
}

Vector3 = {
    distance_squared = function(a, b)
        local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]

        return dx * dx + dy * dy + dz * dz
    end,
}

Camera = {
    local_position = function(camera)
        return camera.pos
    end,
}

ScriptUnit = {
    has_extension = function(unit, system_name)
        return unit.extensions[system_name]
    end,
}

package.preload["scripts/managers/ui/ui_widget"] = function()
    return {
        create_definition = function(passes, scenegraph_id)
            return { passes = passes, scenegraph_id = scenegraph_id }
        end,
    }
end

-- Fake HUD ---------------------------------------------------------------------------------------

local TEMPLATE_NAME = "LightweightStrategicalMarkers_marker"
local Element = {}

Element.__index = Element

local function new_element(hud)
    return setmetatable({
        _parent = hud,
        _marker_templates = {},
        _markers = {},
        _markers_by_id = {},
        _widgets_by_name = {},
        _id_counter = 0,
        camera = { pos = { 0, 0, 0 } },
    }, Element)
end

function Element:_get_camera()
    return self.camera
end

function Element:has_widget(name)
    return self._widgets_by_name[name] ~= nil
end

function Element:_unregister_widget_name(name)
    self._widgets_by_name[name] = nil
end

function Element:_get_fade(fade_settings, distance)
    if distance > fade_settings.distance_max then
        return fade_settings.fade_from
    end

    return 1
end

function Element:event_add_world_marker_unit(marker_type, unit, callback, data)
    local template = deep_clone(self._marker_templates[marker_type])

    self._id_counter = self._id_counter + 1

    local id = self._id_counter
    local definition = template.create_widget_defintion(template, "pivot")
    local widget = { name = "marker_widget_id_" .. id, content = {}, style = {}, visible = true }

    for _, pass in ipairs(definition.passes) do
        if pass.style_id then
            widget.style[pass.style_id] = deep_clone(pass.style)
        end
    end

    self._widgets_by_name[widget.name] = widget

    local marker = { id = id, type = marker_type, unit = unit, widget = widget, data = data, template = template, scale = 1 }

    self._markers[#self._markers + 1] = marker
    self._markers_by_id[id] = marker

    if template.on_enter then
        template.on_enter(widget, marker, template)
    end

    if callback then
        callback(id)
    end
end

function Element:_unregister_marker(marker)
    if marker.template.on_exit then
        marker.template.on_exit(marker.widget, marker, marker.template)
    end

    self._markers_by_id[marker.id] = nil

    for i = 1, #self._markers do
        if self._markers[i] == marker then
            table.remove(self._markers, i)

            break
        end
    end
end

function Element:update(dt)
    local camera_position = self.camera.pos
    local to_remove = {}

    for _, marker in ipairs(self._markers) do
        local update = self._markers_by_id[marker.id] ~= nil
        local remove = marker.remove

        if update and not ALIVE[marker.unit] then
            remove = true
        end

        if remove then
            update = false
            to_remove[#to_remove + 1] = marker
        end

        if update then
            local distance = math.sqrt(Vector3.distance_squared(marker.unit.pos, camera_position))
            local max_distance = marker.template.max_distance

            marker.distance = distance
            marker.widget.content.distance = distance
            marker.draw = not max_distance or distance <= max_distance or marker.block_max_distance == true

            if marker.draw and marker.template.check_line_of_sight then
                marker.raycast_frame_count = (marker.raycast_frame_count or 0) + 1
                marker.raycast_initialized = true
                marker.raycast_result = marker.unit.blocked == true
                marker.raycasts = (marker.raycasts or 0) + 1
            end
        end

        marker.update = update
    end

    for _, marker in ipairs(self._markers) do
        local update_function = marker.update and marker.template.update_function

        if update_function then
            update_function(self, nil, marker.widget, marker, marker.template, dt, 0)
        end
    end

    for _, marker in ipairs(to_remove) do
        self:_unregister_marker(marker)
    end
end

function Element:ours()
    local list = {}

    for _, marker in ipairs(self._markers) do
        if marker.type == TEMPLATE_NAME and not marker.remove then
            list[#list + 1] = marker
        end
    end

    return list
end

function Element:marker_for(unit)
    local found

    for _, marker in ipairs(self:ours()) do
        if marker.unit == unit then
            check(found == nil, "two live markers for one unit")
            found = marker
        end
    end

    return found
end

-- UIHud updates only elements in a visible group (scripts/managers/ui/ui_hud.lua, update).
local hud = { elements = {}, _currently_visible_elements = { HudElementWorldMarkers = true } }

function hud:element(name)
    return self.elements[name]
end

local interactee_map = {}
local destructible_map = {}

Managers = {
    state = {
        extension = {
            system = function(_, name)
                if name == "interactee_system" then
                    return {
                        unit_to_extension_map = function()
                            return interactee_map
                        end,
                    }
                elseif name == "destructible_system" then
                    return {
                        unit_to_extension_map = function()
                            return destructible_map
                        end,
                    }
                end
            end,
        },
    },
    ui = {
        get_hud = function()
            return hud
        end,
    },
    event = {
        trigger = function(_, event_name, ...)
            local element = hud.elements.HudElementWorldMarkers

            if event_name == "add_world_marker_unit" and element then
                element:event_add_world_marker_unit(...)
            end
        end,
    },
}

-- Fake DMF ----------------------------------------------------------------------------------------

local settings = {
    see_through_walls = false,
    max_distance = 40,
    marker_scale = 100,
    show_distance = true,
    show_ammo = true,
    show_grenades = true,
    show_medical = true,
    show_stimms = true,
    show_health_stations = true,
    show_chests = true,
    show_plasteel = false,
    show_diamantine = false,
    show_grimoires = false,
    show_scriptures = false,
    show_heretical_idols = false,
}

local hooks = {}

local mod = {
    get_name = function()
        return "LightweightStrategicalMarkers"
    end,
    get = function(_, id)
        return settings[id]
    end,
    io_dofile = function(_, path)
        return dofile(MODS .. path .. ".lua")
    end,
    hook_safe = function(_, target, method, handler)
        hooks[target .. "." .. method] = handler
    end,
}

get_mod = function()
    return mod
end

dofile(MODS .. "LightweightStrategicalMarkers/scripts/mods/LightweightStrategicalMarkers/LightweightStrategicalMarkers.lua")

local function set_setting(id, value)
    settings[id] = value
    mod.on_setting_changed(id)
end

-- World helpers -----------------------------------------------------------------------------------

local function new_unit(x, data, extensions)
    local unit = { pos = { x, 0, 0 }, data = data or {}, extensions = extensions or {} }

    ALIVE[unit] = true

    return unit
end

local interactee_class = {}

function interactee_class.interaction_icon(self)
    return self.icon
end

-- Spawns an interactable the way the game does: its InteracteeExtension gets an interaction type.
local function spawn(x, interaction_type, data, extensions, icon)
    local unit = new_unit(x, data, extensions)
    local interactee = setmetatable({ _unit = unit, _interactions = { [interaction_type] = true }, icon = icon }, { __index = interactee_class })

    unit.extensions.interactee_system = interactee
    interactee_map[unit] = interactee
    hooks["InteracteeExtension.set_interaction_context"](interactee, interaction_type, {}, true)

    return unit
end

local function despawn(unit)
    ALIVE[unit] = nil
    interactee_map[unit] = nil
end

-- One frame of the mod (sweeps every 0.25 s) and the HUD.
local function frame(dt)
    dt = dt or 0.25

    if mod.update then
        mod.update(dt)
    end

    local element = hud.elements.HudElementWorldMarkers

    if element and hud._currently_visible_elements.HudElementWorldMarkers then
        element:update(dt)
    end
end

local function frames(n, dt)
    for _ = 1, n do
        frame(dt)
    end
end

local function camera_at(x)
    hud.elements.HudElementWorldMarkers.camera.pos = { x, 0, 0 }
end

-- Scenarios ---------------------------------------------------------------------------------------

local function new_hud()
    local element = new_element(hud)

    hud.elements.HudElementWorldMarkers = element
    hooks["HudElementWorldMarkers.init"](element)

    return element
end

local element = new_hud()

mod.on_enabled(true)

-- 1. Discovery and classification.
local ICONS = "content/ui/materials/hud/interactions/icons/"
local ammo = spawn(10, "ammunition", { pickup_type = "small_clip" })
local metal = spawn(10, "forge_material", { pickup_type = "small_metal" })
local chest_state = { open = false }
local chest = spawn(20, "chest", {}, {
    chest_system = { is_open = function()
        return chest_state.open
    end },
}, ICONS .. "default")
local station_state = { charges = 3 }
local station = spawn(30, "health_station", {}, {
    health_station_system = { charge_amount = function()
        return station_state.charges
    end },
}, ICONS .. "respawn")
local crate = spawn(15, "deployable_marker", {}, {}, ICONS .. "pocketable_medkit")
local door = spawn(5, "door_control_panel")
local power = spawn(12, "pocketable", { pickup_type = "syringe_power_boost_pocketable" }, {}, ICONS .. "pocketable_syringe_power")

frames(2)

check(element:marker_for(ammo) ~= nil, "small clip has a marker")
check(element:marker_for(metal) == nil, "crafting material has no marker")
check(element:marker_for(door) == nil, "door has no marker")
check(element:marker_for(chest) ~= nil, "chest has a marker")
check(element:marker_for(crate) ~= nil, "deployed medical crate has a marker")
check(#element:ours() == 5, "five markers, got %d", #element:ours())

local power_marker = element:marker_for(power)

check(power_marker.widget.content.icon == ICONS .. "pocketable_syringe_power", "stimm uses the game's own icon")
local icon_color = power_marker.widget.style.icon.color

check(icon_color[2] == 216 and icon_color[3] == 237 and icon_color[4] == 190, "icons use vanilla's colour")
check(math.abs(power_marker.widget.style.ring.size[1] - 38.4) < 1e-6, "ring matches vanilla at the hand-over distance")
check(power_marker.widget.content.ring == "content/ui/materials/hud/interactions/frames/mission_top", "standard frame")
check(element:marker_for(ammo).widget.content.icon == ICONS .. "ammunition", "pickup without an interactee icon falls back to the kind icon")
check(element:marker_for(ammo).template.position_offset[3] == 0.8, "pickups float like vanilla")
check(element:marker_for(chest).template.position_offset[3] == 0, "chests sit on their node")

-- 2. Health station charges and dimming.
local station_marker = element:marker_for(station)

check(station_marker.widget.content.ring == "content/ui/materials/hud/interactions/frames/pickup_top", "station uses vanilla's point-of-interest frame")
check(math.abs(station_marker.widget.style.ring.size[1] - 57.6) < 1e-6, "station ring matches vanilla's larger frame")

check(station_marker.widget.content.count == "3", "station shows 3 charges, got %s", tostring(station_marker.widget.content.count))
station_state.charges = 0
frames(1)
check(station_marker.widget.content.count == "0", "station shows 0 charges")
check(station_marker.lsm_dim < 1, "empty station is dimmed")
check(station_marker.widget.alpha_multiplier < 0.5 and station_marker.widget.alpha_multiplier > 0.3, "empty station alpha %.2f", station_marker.widget.alpha_multiplier or -1)

-- 3. Distance text, without new strings between frames.
local ammo_marker = element:marker_for(ammo)

check(ammo_marker.widget.content.label == "10 m", "distance label, got %s", tostring(ammo_marker.widget.content.label))

local label = ammo_marker.widget.content.label

frames(1)
check(rawequal(ammo_marker.widget.content.label, label), "label unchanged when the metre is unchanged")

-- 4. Distance hysteresis (max 40: add within 45, keep within 50).
local far = spawn(44, "ammunition", { pickup_type = "large_clip" })

frames(1)
check(element:marker_for(far) ~= nil, "added at 44 m")
camera_at(-5)
frames(1)
check(element:marker_for(far) ~= nil, "kept at 49 m")
camera_at(-7)
frames(1)
check(element:marker_for(far) == nil, "removed at 51 m")
camera_at(-2)
frames(1)
check(element:marker_for(far) == nil, "not re-added at 46 m")
camera_at(0)
frames(1)
check(element:marker_for(far) ~= nil, "re-added at 44 m")

local far_marker = element:marker_for(far)

check(far_marker.draw == false, "beyond 40 m the marker exists but is not drawn")
check(far_marker.widget.style.icon.size[1] == ammo_marker.widget.style.icon.size[1], "large ammo looks like vanilla's (same size as small)")

-- 5. Opened chest: marker removed and never re-added.
chest_state.open = true
frames(2)
check(element:marker_for(chest) == nil, "opened chest has no marker")
chest_state.open = false
frames(2)
check(element:marker_for(chest) == nil, "chest is dropped from the registry once opened")
-- Real chests never close again; keep it open for the rest of the run.
chest_state.open = true

-- 6. Picked-up item.
despawn(ammo)
frames(2)
check(element:marker_for(ammo) == nil, "picked-up item has no marker")
check(element._widgets_by_name[ammo_marker.widget.name] == nil, "its widget name is released")

-- 7. Line of sight.
power.blocked = true
frames(4, 0.1)
check(element:marker_for(power).draw == false, "blocked item is not drawn")
set_setting("see_through_walls", true)
frames(2)

local through = element:marker_for(power)

check(through ~= nil and through.template.check_line_of_sight == false, "through walls disables the line-of-sight check")
check(through.draw == true and through.widget.alpha_multiplier == 1, "blocked item drawn through walls")
set_setting("see_through_walls", false)
power.blocked = false
frames(3, 0.1)
check(element:marker_for(power).widget.alpha_multiplier > 0, "visible item fades in")

-- 8. Yield to vanilla's interaction marker for the same unit.
local vanilla_widget = { alpha_multiplier = 1, visible = true }
local vanilla = { id = 9999, draw = true, widget = vanilla_widget, template = {}, distance = 12 }

element._markers_by_id[9999] = vanilla
hud.elements.HudElementInteraction = { _interaction_units = { [power] = { marker_id = 9999 } } }
frames(1)
check(element:marker_for(power).draw == false, "hidden while vanilla's marker shows")

local yielding = element:marker_for(power)
local raycasts = yielding.raycasts or 0

frames(3)
check(yielding.template.check_line_of_sight == false, "no line-of-sight check while vanilla's marker shows")
check((yielding.raycasts or 0) <= raycasts + 1, "no raycasts while vanilla's marker shows")
vanilla.draw = false
frames(1)
check(element:marker_for(power).draw == true, "shown when vanilla's marker is not drawn")
check(yielding.template.check_line_of_sight == true, "line-of-sight check back on")
vanilla.draw = true
vanilla_widget.alpha_multiplier = 0
frames(1)
check(element:marker_for(power).draw == true, "shown when vanilla's marker is behind a wall")
element._markers_by_id[9999] = nil
hud.elements.HudElementInteraction = nil

-- Half-speed ageing in the shared raycast queue.
local wait_before = yielding.raycast_frame_count

frames(1)
check(yielding.raycast_frame_count - wait_before == 0.5, "our raycast wait ages at half speed, got +%s", tostring(yielding.raycast_frame_count - wait_before))

-- 9. Category toggle.
set_setting("show_stimms", false)
frames(1)
check(element:marker_for(power) == nil, "stimm markers off")
set_setting("show_stimms", true)
frames(1)
check(element:marker_for(power) ~= nil, "stimm markers back on")

-- 10. Longer marker distance.
local distant = spawn(150, "ammunition", { pickup_type = "small_grenade" })

frames(1)
check(element:marker_for(distant) == nil, "no marker at 150 m with distance 40")
set_setting("max_distance", 200)
frames(2)

local distant_marker = element:marker_for(distant)

check(distant_marker ~= nil and distant_marker.draw == true, "marker at 150 m with distance 200")
check(distant_marker.widget.content.label == "150 m", "label at 150 m")
set_setting("max_distance", 40)
frames(1)
check(element:marker_for(distant) == nil, "back to 40 m")

-- 11. Disable and enable.
local live_before = #element:ours()

mod.on_disabled(false)
frames(1)
check(#element:ours() == 0, "no markers while disabled")
check(element._marker_templates[TEMPLATE_NAME] == nil, "template removed while disabled")
check(mod.update == nil, "no update while disabled")
mod.on_enabled(false)
frames(1)
check(#element:ours() == live_before, "markers back after enabling (%d, before %d)", #element:ours(), live_before)

-- 12. New HUD: ids of the old HUD are forgotten, markers are rebuilt in the new one.
hooks["HudElementWorldMarkers.destroy"](element)

local old_element = element

element = new_hud()
frames(1)
check(#element:ours() == live_before, "markers rebuilt in a new HUD (%d)", #element:ours())
check(#old_element:ours() == live_before, "old HUD untouched (it is destroyed by the game)")

-- 12b. Collectibles: off by default, tracked only once turned on.
local small_metal = spawn(6, "forge_material", { pickup_type = "small_metal" }, {}, ICONS .. "environment_generic")
local tome = spawn(7, "pocketable", { pickup_type = "tome" }, {}, ICONS .. "pocketable_default")

-- Idols: the CollectiblesManager hands the picked idol its data; a candidate it did not pick has
-- component data without `id`.
local function spawn_idol(x, picked)
    local unit = new_unit(x)
    local destructible = { _unit = unit, _destruction_info = { current_stage_index = 1 } }

    unit.extensions.destructible_system = destructible
    destructible_map[unit] = destructible
    destructible._collectible_data = { name = "idol", section_id = 1, unit = unit }

    if picked then
        local data = { name = "idol", section_id = 1, unit = unit, id = 1 }

        hooks["DestructibleExtension.set_collectible_data"](destructible, data)
        destructible._collectible_data = data
    end

    return unit, destructible
end

local idol, idol_destructible = spawn_idol(9, true)
local hidden_idol = spawn_idol(11, false)

frames(2)
check(element:marker_for(small_metal) == nil, "plasteel off by default")
check(element:marker_for(tome) == nil, "scriptures off by default")
check(element:marker_for(idol) == nil, "idols off by default")
set_setting("show_plasteel", true)
set_setting("show_scriptures", true)
set_setting("show_heretical_idols", true)
frames(2)
check(element:marker_for(small_metal) ~= nil, "plasteel shown once turned on")
check(element:marker_for(tome) ~= nil, "scripture shown once turned on")
check(element:marker_for(idol) ~= nil, "picked idol shown once turned on")
check(element:marker_for(hidden_idol) == nil, "idol candidate the game did not pick has no marker")
check(element:marker_for(idol).widget.content.icon == ICONS .. "enemy_priority", "idol icon")
check(element:marker_for(idol).template.position_offset[3] == 0.5, "idol marker floats above its base")
idol_destructible._destruction_info.current_stage_index = 0
frames(2)
check(element:marker_for(idol) == nil, "destroyed idol has no marker")
idol_destructible._destruction_info.current_stage_index = 1
frames(2)
check(element:marker_for(idol) == nil, "destroyed idol leaves the registry")
idol_destructible._destruction_info.current_stage_index = 0

local new_idol = spawn_idol(13, true)

frames(2)
check(element:marker_for(new_idol) ~= nil, "idol picked while the group is on is tracked by the hook")
set_setting("show_plasteel", false)
set_setting("show_scriptures", false)
set_setting("show_heretical_idols", false)
frames(2)
check(element:marker_for(small_metal) == nil and element:marker_for(new_idol) == nil, "collectibles off again")
despawn(small_metal)
despawn(tome)
ALIVE[new_idol] = nil
destructible_map[new_idol] = nil
frames(2)

-- 13. While the HUD does not update (menu open, dead), nothing is added or rebuilt, and
-- picked-up items still leave the registry.
local live = #element:ours()
local hidden_pick = spawn(8, "grenade", { pickup_type = "small_grenade" })

hud._currently_visible_elements.HudElementWorldMarkers = false
frames(2)
check(element:marker_for(hidden_pick) == nil, "nothing added while the HUD is hidden")
set_setting("marker_scale", 150)
frames(4)
check(#element._markers == live, "no new markers while the HUD is hidden (%d, before %d)", #element._markers, live)
despawn(hidden_pick)
frames(2)
hud._currently_visible_elements.HudElementWorldMarkers = true
frames(2)
check(#element:ours() == live, "markers rebuilt once the HUD is visible (%d, before %d)", #element:ours(), live)
check(element:marker_for(hidden_pick) == nil, "item picked up while hidden has no marker")
check(math.abs(element:marker_for(power).widget.style.ring.size[1] - 57.6) < 1e-6, "rebuilt with the new size, got %s", tostring(element:marker_for(power).widget.style.ring.size[1]))
set_setting("marker_scale", 100)
frames(2)

-- 14. Mission exit clears everything.
mod.on_game_state_changed("exit", "StateGameplay")
frames(1)
check(#element:ours() == 0, "no markers after leaving the mission")

-- 15. Random spawns, pickups and movement: invariants hold and widgets do not leak.
math.randomseed(1)

local pool = {}
local KINDS = {
    { "ammunition", "small_clip" }, { "ammunition", "large_clip" }, { "grenade", "small_grenade" },
    { "pocketable", "syringe_speed_boost_pocketable" }, { "pocketable", "medical_crate_pocketable" },
    { "forge_material", "large_metal" },
}

for step = 1, 3000 do
    local r = math.random()

    if r < 0.3 or #pool == 0 then
        local k = KINDS[math.random(#KINDS)]

        pool[#pool + 1] = spawn(math.random(-120, 120), k[1], { pickup_type = k[2] })
    elseif r < 0.5 then
        local i = math.random(#pool)

        despawn(pool[i])
        table.remove(pool, i)
    elseif r < 0.55 then
        camera_at(math.random(-100, 100))
    end

    frame(0.25)

    if step % 50 == 0 then
        local camera_x = element.camera.pos[1]

        for _, unit in ipairs(pool) do
            local distance = math.abs(unit.pos[1] - camera_x)
            local marked = element:marker_for(unit) ~= nil
            local markable = unit.data.pickup_type ~= "large_metal"

            if not markable then
                check(not marked, "unmarkable unit has a marker")
            elseif distance <= 45 then
                check(marked, "unit at %d m has no marker (step %d)", distance, step)
            elseif distance > 50 then
                check(not marked, "unit at %d m has a marker (step %d)", distance, step)
            end
        end

        local widgets = 0

        for _ in pairs(element._widgets_by_name) do
            widgets = widgets + 1
        end

        check(widgets == #element._markers, "widget names %d, markers %d (step %d)", widgets, #element._markers, step)
    end
end

print(string.format("%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
