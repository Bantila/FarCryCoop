# Рабочая папка

English version: [workspace.md](workspace.md)

Вся работа идёт в `E:\FarCryCoop` (см. золотое правило 2 в [CLAUDE.md](../CLAUDE.md)).
Сначала загрузить окружение: `. E:\FarCryCoop\env.ps1`.

| Папка | Содержимое |
|---|---|
| `Downloads\<имя>\` | Исходные архивы, у каждого своя папка, SHA-256 проверен |
| `Tools\` | Распакованные портативные инструменты |
| `Data\` | Настройки и кэши инструментов (настройки/кэш Ghidra, кэш npm, глобальный префикс npm) |
| `Temp\` | Временные файлы (сюда указывают `TEMP`/`TMP`) |
| `FarCryCoop\`, `FarCry<N>Coop\` | Репозитории, по одной папке на игру |

## Установленные инструменты (2026-10-18)

| Инструмент | Версия | Источник | SHA-256 (архив) |
|---|---|---|---|
| Node.js | v24.22.0 LTS (zip win-x64) | https://nodejs.org/dist/v24.22.0/ | `f9683a19877e12a9b167305c8db71040d812876359de21f0d2e97c3f321f80c3` |
| Eclipse Temurin JDK | 21.0.12.1+1 (zip x64) | https://github.com/adoptium/temurin21-binaries/releases/tag/jdk-21.0.12.1%2B1 | `f9d6e191ab098c0d416e7d588a24420a8621cd2f4720dab2459b8b7b2d2d8b4e` |
| Ghidra | 12.1.4 (`ghidra_12.1.4_PUBLIC_20260921.zip`) | https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build | `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db` |

Контрольные суммы взяты из `SHASUMS256.txt` на nodejs.org, API Adoptium и релиза Ghidra на GitHub;
все три загрузки совпали.

В Ghidra изменён `support\launch.properties` (оригинал сохранён как `launch.properties.orig`):
`JAVA_HOME_OVERRIDE`, `application.settingsdir`, `application.cachedir`, `application.tempdir`,
`java.io.tmpdir` указывают в `E:\FarCryCoop`. Проверка: `analyzeHeadless.bat` вывел справку и
создал папки настроек/кэша в `E:\FarCryCoop\Data`.

## Известные пределы правила «не трогать C:»

- Сам Claude Code, Windows, PowerShell и системный `git.exe` (`C:\Program Files\Git`) находятся на C:.
  Они используются как установлены; наши инструменты туда ничего нового не пишут.
- `claude mcp add --scope local` (способ подключения REA) пишет в `%USERPROFILE%\.claude.json` на C:.
  Не сделано; нужно решение владельца.
