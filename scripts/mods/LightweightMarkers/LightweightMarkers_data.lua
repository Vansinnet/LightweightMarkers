local mod = get_mod("LightweightMarkers")

local function checkbox(id, default_value)
    return {
        setting_id = id,
        type = "checkbox",
        tooltip = id .. "_tooltip",
        default_value = default_value,
    }
end

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            checkbox("see_through_walls", false),
            {
                setting_id = "max_distance",
                type = "numeric",
                tooltip = "max_distance_tooltip",
                default_value = 40,
                range = { 10, 200 },
            },
            {
                setting_id = "marker_scale",
                type = "numeric",
                tooltip = "marker_scale_tooltip",
                default_value = 100,
                range = { 50, 200 },
            },
            checkbox("show_distance", false),
            {
                setting_id = "categories",
                type = "group",
                title = "categories",
                sub_widgets = {
                    checkbox("show_ammo", true),
                    checkbox("show_grenades", true),
                    checkbox("show_medical", true),
                    checkbox("show_stimms", true),
                    checkbox("show_health_stations", true),
                    checkbox("show_chests", true),
                },
            },
            {
                setting_id = "collectibles",
                type = "group",
                title = "collectibles",
                sub_widgets = {
                    checkbox("show_plasteel", false),
                    checkbox("show_diamantine", false),
                    checkbox("show_grimoires", false),
                    checkbox("show_scriptures", false),
                    checkbox("show_heretical_idols", false),
                },
            },
        },
    },
}
