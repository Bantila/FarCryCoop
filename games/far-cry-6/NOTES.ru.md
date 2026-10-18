# Far Cry 6 — заметки по кооперативу

English version: [NOTES.md](NOTES.md)

Цель владельца: кооператив на 5 игроков (подтверждено владельцем 2026-10-18: «я + 4 друга»).

## Данные игры (правило 5 из AGENTS.md)

Наблюдение 2026-10-18 на ПК владельца (только чтение):

- Магазин: Steam, app 2369390 (`appmanifest_2369390.acf`)
- Номер сборки Steam: 11359732 (`buildid` = `TargetBuildID`)
- `bin\FarCry6.exe` SHA-256: `820537DDCD6A26A54C6A3CA52786780D6834C691F41D2107E05709B95D520E12`
  (FileVersion `1, 0, 0, 0`, размер 345920)
- `bin\FC_m64d3d12.dll` SHA-256: `E82C7320C8554D0AC975C256DB1C79EC046C0448E5B81BF50E3012B3642061AA`
  (размер 521313320)
- Движок: Dunia (движок серии Far Cry; в coop-anything у FC3/FC4 указан Dunia)
- ОС: Windows 11 Pro 10.0.26200
- Статус: установка НЕ подтверждена как оригинальная. В `bin` есть сторонние DLL (подробности в
  `local/`, не коммитится). Правила 5/6 AGENTS.md: анализа нет, пока владелец не вернёт оригинальные
  файлы (Steam → Свойства → Установленные файлы → «Проверить целостность файлов игры») и хэши не
  будут сняты заново.

## Фазы 0–1: исследование, 2026-10-18

### Наблюдения (с источниками)

- Штатный кооп — 2 игрока, только онлайн, без разделённого экрана.
  https://www.gamesradar.com/far-cry-6-co-op/ , https://game8.co/games/FarCry6/archives/346051
- Прогресс кампании сохраняется только у хоста (по гайду, не по данным Ubisoft).
  https://expertbeacon.com/how-many-co-op-players-in-far-cry-6/
- Магазин Ubisoft: для запуска нужен Denuvo DRM; нужны аккаунт Ubisoft и Ubisoft Connect.
  https://store.ubisoft.com/us/far-cry-6-gold-edition/5ecd2d555cdf9a1528a8c1d4.html?lang=en_US
- coop-anything DIRECTORY.md / data/directory.yaml: записи о Far Cry 6 нет (проверено 2026-10-18).
- Для Far Cry 4 на Nexus есть мод «-IN TESTING- Removes Co-op 2 Player Limit». По фрагменту из поиска,
  автор считает, что подход может подойти для FC3/5/6 (тот же движок), а третий игрок может появиться
  невидимым / в T-позе / копией другого персонажа. Саму страницу Nexus открыть не удалось (DNS
  заблокирован в этой среде).
  https://www.nexusmods.com/farcry4/mods/179

### Не найдено этими поисками

- WebSearch «Far Cry 6 4 player co-op mod» (extended), «nexusmods farcry6 multiplayer lobby player limit mod»
  (extended), «Far Cry 6 кооп на 4 игрока мод»: мода для Far Cry 6, поднимающего лимит коопа, нет.
- Ещё не проверено: поиск по коду/репозиториям GitHub, список файлов FC6 на Nexus напрямую, Reddit,
  Discord-сообщества моддеров Far Cry, открытые issue/PR в coop-anything (из этой сессии нет доступа
  к этому репозиторию через gh/API).

### Неизвестно

- Идёт ли трафик коопа FC6 напрямую между игроками (peer-to-peer) или через серверы Ubisoft.
- Где проверяется лимит в 2 игрока: в клиенте игры, в сервисе подбора Ubisoft или в обоих местах.
- Работает ли техника мода для FC4 на FC6.

## Исследование, раунд 2, 2026-10-18 (владелец хочет 5 игроков; обход DRM отклонён)

### Наблюдения (с источниками)

- Мод лимита для FC4: по фрагменту страницы Nexus из поиска, автор с помощью Ghidra + x64dbg нашёл и
  пропатчил код, отвечающий за лимит в 2 игрока; установка — копирование файлов в `bin` с резервными
  копиями `FC64.dll`, `patch_hd.dat`, `patch_hd.fat`; мод нужен всем в лобби.
  https://www.nexusmods.com/farcry4/mods/179 (саму страницу открыть не удалось: сайт заблокирован
  сетевой политикой этой среды).
- DLL с кодом игры FC6: мод на FOV заменяет `FC_m64d3d12.dll` в `bin` (`bin_plus` для Ubisoft+).
  https://www.pcgamer.com/far-cry-6-mod-lets-you-change-fov-while-driving-and-horsing-around/
- Сообщение на форуме: если поменять эту DLL местами между `bin` и `bin_plus`, игра не запускается
  («verification of uplay»).
  https://fearlessrevolution.com/viewtopic.php?t=17693&start=90
- PCGamingWiki (по фрагменту из поиска): во всех версиях нужны Ubisoft Connect, Denuvo Anti-Piracy и VMProtect.
  https://www.pcgamingwiki.com/wiki/Far_Cry_6 (саму страницу открыть не удалось: сайт заблокирован).
- Форум: Ubisoft применяет мутацию VMProtect в коде FC6, это усложняет анализ.
  https://fearlessrevolution.com/viewtopic.php?t=17693&start=90
- FC5 (Dunia, предшественник): мода на кампанию больше чем на 2 игроков не найдено; в режиме Arcade
  игроков может быть больше.
  https://steamcommunity.com/app/552520/discussions/0/4352239903169408552/ ,
  https://expertbeacon.com/does-far-cry-5-have-4-player-co-op/
- Инструменты: Gibbed.Dunia (форматы файлов Dunia) https://github.com/gibbed/Gibbed.Dunia ; Ultimate ASI Loader
  https://github.com/ThirteenAG/Ultimate-ASI-Loader ; FC6 Mod Installer (команда Libertad Mod, пакеты .a3)
  https://www.gamepressure.com/download/far-cry-6-mod-installer-v-20220811-0000/z313870

### Выводы (не проверены)

- Код FC6 лежит в `FC_m64d3d12.dll`, как код FC4 в `FC64.dll`, поэтому подход FC4 (найти лимит и
  пропатчить) — ближайший образец. Изменение DLL на диске, вероятно, конфликтует с проверками
  целостности Denuvo/VMProtect -> запрещено. Изменение значения лимита в памяти уже запущенной игры
  (DRM работает и не тронут) не является обходом DRM, но всё равно меняет сессию, которая идёт через
  онлайн-сервис Ubisoft.

### Догадки (помечены)

- Даже если лимит снять, лишние игроки могут быть невидимыми / в T-позе (как предупреждает автор мода
  для FC4), а сюжетные скрипты рассчитаны на 2 игроков. Шанс на играбельную кампанию впятером: низкий.

### Препятствия / противоречия (правила 6 и 10)

- Чтобы поднять лимит, нужно патчить exe, защищённый Denuvo, и/или менять сессии, которые идут через
  онлайн-сервисы Ubisoft. Правило 10 из AGENTS.md запрещает обход DRM ради онлайн-сервисов.
- Решение владельца 2026-10-18: исследовать и пробовать; обход DRM исключён.
