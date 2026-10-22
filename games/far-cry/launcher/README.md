# FarCryCoop launcher

A Tauri 2 app: Rust in `src/main.rs` (game start) and `src/lobby.rs` (lobby over TCP 49002), UI in `ui/index.html` (plain JS, no npm). It goes into the game folder, next to `Bin32`. Not into `Bin32`: Windows loads DLLs from the exe's folder first, and the game's old `version.dll` / `dbghelp.dll` there crash it. How it talks to the game: [../NOTES.md](../NOTES.md), Spike 10.

The map list is in story order (`STORY` in `src/main.rs`, the order of `DEFIANT` in the game's `defiant.lua`), followed by the host's saves as `save:<name>` (the files `Mods\FarCryCoop\save_<name>.lua`). The difficulty (0-4) is saved with the other settings and goes into the console line as `COOP_Difficulty`. Details: [../NOTES.md](../NOTES.md), Spikes 11 and 12.

## Build

```powershell
& games\far-cry\launcher\build.ps1   # -> E:\FarCryCoop\Temp\launcher\FarCryCoopLauncher.exe
```

You need:
- Rust installed with `RUSTUP_HOME=E:\FarCryCoop\Data\rustup` and `CARGO_HOME=E:\FarCryCoop\Data\cargo` (`env.ps1` sets both), with host `i686-pc-windows-msvc`;
- MSVC in `D:\TailCore\toolchain\vs`;
- the x86 SDK libs in `E:\FarCryCoop\Tools\winsdk-x86`.

The CRT is linked statically. The WebView2 runtime ships with Windows 10/11.

## Development run

Outside the game folder, the launcher looks for the game in `FARCRYCOOP_GAME`:

```powershell
$env:FARCRYCOOP_GAME = 'D:\SteamLibrary\steamapps\common\FarCry'
& E:\FarCryCoop\Temp\launcher\FarCryCoopLauncher.exe
```

The launcher keeps its settings (`FarCryCoopLauncher.json`) and the WebView2 profile (`FarCryCoopLauncherData\`) next to its exe. Nothing goes to `%LOCALAPPDATA%`.
