-- Which interactables get a marker and how each kind looks. Pure data with no engine calls, so
-- tests/test_categories.lua can load it next to the game's own pickup and interaction settings.

local ICONS = "content/ui/materials/hud/interactions/icons/"

-- Vanilla interaction icon colour (Color.ui_hud_green_super_light, scripts/foundation/utilities/color.lua).
local DEFAULT_COLOR = { 255, 216, 237, 190 }

-- Pickups float 0.8 m above their marker node like vanilla "pickup" interaction markers; chests and
-- health stations sit on it ("default" and "point_of_interest" visuals in
-- scripts/ui/hud/elements/world_markers/templates/world_marker_template_interaction.lua).
local PICKUP_OFFSET = { 0, 0, 0.8 }
local NO_OFFSET = { 0, 0, 0 }

local function kind(group, icon, color, size, offset)
    return {
        group = group,
        icon = ICONS .. icon,
        color = color or DEFAULT_COLOR,
        size = size or 1,
        offset = offset or PICKUP_OFFSET,
    }
end

-- `icon` is vanilla's icon for that item: the pickup's interaction_icon, else its interaction
-- template's icon. At runtime the interactee's own interaction_icon() wins, so a level override
-- (for example on a chest) also matches vanilla.
local kinds = {
    -- Small and large ammo share vanilla's icon; the large one is bigger and white.
    ammo_small = kind("ammo", "ammunition"),
    ammo_large = kind("ammo", "ammunition", { 255, 255, 255, 255 }, 1.25),
    ammo_crate = kind("ammo", "pocketable_ammo"),
    grenade = kind("grenades", "grenade"),
    medical_crate = kind("medical", "pocketable_medkit"),
    -- Stimm colours follow the syringe case lights (scripts/components/syringe_case_color.lua).
    stimm_medical = kind("stimms", "pocketable_syringe_corruption", { 255, 80, 230, 70 }),
    stimm_power = kind("stimms", "pocketable_syringe_power", { 255, 240, 80, 55 }),
    stimm_speed = kind("stimms", "pocketable_syringe_speed", { 255, 60, 165, 255 }),
    stimm_concentration = kind("stimms", "pocketable_syringe_ability", { 255, 255, 215, 40 }),
    health_station = kind("health_stations", "respawn", nil, nil, NO_OFFSET),
    chest = kind("chests", "default", { 255, 226, 199, 126 }, nil, NO_OFFSET),
}

kinds.health_station.charges = true
kinds.chest.chest = true

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
