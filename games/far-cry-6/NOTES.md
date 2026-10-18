# Far Cry 6 — co-op notes

Goal from owner: co-op for more than 2 players (owner said "up to 4", and also "me + 4 friends" = 5; to be clarified).

## Game identity (AGENTS.md rule 5)

- Store: unknown (ask owner: Steam app 2369390 / Ubisoft Connect / Epic)
- Version / build id: unknown
- SHA-256 of main exe: unknown
- Engine: Dunia (Far Cry series engine; FC3/FC4 entries in coop-anything list Dunia)
- OS: Windows (owner's PC), unknown version

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

### Blockers / contradictions (rule 6, rule 10)

- Raising the cap means patching a Denuvo-protected exe and/or altering sessions that run through
  Ubisoft's online services. AGENTS.md rule 10 forbids DRM bypass for online services. Needs owner
  decision before any reverse engineering.
