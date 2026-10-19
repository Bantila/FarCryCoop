# Far Cry (2004) — plan: mission select for every player and fun modes

Русская версия: [PLAN-fun-mode.ru.md](PLAN-fun-mode.ru.md)

Status: **postponed** (2026-10-19). The owner will come back to this plan after the optimizations (stutter, checkpoints, saves). No code is written yet.

## Why

Today every `coop_*` command works only in the host console. Clients register them too (`AvailableMods.lua` loads on every machine), but they run locally: `coop_map` on a client would start a server of its own. The owner wants any player to start any campaign mission, plus fun features: friendly fire and more.

Decisions (the owner said "just do it"):

- Interface: the console, as now. A menu comes later if the console proves awkward.
- One map for everyone. Any player changes it for all, no vote (co-op among friends).
- Weapon choice: in the launcher, later (owner's decision). Until then there is `coop_weapons`.
- Friendly fire is off by default. Right now it is effectively on and untested: COOP `GameRules:OnDamage` only drops hits on AI, and `CHIT` accepts a player as the target.

## Changes

### 1. Any player runs commands (`Scripts/Multiplayer/AvailableMods.lua`)

- Helper `CoopCommand(name, func, help)`: registers `Game:AddCommand(name, "CoopRun('"..name.."', %line)", help)` and stores `func` in `COOP_Commands[name]`.
- `CoopRun(name, line)`: if `Game:IsServer()`, call `COOP_Commands[name](line, _localplayer)`; else, if `Client` exists, send `Client:SendCommand("CCMD "..name.." "..line)`; else log "not connected".
- Move every `Game:AddCommand("coop_...")` to `CoopCommand`. Functions get `line` as a string (`%line` already arrives as a string: `CoopMap(%line)` works) and, as the second argument, the player who ran the command.
- `coop_spawn` uses `%1` today: switch it to `%line` plus `tonumber`.

### 2. The server accepts client commands (`Scripts/COOP/gamerules.lua`)

- In `GameRules:OnClientCmd`: if `tk[1] == "CCMD"`, take `f = COOP_Commands[tk[2]]`. If it exists, run it through `call(...)` with an error log (like `CoopWakeError`), passing the text after the command name (`strsub` of the original `cmd`) and the slot's player. Server log: `coop: <player name> ran <cmd>`.
- Only names in `COOP_Commands` are allowed: the whitelist is the command table itself.

### 3. Mission list: `coop_maps`

- A hard-coded list of the 20 campaign maps from the game's `Levels` folder (without `mp_*`, `Demo`, `newcontrol`): Training, Carrier, Fort, Pier, Research, Treehouse, Bunker, Rebellion, Steam, Cooler, Control, Archive, Catacombs, Factory, Dam, Boat, River, Swamp, Regulator, Volcano. Order from memory; fix it against the game.
- `coop_map` without an argument prints the same list.

### 4. Weapon choice: postponed to the launcher

- Not now. Meanwhile `coop_weapons` (every weapon for everyone) becomes available to any player.

### 5. Fun features

- `coop_ff [0/1]`: friendly fire, default `COOP_FF = 0`. In COOP `GameRules:OnDamage`: if `COOP_FF ~= 1`, shooter and target are humans (`not s.ai`, `not t.ai`) and `s ~= t`, drop the damage. Leave self-damage (grenades, falls) alone.
- `coop_dmg [x]`: multiplier for player damage to AI, default `COOP_Dmg = 1`; `10` means enemies drop from one hit. In the same `OnDamage`: `hit.damage = hit.damage * COOP_Dmg` for player -> AI hits.
- `coop_god`, `coop_noclip`, `coop_weapons` become available to everyone: fun too.
- **RocketMod by FarOut** (release 2.1 NATIVE). Owner's source: https://www.speedrun.com/static/resource/ly1lr.zip?v=7179c9c ; owner's local copy: `RocketMod_Release_2.1_NATIVE_3c6dcb9c.zip` in their downloads folder on drive C:. No description found online (ModDB and speedrun.com return 403). Steps:
  1. Load `. E:\FarCryCoop\env.ps1`. Copy the archive from drive C: once into `E:\FarCryCoop\Downloads\RocketMod\` (the owner allowed this exception to CLAUDE.md rule 2, 2026-10-19). Do not touch drive C: again. Record the SHA-256.
  2. Unpack into a new empty folder `Downloads\RocketMod\unpacked\`. Run nothing from it. Read every file. "NATIVE" in the name hints at native code: if it holds exe/dll/asi files, do not run them and show the owner first.
  3. Read the readme for redistribution permission.
  4. If it is Lua/XML scripts: port the idea into the FarCryCoop mod as a `coop_rockets [0/1]` toggle (via `CoopCommand`; if the effect is client-side, also a `ServerCommandTable` entry on clients). Credit FarOut in a comment and in NOTES. Without permission to port, do not copy its files into the repo; describe in NOTES how to install it alongside.
  5. If step 4 turns out large, stop and show the owner.
- Postponed: slow motion, big heads and the like: they need reverse engineering of engine variables.

### 6. Documentation (both languages)

- In `NOTES.md` and `NOTES.ru.md`: a "Mission select" paragraph with the command list, marked "untested in game"; update "Next steps".

### Commits

- `feat(far-cry): let every co-op player run coop commands, add coop_maps`
- `feat(far-cry): add friendly fire toggle and damage multiplier`
- `feat(far-cry): add coop_rockets based on RocketMod by FarOut`
- `docs(far-cry): document mission select and fun commands`

## Verification (owner, in game)

1. Host: `coop_map Pier`, a client connects.
2. Client: `coop_map` prints the map list; `coop_map Fort` moves both players to Fort and the client stays connected; `coop_weapons` from the client works.
3. The client shoots the host: no damage. After `coop_ff 1` there is damage. The host shoots the client: same.
4. `coop_dmg 10`: enemies drop from one hit for both players.
5. `coop_rockets 1`: the RocketMod effect shows for host and client; `coop_rockets 0` turns it off.
6. The server log has `coop: <name> ran ...` lines.
