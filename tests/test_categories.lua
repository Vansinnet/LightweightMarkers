-- Offline check of the classification table against the game's own pickup and interaction
-- settings, and of the options against the localization. Run from the workspace root:
--   tools/luajit/luajit mods/active/LightweightMarkers/tests/test_categories.lua

local MOD_DIR = "mods/active/LightweightMarkers/scripts/mods/LightweightMarkers/"

package.path = "darktide-source/?.lua;" .. package.path

-- Engine natives and globals the settings files touch at load time.
settings = function(_, t)
    return t
end
Vector3Box = function(...)
    return { ... }
end
Vector3 = Vector3Box
QuaternionBox = Vector3Box
package.preload["scripts/settings/projectile/projectile_templates"] = function()
    return setmetatable({}, {
        __index = function()
            return {}
        end,
    })
end

local Pickups = require("scripts/settings/pickup/pickups")
local InteractionTemplates = require("scripts/settings/interaction/interaction_templates")
local Categories = dofile(MOD_DIR .. "categories.lua")

local failures = 0

local function fail(fmt, ...)
    failures = failures + 1
    print("FAIL: " .. string.format(fmt, ...))
end

-- Pickups deliberately without a marker. A pickup missing from both this list and the mod's table
-- fails, so a game update that adds pickups forces a decision.
local IGNORED = {
    -- Mission, side-mission and event items.
    "communications_hack_device", "consumable", "hordes_mcguffin",
    "paper_pickup", "paper_pickup_02", "paper_pickup_03", "paper_pickup_04",
    "skulls_01_pickup", "stolen_rations_01_pickup_small", "stolen_rations_01_pickup_medium",
    "live_event_leftover_01_pickup_small", "live_event_leftover_01_pickup_medium",
    "live_event_leftover_01_pickup_large", "live_event_saints_01_pickup_small",
    "live_event_saints_01_pickup_medium", "live_event_saints_01_pickup_large",
    -- Luggables other than power cells and mission containers, which are marked.
    "control_rod_01_luggable", "prismata_case_01_luggable",
    "expedition_explosive_luggable_01",
    -- Expedition-only items (the large ammo crate is marked).
    "expedition_currency_small_tier_1", "expedition_currency_small_tier_2",
    "expedition_loot_small_tier_1", "expedition_loot_small_tier_2", "expedition_loot_small_tier_3",
    "expedition_loot_heavy_tier_1", "expedition_loot_heavy_tier_2", "expedition_loot_heavy_tier_3",
    "expedition_loot_player_drop", "expedition_time_syringe_timed",
    "expedition_deployable_force_field_pocketable", "expedition_grenade_airstrike_pocketable",
    "expedition_grenade_artillery_strike_pocketable", "expedition_grenade_big_pocketable",
    "expedition_grenade_valkyrie_hover_pocketable", "motion_detection_mine_explosive_pocketable",
    "motion_detection_mine_fire_pocketable", "motion_detection_mine_shock_pocketable",
    -- Other.
    "breach_charge_pocketable",
    -- Unused pickup: deployed medical crates are the "medical_crate_deployable" unit template
    -- (settings/deployables/templates/medical_crate.lua), marked through "deployable_marker".
    "medical_crate_deployable",
}

local ignored = {}

for i = 1, #IGNORED do
    ignored[IGNORED[i]] = true
end

-- The icon vanilla shows for a pickup: its interaction_icon, else its interaction template's
-- (scripts/extension_systems/interaction/interactee_extension.lua, interaction_icon).
local function vanilla_pickup_icon(pickup)
    local template = InteractionTemplates[pickup.interaction_type]

    return pickup.interaction_icon or template and template.interaction_icon
end

local num_pickups, num_marked = 0, 0

for name, pickup in pairs(Pickups.by_name) do
    num_pickups = num_pickups + 1

    local kind = Categories.by_pickup[name]

    if kind then
        num_marked = num_marked + 1

        if ignored[name] then
            fail("%s is both marked and ignored", name)
        end

        if kind.icon ~= vanilla_pickup_icon(pickup) then
            fail("%s: icon %s, vanilla shows %s", name, kind.icon, tostring(vanilla_pickup_icon(pickup)))
        end

        if Categories.classify(name, pickup.interaction_type) ~= kind then
            fail("%s: classify does not return its kind", name)
        end
    elseif not ignored[name] then
        fail("pickup %s is neither marked nor ignored", name)
    end
end

for name in pairs(Categories.by_pickup) do
    if not Pickups.by_name[name] then
        fail("marked pickup %s does not exist in the game", name)
    end
end

for name in pairs(ignored) do
    if not Pickups.by_name[name] then
        fail("ignored pickup %s does not exist in the game", name)
    end
end

for interaction_type, kind in pairs(Categories.by_interaction) do
    local template = InteractionTemplates[interaction_type]

    if not template then
        fail("interaction type %s does not exist in the game", interaction_type)
    elseif kind.icon ~= template.interaction_icon then
        fail("%s: icon %s, vanilla template shows %s", interaction_type, kind.icon, template.interaction_icon)
    end

    if Categories.classify(nil, interaction_type) ~= kind then
        fail("classify(nil, %s) does not return its kind", interaction_type)
    end
end

-- A pickup is never classified by its interaction type: a crafting material is a pickup whose
-- interaction type is not ours, and a pickup type wins over a matching interaction type.
if Categories.classify("hordes_mcguffin", "chest") ~= nil then
    fail("an unmarked pickup was classified by its interaction type")
end

if Categories.classify(nil, "ammunition") ~= nil or Categories.classify(nil, nil) ~= nil then
    fail("an unknown interaction type was classified")
end

-- Every kind belongs to a group with a setting; every group has a kind.
local groups_used = {}

for name, kind in pairs(Categories.kinds) do
    if kind.name ~= name then
        fail("kind %s has name %s", name, tostring(kind.name))
    end

    if not Categories.group_settings[kind.group] then
        fail("kind %s has group %s without a setting", name, tostring(kind.group))
    end

    groups_used[kind.group] = true

    if #kind.color ~= 4 or #kind.offset ~= 3 or type(kind.size) ~= "number" then
        fail("kind %s has a malformed color, offset or size", name)
    end
end

for group in pairs(Categories.group_settings) do
    if not groups_used[group] then
        fail("group %s has no kind", group)
    end
end

-- Options and localization: every widget has a title and tooltip, every group setting is a
-- widget, and localized strings survive string.format as DMF's mod:localize applies it.
local localization = dofile(MOD_DIR .. "LightweightMarkers_localization.lua")

get_mod = function()
    return {
        localize = function(_, id)
            return id
        end,
    }
end

local data = dofile(MOD_DIR .. "LightweightMarkers_data.lua")
local widget_ids = {}

local function check_widgets(widgets)
    for i = 1, #widgets do
        local widget = widgets[i]
        local id = widget.setting_id

        widget_ids[id] = widget

        if not localization[id] then
            fail("widget %s has no title", id)
        end

        if widget.tooltip and not localization[widget.tooltip] then
            fail("widget %s has no tooltip text %s", id, widget.tooltip)
        end

        if widget.sub_widgets then
            check_widgets(widget.sub_widgets)
        end
    end
end

check_widgets(data.options.widgets)

for group, setting_id in pairs(Categories.group_settings) do
    local widget = widget_ids[setting_id]

    if not widget or widget.type ~= "checkbox" then
        fail("group %s: setting %s is not a checkbox widget", group, setting_id)
    end
end

for id, text in pairs(localization) do
    local ok = pcall(string.format, text.en)

    if not ok then
        fail("localization %s does not survive string.format", id)
    end
end

print(string.format("%d pickups in the game, %d marked, %d ignored, %d interaction types: %d failures",
    num_pickups, num_marked, #IGNORED, (function()
        local n = 0

        for _ in pairs(Categories.by_interaction) do
            n = n + 1
        end

        return n
    end)(), failures))

os.exit(failures == 0 and 0 or 1)
