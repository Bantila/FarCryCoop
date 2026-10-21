# FarCryCoop 0.2 beta — campaign co-op for Far Cry (2004)

Play the Far Cry campaign together: one player hosts, friends join. Beta: expect bugs.

## Requirements
- Far Cry 1.4 (the Steam / GOG version is 1.4). Everyone needs the same mod version.
- Windows 10 or 11.

## Install (every player)
1. Copy the `Mods` and `Bin32` folders from this archive into the Far Cry folder (for Steam: `steamapps\common\FarCry`). Allow merging.
2. `Bin32\dinput8.dll` is the Ultimate ASI Loader; it loads `FarCryCoopNet.asi`. If your `Bin32` already has an ASI loader (`version.dll` or `dinput8.dll` from a widescreen fix), do not copy `dinput8.dll`.
3. Start the game with `Bin32\FarCryCoop.bat` (it runs `FarCry.exe -DEVMODE -MOD:FarCryCoop`).

## Host
1. Start the game with `FarCryCoop.bat`.
2. Open the console with `~` and type, for example: `#CoopMap("pier")`
   Maps: training, fort, pier, carrier, factory, research, treehouse, bunker, rebellion, steam, archive, control, swamp, catacombs, river, boat, dam, cooler, regulator, volcano.
3. Friends on the internet need your IP and UDP port 49001 open (port forwarding, or a virtual LAN such as Radmin VPN or ZeroTier).

## Join
1. Start the game with `FarCryCoop.bat`.
2. Multiplayer, LAN: the host's game shows up. Or open the console (`~`) and type `connect <host IP>`.

## Useful console commands (host)
- `#CoopGod(1)` / `#CoopGod(0)` — god mode for everyone on/off
- `#CoopAmmo()` — full ammo, `#CoopWeapons()` — all weapons
- `#CoopGoto()` — list checkpoints, `#CoopGoto(3)` — move everyone to checkpoint 3
- `#CoopMap(COOP_Map)` — restart the map, friends stay connected

## Known limitations
- Cutscenes are off for joined players.
- Helicopters fly only for the host; joined players see them hanging in place.
- Barrels and crates: a joined player cannot push them.
- In-game chat and console type Latin letters only (the game works with any keyboard layout).
- The short console commands (`coop_map pier` and the like) do not work in the game client yet: use the `#...` forms above.
- Enemies may move in small jerks for joined players.

Source and bug reports: https://github.com/Bantila/FarCryCoop
Ultimate ASI Loader: https://github.com/ThirteenAG/Ultimate-ASI-Loader (MIT, see `Bin32\UltimateASILoader-LICENSE.txt`).
