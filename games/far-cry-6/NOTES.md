# Far Cry 6 — co-op notes

Russian version: [NOTES.ru.md](NOTES.ru.md)

Goal from owner: co-op for 5 players (owner confirmed 2026-10-18: "me + 4 friends").

## Game identity (AGENTS.md rule 5)

Observed 2026-10-18 on the owner's PC (read-only):

- Store: Steam, app 2369390 (`appmanifest_2369390.acf`)
- Steam build id: 11359732 (`buildid` = `TargetBuildID`)
- `bin\FarCry6.exe` SHA-256: `820537DDCD6A26A54C6A3CA52786780D6834C691F41D2107E05709B95D520E12`
  (FileVersion `1, 0, 0, 0`, size 345920)
- `bin\FC_m64d3d12.dll` SHA-256: `E82C7320C8554D0AC975C256DB1C79EC046C0448E5B81BF50E3012B3642061AA`
  (size 521313320)
- Engine: Dunia (Far Cry series engine; FC3/FC4 entries in coop-anything list Dunia)
- OS: Windows 11 Pro 10.0.26200
- Status: install NOT confirmed as original. `bin` contains third-party DLLs (details in `local/`, not
  committed). AGENTS.md rule 5/6: no analysis until the owner restores original files
  (Steam → Properties → Installed Files → "Verify integrity of game files") and hashes are re-taken.

## Phase 0–1: research, 2026-10-18

### Observations (with sources)

- Official co-op is 2 players, online only, no split screen.
  https://www.gamesradar.com/far-cry-6-co-op/ , https://game8.co/games/FarCry6/archives/346051
- Campaign progress is saved for the host only (per guide, not Ubisoft).
  https://expertbeacon.com/how-many-co-op-players-in-far-cry-6/
- Ubisoft store: Denuvo DRM required to launch; Ubisoft account + Ubisoft Connect required.
  https://store.ubisoft.com/us/far-cry-6-gold-edition/5ecd2d555cdf9a1528a8c1d4.html?lang=en_US
- coop-anything DIRECTORY.md / data/directory.yaml: no Far Cry 6 entry (checked 2026-10-18).
- Far Cry 4 has an "-IN TESTING- Removes Co-op 2 Player Limit" mod on Nexus. Search snippet says the
  author thinks the approach may apply to FC3/5/6 (same engine) and that a 3rd player may spawn
  invisible / T-posed / as a duplicate. Nexus page itself could not be fetched (DNS blocked here).
  https://www.nexusmods.com/farcry4/mods/179

### Not found by these searches

- WebSearch "Far Cry 6 4 player co-op mod" (extended), "nexusmods farcry6 multiplayer lobby player limit mod"
  (extended), "Far Cry 6 кооп на 4 игрока мод": no Far Cry 6 mod that raises the co-op cap.
- Not yet checked: GitHub code/repo search, Nexus FC6 file list directly, Reddit, FC modding Discords,
  coop-anything open issues/PRs (no gh/API access to that repo from this session).

### Unknowns

- Whether FC6 co-op traffic is peer-to-peer or relayed by Ubisoft servers.
- Whether the 2-player cap is enforced client-side, in Ubisoft's matchmaking service, or both.
- Whether the FC4 mod technique actually works on FC6.

## Research round 2, 2026-10-18 (owner wants 5 players; DRM bypass refused)

### Observations (with sources)

- FC4 cap mod: per search snippet of the Nexus page, author used Ghidra + x64dbg to find and patch the
  code behind the 2-player limit; install copies files into `bin`, backing up `FC64.dll`,
  `patch_hd.dat`, `patch_hd.fat`; all lobby members need the mod. https://www.nexusmods.com/farcry4/mods/179
  (page itself not fetched: host blocked by this environment's network policy).
- FC6 game code DLL: an FOV mod replaces `FC_m64d3d12.dll` in `bin` (`bin_plus` for Ubisoft+).
  https://www.pcgamer.com/far-cry-6-mod-lets-you-change-fov-while-driving-and-horsing-around/
- Forum post: swapping that DLL between `bin` and `bin_plus` stops launch ("verification of uplay").
  https://fearlessrevolution.com/viewtopic.php?t=17693&start=90
- PCGamingWiki (via search snippet): all versions need Ubisoft Connect, Denuvo Anti-Piracy and VMProtect.
  https://www.pcgamingwiki.com/wiki/Far_Cry_6 (page itself not fetched: blocked host).
- Forum: Ubisoft uses VMProtect mutation in FC6 code, complicating analysis.
  https://fearlessrevolution.com/viewtopic.php?t=17693&start=90
- FC5 (Dunia, predecessor): no campaign mod above 2 players found; Arcade mode supports more players.
  https://steamcommunity.com/app/552520/discussions/0/4352239903169408552/ ,
  https://expertbeacon.com/does-far-cry-5-have-4-player-co-op/
- Tools: Gibbed.Dunia (Dunia file formats) https://github.com/gibbed/Gibbed.Dunia ; Ultimate ASI Loader
  https://github.com/ThirteenAG/Ultimate-ASI-Loader ; FC6 Mod Installer (Libertad Mod team, .a3 packages)
  https://www.gamepressure.com/download/far-cry-6-mod-installer-v-20220811-0000/z313870

### Derived (not verified)

- Since FC6 code lives in `FC_m64d3d12.dll` like FC4's `FC64.dll`, the FC4 approach (find the cap, patch it)
  is the closest template. Patching the DLL file on disk likely conflicts with Denuvo/VMProtect integrity
  checks -> off limits. A runtime patch of the cap value after the game has started (DRM left running and
  untouched) does not bypass DRM, but still changes a session hosted through Ubisoft's online service.

### Guesses (labelled)

- Even if the cap is lifted, extra players may be invisible/T-posed (as the FC4 author warns) and story
  scripts assume 2 players. Chance of a playable 5-player campaign: low.

### Blockers / contradictions (rule 6, rule 10)

- Raising the cap means patching a Denuvo-protected exe and/or altering sessions that run through
  Ubisoft's online services. AGENTS.md rule 10 forbids DRM bypass for online services.
- Owner decision 2026-10-18: research and try; DRM bypass stays off the table.

## Update 2026-10-18: FC4 cap mod hidden

- Observation (owner pasted the page text): https://www.nexusmods.com/farcry4/mods/179 shows "Hidden mod", hidden at 18 Oct 2026, 6:30AM by PropertyNotYours: "The mod has (possible) permission issues that the author is working to address."
- Consequence: the patch details cannot be read. Unofficial mirrors are not used (AGENTS.md rule 8, permission issue stated by Nexus).
- Next step: find the 2-player cap in FC6 ourselves, after the install is restored to original files.
