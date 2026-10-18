# REA (Reverse Engineer Anything)

English version: [rea.md](rea.md)

- Репозиторий: https://github.com/morluto/rea (MIT). Пакет npm: `rea-agents`.
- Что это: MCP-сервер + CLI, дающий агенту инструменты реверс-инжиниринга (нативные бинарники через
  Ghidra / IDA / Hopper, JavaScript/Electron, .NET, сайты). Анализ выполняется локально.
- Проверенная версия: 6.7.0 (`server.json`, `package.json`, коммит `a25eb5fb`, 2026-10-18).

## Почему REA НЕ прописан в `.mcp.json` этого репозитория

Документация REA (`docs/installation.md`, раздел «One project») советует не использовать
`--scope project`, который пишет `.mcp.json` в репозиторий, откуда его можно закоммитить или скопировать.
Вместо этого — локальная область (local scope) Claude Code. Кроме того, REA имеет смысл только на ПК
владельца: там файлы игры и Ghidra, а не в облачной сессии.

## Установка на Windows-ПК владельца (по документации REA)

Требования из `docs/windows-ghidra-p0.md` (поддержка Windows **экспериментальная**, только чтение):

- Windows 10+ x64, копия игры на локальном диске NTFS;
- Node.js 22.x (>=22.19), 24.x (>=24.11) или 26+;
- Ghidra 12.1.x, установленная вами (проверено на 12.1.4) — REA её никогда не ставит;
- 64-битный полный JDK 21+ в пределах версий Java, указанных в Ghidra.

Шаги (PowerShell, из папки проекта):

```powershell
Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
claude mcp add --scope local rea -- cmd.exe /d /c npx -y rea-agents@6.7.0 mcp
$env:GHIDRA_INSTALL_DIR = "C:\tools\ghidra_12.1.4_PUBLIC"   # ваш путь
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"              # ваш путь
npx -y rea-agents@6.7.0 doctor --json
claude mcp list
```

Локальная область хранит запись в `%USERPROFILE%\.claude.json` только для этой папки. Навык (skill) REA
при этом не ставится. Удаление: `claude mcp remove --scope local rea` из той же папки.
Альтернатива: `npx rea-agents setup` регистрирует REA для всех проектов (user scope) и ставит навык.

## Правила, которые нас касаются

- Правило 2 из AGENTS.md: анализируем только **копию** папки игры, не установку.
- `DISCLAIMER.md` REA: проект не поддерживает «circumventing DRM, license checks, anti-cheat systems or
  other technical protection measures» (обход DRM, проверок лицензии, античитов и других мер защиты) и
  «developing game cheats or tampering with online services» (создание читов и вмешательство в
  онлайн-сервисы). Та же граница, что и правило 10 из AGENTS.md.
- Windows Ghidra P0 работает только на чтение: REA не меняет байты исполняемых файлов.

## Неизвестно / догадка

- Догадка, не проверено: `FC_m64d3d12.dll` защищена Denuvo и VMProtect, поэтому статический анализ
  в Ghidra может показать мало полезного кода. Неизвестно, пока не попробуем на копии владельца.
