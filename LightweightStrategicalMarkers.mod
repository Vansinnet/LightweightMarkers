return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`LightweightStrategicalMarkers` encountered an error loading the Darktide Mod Framework.")
        new_mod("LightweightStrategicalMarkers", {
            mod_script = "LightweightStrategicalMarkers/scripts/mods/LightweightStrategicalMarkers/LightweightStrategicalMarkers",
            mod_data = "LightweightStrategicalMarkers/scripts/mods/LightweightStrategicalMarkers/LightweightStrategicalMarkers_data",
            mod_localization = "LightweightStrategicalMarkers/scripts/mods/LightweightStrategicalMarkers/LightweightStrategicalMarkers_localization",
        })
    end,
    packages = {},
}
