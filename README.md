# CraftFocus

Окно профессии в World of Warcraft 1.12.1 на приватном сервере **Emberveil**:
фильтры и сортировка рецептов, слежение за недостающими реагентами и точки на
карте там, где эти реагенты добываются.

Своего громоздкого интерфейса нет: панель встроена в штатное окно профессии,
плюс одно небольшое окно слежения и кнопка у миникарты.

## Требования

* WoW 1.12.1, сервер Emberveil.
* Библиотек не нужно, один файл `CraftFocus.lua` и две картинки.
* **KoQuest** — необязателен. Если он установлен, CraftFocus берёт из его базы
  сведения о том, с кого и откуда падает реагент. Без него аддон работает,
  просто знает меньше и опирается на собственные наблюдения.

## Установка

Распаковать так, чтобы получилось:

```
Interface/AddOns/CraftFocus/CraftFocus.toc
Interface/AddOns/CraftFocus/CraftFocus.lua
Interface/AddOns/CraftFocus/img/dot.tga
Interface/AddOns/CraftFocus/img/anvil.tga
```

Папку `img` терять нельзя — без неё не будет значков на карте.
После распаковки перезайти в игру (не `/reload`).

---

## Панель в окне профессии

Появляется в штатном окне профессии, под списком рецептов.

* **Фильтры по цвету сложности** — оранжевый, жёлтый, зелёный, серый.
  Выключенный цвет пропадает из списка. `/cf q opt|med|easy|triv`,
  `/cf all` и `/cf none` — включить или выключить все сразу.
* **Сортировка** — по цвету сложности или по наличию реагентов (`/cf sort`).
* **Фильтр по сумкам** (`/cf bag off|any|all`): показывать всё, только то,
  для чего есть хотя бы один реагент, или только то, что можно скрафтить
  прямо сейчас.
* **Только отмеченные** (`/cf only`) — в списке остаются лишь рецепты,
  за которыми ты следишь.
* **Выгода** (`/cf best`) — что выгоднее учить прямо сейчас. Стоимость
  недостающих реагентов делится на шанс поднять навык: оранжевый рецепт
  считается как верное очко, жёлтый — как 0.75, зелёный — как 0.25. Поэтому
  дешёвый зелёный не выглядит выгоднее оранжевого, а выключенные
  фильтром цвета в расчёт не идут.
* **Настройки** (`/cf config`) — окно с переключателями всего перечисленного.

## Слежение за реагентами

Слева от каждого рецепта — квадратик. Отмеченные рецепты попадают в окно
слежения: там список того, чего не хватает, с учётом сумок, банка и уже
отмеченного. Окно двигается мышью, размер тянется за угол, положение и размер
запоминаются.

* `/cf watch` — список в чат;
* `/cf where <реагент>` — откуда он берётся;
* `/cf marks` — прятать или показывать квадратики в списке рецептов;
* `/cf signal` — сообщение в чат, когда нужный реагент падает в сумку;
* `/cf tips` — строка в подсказке предмета: «нужен для такого-то рецепта»;
* `/cf max N` — сколько рецептов перечислять в подсказке и в чате.

Кнопка у миникарты открывает окно слежения; она же умеет открыть само окно
профессии. Заклинание профессии на этом клиенте защищено и по имени не
вызывается, поэтому аддон нажимает ячейку панели команд, на которой оно стоит:
`/cf actions` показывает, что где лежит, `/cf prof <слот>` привязывает вручную,
если найти не удалось. `/cf minimap` убирает или возвращает кнопку.

## Карта и миникарта

Точки показывают, где взять недостающий реагент.

* **Источники из базы** — мобы и объекты, с которых он падает.
* **Свои наблюдения** отмечаются зелёным. Это то, что аддон видел сам:
  например, кожа — её нет ни в одной базе вовсе, поэтому только так.
* **Станции для крафта** — наковальня и прочее, что нужно отмеченным рецептам,
  отдельным значком (`/cf stations`).
* **Скучивание**: одиночная цель — маленький маркер, толпа рядом — один общий,
  и между маркерами всегда остаётся зазор, чтобы карта не превращалась в кашу.
  При наведении подпись, кто это и что с него нужно.
* `/cf map` и `/cf mmap` — точки на большой карте и на миникарте;
* `/cf mapall` — показывать источники и для тех реагентов, что уже собраны;
* `/cf shop` — отмечать у торговца то, что нужно отмеченным рецептам.

## Подсказка на мобе

Наведись на существо — в подсказке будет сказано, падает ли с него что-то
из нужного (`/cf mobs`). Наблюдения копятся сами: что с кого упало, аддон
запоминает и потом показывает на карте.

---

## Команды

`/cf` или `/craftfocus`.

| команда | что делает |
| --- | --- |
| `/cf` | состояние |
| `/cf config` | окно настроек |
| `/cf best` | что выгоднее учить |
| `/cf watch` | список недостающих реагентов |
| `/cf where <реагент>` | откуда берётся реагент |
| `/cf only` | показывать только отмеченные рецепты |
| `/cf sort` | сортировка: по цвету / по наличию |
| `/cf bag off\|any\|all` | фильтр по сумкам |
| `/cf q opt\|med\|easy\|triv` | включить-выключить цвет |
| `/cf all` / `/cf none` | все цвета / ни одного |
| `/cf map`, `/cf mmap` | точки на карте и миникарте |
| `/cf mapall` | точки и для собранных реагентов |
| `/cf stations` | значки станций для крафта |
| `/cf shop` | отмечать нужное у торговца |
| `/cf mobs` | строки в подсказке существа |
| `/cf drops` | запоминать ли добычу |
| `/cf signal` | сообщение, когда реагент падает |
| `/cf tips` | строка в подсказке предмета |
| `/cf marks` | квадратики слежения в списке |
| `/cf max N` | сколько рецептов перечислять |
| `/cf panel` | панель в окне профессии |
| `/cf minimap` | кнопка у миникарты |
| `/cf actions` | что лежит на панели команд |
| `/cf prof <слот>` | привязать профессию к слоту панели |
| `/cf pos` | вернуть окно слежения на место |
| `/cf safe` | аварийно выключить всё вмешательство |
| `/cf reset` | сбросить настройки |
| `/cf lang ru\|en\|auto` | язык сообщений |

Диагностика: `/cf probe`, `/cf names`, `/cf dump N`, `/cf full`.

Если что-то пошло не так в окне профессии — `/cf safe` возвращает клиенту его
собственную отрисовку списка и выключает аддон до следующего включения `/cf on`.

## Что сохраняется

| переменная | где | что в ней |
| --- | --- | --- |
| `CraftFocusDB` | у каждого персонажа свой | настройки, отмеченные рецепты, положение окон |
| `CraftFocusDrops` | общая на аккаунт | что с кого падало |
| `CraftFocusKinds` | общая на аккаунт | какого рода добыча у существа |

Наблюдения старше 30 дней забываются сами. Клиент пишет сохранённые переменные
при выходе из игры, а не по `/reload`.

## Чего в нём нет

Окно `Craft` (наложение чар и подобные профессии без реагентного списка) пока
не поддерживается — только `TradeSkill`.

## Языки

Русский и английский, по языку клиента; `/cf lang` переключает вручную.

## Автор

Vivk (Emberveil).

---

# CraftFocus (English)

A trade skill helper for WoW 1.12.1 on the **Emberveil** private server: filter
and sort recipes by difficulty colour, keep a watch list of the reagents you are
still missing, and see on the world map and minimap where those reagents come
from. No heavy interface of its own — a strip built into the stock trade skill
window, one small watch window and a minimap button.

## Install

Unpack so that `CraftFocus.toc`, `CraftFocus.lua` and the `img` folder end up in
`Interface/AddOns/CraftFocus/`, then restart the game (not `/reload`). The `img`
folder holds the map icons and must not be lost.

## The panel

Difficulty colour filters (orange, yellow, green, grey), sorting by colour or by
what your bags can already make, a bag filter (`off` / `any` / `all`), a
"watched only" switch, and a settings window.

**Worth learning** (`/cf best`) ranks recipes by cost per skill point rather than
by cost: an orange recipe counts as a certain point, yellow as 0.75, green as
0.25. A cheap green therefore does not look better than it is, and colours you
have filtered out are left out of the ranking.

## Watch list

Tick the box beside a recipe and its missing reagents go into the watch window,
counted against your bags and bank. `/cf where <reagent>` says where a reagent
comes from, `/cf signal` announces one arriving in your bags, and `/cf tips`
adds a line to the item's tooltip.

## Map pins

Pins show where a missing reagent comes from: sources from KoQuest's database
when it is installed, the addon's own observations in green (skinning, for one,
is in no database at all), and crafting stations — an anvil and the like — as
their own icon. A lone target gets a small marker, a crowd is merged into one,
spacing between markers is kept so the map stays readable, and hovering names
what is there and what you need from it.

## Commands

`/cf` or `/craftfocus`: `config`, `best`, `watch`, `where <reagent>`, `only`,
`sort`, `bag off|any|all`, `q opt|med|easy|triv`, `all`, `none`, `map`, `mmap`,
`mapall`, `stations`, `shop`, `mobs`, `drops`, `signal`, `tips`, `marks`,
`max N`, `panel`, `minimap`, `actions`, `prof <slot>`, `pos`, `safe`, `reset`,
`lang ru|en|auto`. Diagnostics: `probe`, `names`, `dump N`, `full`.

`/cf safe` is the panic switch: it gives the client its own recipe list drawing
back and stops the addon until `/cf on`.

## Saved variables

`CraftFocusDB` per character (settings, watched recipes, window positions);
`CraftFocusDrops` and `CraftFocusKinds` shared by the account (what dropped from
whom). Observations older than 30 days are forgotten. The client writes saved
variables when the game exits, not on `/reload`.

## What it does not do

The `Craft` window (enchanting and similar) is not supported yet — trade skills
only.

## Author

Vivk (Emberveil).
