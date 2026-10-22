# Лаунчер FarCryCoop

Приложение на Tauri 2: Rust в `src/main.rs` (запуск игры) и `src/lobby.rs` (лобби по TCP 49002), интерфейс в `ui/index.html` (обычный JS, без npm). Лаунчер кладётся в папку игры рядом с `Bin32`. Не в саму `Bin32`: Windows сначала грузит DLL из папки exe, и старые игровые `version.dll` / `dbghelp.dll` оттуда его роняют. Как он общается с игрой: [../NOTES.ru.md](../NOTES.ru.md), спайк 10.

Список карт идёт в сюжетном порядке (`STORY` в `src/main.rs`, порядок `DEFIANT` из `defiant.lua` игры), дальше сохранения хоста как `save:<имя>` (файлы `Mods\FarCryCoop\save_<имя>.lua`). Сложность (0–4) хранится вместе с остальными настройками и попадает в строку консоли как `COOP_Difficulty`. Подробности: [../NOTES.ru.md](../NOTES.ru.md), спайки 11 и 12.

## Сборка

```powershell
& games\far-cry\launcher\build.ps1   # -> E:\FarCryCoop\Temp\launcher\FarCryCoopLauncher.exe
```

Нужно:
- Rust, установленный с `RUSTUP_HOME=E:\FarCryCoop\Data\rustup` и `CARGO_HOME=E:\FarCryCoop\Data\cargo` (обе переменные ставит `env.ps1`), хост `i686-pc-windows-msvc`;
- MSVC в `D:\TailCore\toolchain\vs`;
- x86-библиотеки SDK в `E:\FarCryCoop\Tools\winsdk-x86`.

CRT линкуется статически. Среда WebView2 входит в Windows 10/11.

## Запуск при разработке

Вне папки игры лаунчер ищет игру в `FARCRYCOOP_GAME`:

```powershell
$env:FARCRYCOOP_GAME = 'D:\SteamLibrary\steamapps\common\FarCry'
& E:\FarCryCoop\Temp\launcher\FarCryCoopLauncher.exe
```

Лаунчер хранит настройки (`FarCryCoopLauncher.json`) и профиль WebView2 (`FarCryCoopLauncherData\`) рядом со своим exe. В `%LOCALAPPDATA%` ничего не пишется.
