# FarCryCoop — campaign co-op for Far Cry (2004)

Русская версия: [README.ru.md](README.ru.md)

Play the original Far Cry campaign together: one player hosts a campaign map, friends join it and play the missions side by side. It is a mod: a script pack in `Mods\FarCryCoop`, a small ASI plugin that fixes the engine's networking for campaign maps, and a launcher with a lobby. No game files are replaced.

**Status: 0.2 beta, in active development** (started 2026-10-18). Tested with 2 players on Far Cry 1.4 (Steam). Target: up to 4 players. Expect bugs.

## Contents

- [What works](#what-works)
- [Quick start](#quick-start)
- [Launcher and lobby](#launcher-and-lobby)
- [Host console commands](#host-console-commands)
- [How it works](#how-it-works)
- [Known limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Building from source](#building-from-source)
- [Repository layout](#repository-layout)
- [Prior art and credits](#prior-art-and-credits)
- [Other games of the series](#other-games-of-the-series)

## What works

Far Cry has no official co-op. The campaign already runs as a local server plus a local client, and the mod builds on that: the host runs a campaign map as a network server with the single-player rules, and other players join as remote clients.

| Area | State | Notes |
|---|---|---|
| Campaign map as a server | works | in the game client (host plays, "listen server") or on `FarCry_WinSV.exe` (dedicated) |
| Remote players: movement, weapons, firing | works | the engine lost ~40% of every snapshot on campaign maps; the ASI fixes it |
| Hits on enemies by remote players | works | client-side hits (`CHIT`), applied by the server |
| Enemy AI, melee | works | sleeping AI wake near players; melee works on a dedicated server |
| Area triggers for remote players | works | missions that advance on "reach this place" |
| Map change and restart | works | friends stay connected |
| Mission objectives and messages | works | forwarded from the server to every player |
| Leaving vehicles and the paraglider | works | the server tells the client to let go |
| Barrels and crates moved on the server | works | moved by explosions; no player can push them, the host included |
| Russian keyboard layout | works | the game used to lose its key bindings with it |
| Checkpoints and respawn | partly | the respawn point follows checkpoints; hopping to the checkpoints of 9 levels worked for both players; a client respawning at a checkpoint after death not seen |
| Shirt color | works | 10 colors from the launcher; other players use the multiplayer Jack model, which has the color mask |
| Loadout | in testing | 4 of 11 weapons, chosen in the launcher; the host turns it on |
| Lobby | in testing | player list with colors and loadouts; "Start" not yet tried with two games |
| Join through Steam friends | in testing | the bridge runs as Spacewar (AppID 480): its start, Steam login, the "connect" presence and a joining game through the tunnel are checked on one PC; a real friend's Join is not |
| Cutscenes | partly | the host sees them; joined players do not |
| Paraglider | works | a copy appears for each next player; to others a climbing glider looks as if it falls |
| Buggies and boats (2 seats) | works (tested with 2 games) | a copy appears on the start spot when the players do not fit |
| Helicopters | partly | a helicopter that moves on the host is followed by the client; one that has not moved hovers at another height on the client; a real mission flight not seen |
| Saves | host only | autosave at checkpoints, `coop_save` / `coop_load` (F6 / F7 not tested), start from a save in the launcher; players, weapons and dead enemies, not mission progress |
| Difficulty | works | launcher or `#CoopDifficulty(n)`; the five levels of the single-player menu |
| Levels | 20 of 20 load | Treehouse and Swamp needed a workaround (baked physics states are skipped, [#1](https://github.com/Bantila/FarCryCoop/issues/1)); a level change sometimes crashes the host (3 of 11 runs on Bunker → Steam, 4 of 25 on Cooler → Boat, [#2](https://github.com/Bantila/FarCryCoop/issues/2)) |

The full research log with every fix, address and test is in [games/far-cry/NOTES.md](games/far-cry/NOTES.md).

## Quick start

Requirements: Far Cry 1.4 (the Steam and GOG versions are 1.4), Windows 10 or 11. Everyone needs the same mod version.

1. Get the player archive `FarCryCoop-<version>.zip` from the project owner, or build it (see [Building from source](#building-from-source)).
2. Copy `Mods`, `Bin32` and `FarCryCoopLauncher.exe` into the Far Cry folder (Steam: `steamapps\common\FarCry`). Allow merging. If your `Bin32` already has an ASI loader (`version.dll` from a widescreen fix), do not copy `dinput8.dll`.
3. Start `FarCryCoopLauncher.exe`.
4. Host: choose a map, press "Host lobby". Friends: enter the host's IP, press "Join lobby". The host presses "Start".

Three ways to invite friends: Steam friends list through the Spacewar bridge (no IP or ports), a virtual LAN (Radmin VPN, Hamachi, ZeroTier), or port forwarding of UDP 49001 (game) and TCP 49002 (lobby). Step by step, plus a beta test checklist: [games/far-cry/release/INSTALL.md](games/far-cry/release/INSTALL.md).

Without the launcher: start `Bin32\FarCryCoop.bat`. The host types `#CoopMap("pier")` in the console (`~`), and friends type `connect <host IP>`.

## Launcher and lobby

`FarCryCoopLauncher.exe` (Rust + Tauri, one window in the style of the game menu):

- **Player:** name, shirt color (10 colors of the multiplayer palette), 4 of 11 weapons for the loadout (Machete, Falcon, MP5, P90, M4, AG36, OICW, Shotgun, SniperRifle, M249, RL).
- **Lobby:** the host creates it, friends join by IP. Everyone sees the player list with shirt colors and loadouts, and the host's map and loadout mode.
- **Start:** the game starts for everyone; the host's game loads the map, and friends connect once the host's server is up.
- **Steam invite:** starts the game and waits for the host's invite from the Steam friends list.
- **Test on one PC:** host game on the left, and once its server is up, a client game on the right that joins by itself.
- **Loadout on:** every spawn gives your 4 weapons with full ammo. Weapons taken from enemies carry over to the next level, with the ammo refilled.

The launcher talks to the game only through two files: `Mods\FarCryCoop\prefs.lua` (color, weapons, loadout mode) and `Mods\FarCryCoop\join_<pid>.txt` (one console line, run by the ASI in the game with that process id; the Steam bridge uses the shared `join.txt`). Details: [games/far-cry/launcher/README.md](games/far-cry/launcher/README.md).

## Host console commands

Type them in the console (`~`) as `#Function()`; the short form (`coop_god 1`) works only on the dedicated server for now.

| Command | What it does |
|---|---|
| `#CoopMap("pier")` | host a campaign map; again later: change the map, friends stay |
| `#CoopMap(COOP_Map)` | restart the current map |
| `#CoopGod(1)` / `#CoopGod(0)` | god mode for everyone |
| `#CoopAmmo()` / `#CoopWeapons()` | full ammo / every weapon for everyone |
| `#CoopGoto()` / `#CoopGoto(3)` | list checkpoints / move everyone to checkpoint 3 |
| `#CoopGather()` | move everyone to the host |
| `#CoopNoclip(1)` | fly mode for everyone |
| `#CoopBot()` | spawn a teammate bot that follows the nearest player |
| `#CoopSave("name")` / `#CoopLoad("name")` | save / load a co-op game (`quick` and `auto` are the default names) |
| `#CoopDifficulty(2)` | difficulty 0-4 (easy, medium, challenging, veteran, realistic) |
| `#CoopMonitorSet(1)` | log the state of players, AI and vehicles once a second (debugging) |

## How it works

```
 FarCryCoopLauncher.exe ──TCP 49002── other launchers (lobby)
        │ prefs.lua, join_<pid>.txt
        ▼
 FarCry.exe -DEVMODE -MOD:FarCryCoop
  ├─ Mods\FarCryCoop\FarCryCoop.pak   Lua: game type COOP = single-player rules + co-op fixes
  └─ Bin32\FarCryCoopNet.asi          C: hooks in CryGame.dll 1.4 by address
        │ UDP 49001 (the game's own network code)
        ▼
 friends' FarCry.exe
```

- **Game type `COOP`** (Lua, `Scripts/COOP/`): the single-player rules, plus the parts a network game is missing there. AI wake-up near any player, AI melee without animation events, checkpoints for every player, mission objectives and movie sequences forwarded to clients, client-side hits, vehicle exit relay, shirt color and loadout.
- **ASI plugin** (`asi/FarCryCoopNet.c`, built without the CRT or Windows SDK). It hooks the original `CryGame.dll` 1.4 by address, with addresses found with REA/Ghidra and checked against the official MOD SDK 1.4 source:
  - **Snapshots:** each snapshot goes out by priority and stays within the 8992-bit stream limit, so campaign maps (~650 net entities) reach the client.
  - **Area triggers** for remote players.
  - **Dedicated server:** cutscene and sound callbacks no longer crash it, and 1 ms timer resolution gives 35 snapshots a second.
  - **Props** that move on the server are sent to clients.
  - **Keyboard:** US layout for the game's key table.
  - **Console:** one console line from `join_<pid>.txt` (launcher) or `join.txt` (Steam bridge) runs on the main thread.
- **Steam bridge** (`steam/FarCryCoopSteam.c`): runs as Spacewar, shows "Join" in the Steam friends list and relays the connection through `127.0.0.1:49011`.
- **Launcher** (`launcher/`): Rust + Tauri 2, one HTML page, lobby over TCP.

The game's own binaries are not changed. A `CryGame.dll` rebuilt from the SDK was tried and rejected: it needs VC 7.1 with STLport, and gave nothing the ASI does not.

## Known limitations

- Helicopters (`Gunship`, `CargoChopper`): a client follows a helicopter once it has moved on the host; before that it hovers up to 34 m higher. A real mission flight (the Boat boss) is not seen.
- Treehouse and Swamp used to crash at the level load (`CRITICAL ERROR:: ReadPacked i== 20`); the ASI now skips the physics state that the level file bakes into some entities, so those objects start where the level puts them ([#1](https://github.com/Bantila/FarCryCoop/issues/1)).
- **A level change sometimes crashes the host** (random heap corruption in `CrySystem.dll`; seen on Bunker → Steam and Cooler → Boat, a few in ten): [#2](https://github.com/Bantila/FarCryCoop/issues/2).
- After a move (a checkpoint hop, a load) a client that missed it is now moved again by the server, also when it falls through the ground ([#3](https://github.com/Bantila/FarCryCoop/issues/3), closed); the Bunker AI conversation error is guarded ([#4](https://github.com/Bantila/FarCryCoop/issues/4), closed). Vehicles with fewer seats than players (Swamp, buggies): [#5](https://github.com/Bantila/FarCryCoop/issues/5).
- To the other players a paraglider that climbs looks as if it falls.
- No player can push barrels or crates, the host included.
- Joined players do not see cutscenes; the host's intro cutscene is not verified on every map.
- Saves keep players, weapons and dead enemies only; after a load the mission script starts from the beginning of the map (triggers, pickups and vehicles are not saved).
- AI jumps and other animation-driven AI actions do not happen on a dedicated server.
- In-game chat and console type Latin letters only.
- PunkBuster stays off; the mod never touches it.

## Roadmap

1. Find the random crash on a level change ([#2](https://github.com/Bantila/FarCryCoop/issues/2)), then repeat the sweep over all 20 levels in one run (Treehouse, Swamp, Factory, Dam and Volcano were swept after the workaround).
1a. Verify shirt color, loadout, the lobby "Start" and the F6 / F7 save keys in game with two players.
2. Steam join with a friend's real second account.
3. Host admin panel inside the game (ESC menu instead of the console), any player able to start a mission, friendly fire switch: [games/far-cry/PLAN-fun-mode.md](games/far-cry/PLAN-fun-mode.md).
4. Cutscenes for joined players (written, not seen in game) and a real helicopter flight.
5. Save the mission progress (triggers, objectives, pickups) too.
6. Player list during the game in the launcher.

## Building from source

Every script loads `E:\FarCryCoop\env.ps1` and works inside `E:\FarCryCoop` (see [docs/workspace.md](docs/workspace.md)). Tools: MSVC 14.44 (x86, read-only copy), x86 Windows SDK libs, Rust (i686) for the launcher.

| Part | Command | Output |
|---|---|---|
| Mod scripts | `& games\far-cry\mod\deploy.ps1` | `<game>\Mods\FarCryCoop\FarCryCoop.pak` |
| ASI plugin | `& games\far-cry\asi\build.ps1` | `Temp\asi\FarCryCoopNet.asi` |
| Steam bridge | `& games\far-cry\steam\build.ps1` | `Temp\steam\FarCryCoopSteam.exe` |
| Launcher | `& games\far-cry\launcher\build.ps1` | `Temp\launcher\FarCryCoopLauncher.exe` |
| Player archive | `& games\far-cry\release\release.ps1` | `Temp\release\FarCryCoop-<version>.zip` |

## Repository layout

```
games/far-cry/
  NOTES.md, NOTES.ru.md          research log: every spike, fix and address
  PLAN-fun-mode.md               planned host panel and fun features
  mod/FarCryCoop/Scripts/        Lua: COOP rules, client side, monitor, host commands
  mod/deploy.ps1                 packs the scripts into FarCryCoop.pak
  asi/                           FarCryCoopNet.asi (C) and its build script
  steam/                         Steam join bridge (C)
  launcher/                      launcher with lobby (Rust + Tauri)
  release/                       player archive script and INSTALL notes
docs/                            workspace and tool setup
```

## Prior art and credits

- [Assault Coop](https://www.moddb.com/mods/assault-coop) by FlameKnight7 (2011): 7 re-edited campaign maps for co-op. It showed the client relay idea for area triggers. Its scripts may not be reused without permission, so none of its code is here.
- [FCAV](https://farcry1.itch.io/far-cry-advanced-version): announced co-op, not released.
- Method: the [coop-anything](https://github.com/cranebeaker/coop-anything) playbook.
- README structure inspired by co-op projects such as [TES3MP](https://github.com/TES3MP/TES3MP) and [sm64coopdx](https://github.com/coop-deluxe/sm64coopdx).
- Official CryENGINE MOD SDK 1.4 (source of `CryGame.dll`, used to check addresses). The leaked full engine source is not used.
- [Ultimate ASI Loader](https://github.com/ThirteenAG/Ultimate-ASI-Loader) (MIT) loads the plugin.

License: [MIT](LICENSE). Far Cry is a trademark of Crytek / Ubisoft. This is a fan project, not affiliated with them. You need your own copy of the game.

## Other games of the series

One repository per game. Private ones open up when work on that game gets close.

| Game | Repository | Status |
|---|---|---|
| Far Cry (2004) | this one | **0.2 beta** |
| Far Cry 2 | `FarCry2Coop` (private) | placeholder |
| Far Cry 3 | [FarCry3Coop](https://github.com/Bantila/FarCry3Coop) | plan, next game |
| Far Cry 3: Blood Dragon | `FarCry3BloodDragonCoop` (private) | placeholder |
| Far Cry 4 | `FarCry4Coop` (private) | placeholder |
| Far Cry 5 | `FarCry5Coop` (private) | placeholder |
| Far Cry Primal | `FarCryPrimalCoop` (private) | placeholder |
| Far Cry New Dawn | `FarCryNewDawnCoop` (private) | placeholder |
| Far Cry 6 | `FarCry6Coop` (private) | research |

Workspace: [docs/workspace.md](docs/workspace.md)
