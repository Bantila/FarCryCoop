# Workspace

Russian version: [workspace.ru.md](workspace.ru.md)

All work happens in `E:\FarCryCoop` (see the golden rule 2 in [CLAUDE.md](../CLAUDE.md)).
Load the environment first: `. E:\FarCryCoop\env.ps1`.

| Folder | Contents |
|---|---|
| `Downloads\<name>\` | Original archives, one folder each, SHA-256 checked |
| `Tools\` | Unpacked portable tools |
| `Data\` | Tool settings and caches (Ghidra settings/cache, npm cache, npm global prefix) |
| `Temp\` | Temporary files (`TEMP`/`TMP` point here) |
| `FarCryCoop\`, `FarCry<N>Coop\` | Repositories, one folder per game |

## Installed tools (2026-10-18)

| Tool | Version | Source | SHA-256 (archive) |
|---|---|---|---|
| Node.js | v24.22.0 LTS (win-x64 zip) | https://nodejs.org/dist/v24.22.0/ | `f9683a19877e12a9b167305c8db71040d812876359de21f0d2e97c3f321f80c3` |
| Eclipse Temurin JDK | 21.0.12.1+1 (x64 zip) | https://github.com/adoptium/temurin21-binaries/releases/tag/jdk-21.0.12.1%2B1 | `f9d6e191ab098c0d416e7d588a24420a8621cd2f4720dab2459b8b7b2d2d8b4e` |
| Ghidra | 12.1.4 (`ghidra_12.1.4_PUBLIC_20260921.zip`) | https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build | `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db` |

Checksums came from nodejs.org `SHASUMS256.txt`, the Adoptium API and the Ghidra GitHub release;
all three downloads matched.

Ghidra `support\launch.properties` was changed (original kept as `launch.properties.orig`):
`JAVA_HOME_OVERRIDE`, `application.settingsdir`, `application.cachedir`, `application.tempdir`,
`java.io.tmpdir` point into `E:\FarCryCoop`. Check run: `analyzeHeadless.bat` printed its usage and
created its settings/cache folders under `E:\FarCryCoop\Data`.

## Known limits of "never touch C:"

- Claude Code itself, Windows, PowerShell and the system `git.exe` (`C:\Program Files\Git`) live on C:.
  They are used as installed; nothing new is written there by our tools.
- `claude mcp add --scope local` (the REA setup route) writes to `%USERPROFILE%\.claude.json` on C:.
  Not done; needs the owner's decision.
