# Far Cry (2004) — заметки по кооперативу

English version: [NOTES.md](NOTES.md)

Статус: разведка (ветка `game/far-cry`, начата 2026-10-18). Цель: кооперативное прохождение кампании до 4 игроков, подключение через общий лаунчер серии (друзья Steam, Spacewar AppID 480, код комнаты).

## Данные игры (правило 5 AGENTS.md)

- Магазин / владение: Steam app 13520, installed in D:\SteamLibrary
- Версия / номер сборки: 1.4.0.1405 (из `log.txt`)
- SHA-256 основного exe: `Bin32\FarCry.exe` `21a907fae0b6e2d4b10d546dba0965ef89c39a69f8cb00036307c0564ca1a813`; `CryGame.dll` `db9c7660b698600ae34dd4a18f7ca5989911ad51bf9286ba1cc047ae52ef7634`; `CryNetwork.dll` `10aed71c092c4f057edcba49a593b569dab9fc10a263b48e60f973065bdaa908`
- Движок: CryEngine 1
- Установка проверена на сторонние DLL: да. В `Bin32` и `Bin64`: `version.dll` (ASI-загрузчик), `SilentPatchFarCry.asi`, `FarCry.WidescreenFix.asi`; мод `Mods\FarOut_Widescreen`; `FCData\Tent AI Bug Fix.pak`. PunkBuster в `Pb\`. В `Bin64` нет 64-битного exe игры, только эти дополнения.

## Что известно

- Штатного коопа нет; есть соревновательный мультиплеер. Моды: Assault Coop (частично, ~7 карт кампании, 2011) https://www.moddb.com/mods/assault-coop ; FCAV (кооп анонсирован, не вышел) https://farcry1.itch.io/far-cry-advanced-version (источник: coop-anything data/directory.yaml, проверено 2026-10-16).

## Разведка 2026-10-18

Рабочая копия: `E:\FarCryCoop\Workar-cry\Bin32` (exe и DLL) и `Workar-cry\scripts` (распакованный `FCData\Scripts.pak`).

- Одиночная игра уже работает как локальный сервер плюс локальный клиент. В `Scripts\Default\gamerules.lua` (правила одиночной игры) есть `OnClientConnect`, `OnClientDisconnect` и `RespawnPlayer` для каждого `server_slot`. Возрождение уже идёт на последний чекпоинт (`_LastCheckPPos`).
- Тип игры задаёт глобальная переменная Lua `g_GameType`. Кампания ставит `Default` (`MenuScreens\Campaign.lua`). Мультиплеер ставит `ASSAULT`, `FFA` или `TDM` и запускает карту через `Game:LoadLevelMPServer`. Меню создания сервера скрывает `Default`.
- Каждый уровень перечисляет свои миссии в `levelinfo.xml`. У карты кампании `Training` миссия `Training` (`mission_training.xml`); у MP-карты `mp_airstrip` миссия `ASSAULT`. `Game:CheckMap(map, gametype)` проверяет этот список перед загрузкой MP-карты.
- Моды лежат в `Mods\<имя>\` со своими `.pak`, которые подменяют скрипты. Кооп-мод может быть папкой мода; бинарники игры не трогаем, пока хватает Lua.
- Официальный CryENGINE MOD SDK 1.4 содержит исходники C++ `CryGame.dll` (игровая DLL: логика сервера и клиента). Используем только этот официальный SDK, не утёкшие исходники движка.

Догадка, не проверено: хост может запустить карту кампании как MP-сервер с `g_GameType=Default` и миссией `Training`, и удалённые клиенты получат правила одиночной игры. Неизвестно: что сторона C++ (`CXServer`, `CXClient`, ИИ, катсцены, сохранения) делает с несколькими клиентами в миссии кампании.

Не сделано: REA не подключён в этой сессии (см. `docs/tools/rea.ru.md`), анализа в Ghidra пока нет. Страница Assault Coop на moddb вернула HTTP 403.

## Спайк 1 — карта кампании как сетевой сервер (2026-10-18, работает)

Запуск из установки в `D:` (разовое исключение от владельца из правила работы с копией; игра сама переписала там свои `log.txt` / `log_WinSV.txt`, мы файлы не меняли).

Что сработало:
1. `Bin32\FarCry_WinSV.exe -DEVMODE` (Lua-команды консоли через `#` работают только с `-DEVMODE`; строка ввода консоли ограничена примерно 100 символами).
2. В консоли сервера, после баннера (команды из командной строки выполняются слишком рано и игнорируются):
   ```
   #AvailableMODList.DEFAULT={team=0,respawntime=0,mission="Training"}
   g_GameType DEFAULT
   start_server Training
   ```
   `start_server` берёт миссию из `AvailableMODList[g_GameType]`; `Game:CheckMap("Training","Training")` = 1, с `"Default"` = nil.
3. Клиент: обычный `Bin32\FarCry.exe`, Multiplayer -> LAN -> подключиться. (С `"connect 127.0.0.1"` или `r_Width` в командной строке клиент закрывался сразу после инициализации; `connect` в консоли главного меню ничего не делал.)

Результат: сервер загрузил `Training` с правилами одиночной игры `GameRules` (655 сущностей). Клиент получил слот 1, сущность игрока на первой точке возрождения со здоровьем 255, обычный HUD, может ходить, стрелять и играть. Два процесса (выделенный сервер + клиент) работают на одном ПК.

Ещё не проверено: задания миссии, поведение ИИ, катсцены, чекпоинты, второй удалённый игрок.

## Следующие шаги

1. Спайк: запустить `Training` как MP-сервер с `g_GameType=Default` и подключиться вторым экземпляром по LAN. Записать, что ломается.
2. Скачать CryENGINE MOD SDK 1.4 в `Downloadsarcry-sdk-1.4\`, проверить SHA-256, прочитать код `CXServer`/`CXClient`/правил игры.
3. Транспорт Steam P2P: найти, где `CryNetwork.dll` открывает UDP-сокет, чтобы спланировать туннель для лаунчера.
4. PunkBuster остаётся выключенным (`sv_punkbuster 0`); его не трогаем (правило 10 AGENTS.md).
