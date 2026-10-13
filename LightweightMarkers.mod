return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`LightweightMarkers` encountered an error loading the Darktide Mod Framework.")
        new_mod("LightweightMarkers", {
            mod_script = "LightweightMarkers/scripts/mods/LightweightMarkers/LightweightMarkers",
            mod_data = "LightweightMarkers/scripts/mods/LightweightMarkers/LightweightMarkers_data",
            mod_localization = "LightweightMarkers/scripts/mods/LightweightMarkers/LightweightMarkers_localization",
        })
    end,
    packages = {},
}
