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
local PLASTEEL_LIGHT_ORANGE = { 255, 255, 190, 120 }
local CHARGES_ORANGE = { 255, 255, 150, 30 }

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
-- colour give vanilla's marker that colour too, and large ammo gives it its own icon; heretical
-- idols, which vanilla never marks, have their own look.
local kinds = {
    ammo_small = kind("ammo", "ammunition"),
    ammo_large = kind("ammo", "ammunition"),
    ammo_crate = kind("ammo", "pocketable_ammo"),
    ammo_crate_deployed = kind("ammo", "pocketable_ammo"),
    grenade = kind("grenades", "grenade"),
    medical_crate = kind("medical", "pocketable_medkit"),
    stimm_medical = kind("stimms", "pocketable_syringe_corruption", MEDICAL_GREEN),
    stimm_power = kind("stimms", "pocketable_syringe_power", POWER_RED),
    stimm_speed = kind("stimms", "pocketable_syringe_speed", SPEED_BLUE),
    stimm_concentration = kind("stimms", "pocketable_syringe_ability", CONCENTRATION_YELLOW),
    health_station = kind("health_stations", "respawn", MEDICAL_GREEN, nil, NO_OFFSET),
    chest = kind("chests", "default", nil, nil, NO_OFFSET),
    plasteel_small = kind("plasteel", "environment_generic", PLASTEEL_LIGHT_ORANGE),
    plasteel_large = kind("plasteel", "environment_generic", PLASTEEL_LIGHT_ORANGE),
    diamantine_small = kind("diamantine", "environment_generic", MATERIAL_LIGHT_BLUE),
    diamantine_large = kind("diamantine", "environment_generic", MATERIAL_LIGHT_BLUE),
    -- Two-handed items carried to a socket: power cells for medicae stations
    -- (health_station_extension.lua, register_socket_unit) and objectives, and mission containers.
    -- Vanilla's luggable template icon.
    carry_item = kind("carry_items", "default"),
    grimoire = kind("grimoires", "pocketable_default"),
    scripture = kind("scriptures", "pocketable_default"),
    -- Vanilla shows no marker on idols; this is Markers Improved AIO's default idol look: the game's
    -- enemy icon, its colour and frame (heretical_idol_markers_template.lua, markers_aio_data.lua).
    heretical_idol = kind("heretical_idols", "enemy", { 255, 132, 156, 99 }, nil, IDOL_OFFSET),
}

-- Health stations use vanilla's larger "point_of_interest" frame; everything else the standard one.
kinds.health_station.frame = "point_of_interest"
kinds.heretical_idol.frame = "idol"

-- Remaining charges as a number: a health station's synced charge amount, a deployed ammo crate's
-- pickup charges (4 when deployed). The crate is tagged when deployed, which keeps vanilla's marker
-- on it, so its count stays while vanilla's marker shows it.
kinds.health_station.charges = "health_station"
kinds.ammo_crate_deployed.charges = "pickup"
kinds.ammo_crate_deployed.keep_count = true
-- An icon that replaces vanilla's, on our marker and on vanilla's, once its package is loaded
-- (LightweightMarkers.lua, ICON_PACKAGE): the loadout-preset ammo icon, as in Markers Improved AIO.
kinds.ammo_large.own_icon = "content/ui/materials/icons/presets/preset_16"
kinds.chest.chest = true
kinds.carry_item.luggable = true
kinds.heretical_idol.idol = true

for name, data in pairs(kinds) do
    data.name = name
end

-- Unit data "pickup_type" (scripts/extension_systems/unit_templates/pickup_unit_template.lua).
local by_pickup = {
    small_clip = kinds.ammo_small,
    large_clip = kinds.ammo_large,
    ammo_cache_pocketable = kinds.ammo_crate,
    ammo_cache_deployable = kinds.ammo_crate_deployed,
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
    battery_01_luggable = kinds.carry_item,
    battery_02_luggable = kinds.carry_item,
    container_01_luggable = kinds.carry_item,
    container_02_luggable = kinds.carry_item,
    container_03_luggable = kinds.carry_item,
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
    carry_items = "show_carry_items",
    grimoires = "show_grimoires",
    scriptures = "show_scriptures",
    heretical_idols = "show_heretical_idols",
}

-- Text colour of a charge count: 4 green, 3 yellow, 2 orange, 1 and 0 red.
local charge_colors = {
    [0] = POWER_RED,
    POWER_RED,
    CHARGES_ORANGE,
    CONCENTRATION_YELLOW,
    MEDICAL_GREEN,
}

-- Inventory item -> stimm colour, for the stimm icons in the HUD. Pickups' inventory_item
-- (scripts/settings/pickup/pickups/pocketable/syringe_*_pocketable_pickup.lua).
local stimm_colors = {
    ["content/items/pocketable/syringe_corruption_pocketable"] = MEDICAL_GREEN,
    ["content/items/pocketable/syringe_power_boost_pocketable"] = POWER_RED,
    ["content/items/pocketable/syringe_speed_boost_pocketable"] = SPEED_BLUE,
    ["content/items/pocketable/syringe_ability_boost_pocketable"] = CONCENTRATION_YELLOW,
}

local Categories = {
    kinds = kinds,
    charge_colors = charge_colors,
    stimm_colors = stimm_colors,
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
