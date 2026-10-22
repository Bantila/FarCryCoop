# Far Cry (2004) — plan: host admin panel, mission select and fun modes

Русская версия: [PLAN-fun-mode.ru.md](PLAN-fun-mode.ru.md)

Status: **postponed** (2026-10-19). The owner will come back to this plan after the optimizations (stutter, checkpoints, saves). No code is written yet.

## Why

Today every `coop_*` command works only in the host console. Clients register them too (`AvailableMods.lua` loads on every machine), but they run locally: `coop_map` on a client would start a server of its own. The owner wants:

- an in-game interface instead of the console: a host admin panel;
- any player able to start any campaign mission;
- fun features: friendly fire and more.

Decisions (the owner said "just do it"):

- The main interface is the host admin panel (section 0). Console commands stay as a fallback.
- One map for everyone. Any player changes it for all, no vote (co-op among friends).
- Weapon choice: in the launcher, later (owner's decision). Until then there is `coop_weapons`.
- Friendly fire is off by default. Right now it is effectively on and untested: COOP `GameRules:OnDamage` only drops hits on AI, and `CHIT` accepts a player as the target.

## Changes

### 0. Host admin panel (do this first)

Recon findings (game scripts in `E:\FarCryCoop\Work\far-cry\scripts\SCRIPTS`):

- Menu screens are Lua widget tables in `MenuScreens/*.lua`, built with `UI:CreateScreenFromTable(name, GUI)`. They load in `UI:OnInit` (`MenuScreens/UISystem.lua:35-98`).
- Widgets: buttons (`OnCommand`), listview, combobox, checkbox (`OnChanged`, `GetChecked`). The left button column is `AddUISideMenu` (`MenuScreens/UISystemUtils.lua:413`). Navigation is `GotoPage`; the target `$Return$` closes the menu.
- ESC opens the screen named by `ClientStuff:GetInGameMenuName()`. In COOP that is `InGameSingle` today (`Default/ClientStuff.lua:227`), with a video background (`GetInGameMenuVideoOn()` = 1).
- The game already ships an unfinished `MenuScreens/MultiPlayer/ServerAdmin.lua` (map change, restart, FriendlyFire checkbox, kick). Use it as a widget sample: combobox `:426-492`, buttons `:494-558`, checkbox `:883-904`. Do not reuse it whole: it is built around RCON and MP game modes.
- The campaign list is ready-made: the `DEFIANT` table (`defiant.lua`). Filling a listview with localized names via `AddItem("@Level"..name)` is in `MenuScreens/Campaign.lua:300-305`; reading the selection with `GetSelection(0)` is at `:242-262`.

Decisions:

- Only the host of a listen server has the panel (`Game:IsServer()`). Buttons call the mod's Lua functions directly (`CoopMap`, `CoopGod`, ...), no console or RCON. ESC for other players stays as it is.
- A dedicated server has no UI, so the panel does not cover it (console or RCON there). Later a client's panel could send commands through `CCMD` (section 2).
- The panel is the co-op's own ESC menu. In `COOP/ClientStuff.lua`, override `GetInGameMenuName()` to return `"CoopAdmin"` for the host, and `GetInGameMenuVideoOn()` to return 0 so the game stays visible behind the menu.
- New file `Scripts/MenuScreens/Ingame/CoopAdmin.lua`:
  - left column via `AddUISideMenu`, as in `InGameSingle.lua:203-213` (Return, Main menu, Options, Quit);
  - "Mission": a listview from `DEFIANT`, a "Start" button (first `GotoPage("$Return$")`, then `CoopMap`) and a "Restart" button;
  - "Checkpoint": a combobox filled in `OnActivate`, and a "Move everyone" button. Move the checkpoint scan out of `CoopGoto` into `CoopCheckpoints()` in `AvailableMods.lua`;
  - God and Noclip checkboxes: `OnChanged` calls `CoopGod(0/1)` and `CoopNoclip(0/1)`; `OnActivate` sets them from `COOP_God` and `COOP_Noclip`;
  - buttons "All weapons", "Ammo", "Save", "Load";
  - later (section 5): "Friendly fire" and "Rockets" checkboxes, a damage multiplier field.
- Screen loading: late, from `COOP/ClientStuff:OnInit` via `Script:LoadScript`, guarded against creating it twice. Risk: a late `CreateScreenFromTable` is not verified to work. Fallback: override `MenuScreens/UISystem.lua` and add a `LoadScript` line to it.

### 1. Any player runs commands (`Scripts/Multiplayer/AvailableMods.lua`)

- Helper `CoopCommand(name, func, help)`: registers `Game:AddCommand(name, "CoopRun('"..name.."', %line)", help)` and stores `func` in `COOP_Commands[name]`.
- `CoopRun(name, line)`: if `Game:IsServer()`, call `COOP_Commands[name](line, _localplayer)`; else, if `Client` exists, send `Client:SendCommand("CCMD "..name.." "..line)`; else log "not connected".
- Move every `Game:AddCommand("coop_...")` to `CoopCommand`. Functions get `line` as a string (`%line` already arrives as a string: `CoopMap(%line)` works) and, as the second argument, the player who ran the command.
- `coop_spawn` uses `%1` today: switch it to `%line` plus `tonumber`.

### 2. The server accepts client commands (`Scripts/COOP/gamerules.lua`)

- In `GameRules:OnClientCmd`: if `tk[1] == "CCMD"`, take `f = COOP_Commands[tk[2]]`. If it exists, run it through `call(...)` with an error log (like `CoopWakeError`), passing the text after the command name (`strsub` of the original `cmd`) and the slot's player. Server log: `coop: <player name> ran <cmd>`.
- Only names in `COOP_Commands` are allowed: the whitelist is the command table itself.

### 3. Mission list: `coop_maps`

- Use the ready-made `DEFIANT` table (`Scripts/defiant.lua`): 20 maps in campaign order, entries `{level, mission}`. The same table fills the list in the panel.
- `coop_map` without an argument prints the same list.

### 4. Weapon choice: postponed to the launcher

- Not now. Meanwhile `coop_weapons` (every weapon for everyone) becomes available to any player.

### 5. Fun features

Each feature is a console command and an admin panel control.

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

- In `NOTES.md` and `NOTES.ru.md`: "Admin panel" and "Mission select" paragraphs with the command list, marked "untested in game"; update "Next steps".

### Commits

- `feat(far-cry): add host admin panel to the co-op ESC menu`
- `feat(far-cry): let every co-op player run coop commands, add coop_maps`
- `feat(far-cry): add friendly fire toggle and damage multiplier`
- `feat(far-cry): add coop_rockets based on RocketMod by FarOut`
- `docs(far-cry): document admin panel, mission select and fun commands`

## Verification (owner, in game)

1. Host: `coop_map Pier`, a client connects.
2. Host: ESC opens the admin panel over the game. Every button and checkbox does the same as its console command. "Return" closes the panel. The client sees the usual menu on ESC.
3. Client: `coop_map` prints the map list; `coop_map Fort` moves both players to Fort and the client stays connected; `coop_weapons` from the client works.
4. The client shoots the host: no damage. After `coop_ff 1` there is damage. The host shoots the client: same.
5. `coop_dmg 10`: enemies drop from one hit for both players.
6. `coop_rockets 1`: the RocketMod effect shows for host and client; `coop_rockets 0` turns it off.
7. The server log has `coop: <name> ran ...` lines.
