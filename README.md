# Lightweight Markers

A client-side [Darktide Mod Framework (DMF)](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework) mod for Warhammer 40,000: Darktide. It shows markers on ammo, grenade refills, medical crates, stimms, health stations and chests, with the game's own icons. Plasteel, diamantine, power cells, rods and containers, grimoires, scriptures and heretical idols can be turned on in the options.

It is built to cost as little as possible:

- No game function is replaced; the mod only adds its own marker type.
- Items are found when they spawn, not by scanning the level.
- Only items within the marker distance get a marker, so a handful are live at a time.
- Nothing is allocated or looked up in settings per frame, and hidden markers are not drawn.

## What is marked

| Item | Icon | Notes |
| --- | --- | --- |
| Small and large ammo | The game's ammo icon; large ammo the game's three-cartridge preset icon | |
| Ammo crates | The game's ammo crate icon | Carried and deployed crates, and expedition ammo crates; deployed crates show their remaining charges |
| Grenade refills | The game's grenade icon | |
| Medical crates | The game's medical crate icon | Carried and deployed crates; deployed crates show an estimate of the healing left in percent |
| Stimms | The game's stimm icons | |
| Health stations | The game's health station icon | Remaining charges; dimmed when empty |
| Chests | The game's chest icon | Removed once the chest is opened |
| Plasteel and diamantine (off by default) | The game's material icon | |
| Power cells, rods and containers (off by default) | The game's pickup icon | Power cells for medicae stations (often hidden in the level) and objectives, cryonic rods and prismata crystal cases, and containers some missions ask you to carry to a drop-off point (such as vacuum capsules and ammunition crates); hidden while carried, plugged in or delivered |
| Grimoires and scriptures (off by default) | The game's side-mission item icon | |
| Heretical idols (off by default) | The game's enemy icon in a point-of-interest frame, as in Markers Improved AIO | Only the idols the mission actually uses; removed once destroyed |

Stimms are coloured by type (medical green, power red, speed blue, concentration yellow), health stations green like the medical stimm, plasteel light orange, diamantine light blue, and grimoires and scriptures purple. Charge counts are green at 4, yellow at 3, orange at 2 and red at 1 (for medical crates: above 75, 50, 25 and 0 %), and stay visible above the marker at every distance, also when the game's own marker takes over up close. A deployed medical crate's percentage is an estimate: the game does not send the exact amount to players, so the mod replays the game's healing formula for the players within the crate's radius, also while damage such as grimoire corruption keeps their health from rising. It misses healing spent before you saw the crate. Stimm icons in the HUD, in your own slots and on teammates' panels, take the same stimm colours. Everything else uses the game's colour.

Within about 15 m the game shows its own marker for the same item. This mod's marker then fades out, so there is never a double icon, and tags and the interaction prompt look as usual. Markers use the game's frame and size at that distance, and the game's marker gets the same colour, so the hand-over is not visible and an item keeps its colour at every distance. Large ammo has its own icon, on the game's marker too; otherwise, like the game's own markers, small and large amounts of the same item look alike.

Aim at a marker and tag it as usual, also beyond the game's 15 m and, with "See markers through walls" on, behind walls. Chests and heretical idols cannot be tagged, as in the base game.


## Settings

| Setting | Default | Effect |
| --- | --- | --- |
| See markers through walls | Off | When off, a marker shows only while the item is in line of sight. |
| Marker distance (m) | 40 (10–200) | How far away markers are shown. |
| Marker size (%) | 100 (50–200) | Size of the markers. |
| Show distance | Off | Distance in metres below each marker. |
| Items | All on | Ammo, grenades, medical crates, stimms, health stations and chests can each be turned off. |
| Materials and collectibles | All off | Plasteel, diamantine, power cells, rods and containers, grimoires, scriptures and heretical idols. A group that is off costs nothing: its items are not even tracked. |

## Compatibility

Markers Improved AIO marks the same items. Turn off its matching categories, or disable it, or both mods show a marker on the same item.

## Install

1. Install and enable Darktide Mod Framework and its required mod loader.
2. Place the `LightweightMarkers` folder in Darktide's `mods` folder, so the path is `mods/LightweightMarkers/LightweightMarkers.mod`.
3. Add `LightweightMarkers` as a line in `mods/mod_load_order.txt` and start the game.

## Testing status

Developed against Darktide 1.13.1. Static checks and offline tests pass, and all features have been tested in game.

## License

Licensed under the [MIT License](LICENSE).
