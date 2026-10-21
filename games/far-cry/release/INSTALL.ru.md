# FarCryCoop 0.2 бета — кооператив кампании Far Cry (2004)

Проходите кампанию Far Cry вместе: один игрок хостит, друзья подключаются. Это бета: будут баги.

## Что нужно
- Far Cry версии 1.4 (версия из Steam / GOG — 1.4). У всех должна быть одна и та же версия мода.
- Windows 10 или 11.

## Установка (у каждого игрока)
1. Скопируйте папки `Mods` и `Bin32` из архива в папку Far Cry (в Steam: `steamapps\common\FarCry`). Разрешите слияние.
2. `Bin32\dinput8.dll` — это Ultimate ASI Loader, он загружает `FarCryCoopNet.asi`. Если в вашей `Bin32` уже есть ASI-загрузчик (`version.dll` или `dinput8.dll` от широкоэкранного фикса), `dinput8.dll` не копируйте.
3. Запускайте игру через `Bin32\FarCryCoop.bat` (он запускает `FarCry.exe -DEVMODE -MOD:FarCryCoop`).

## Хост
1. Запустите игру через `FarCryCoop.bat`.
2. Откройте консоль клавишей `~` и наберите, например: `#CoopMap("pier")`
   Карты: training, fort, pier, carrier, factory, research, treehouse, bunker, rebellion, steam, archive, control, swamp, catacombs, river, boat, dam, cooler, regulator, volcano.
3. Друзьям через интернет нужен ваш IP и открытый UDP-порт 49001 (проброс порта или виртуальная сеть вроде Radmin VPN или ZeroTier).

## Подключение
1. Запустите игру через `FarCryCoop.bat`.
2. Multiplayer, LAN: там появится игра хоста. Или откройте консоль (`~`) и наберите `connect <IP хоста>`.

## Полезные команды консоли (у хоста)
- `#CoopGod(1)` / `#CoopGod(0)` — бессмертие для всех вкл./выкл.
- `#CoopAmmo()` — полный боезапас, `#CoopWeapons()` — всё оружие
- `#CoopGoto()` — список чекпоинтов, `#CoopGoto(3)` — перенести всех на чекпоинт 3
- `#CoopMap(COOP_Map)` — перезапуск карты, друзья остаются подключёнными

## Известные ограничения
- У подключившихся игроков заставки выключены.
- Вертолёты летают только у хоста; подключившиеся видят их висящими на месте.
- Бочки и ящики: подключившийся игрок не может их толкать.
- Чат и консоль в игре печатают только латиницу (сама игра работает с любой раскладкой).
- Короткие консольные команды (`coop_map pier` и подобные) в игровом клиенте пока не работают: используйте варианты с `#` выше.
- У подключившихся враги могут двигаться небольшими рывками.

Исходники и сообщения об ошибках: https://github.com/Bantila/FarCryCoop
Ultimate ASI Loader: https://github.com/ThirteenAG/Ultimate-ASI-Loader (MIT, см. `Bin32\UltimateASILoader-LICENSE.txt`).
