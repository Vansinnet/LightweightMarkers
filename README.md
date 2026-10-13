# Lightweight Strategical Markers

A client-side [Darktide Mod Framework (DMF)](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework) mod for Warhammer 40,000: Darktide. It shows markers on ammo, grenade refills, medical crates, stimms, health stations and chests, with the game's own icons. Plasteel, diamantine, grimoires, scriptures and heretical idols can be turned on in the options.

It is built to cost as little as possible:

- No game function is replaced; the mod only adds its own marker type.
- Items are found when they spawn, not by scanning the level.
- Only items within the marker distance get a marker, so a handful are live at a time.
- Nothing is allocated or looked up in settings per frame, and hidden markers are not drawn.

## What is marked

| Item | Icon | Notes |
| --- | --- | --- |
| Small ammo | The game's ammo icon | |
| Large ammo | The game's ammo icon | Larger and white |
| Ammo crates | The game's ammo crate icon | Carried and deployed crates, and expedition ammo crates |
| Grenade refills | The game's grenade icon | |
| Medical crates | The game's medical crate icon | Carried and deployed crates |
| Stimms | The game's stimm icons | Tinted like the stimm cases: green medical, red power, blue speed, yellow concentration |
| Health stations | The game's health station icon | Remaining charges; dimmed when empty |
| Chests | The game's chest icon | Gold; removed once the chest is opened |
| Plasteel (off by default) | The game's material icon | Steel grey; large amounts bigger |
| Diamantine (off by default) | The game's material icon | Blue; large amounts bigger |
| Grimoires (off by default) | The game's side-mission item icon | Purple |
| Scriptures (off by default) | The game's side-mission item icon | Gold |
| Heretical idols (off by default) | The game's priority-target icon | Only the idols the mission actually uses; removed once destroyed |

Within about 15 m the game shows its own marker for the same item. This mod's marker then fades out, so there is never a double icon, and tags and the interaction prompt look as usual.

## Settings

| Setting | Default | Effect |
| --- | --- | --- |
| See markers through walls | Off | When off, a marker shows only while the item is in line of sight. |
| Marker distance (m) | 40 (10–200) | How far away markers are shown. |
| Marker size (%) | 100 (50–200) | Size of the markers. |
| Show distance | On | Distance in metres below each marker. |
| Items | All on | Ammo, grenades, medical crates, stimms, health stations and chests can each be turned off. |
| Materials and collectibles | All off | Plasteel, diamantine, grimoires, scriptures and heretical idols. A group that is off costs nothing: its items are not even tracked. |

## Compatibility

Markers Improved AIO marks the same items. Turn off its matching categories, or disable it, or both mods show a marker on the same item.

## Install

1. Install and enable Darktide Mod Framework and its required mod loader.
2. Place the `LightweightStrategicalMarkers` folder in Darktide's `mods` folder, so the path is `mods/LightweightStrategicalMarkers/LightweightStrategicalMarkers.mod`.
3. Add `LightweightStrategicalMarkers` as a line in `mods/mod_load_order.txt` and start the game.

## Testing status

Developed against Darktide 1.13.1. Static checks and offline tests pass. The base markers work in game; the material and collectible options are not yet tested in game.

## License

Licensed under the [MIT License](LICENSE).
