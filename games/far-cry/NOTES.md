# Far Cry (2004) — co-op notes

Russian version: [NOTES.ru.md](NOTES.ru.md)

Status: recon (branch `game/far-cry`, started 2026-10-18). Goal: campaign co-op for up to 4 players, joined through a shared launcher for the whole series (Steam friends, Spacewar AppID 480, room code).

## Game identity (AGENTS.md rule 5)

- Store / ownership: Steam app 13520, installed in D:\SteamLibrary
- Version / build id: 1.4.0.1405 (from `log.txt`)
- SHA-256 of main exe: `Bin32\FarCry.exe` `21a907fae0b6e2d4b10d546dba0965ef89c39a69f8cb00036307c0564ca1a813`; `CryGame.dll` `db9c7660b698600ae34dd4a18f7ca5989911ad51bf9286ba1cc047ae52ef7634`; `CryNetwork.dll` `10aed71c092c4f057edcba49a593b569dab9fc10a263b48e60f973065bdaa908`
- Engine: CryEngine 1
- Install checked for third-party DLLs: yes. Found in `Bin32` and `Bin64`: `version.dll` (ASI loader), `SilentPatchFarCry.asi`, `FarCry.WidescreenFix.asi`; mod `Mods\FarOut_Widescreen`; `FCData\Tent AI Bug Fix.pak`. PunkBuster in `Pb\`. `Bin64` has no 64-bit game exe, only these add-ons.

## Known so far

- No official co-op; competitive multiplayer exists. Mods: Assault Coop (partial, ~7 campaign maps, 2011) https://www.moddb.com/mods/assault-coop ; FCAV (co-op announced, not released) https://farcry1.itch.io/far-cry-advanced-version (source: coop-anything data/directory.yaml, checked 2026-10-16).

## Recon 2026-10-18

Working copy: `E:\FarCryCoop\Workar-cry\Bin32` (exe + DLLs) and `Workar-cry\scripts` (unpacked `FCData\Scripts.pak`).

- Single player already runs as a local server plus a local client. `Scripts\Default\gamerules.lua` (the single-player rules) has `OnClientConnect`, `OnClientDisconnect` and `RespawnPlayer` per `server_slot`. Respawn already goes to the last checkpoint (`_LastCheckPPos`).
- The game type is the Lua global `g_GameType`. Campaign sets it to `Default` (`MenuScreens\Campaign.lua`). Multiplayer sets it to `ASSAULT`, `FFA` or `TDM` and starts the map with `Game:LoadLevelMPServer`. The create-server menu hides `Default`.
- Each level lists its missions in `levelinfo.xml`. Campaign map `Training` has mission `Training` (`mission_training.xml`); MP map `mp_airstrip` has mission `ASSAULT`. `Game:CheckMap(map, gametype)` checks this list before an MP map load.
- Mods live in `Mods\<name>\` with their own `.pak` files that override scripts. A co-op mod can be a mod folder; the game binaries stay untouched as long as Lua is enough.
- Official CryENGINE MOD SDK 1.4 includes the C++ source of `CryGame.dll` (the game DLL: server/client game logic). Use only this official SDK, not the leaked full engine source.

Guess, not verified: a host can start a campaign map as an MP server with `g_GameType=Default` and mission `Training`, and remote clients get the single-player rules. Unknown: what the C++ side (`CXServer`, `CXClient`, AI, cut scenes, save games) does with more than one client in a campaign mission.

Not done: REA is not registered in this session (see `docs/tools/rea.md`), so no Ghidra analysis yet. Assault Coop page on moddb returned HTTP 403.

## Spike 1 — campaign map as a network server (2026-10-18, works)

Run from the install in `D:` (owner's one-time exception to the copy rule; the game rewrote its own `log.txt` / `log_WinSV.txt` there, no files were changed by us).

Steps that worked:
1. `Bin32\FarCry_WinSV.exe -DEVMODE` (Lua `#` console commands work only with `-DEVMODE`; console input line is limited to roughly 100 characters).
2. In the server console, after the banner (commands passed on the command line run too early and are ignored):
   ```
   #AvailableMODList.DEFAULT={team=0,respawntime=0,mission="Training"}
   g_GameType DEFAULT
   start_server Training
   ```
   `start_server` takes the mission from `AvailableMODList[g_GameType]`; `Game:CheckMap("Training","Training")` is 1, with `"Default"` it is nil.
3. Client: plain `Bin32\FarCry.exe`, Multiplayer -> LAN -> join. (Passing `"connect 127.0.0.1"` or `r_Width` on the command line made the client shut down right after init; typing `connect` in the main-menu console did nothing.)

Result: the server loaded `Training` with the single-player `GameRules` (655 entities). The client got slot 1, a player entity at the first respawn point with 255 health, the normal HUD, and could walk, shoot and play. Two processes (dedicated server + client) run on one PC.

Still unchecked: mission objectives, AI behaviour, cut scenes, checkpoints, a second remote player.

## Spike 2 — weapons broken for the remote client (2026-10-18, root cause found)

Symptom on campaign maps (both `DEFAULT` and `FFA` rules): the remote client can walk, run and jump, but has no weapon model, cannot fire (endless reload), and crouch is not shown. Stock `mp_airstrip` + `ASSAULT` works fully.

Evidence (server tracer `GameRules:OnUpdate` hook, client tracer `ClientStuff.OnUpdate` hook, one line per second):
- Server receives everything: crouch (`crouching=1`), fire (`firing=1`), weapon switches, damage, respawn.
- Client on `mp_airstrip`: weapon 19, clip 50, ammo 100, `canfire=1`, `drawfpweapon=1`.
- Client on `Pier`: weapon 19 (P90), clip 0, ammo 0, `canfire=nil`, `drawfpweapon=nil`; the server meanwhile already switched to weapon 12 (MP5).

Root cause: a level loads weapon classes from its mission XML `<Weapons><Used>` list (`CXSystemBase::LoadXMLNode` -> `CWeaponSystemEx::AddWeapon`). MP missions list every weapon; campaign missions list only a few (`Pier`: Falcon, M4, Machete, SniperRifle). On the server, missing classes are loaded on demand by `BasicPlayer:ScriptInitWeapon` -> `Game:AddWeapon`; the remote client never does this, so `CPlayer::Read` -> `SelectWeapon` fails for unloaded classes.

Fix direction (for the mod): client-side co-op script loads every class from `WeaponClassesEx` (`Scripts\Default\Entities\Weapons\WeaponSystem.lua`) at level load, before the local player is spawned. A runtime test from the console (`Game:AddWeapon` for all classes after spawn) gave the first-person weapon back (`drawfpweapon=1`) but not ammo/fire, so it must happen before the player is set up.

Also seen: switching the map on the server drops the client back to the menu; the campaign intro cut scene does not play for the client; FC1 console input is cut at about 100 characters (use `#dofile("E:/...")` for longer Lua).

## Next steps

1. Spike: start `Training` as an MP server with `g_GameType=Default` and join from a second instance on LAN. Write down what breaks.
2. Download CryENGINE MOD SDK 1.4 into `Downloadsarcry-sdk-1.4\`, check SHA-256, read `CXServer`/`CXClient`/game-rules code.
3. Steam P2P transport: check where `CryNetwork.dll` opens its UDP socket, to plan a tunnel for the launcher.
4. PunkBuster stays off (`sv_punkbuster 0`); we never touch it (AGENTS.md rule 10).
