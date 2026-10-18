# Project rules for Claude / Правила проекта для Claude

## Golden rule / Золотое правило

**EN:** ALWAYS write documentation and every other human-readable project text (README, notes,
guides, comments in docs, issue/PR descriptions) in BOTH Russian and English. No exceptions.
Use a pair of files `NAME.md` (English) + `NAME.ru.md` (Russian), or both languages in one file
for short texts. When one language version changes, update the other in the same commit.

**RU:** ВСЕГДА пиши документацию и любые другие тексты проекта для людей (README, заметки,
руководства, комментарии в документах, описания issue/PR) на ДВУХ языках: русском и английском.
Без исключений. Используй пару файлов `NAME.md` (английский) + `NAME.ru.md` (русский) или оба
языка в одном файле для коротких текстов. Если меняется одна языковая версия, обнови другую в
том же коммите.

## Golden rule 2: workspace / Золотое правило 2: рабочая папка

**EN:** Work ONLY inside `E:\FarCryCoop`. NEVER read, write or download anything on drive C: —
no exceptions. NEVER download into `%TEMP%`. Before running any tool, load `. E:\FarCryCoop\env.ps1`
(it points TEMP/TMP, npm cache, JAVA_HOME, Ghidra to `E:\FarCryCoop`). Layout:
`Downloads\<name>\` — verified archives (one folder each); `Tools\` — unpacked tools;
`Data\` — tool settings and caches; `Temp\` — temporary files. The game at
`D:\SteamLibrary\steamapps\common\Far Cry 6` is read-only (AGENTS.md rule 2); work on copies in
`E:\FarCryCoop`. If a step would need drive C:, stop and ask the owner.

**RU:** Работать ТОЛЬКО внутри `E:\FarCryCoop`. НИКОГДА ничего не читать, не писать и не скачивать
на диск C: — без исключений. НИКОГДА не качать в `%TEMP%`. Перед запуском любых инструментов
загружать `. E:\FarCryCoop\env.ps1` (он направляет TEMP/TMP, кэш npm, JAVA_HOME, Ghidra в
`E:\FarCryCoop`). Структура: `Downloads\<имя>\` — проверенные архивы (у каждого своя папка);
`Tools\` — распакованные инструменты; `Data\` — настройки и кэши инструментов; `Temp\` — временные
файлы. Игра в `D:\SteamLibrary\steamapps\common\Far Cry 6` — только чтение (правило 2 AGENTS.md);
работать с копиями в `E:\FarCryCoop`. Если шаг требует диска C:, остановиться и спросить владельца.

## Commits / Коммиты

**EN:** Commit messages follow Conventional Commits (https://www.conventionalcommits.org/en/v1.0.0/)
and are written in English only: `<type>(<optional scope>): <description>`, e.g.
`docs(far-cry-6): add research notes`. Types: feat, fix, docs, chore, refactor, test, build, ci, perf, style, revert.

**RU:** Сообщения коммитов пишутся по Conventional Commits и только на английском:
`<тип>(<область, необязательно>): <описание>`, например `docs(far-cry-6): add research notes`.

## Tools / Инструменты

**EN:** Reverse engineering uses REA (https://github.com/morluto/rea) as an MCP server, registered
locally on the owner's PC: see [docs/tools/rea.md](docs/tools/rea.md).

**RU:** Для реверс-инжиниринга используется REA (https://github.com/morluto/rea) как MCP-сервер,
подключённый локально на ПК владельца: см. [docs/tools/rea.ru.md](docs/tools/rea.ru.md).

## Communication / Общение

**EN:** Chat with the owner in Russian.

**RU:** С владельцем общаться по-русски.
