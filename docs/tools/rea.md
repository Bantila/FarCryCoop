# REA (Reverse Engineer Anything)

Russian version: [rea.ru.md](rea.ru.md)

- Repository: https://github.com/morluto/rea (MIT). npm package: `rea-agents`.
- What it is: one MCP server + CLI that gives an agent reverse-engineering tools (native binaries via
  Ghidra / IDA / Hopper, JavaScript/Electron, .NET, websites). Analysis runs locally.
- Version checked: 6.7.0 (`server.json`, `package.json`, commit `a25eb5fb`, 2026-10-18).

## Why it is NOT registered in this repository's `.mcp.json`

REA's own docs (`docs/installation.md`, "One project") say: avoid `--scope project`, which writes
`.mcp.json` into the repository where it can be committed or copied. Use Claude Code's local scope instead.
It also only makes sense on the owner's PC: the game files and Ghidra are there, not in the cloud session.

## Setup on the owner's Windows PC (per REA docs)

Requirements from `docs/windows-ghidra-p0.md` (Windows support is **experimental**, read-only):

- Windows 10+ x64, game copy on a local NTFS drive;
- Node.js 22.x (>=22.19), 24.x (>=24.11) or 26+;
- Ghidra 12.1.x installed by you (verified with 12.1.4) — REA never installs it;
- 64-bit full JDK 21+ inside Ghidra's declared Java range.

Steps (PowerShell, from the project folder):

```powershell
Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
claude mcp add --scope local rea -- cmd.exe /d /c npx -y rea-agents@6.7.0 mcp
$env:GHIDRA_INSTALL_DIR = "C:\tools\ghidra_12.1.4_PUBLIC"   # your path
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"              # your path
npx -y rea-agents@6.7.0 doctor --json
claude mcp list
```

Local scope stores the entry in `%USERPROFILE%\.claude.json` for this folder only. It does not install
REA's skill. Remove with `claude mcp remove --scope local rea` from the same folder.
Alternative: `npx rea-agents setup` registers REA for every project (user scope) and installs the skill.

## Rules that apply to us

- AGENTS.md rule 2: analyse only a **copy** of the game folder, never the install.
- REA's `DISCLAIMER.md` says the project does not support "circumventing DRM, license checks,
  anti-cheat systems or other technical protection measures" or "developing game cheats or tampering
  with online services". Same line as AGENTS.md rule 10.
- Windows Ghidra P0 is read-only: REA does not change executable bytes.

## Unknown / guess

- Guess, not verified: `FC_m64d3d12.dll` is protected by Denuvo and VMProtect, so static Ghidra
  analysis may show little useful code. Unknown until tried on the owner's copy.
