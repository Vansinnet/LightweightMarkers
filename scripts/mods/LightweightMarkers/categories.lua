-- Which interactables get a marker and how each kind looks. Pure data with no engine calls, so
-- tests/test_categories.lua can load it next to the game's own pickup and interaction settings.

local ICONS = "content/ui/materials/hud/interactions/icons/"

-- Vanilla interaction icon colour (Color.ui_hud_green_super_light, scripts/foundation/utilities/color.lua).
local DEFAULT_COLOR = { 255, 216, 237, 190 }
-- Stimm colours follow Markers Improved AIO's defaults; health stations share the medical stimm's.
local MEDICAL_GREEN = { 255, 30, 255, 30 }
local POWER_RED = { 255, 255, 30, 30 }
local SPEED_BLUE = { 255, 30, 150, 255 }
local CONCENTRATION_YELLOW = { 255, 255, 255, 30 }
local MATERIAL_LIGHT_BLUE = { 255, 140, 200, 255 }

-- Pickups float 0.8 m above their marker node like vanilla "pickup" interaction markers; chests and
-- health stations sit on it ("default" and "point_of_interest" visuals in
-- scripts/ui/hud/elements/world_markers/templates/world_marker_template_interaction.lua).
local PICKUP_OFFSET = { 0, 0, 0.8 }
local NO_OFFSET = { 0, 0, 0 }
-- Heretical idols are not interactables and have no marker node; the marker floats above the base.
local IDOL_OFFSET = { 0, 0, 0.5 }

local function kind(group, icon, color, size, offset)
    return {
        group = group,
        icon = icon:find("/", 1, true) and icon or ICONS .. icon,
        color = color or DEFAULT_COLOR,
        -- A kind with its own colour also recolours vanilla's interaction marker for the item.
        recolor = color ~= nil,
        size = size or 1,
        offset = offset or PICKUP_OFFSET,
    }
end

-- `icon` is vanilla's icon for that item: the pickup's interaction_icon, else its interaction
-- template's icon. At runtime the interactee's own interaction_icon() wins, so a level override
-- (for example on a chest) also matches vanilla.
-- Every kind looks like vanilla's interaction marker for it at the hand-over distance (same icon,
-- frame and size), so the switch to vanilla's marker up close is invisible. Kinds with their own
-- colour give vanilla's marker that colour too; heretical idols, which vanilla never marks, have
-- their own look.
local kinds = {
    ammo_small = kind("ammo", "ammunition"),
    ammo_large = kind("ammo", "ammunition"),
    ammo_crate = kind("ammo", "pocketable_ammo"),
    grenade = kind("grenades", "grenade"),
    medical_crate = kind("medical", "pocketable_medkit"),
    stimm_medical = kind("stimms", "pocketable_syringe_corruption", MEDICAL_GREEN),
    stimm_power = kind("stimms", "pocketable_syringe_power", POWER_RED),
    stimm_speed = kind("stimms", "pocketable_syringe_speed", SPEED_BLUE),
    stimm_concentration = kind("stimms", "pocketable_syringe_ability", CONCENTRATION_YELLOW),
    health_station = kind("health_stations", "respawn", MEDICAL_GREEN, nil, NO_OFFSET),
    chest = kind("chests", "default", nil, nil, NO_OFFSET),
    plasteel_small = kind("plasteel", "environment_generic", MATERIAL_LIGHT_BLUE),
    plasteel_large = kind("plasteel", "environment_generic", MATERIAL_LIGHT_BLUE),
    diamantine_small = kind("diamantine", "environment_generic", MATERIAL_LIGHT_BLUE),
    diamantine_large = kind("diamantine", "environment_generic", MATERIAL_LIGHT_BLUE),
    -- Mission containers carried to a socket; vanilla's luggable template icon.
    luggable_container = kind("containers", "default"),
    -- Batteries for medicae stations (health_station_extension.lua, register_socket_unit) and some
    -- objectives; the same pickup types, so both are marked.
    power_cell = kind("power_cells", "default"),
    grimoire = kind("grimoires", "pocketable_default"),
    scripture = kind("scriptures", "pocketable_default"),
    -- Vanilla shows no marker on idols; this is the game's priority-target icon.
    heretical_idol = kind("heretical_idols", "enemy_priority", { 255, 220, 70, 150 }, nil, IDOL_OFFSET),
}

-- Health stations use vanilla's larger "point_of_interest" frame; everything else the standard one.
kinds.health_station.frame = "point_of_interest"

kinds.health_station.charges = true
kinds.chest.chest = true
kinds.luggable_container.luggable = true
kinds.power_cell.luggable = true
kinds.heretical_idol.idol = true

for name, data in pairs(kinds) do
    data.name = name
end

-- Unit data "pickup_type" (scripts/extension_systems/unit_templates/pickup_unit_template.lua).
local by_pickup = {
    small_clip = kinds.ammo_small,
    large_clip = kinds.ammo_large,
    ammo_cache_pocketable = kinds.ammo_crate,
    ammo_cache_deployable = kinds.ammo_crate,
    large_ammunition_crate = kinds.ammo_crate,
    small_grenade = kinds.grenade,
    medical_crate_pocketable = kinds.medical_crate,
    syringe_corruption_pocketable = kinds.stimm_medical,
    syringe_power_boost_pocketable = kinds.stimm_power,
    syringe_speed_boost_pocketable = kinds.stimm_speed,
    syringe_ability_boost_pocketable = kinds.stimm_concentration,
    small_metal = kinds.plasteel_small,
    large_metal = kinds.plasteel_large,
    small_platinum = kinds.diamantine_small,
    large_platinum = kinds.diamantine_large,
    container_01_luggable = kinds.luggable_container,
    container_02_luggable = kinds.luggable_container,
    container_03_luggable = kinds.luggable_container,
    battery_01_luggable = kinds.power_cell,
    battery_02_luggable = kinds.power_cell,
    grimoire = kinds.grimoire,
    tome = kinds.scripture,
}

-- Interaction types of units that are not pickups. "deployable_marker" is used only by the
-- deployed medical crate (scripts/extension_systems/unit_templates/medical_crate_deployable_unit_template.lua).
local by_interaction = {
    chest = kinds.chest,
    health_station = kinds.health_station,
    deployable_marker = kinds.medical_crate,
}

-- Group -> setting id of its on/off checkbox.
local group_settings = {
    ammo = "show_ammo",
    grenades = "show_grenades",
    medical = "show_medical",
    stimms = "show_stimms",
    health_stations = "show_health_stations",
    chests = "show_chests",
    plasteel = "show_plasteel",
    diamantine = "show_diamantine",
    containers = "show_containers",
    power_cells = "show_power_cells",
    grimoires = "show_grimoires",
    scriptures = "show_scriptures",
    heretical_idols = "show_heretical_idols",
}

local Categories = {
    kinds = kinds,
    by_pickup = by_pickup,
    by_interaction = by_interaction,
    group_settings = group_settings,
}

-- A pickup is classified only by its pickup type, anything else by its interaction type.
function Categories.classify(pickup_type, interaction_type)
    if pickup_type then
        return by_pickup[pickup_type]
    end

    return interaction_type and by_interaction[interaction_type] or nil
end

return Categories
