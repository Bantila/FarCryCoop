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

## Spike 3 — mod `FarCryCoop` and the real blocker (2026-10-18)

Owner decision: the mod lives in `<game>\Mods\FarCryCoop\` on the install in `D:` (only this folder is ours; game files stay untouched). Source: `games/far-cry/mod/FarCryCoop/`, packed by `games/far-cry/mod/deploy.ps1` into `FarCryCoop.pak`. Start both server and client with `-MOD:FarCryCoop`.

Mod v0.1: game type `COOP` (single-player rules), console command `coop_map <map>` (mission = `Game:GetMapDefaultMission`), client preloads all `WeaponClassesEx` in `ClientStuff:OnInit` (runs after level load, before the server sends the player).

Result: the weapon preload alone does not help. Real blocker: on campaign maps the server's entity updates never reach the client. The client copy of its own player stays at the spawn point with `hp=255` and no name, while on the server it is "Jack Carver" far away with other health; AI moved on the server stay at their XML position on the client. Input from the client does reach the server. On `mp_airstrip` with the same `COOP` rules sync works (crouch visible), so the cause is the campaign map (≈650 net entities), not the rules. Raising `sv_maxrate_lan` / `sv_maxrate` did not help; `cl_maxrate` on the command line runs before `Client` exists and is ignored. Suspects in C++: `CXSnapshot::BuildAndSendSnapshot` priority threshold, `CXClient::OnServerMsgTimeStamp` (`m_bIgnoreSnapshot`).

Russian keyboard layout: the game does not take input with it; switch to EN before playing (to fix later).

Toolchain: MSVC 14.44 (VS 2022, x86) found at `D:\TailCore\toolchain\vs` (another project's, used read-only). Rebuilding `CryGame.dll` with it is unsafe: engine interfaces pass `std::string` / `std::vector` across DLL borders (e.g. `IEntitySystem::GetEntitiesInRadius`, `IXGame::CreateTagPoint`), and VS 2022 STL layout differs from VS 2003. Chosen path (owner, 2026-10-18): an ASI plugin (loaded by the already installed `version.dll`) that hooks functions of the original `CryGame.dll` 1.4 by address; addresses found with REA/Ghidra against the SDK source.

## Spike 4 — ASI logger finds where updates are lost (2026-10-18)

Plugin: `games/far-cry/asi/FarCryCoopNet.c`, built by `asi/build.ps1` (VS 2022 x86, no Windows SDK and no CRT: import libraries come from stub DLLs). Installed as `Bin32\FarCryCoopNet.asi` (owner allowed this one file), loaded by `version.dll` in both `FarCry.exe` and `FarCry_WinSV.exe`. It checks the `CryGame.dll` PE timestamp `0x44e2f64d`, hooks by address and writes a once-per-second summary to `Mods\FarCryCoop\netlog_<exe>_<pid>.txt`.

Addresses in `CryGame.dll` 1.4.0.1405 (image base `0x33000000`, found with REA/Ghidra and checked against SDK sources):

| Function | Address | Calling convention / notes |
|---|---|---|
| `CXSnapshot::BuildAndSendSnapshot` | `0x3306faba` | thiscall, no arguments; anchor string `netentities %d/%d` |
| `CNetEntityInfo::Update(Vec3)` | `0x330bb9b7` | thiscall, `ret 0xc`; `+0x04` m_pEntity, `+0x1c` m_nPriority |
| `CNetEntityInfo::Write(CXServer*, CStream&)` | `0x330bb82d` | thiscall, `ret 8` |
| `CXClient::OnServerMsgTimeStamp(CStream&)` | `0x33080227` | thiscall, `ret 4` |
| `CXClient::OnServerMsgUpdateEntity(CStream&)` | `0x330816ef` | thiscall, `ret 4`; anchor `error reading from the snapshot` |
| `CXClient::ParseIncomingStream` (message switch) | `0x3308354b` | `false` from UpdateEntity drops the rest of the packet |
| `GameWarning` | `0x3307019e` | cdecl, varargs |

`CXClient` fields: `+0x0c` m_wPlayerID, `+0x10` m_iPhysicalWorldTime, `+0x14` m_bIgnoreSnapshot, `+0x40` m_bLocalHost, `+0x44` m_pGame, `+0x4c` m_pISystem. `CStream`: `+0x470` size in bits, `+0x474` read position.

Result on `Pier` (COOP, `sv_maxrate*` 10000000):
- Server: ~17 snapshots/s, 550 net entities, 442 of them priority 0, ~108 actually written per snapshot (1836/s), the slot player (id 65489, priority 1.1 million) in every snapshot, ~18 000 bits per snapshot.
- Client: TimeStamp 17/s, `m_bIgnoreSnapshot` never set, ~63 `UpdateEntity` per snapshot (~1080/s), 0 failures, no "not spawned" warnings. `m_wPlayerID` = 65489 matches the server, but not one update for 65489 arrives.

Conclusion: CryGame on both sides works; ~40% of every snapshot (its tail) is lost between `CXServerSlot::SendUnreliableMsg` -> `m_pISSlot->SendUnreliable` (CryNetwork.dll) and the client. The own player was spawned last, sits at the end of `m_lstNetEntities` and is always in the lost tail; AI at the end of the list freeze the same way. `mp_airstrip` has few entities, so its snapshot fits. Likely the unreliable packet has a size limit (~10 000 bits arrive) and the rest is dropped. Our `sv_maxrate*` = 10000000 makes it worse: the priority threshold falls to ~0 and every candidate is sent.

Fix 1 (done, in the ASI): before every `BuildAndSendSnapshot` the plugin sorts `m_lstNetEntities` by `m_nPriority * time since last send` (std::list node: `+0` next, `+4` prev, `+8` CNetEntityInfo with `+0x10` m_fLastUpdate, `+0x24` m_nPriority). Result on `Pier`: the client now gets its own player in every snapshot (16-17/s) and its position matches the server (e.g. server `815.7,1160.4`, client `815.6,1160.4`). The limit (found): CryNetwork collects a frame's unreliable data in a `CStream` with a fixed stack buffer, `DEFAULT_STREAM_BYTESIZE` 1124 bytes = 8992 bits (`CryCommon/Stream.h`; without an allocator `Resize` returns false). In `CryNetwork.dll` the constant `0x2320` occurs once, in the `CStream` constructor `FUN_34502810`. Writes past it are dropped silently.

Fix 2 (done, in the ASI): hook `CXServerSlot::SendUnreliableMsg` (`0x3306c620`, thiscall, `ret 0x10`, `m_pISSlot` at `+0xa3c`). During a snapshot, `XSERVERMSG_UPDATEENTITY` messages are counted against `SNAP_BUDGET_BITS` = 8000; once the budget is used up, the rest of the snapshot is held back (not sent), and these entities get their old `m_fLastUpdate` back, so their time-affected priority grows and they move to the front of a later snapshot. The client hooks `CXClient::ParseIncomingStream` (`0x3308354b`) to measure packets.

Result on `Pier`: server writes ~1815 updates/s, holds back ~1160, sends ~655; the client receives ~655 `UpdateEntity`/s (100% instead of ~40%), the biggest packet is 7928-8021 bits (< 8992), own player 16-17/s, positions match. Knob: `SNAP_BUDGET_BITS` (overhead seen ~20-100 bits, so up to ~8800 should still fit). Checked in game by the owner (2026-10-18, `Pier`): the client has its weapon and it fires; the rest works too. Open issues: occasional stutter; the crosshair does not turn red when aimed at an enemy (it does in the single-player campaign). `Training` (656 net entities) by the logs: ~680 updates/s sent and received, own player 17/s, biggest packet 7920 bits, positions match. Server crash on `Training` (owner, 2026-10-18): NULL read at `0x330cfe4a` in `CMovieUser::BeginCutScene` (`0x330cfd25`, `GameMovieUser.cpp`): it calls `GetISystem()->GetIInput()->GetIKeyboard()->ClearKeyState()`, and the dedicated server has no input. `EndCutScene` (`0x330cfed6`) does the same. Fix 3 (in the ASI): when `GetIInput()` is NULL both callbacks are skipped. Second crash at the same spot: NULL read at `0x3401a4eb` in `CryMovie.dll` (base `0x34000000`, PE timestamp `0x44ae37b4`): the cutscene sound track key handler `0x3401a396` calls `GetISystem()->GetISoundSystem()->LoadSound(...)`, and the dedicated server has no sound system. Fix 4 (in the ASI): skip only this sound key when `GetISoundSystem()` is NULL; the sequence itself keeps running on the server. Note: the handler is thiscall with 5 arguments (`RET 0x14`); the first hook build took 4 and corrupted the stack (crash at `0x3401046d`), fixed. Third crash at the same spot: `0x34013b53`, another CryMovie sound handler (`0x34013a7b`, same `GetISoundSystem()` pattern; several more exist). Fix 5 (in the mod, systemic): `coop_map` sets `mov_NoCutscenes 1`; `CMovieSystem::PlaySequence` (`0x34017ef9`) then does not start sequences flagged as cutscenes (flags `0x8`/`0x10`), so their sound and input code never runs on the server. Remote clients never saw these cutscenes anyway. Risk: a mission script waiting for a cutscene's end event could stall; not seen yet. Not yet verified at the cutscene.

Stutter: `SNAP_BUDGET_BITS` raised to 8800 (biggest packet 8755 bits, ~750 updates/s delivered, no loss). Measured the longest pause between snapshots (server) and TimeStamps (client) over 29 s on `Training`: 63-94 ms on both sides, so delivery itself is steady. Remaining suspect: each non-own entity gets only ~7 updates/s (750/s shared by ~110 active entities). AI on the dedicated server (owner, 2026-10-19: enemies stand still and do not see the client): not solved yet. Checked: `ESYSUPDATE_MULTIPLAYER` (passed by `CXGame::Update`) does not gate the AI update in `CSystem::Update` (`CrySystem.dll` `0x365151ce`); AI runs if `nPauseMode==0` and an unidentified cvar at `this[0xa18]` is 0. Server cvars: `ai_systemupdate=1`, `ai_ignoreplayer=0`, `es_UpdateAI=1`, `es_UpdateEntities=1`. Every `Player` entity registers as `AIOBJECT_PLAYER` in `Player:OnReset` (`player.lua`). Tried `es_VisCheckForUpdate 0` in `coop_map`: no change. `ai_noupdate` (CrySystem, `+0x2860`) is 0; the AI system itself runs (`CAISystem` `+0x1e4`=1, ~80 passes/s, logged by the ASI). Cause: the puppets are asleep on the dedicated server (a Lua tracer showed all 76 frozen); `AIEVENT_WAKEUP` + `AIEVENT_ENABLE` brings them to life. Fix 6 (mod, `Scripts/COOP/gamerules.lua`): once a second the server wakes puppets within 150 m of any player, except `bSleepOnSpawn` and hidden (`Enemy_Hidden`) ones. Verified on `Pier` by the tracer: behaviours `RunToFriend`/`CoverHold`/`RearAttack`, attention target = the player, enemies take damage and die.

Next: test other campaign maps.

## Spike 5 — host tools, client-side hits, map restart, saves recon (2026-10-19)

Host console commands (mod, `Scripts/Multiplayer/AvailableMods.lua`): `coop_goto [id]` lists the campaign checkpoints (`GameEvent` entities with `Properties.nId`) or moves all players to one and makes it the respawn point; `coop_spawn <n>` uses tagpoint `Respawn<n>`; `coop_god [0/1]`; `coop_ammo` refills every ammo type (`MaxAmmo` via `BasicPlayer.AddAmmo`); `coop_weapons` gives every weapon (9 slots, `PLAYER_MAX_WEAPONS`) — it needs all weapon classes loaded on the server before players spawn, because `CPlayer::m_mapPlayerWeapons` only holds the classes loaded at that time (`MakeWeaponAvailable` returned -1), so the COOP gamerules preload them; `coop_noclip [0/1]` (DevMode "designer fly mode", applied on the server and, through the `NOCLIP` server command, on every client); `coop_restart`. Lua 4 pitfall: `tinsert` adds a field `n`, so `for i, P in t` met a number and broke every command; `CoopPlayers` builds the table by index.

Map change/restart without dropping clients: the first `coop_map` uses `Game:LoadLevelListen` (starts the server), later ones `Game:LoadLevelMPServer` ("keeping the current clients connected", `ScriptObjectGame.cpp`). Verified: after `coop_restart` the client's world time resets and it keeps getting its own player 16-17 times a second, no menu.

Unkillable enemies / no red crosshair: the red crosshair is a hit flash (`Hud.hit=5` in `Player:Client_OnRemoteEffect`, userbyte 3, sent by `BasicWeapon.Server:OnHit` as `FX`; drawn by `Hud:DrawCrosshair` in `GUI/HudCommon.lua`), not aiming. A client tracer showed that every `FX 3` the client got came from AI shooters: the server never registered the remote player's hits (it sees `fire=1`, but the clip barely drops). Not root-caused. Replaced by client-side hits: the client hooks the global `ExecuteMaterial2(hit, effect)` (`CWeaponClass` caches each weapon's `Client.OnHit`/`Server.OnHit` at class load, `WeaponClass.cpp` `GET_VALUE`, so hooks on weapon tables never run), sets `Hud.hit=5` and sends `CHIT <id> <dmg> <part> <mat> <pos> <dir>` with `Client:SendCommand`; COOP `GameRules:OnClientCmd` applies it with `target:Damage(hit)`; `GameRules:OnDamage` drops server-side hits of remote players on AI. Server side verified with a simulated `CHIT` (170 -> 120 hp); client side not yet confirmed in game.

Saves recon: `CXGame::Save`/`LoadFromStream` return early when `IsMultiplayer()`. `SaveToStream` also needs a local client player (`m_pClient`, `CryError` otherwise) and the sound system (EAX preset), both missing on a dedicated server; `LoadFromStream` reloads the level through a local demo client and asserts a single server slot. Options: (A) real engine saves on a listen-server host: ASI bypass of the MP checks plus a custom loader that reloads with `LoadLevelMPServer` and restores entities without the single-player parts, large; (B) lightweight co-op checkpoint in Lua on the server: remember checkpoint, dead AI ids (static entity ids are stable across a reload of the same map), player ammo/health and mission objectives, then `coop_restart` and reapply; survives `coop_restart` (Lua globals persist), not a server restart unless written to a file. Recommended for testing: B.

Open bug: `GameEvent:OnTimer` (checkpoint save) reads `_localplayer`, which is nil on a dedicated server.

## Next steps

1. Verify in game (written without a run, owner was busy): AI after `coop_restart`, `coop_save`/`coop_load`, the forwarded heli sequence on `Pier`, `coop_weapons`.
2. Fix checkpoints on the dedicated server: `GameEvent:OnTimer` reads `_localplayer`.
3. Real engine saves (option A of the saves recon), after the lightweight `coop_save`.
4. Occasional stutter: non-own entities get ~7 updates/s under the snapshot budget.
5. Launcher / Steam P2P transport: postponed by the owner (2026-10-19).
6. PunkBuster stays off (`sv_punkbuster 0`); we never touch it (AGENTS.md rule 10).
