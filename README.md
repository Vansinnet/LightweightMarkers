# Lightweight Markers

A client-side [Darktide Mod Framework (DMF)](https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework) mod for Warhammer 40,000: Darktide. It shows markers on ammo, grenade refills, medical crates, stimms, health stations and chests, with the game's own icons. Plasteel, diamantine, power cells and containers, grimoires, scriptures and heretical idols can be turned on in the options.

It is built to cost as little as possible:

- No game function is replaced; the mod only adds its own marker type.
- Items are found when they spawn, not by scanning the level. (The optional chest prediction reads the level once at mission start.)
- Only items within the marker distance get a marker, so a handful are live at a time.
- Nothing is allocated or looked up in settings per frame, and hidden markers are not drawn.

## What is marked

| Item | Icon | Notes |
| --- | --- | --- |
| Small and large ammo | The game's ammo icon | |
| Ammo crates | The game's ammo crate icon | Carried and deployed crates, and expedition ammo crates |
| Grenade refills | The game's grenade icon | |
| Medical crates | The game's medical crate icon | Carried and deployed crates |
| Stimms | The game's stimm icons | |
| Health stations | The game's health station icon | Remaining charges; dimmed when empty |
| Chests | The game's chest icon | Removed once the chest is opened |
| Plasteel and diamantine (off by default) | The game's material icon | |
| Power cells and containers (off by default) | The game's pickup icon | Power cells for medicae stations (often hidden in the level) and objectives, and containers some missions ask you to carry to a drop-off point; hidden while carried, plugged in or delivered |
| Grimoires and scriptures (off by default) | The game's side-mission item icon | |
| Heretical idols (off by default) | The game's priority-target icon | Only the idols the mission actually uses; removed once destroyed |

Stimms are coloured by type (medical green, power red, speed blue, concentration yellow), health stations green like the medical stimm, and plasteel and diamantine light blue. Everything else uses the game's colour.

Within about 15 m the game shows its own marker for the same item. This mod's marker then fades out, so there is never a double icon, and tags and the interaction prompt look as usual. Markers use the game's frame and size at that distance, and the game's marker gets the same colour, so the hand-over is not visible and an item keeps its colour at every distance. Like the game's own markers, small and large amounts of the same item look alike.

Aim at a marker and tag it as usual, also beyond the game's 15 m and, with "See markers through walls" on, behind walls. Chests and heretical idols cannot be tagged, as in the base game.

## Chest contents (optional)

With "Predict chest contents" on, chest markers show the items the server put into that chest when the mission started, such as "Diamantine" or "Large ammo + Grenades", before anyone opens it.

- The game never sends chest contents to players. The mod works them out instead, a few seconds after you spawn in, by replaying the server's own distribution from information every player already has: the mission's seed, its pickup pools and the layout of the level.
- The result is shown only when the calculation is confirmed by the items lying around the level: it must explain every one of them it can check, and at least ten. Chests it cannot confirm show nothing; that is also the case when you join late and most items have been picked up.
- Only the pre-placed items are known. A chest's other slots are filled when it is opened, depending on what the team needs, so a chest can give more than shown. Plasteel and diamantine in chests are always pre-placed.
- Regular missions only, not horde or expedition modes. Works best when you are in the mission from the start.
- The calculation runs once per mission, spread over a few frames (about 2 ms of work per frame).

## Settings

| Setting | Default | Effect |
| --- | --- | --- |
| See markers through walls | Off | When off, a marker shows only while the item is in line of sight. |
| Marker distance (m) | 40 (10–200) | How far away markers are shown. |
| Marker size (%) | 100 (50–200) | Size of the markers. |
| Show distance | Off | Distance in metres below each marker. |
| Items | All on | Ammo, grenades, medical crates, stimms, health stations and chests can each be turned off. |
| Predict chest contents | Off | Shows the pre-placed items above the marker of each chest whose contents could be confirmed (see Chest contents). Needs Chests to be on. |
| Materials and collectibles | All off | Plasteel, diamantine, power cells and containers, grimoires, scriptures and heretical idols. A group that is off costs nothing: its items are not even tracked. |

## Compatibility

Markers Improved AIO marks the same items. Turn off its matching categories, or disable it, or both mods show a marker on the same item.

## Install

1. Install and enable Darktide Mod Framework and its required mod loader.
2. Place the `LightweightMarkers` folder in Darktide's `mods` folder, so the path is `mods/LightweightMarkers/LightweightMarkers.mod`.
3. Add `LightweightMarkers` as a line in `mods/mod_load_order.txt` and start the game.

## Testing status

Developed against Darktide 1.13.1. Static checks and offline tests pass, and all features have been tested in game. The chest prediction method was confirmed in game (every predicted item was found when the chests were opened); the option itself is new and not yet tested in game.

## License

Licensed under the [MIT License](LICENSE).
