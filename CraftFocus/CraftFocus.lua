--[[--------------------------------------------------------------------
  CraftFocus 0.1.33

  The trade skill window, sorted by how hard the recipe is: orange first,
  then yellow, green and grey. Four colour switches hide a difficulty
  outright, and one more switch keeps only the recipes you already hold a
  reagent for.

  The list itself belongs to the server and cannot be reordered, so the
  addon draws the rows itself: the stock update runs first, then every
  visible button is given the recipe our own ordering puts there. The
  button keeps the real recipe index, so clicking, the detail panel and
  crafting all behave exactly as before.
----------------------------------------------------------------------]]

local ADDON   = "CraftFocus"
local VERSION = "0.1.1"


-- Fixed numbers and strings, gathered into one table on purpose: a chunk in
-- this client's Lua may hold no more than 200 locals, and this file is long.
local K = {
  ROWS_FALLBACK = 8,        -- visible rows, when the client does not say
  ROW_FALLBACK  = 16,       -- row height, likewise
  SW_W = 20, SW_H = 14,     -- a colour swatch in the filter panel
  BTN_H = 16,               -- a button in the filter panel
  DROPS_CAP = 600,          -- creatures remembered by name
  KINDS_CAP = 400,          -- creature kind + level band entries
  FORGET_AFTER = 30 * 24 * 60 * 60,   -- and how long a silent one is kept
  TIP_MARK = "|cff66ccff> |r",
  WND_MAXROWS = 40,         -- lines the watch window will ever build
  WND_TOP = 38, WND_BOTTOM = 38, WND_LINE = 14,
  WND_MINW = 350,           -- the bottom row of buttons needs this much
  -- how often a craft of each colour actually raises the skill; grey is
  -- absent on purpose, it never does
  CHANCE = { optimal = 1.00, medium = 0.75, easy = 0.25 },
}

local defaults = {
  enabled = true,
  sort    = "quality",   -- quality | stock
  reagents = "off",      -- off | any (one reagent in the bags) | all (a full craft)
  onlyWatched = false,   -- show nothing but the marked recipes
  drops   = true,        -- remember what dropped from whom
  mobs    = true,        -- lines on creature tooltips (the heavy one)
  map     = true,        -- pins for the missing reagents
  panel   = true,
  lang    = "auto",
  pos     = false,       -- false: hug the window; a table: dragged by hand
  signal  = true,        -- say in chat when a watched reagent arrives
  tips    = true,        -- add a line to the tooltip of a watched reagent
  marks   = true,        -- show the watch boxes in the recipe list
  wpos    = false,       -- where the watch window sits
  mmap    = true,        -- and the same pins on the minimap
  stations = true,       -- and where the anvil or forge a recipe needs is
  mapall  = false,       -- show sources even for reagents already collected
  shop    = true,        -- mark what a vendor has that is still needed
  maxrec  = 5,           -- recipes listed in a tooltip and in the chat
  wsize   = false,       -- how big it was dragged to be
  minimap = true,        -- the button on the minimap
  mmangle = 205,         -- and where it sits on the ring

  show    = { optimal = true, medium = true, easy = true, trivial = true },
}

-- the fallback palette, used only if the client hides TradeSkillTypeColor
local FALLBACK_COLOR = {
  optimal = { r = 1.00, g = 0.50, b = 0.25 },
  medium  = { r = 1.00, g = 1.00, b = 0.00 },
  easy    = { r = 0.25, g = 0.75, b = 0.25 },
  trivial = { r = 0.50, g = 0.50, b = 0.50 },
  header  = { r = 1.00, g = 0.82, b = 0.00 },
}

local RANK = { optimal = 1, medium = 2, easy = 3, trivial = 4 }
local KEYS = { "optimal", "medium", "easy", "trivial" }

----------------------------------------------------------------------
-- language
----------------------------------------------------------------------

local STRINGS = {
  ru = {
    loaded      = "%s загружен. /cf - справка.",
    help1       = "/cf - состояние; config, map, mmap, mapall, stations, shop, best, max N, watch, where <реагент>, only, prof <слот>, actions, minimap, signal, tips, marks, safe, panel, pos, sort, bag [off|any|all], q <цвет>, all, none, reset, lang",
    help2       = "цвета: opt (оранжевый), med (жёлтый), easy (зелёный), triv (серый)",
    help3       = "диагностика: probe, names, dump N, full",
    on          = "вкл",
    off         = "выкл",
    sortQuality = "по качеству",
    sortStock   = "оригинал",
    stateSort   = "порядок: %s",
    stateShow   = "показывать: %s",
    stateBag    = "фильтр по реагентам: %s",
    statePanel  = "панель: %s",
    stateCount  = "видно %d из %d",
    qOpt        = "оранжевые",
    qMed        = "жёлтые",
    qEasy       = "зелёные",
    qTriv       = "серые",
    ttSort      = "Порядок строк",
    ttSortNow   = "сейчас: %s",
    ttSortHint  = "Клик - переключить",
    ttBag       = "Фильтр по реагентам",
    ttBagHint   = "Клик - следующий режим",
    ttColor     = "%s: %s",
    ttColorHint = "Клик - показать или скрыть",
    ttReset     = "Правый клик - показать все цвета",
    ttCount     = "Видно %d из %d рецептов",
    resetDone   = "настройки сброшены.",
    langSet     = "язык: %s",
    noWindow    = "окно профессии ещё не открыто.",
    openFirst   = "откройте окно профессии и повторите.",
    bagOff      = "Реаг: -",
    bagAny      = "Реаг: 1+",
    bagAll      = "Реаг: всё",
    ttBagOff    = "Выключен: видно все рецепты",
    ttBagAny    = "1+ реагент: есть хотя бы один из нужных, не обязательно все",
    ttBagAll    = "Все реагенты: хватает на полный крафт",
    sortQBtn    = "Качество",
    sortSBtn    = "Оригинал",
    ttSortQ     = "По качеству: один список, сперва оранжевые, потом жёлтые, зелёные, серые",
    ttSortS     = "Оригинал: окно рисует сам клиент - категории и порядок сервера",
    ttDrag      = "Тащить левой кнопкой",
    ttNeedQ     = "Фильтры работают в режиме «По качеству» - клик включит его",
    ttCollapsed = "Звёздочка: часть категорий свёрнута, их рецептов в списке нет",
    safeDone    = "аддон снят с окна профессии полностью. /cf on - вернуть.",
    posReset    = "панель вернулась на место.",
    dbgHave     = "есть реагент",
    wMarkOn     = "Слежу за рецептом",
    wMarkOff    = "Следить за рецептом",
    wMarkHint   = "Клик - отметить или снять",
    wNeedWindow = "рецепты отмечаются в открытом окне профессии.",
    wAdded      = "слежу: %s",
    wRemoved    = "снято: %s",
    wNone       = "не отмечено ни одного рецепта. Плюс в строке рецепта - отметить.",
    wGot        = "%s %d/%d - %s",
    wReady      = "собрано на «%s»!",
    wTitle      = "Слежу за рецептами",
    wClose      = "Закрыть",
    wSignal     = "сигнал в чат: %s",
    wTips       = "подсказки на предметах: %s",
    wMarks      = "отметки в списке: %s",
    wCleared    = "список слежения очищен.",
    tipNeed     = "нужен для:",
    mobHead     = "может дать:",
    whereHead   = "%s - откуда падает:",
    whereLine   = "  %s  %s",
    whereNone   = "в базе нет источников для «%s».",
    whereBad    = "укажите реагент: /cf where тонкая кожа",
    whereNoKo   = "для этого нужен аддон KoQuest - в нём лежит база.",
    dropsState  = "запоминать добычу: %s",
    dropsCount  = "запомнено: %d мобов, %d видов существ",
    dropsWiped  = "память о добыче очищена.",
    mobsState   = "подсказки на мобах: %s",
    cfgTitle    = "CraftFocus - настройки",
    cfgSignal   = "Сигнал в чат о нужном",
    cfgTips     = "Подсказки на предметах",
    cfgMobs     = "Подсказки на мобах",
    cfgMobsHint = "самое тяжёлое: ищет по базе KoQuest",
    cfgDrops    = "Запоминать, что с кого падало",
    cfgMarks    = "Отметки в списке рецептов",
    cfgPanel    = "Панель фильтров над окном",
    cfgMinimap  = "Кнопка у миникарты",
    cfgMap      = "Точки на карте",
    cfgMapHint  = "где искать недостающее; нужен KoQuest",
    mapState    = "точки на карте: %s",
    mapCount    = "поставлено точек: %d",
    mapNoKo     = "для точек на карте нужен аддон KoQuest.",
    mmapState   = "точки на миникарте: %s",
    mapCanvas   = "полотно карты %s, открыта %s, ширина %d",
    mapWhy      = "карта: KoQuest %s, зона %s, не хватает %d, источников %d",
    mapNodes    = "в этой зоне %d, всего %d",
    cfgMmap     = "Точки на миникарте",
    cfgStations = "Станки на карте",
    cfgStationsHint = "наковальня, горн и прочее для отмеченных рецептов",
    cfgMapAll   = "Показывать и собранное",
    cfgMapAllHint = "иначе на карте только то, чего не хватает",
    mapAllState = "показывать и собранное: %s",
    mapEmpty    = "на карте пусто: всё нужное уже собрано. /cf mapall - показывать источники и для собранного.",
    mapStation  = "станок",
    mapMine     = "по твоим наблюдениям",
    mapFrom     = "из базы %d, по своим %d, станки %d; мобов в памяти %d",
    mapTop      = "больше всего точек: %s",
    cfgShop     = "Отмечать у торговца",
    cfgShopHint = "что из нужного продаётся здесь",
    shopHas     = "%s продаёт нужное:",
    shopState   = "отметки у торговца: %s",
    stationsState = "станки на карте: %s",
    bestHead    = "%s %d/%d - что выгоднее делать:",
    bestBtn     = "Выгода",
    ttBest      = "Что выгоднее делать",
    ttBestHint  = "жёлтый даёт очко в 3 из 4, зелёный в 1 из 4; учитывает фильтр цвета",
    bestPer     = "%d реаг = %.1f за очко",
    bestNone    = "нечего предложить: серые не в счёт, остальное убрано фильтром.",
    wTool       = "   станок: %s",
    wMade       = "   за раз: %s",
    cfgMmapHint = "те же точки рядом с игроком",
    mapLevel    = "уровень %s",
    mapMany     = "мест поблизости: %d",
    cfgLang     = "Язык",
    cfgLangHint = "как в клиенте / русский / английский",
    langauto    = "как в игре",
    langru      = "русский",
    langen      = "English",
    cfgMax      = "Рецептов в списке",
    cfgMaxHint  = "сколько рецептов показывать в подсказке и в чате",
    maxState    = "рецептов в списке: %d",
    cfgBtn      = "Настройки",
    cfgHint     = "Shift и клик - настройки",
    mobLike     = "с таких обычно падает",
    srcVendor   = "у торговца",
    srcObject   = "добывается",
    whereVendor = "  продаётся у торговцев (%d), например: %s",
    whereObject = "  добывается: %s",
    whereSeen   = "  падало у тебя с: %s",
    whereSkin   = "  |cff9d9d9dсвежевание в базе не записано - тут поможет только свой опыт|r",
    wMore       = "   ... и ещё %d",
    wBtn        = "Слежу",
    wBtnTip     = "Только отмеченные рецепты",
    wBtnHint    = "Клик - включить или выключить фильтр",
    wBtnRight   = "Правый клик - открыть список отмеченного",
    wOnlyState  = "только отмеченные: %s",
    mmTitle     = "CraftFocus",
    mmLeft      = "Клик - список отслеживаемого",
    mmRight     = "Правый клик - убрать эту кнопку (/cf minimap вернёт)",
    mmMove      = "Shift и перетаскивание - двигать по кольцу",
    mmState     = "кнопка у миникарты: %s",
    mmPanelHint = "панель фильтров возвращается командой /cf panel",
    wGrip       = "Тянуть - менять размер",
    wClear      = "Очистить",
    wClearSure  = "Точно?",
    wClearTip   = "Забыть все отмеченные рецепты",
    wClearHint  = "Клик, потом ещё раз для подтверждения",
    wOpen       = "Клик - показать рецепт в окне профессии",
    wForget     = "Забыть рецепт",
    wNoWindow   = "откройте окно профессии, чтобы показать рецепт.",
    wOpening    = "открываю %s...",
    wNoAction   = "чтобы аддон открывал профессию сам, положите %s на панель действий.",
    wSlotSet    = "кнопка профессии: слот %d (%s)",
    wSlotLearn  = "запомнил кнопку профессии: слот %d (%s)",
    wSlotBad    = "укажите номер слота: /cf prof 5",
    wSlotNone   = "в слоте %d ничего нет.",
    wActHead    = "что видно на панели действий:",
    wActNone    = "ни один слот не читается - назначьте вручную: /cf prof <номер>",
    wActLine    = "  %d: %s",
    wNotFound   = "«%s» нет в открытом списке: другая профессия, фильтр или свёрнутая категория.",
    wUp         = "выше",
    wDown       = "ниже",
    dbgTotal    = "всего %d",
  },
  en = {
    loaded      = "%s loaded. /cf for help.",
    help1       = "/cf - state; config, map, mmap, mapall, stations, shop, best, max N, watch, where <reagent>, only, prof <slot>, actions, minimap, signal, tips, marks, safe, panel, pos, sort, bag [off|any|all], q <colour>, all, none, reset, lang",
    help2       = "colours: opt (orange), med (yellow), easy (green), triv (grey)",
    help3       = "diagnostics: probe, names, dump N, full",
    on          = "on",
    off         = "off",
    sortQuality = "by difficulty",
    sortStock   = "original",
    stateSort   = "order: %s",
    stateShow   = "showing: %s",
    stateBag    = "reagent filter: %s",
    statePanel  = "panel: %s",
    stateCount  = "%d of %d shown",
    qOpt        = "orange",
    qMed        = "yellow",
    qEasy       = "green",
    qTriv       = "grey",
    ttSort      = "Row order",
    ttSortNow   = "now: %s",
    ttSortHint  = "Click to switch",
    ttBag       = "Reagent filter",
    ttBagHint   = "Click for the next mode",
    ttColor     = "%s: %s",
    ttColorHint = "Click to show or hide",
    ttReset     = "Right click shows every colour",
    ttCount     = "%d of %d recipes shown",
    resetDone   = "settings reset.",
    langSet     = "language: %s",
    noWindow    = "the trade skill window has not been opened yet.",
    openFirst   = "open a profession window and try again.",
    bagOff      = "Reag: -",
    bagAny      = "Reag: 1+",
    bagAll      = "Reag: all",
    ttBagOff    = "Off: every recipe is shown",
    ttBagAny    = "1+ reagent: at least one of the needed ones, not all",
    ttBagAll    = "All reagents: enough for a full craft",
    sortQBtn    = "Quality",
    sortSBtn    = "Original",
    ttSortQ     = "By difficulty: one list, orange first, then yellow, green, grey",
    ttSortS     = "Original: the client draws its own window - categories and server order",
    ttDrag      = "Drag with the left button",
    ttNeedQ     = "Filters work in the difficulty order - a click switches to it",
    ttCollapsed = "The star: some categories are collapsed, their recipes are not in the list",
    safeDone    = "the addon is off the trade skill window entirely. /cf on brings it back.",
    posReset    = "the panel is back in its place.",
    dbgHave     = "reagent in bags",
    wMarkOn     = "Watching this recipe",
    wMarkOff    = "Watch this recipe",
    wMarkHint   = "Click to watch or drop",
    wNeedWindow = "recipes are marked with the profession window open.",
    wAdded      = "watching: %s",
    wRemoved    = "dropped: %s",
    wNone       = "nothing is watched yet. The plus on a recipe row marks it.",
    wGot        = "%s %d/%d - %s",
    wReady      = "enough for \"%s\"!",
    wTitle      = "Watched recipes",
    wClose      = "Close",
    wSignal     = "chat signal: %s",
    wTips       = "item tooltips: %s",
    wMarks      = "marks in the list: %s",
    wCleared    = "the watch list is empty again.",
    tipNeed     = "needed for:",
    mobHead     = "can drop:",
    whereHead   = "%s - drops from:",
    whereLine   = "  %s  %s",
    whereNone   = "no sources for \"%s\" in the database.",
    whereBad    = "name a reagent: /cf where light leather",
    whereNoKo   = "this needs the KoQuest addon - the database lives there.",
    dropsState  = "remember loot: %s",
    dropsCount  = "remembered: %d creatures by name, %d kinds",
    dropsWiped  = "the loot memory is empty again.",
    mobsState   = "creature tooltips: %s",
    cfgTitle    = "CraftFocus - settings",
    cfgSignal   = "Say in chat what arrived",
    cfgTips     = "Lines on item tooltips",
    cfgMobs     = "Lines on creature tooltips",
    cfgMobsHint = "the heaviest one: it searches the KoQuest database",
    cfgDrops    = "Remember what dropped from whom",
    cfgMarks    = "Marks in the recipe list",
    cfgPanel    = "Filter panel above the window",
    cfgMinimap  = "Minimap button",
    cfgMap      = "Pins on the map",
    cfgMapHint  = "where to find what is missing; needs KoQuest",
    mapState    = "map pins: %s",
    mapCount    = "pins placed: %d",
    mapNoKo     = "map pins need the KoQuest addon.",
    mmapState   = "minimap pins: %s",
    mapCanvas   = "map canvas %s, open %s, width %d",
    mapWhy      = "map: KoQuest %s, zone %s, missing %d, sources %d",
    mapNodes    = "in this zone %d, %d in all",
    cfgMmap     = "Pins on the minimap",
    cfgStations = "Stations on the map",
    cfgStationsHint = "anvil, forge and the like, for watched recipes",
    cfgMapAll   = "Show what is collected too",
    cfgMapAllHint = "otherwise the map holds only what is still missing",
    mapAllState = "show collected too: %s",
    mapEmpty    = "the map is empty: everything needed is already collected. /cf mapall shows sources for those too.",
    mapStation  = "station",
    mapMine     = "from what you have seen",
    mapFrom     = "from the database %d, your own %d, stations %d; creatures remembered %d",
    mapTop      = "most places in: %s",
    cfgShop     = "Mark at the vendor",
    cfgShopHint = "what is sold here that is still needed",
    shopHas     = "%s sells what you need:",
    shopState   = "vendor marks: %s",
    stationsState = "stations on the map: %s",
    bestHead    = "%s %d/%d - best value to make:",
    bestBtn     = "Value",
    ttBest      = "Best value to make",
    ttBestHint  = "yellow gives a point 3 times in 4, green 1 in 4; obeys the colour filter",
    bestPer     = "%d reag = %.1f per point",
    bestNone    = "nothing to suggest: grey does not count, the rest is filtered out.",
    wTool       = "   station: %s",
    wMade       = "   yields: %s",
    cfgMmapHint = "the same pins, near the player",
    mapLevel    = "level %s",
    mapMany     = "places nearby: %d",
    cfgLang     = "Language",
    cfgLangHint = "follow the client / Russian / English",
    langauto    = "as in game",
    langru      = "Русский",
    langen      = "English",
    cfgMax      = "Recipes listed",
    cfgMaxHint  = "how many recipes to show in a tooltip and in the chat",
    maxState    = "recipes listed: %d",
    cfgBtn      = "Settings",
    cfgHint     = "Shift and click for settings",
    mobLike     = "creatures like this usually give",
    srcVendor   = "from a vendor",
    srcObject   = "gathered",
    whereVendor = "  sold by vendors (%d), for example: %s",
    whereObject = "  gathered from: %s",
    whereSeen   = "  you have seen it drop from: %s",
    whereSkin   = "  |cff9d9d9dskinning is not in the database - only your own record helps here|r",
    wMore       = "   ... and %d more",
    wBtn        = "Watched",
    wBtnTip     = "Only the recipes you watch",
    wBtnHint    = "Click to switch the filter on or off",
    wBtnRight   = "Right click opens the watch list",
    wOnlyState  = "only watched: %s",
    mmTitle     = "CraftFocus",
    mmLeft      = "Click for the watch list",
    mmRight     = "Right click for the filter panel",
    mmMove      = "Shift and drag moves it around the ring",
    mmState     = "minimap button: %s",
    mmPanelHint = "the filter panel comes back with /cf panel",
    wGrip       = "Drag to resize",
    wClear      = "Clear",
    wClearSure  = "Sure?",
    wClearTip   = "Forget every watched recipe",
    wClearHint  = "Click, then click again to confirm",
    wOpen       = "Click to show the recipe in the profession window",
    wForget     = "Forget this recipe",
    wNoWindow   = "open the profession window to show the recipe.",
    wOpening    = "opening %s...",
    wNoAction   = "to let the addon open it, drag %s onto an action bar.",
    wSlotSet    = "profession button: slot %d (%s)",
    wSlotLearn  = "remembered the profession button: slot %d (%s)",
    wSlotBad    = "give a slot number: /cf prof 5",
    wSlotNone   = "slot %d is empty.",
    wActHead    = "what can be seen on the action bars:",
    wActNone    = "no slot can be read - set it by hand: /cf prof <number>",
    wActLine    = "  %d: %s",
    wNotFound   = "\"%s\" is not in the open list: another profession, a filter or a collapsed category.",
    wUp         = "up",
    wDown       = "down",
    dbgTotal    = "%d in total",
  },
}

local function CurrentLang()
  local pick = CraftFocusDB and CraftFocusDB.lang or "auto"
  if pick == "ru" or pick == "en" then return pick end
  if GetLocale and GetLocale() == "ruRU" then return "ru" end
  return "en"
end

local function L(key)
  local set = STRINGS[CurrentLang()]
  return (set and set[key]) or key
end

local function Lf(key, a, b, c, d)
  return string.format(L(key), a, b, c, d)
end

local function Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. ADDON .. ":|r " .. tostring(msg))
  end
end

local function OnOff(v)
  if v then return L("on") end
  return L("off")
end

local REAGENT_ORDER = { off = "any", any = "all", all = "off" }

local function BagLabel()
  local mode = CraftFocusDB and CraftFocusDB.reagents or "off"
  if mode == "any" then return L("bagAny") end
  if mode == "all" then return L("bagAll") end
  return L("bagOff")
end

local function QName(key)
  if key == "optimal" then return L("qOpt") end
  if key == "medium"  then return L("qMed") end
  if key == "easy"    then return L("qEasy") end
  return L("qTriv")
end

----------------------------------------------------------------------
-- database
----------------------------------------------------------------------

local DB

-- The addon used to be called CraftLens. Rename its saved variables file and
-- the client still executes it, so the old tables arrive as plain globals --
-- adopt them once, and every setting, watched recipe and remembered drop
-- carries over. Nothing is copied when the new tables already hold something.
local function AdoptOldNames()
  if type(CraftFocusDB) ~= "table" and type(CraftLensDB) == "table" then
    CraftFocusDB = CraftLensDB
  end
  if type(CraftFocusDrops) ~= "table" and type(CraftLensDrops) == "table" then
    CraftFocusDrops = CraftLensDrops
  end
  if type(CraftFocusKinds) ~= "table" and type(CraftLensKinds) == "table" then
    CraftFocusKinds = CraftLensKinds
  end
end

local function InitDB()
  AdoptOldNames()
  if type(CraftFocusDB) ~= "table" then CraftFocusDB = {} end
  for key, value in pairs(defaults) do
    if CraftFocusDB[key] == nil then CraftFocusDB[key] = value end
  end
  if type(CraftFocusDB.show) ~= "table" then CraftFocusDB.show = {} end
  if type(CraftFocusDB.watch) ~= "table" then CraftFocusDB.watch = {} end
  -- positions used to be stored as an anchor pair; those are not readable
  -- the same way any more, so they go back to the default
  if type(CraftFocusDB.pos) == "table" and CraftFocusDB.pos.p then CraftFocusDB.pos = false end
  if type(CraftFocusDB.wpos) == "table" and CraftFocusDB.wpos.p then CraftFocusDB.wpos = false end
  local i = 1
  while KEYS[i] do
    if CraftFocusDB.show[KEYS[i]] == nil then CraftFocusDB.show[KEYS[i]] = true end
    i = i + 1
  end
  if CraftFocusDB.sort ~= "quality" and CraftFocusDB.sort ~= "stock" then
    CraftFocusDB.sort = "quality"
  end
  -- the quality order is what this addon is for, so that is where it starts;
  -- done once, after which the player's own choice is kept
  if not CraftFocusDB.startedInQuality then
    CraftFocusDB.sort = "quality"
    CraftFocusDB.startedInQuality = true
  end
  -- the reagent filter used to be a yes or no switch
  if CraftFocusDB.bagOnly ~= nil then
    if CraftFocusDB.bagOnly and CraftFocusDB.reagents == "off" then
      CraftFocusDB.reagents = "any"
    end
    CraftFocusDB.bagOnly = nil
  end
  if CraftFocusDB.reagents ~= "off" and CraftFocusDB.reagents ~= "any"
     and CraftFocusDB.reagents ~= "all" then
    CraftFocusDB.reagents = "off"
  end
  DB = CraftFocusDB
end

local function Color(kind)
  local t = getglobal("TradeSkillTypeColor")
  if type(t) == "table" and type(t[kind]) == "table" then return t[kind] end
  return FALLBACK_COLOR[kind] or FALLBACK_COLOR.trivial
end

-- the same colour as a chat escape, for lines that are printed rather than drawn
local function Hex(c)
  return string.format("|cff%02x%02x%02x",
    math.floor((c.r or 1) * 255), math.floor((c.g or 1) * 255), math.floor((c.b or 1) * 255))
end

----------------------------------------------------------------------
-- the ordered, filtered list
----------------------------------------------------------------------

local view, viewN, totalN = {}, 0, 0

-- one pass over a recipe's reagents: whether a single one of them is in
-- the bags, and whether all of them are
local function ReagentCheck(index, avail)
  if type(GetTradeSkillNumReagents) ~= "function" then return true, true end
  local n = GetTradeSkillNumReagents(index) or 0
  if n == 0 then return true, true end

  local any, all = false, true
  local j = 1
  while j <= n do
    local _, _, need, have = GetTradeSkillReagentInfo(index, j)
    if have and have > 0 then any = true end
    if not have or not need or have < need then all = false end
    j = j + 1
  end

  -- the client already knows how many can be made; trust it when it says so
  if type(avail) == "number" and avail > 0 then any, all = true, true end
  return any, all
end

local function AnyReagent(index)
  local any = ReagentCheck(index)
  return any
end

-- orange first, then yellow, green, grey; inside one colour, by name
local function Cmp(a, b)
  local ra = RANK[a.kind] or 9
  local rb = RANK[b.kind] or 9
  if ra ~= rb then return ra < rb end
  if a.name ~= b.name then return a.name < b.name end
  return a.id < b.id
end

local function BuildView()
  view, viewN, totalN = {}, 0, 0
  if type(GetNumTradeSkills) ~= "function" then return end
  local n = GetNumTradeSkills() or 0

  local i = 1
  while i <= n do
    local name, kind, avail = GetTradeSkillInfo(i)
    if kind ~= "header" and name then
      totalN = totalN + 1
      local pass = (DB.show[kind] ~= false)
      if pass and DB.onlyWatched then
        pass = (type(DB.watch) == "table" and DB.watch[name] ~= nil)
      end
      if pass and DB.reagents ~= "off" then
        local any, all = ReagentCheck(i, avail)
        if DB.reagents == "all" then pass = all else pass = any end
      end
      if pass then
        viewN = viewN + 1
        view[viewN] = { id = i, name = name, kind = kind, avail = avail or 0 }
      end
    end
    i = i + 1
  end

  if DB.sort == "quality" then pcall(table.sort, view, Cmp) end
end

-- This addon never writes anything into the trade skill list: it does not
-- expand, collapse, select or craft. Earlier versions expanded every
-- category so that the whole list could be sorted, and that is where the
-- freezes came from -- the client was left in a state it could not get out
-- of. A collapsed category simply has no rows in the list, so its recipes
-- are not sorted and not counted; the panel says so instead.
local function SomethingCollapsed()
  if type(GetNumTradeSkills) ~= "function" then return false end
  local n = GetNumTradeSkills() or 0
  local i = 1
  while i <= n do
    local _, kind, _, isExpanded = GetTradeSkillInfo(i)
    if kind == "header" and not isExpanded then return true end
    i = i + 1
  end
  return false
end

----------------------------------------------------------------------
-- drawing
----------------------------------------------------------------------

local hooked, inDraw = false, false
local origUpdate = nil                -- the client's own function
local myWrapper = nil                 -- ours, so we only ever remove our own
local fuseAt, fuseCount = 0, 0        -- see the note in Draw
local drawn = {}                      -- what this addon put in each row
local UpdatePanel                     -- forward declarations
local SyncHook

-- Game order means the client's own list, untouched. Our filters need our
-- own drawing, so leaving one of them switched on would quietly drag the
-- addon back into drawing the list -- "Original" that is not original. Turn
-- them off with the order, and they come back the moment a filter is used.
local function SetSort(order)
  DB.sort = order
  if order ~= "quality" then
    DB.onlyWatched = false
    DB.reagents = "off"
  end
end

local function Active()
  if not DB.enabled then return false end
  if DB.onlyWatched and DB.sort ~= "quality" then return true end
  -- Game order is exactly that: the client draws the list itself, with its
  -- own categories. Drawing our own header rows made the client hang when
  -- one was clicked, so the filters live in the quality order, where every
  -- row on screen is one this addon put there.
  return (DB.sort == "quality")
end

local function RowHeight()
  local h = getglobal("TRADE_SKILL_HEIGHT")
  if type(h) == "number" and h > 0 then return h end
  local b = getglobal("TradeSkillSkill1")
  if b and b.GetHeight then
    local bh = b:GetHeight()
    if bh and bh > 0 then return bh end
  end
  return K.ROW_FALLBACK
end

local function RowCount()
  local n = getglobal("TRADE_SKILLS_DISPLAYED")
  if type(n) == "number" and n > 0 then return n end
  return K.ROWS_FALLBACK
end

-- the collapse icon has to go from every row this addon draws: an empty
-- path is not the way, since this client draws a red "texture missing"
-- square for it. A fully transparent colour hides the icon and still lets
-- the stock code put a real one back when it draws the list itself.
local savedIcon = {}                  -- what was on a row before we cleared it

local function ClearIcon(button, i)
  if not button.GetNormalTexture then return end
  local tex = button:GetNormalTexture()
  if not tex or not tex.SetTexture then return end
  if i and savedIcon[i] == nil then
    local was = tex.GetTexture and tex:GetTexture()
    savedIcon[i] = was or false
  end
  pcall(tex.SetTexture, tex, 0, 0, 0, 0)
end

-- give the rows back to the client exactly as they were found
local function ReleaseRows()
  local any = false
  for key in pairs(savedIcon) do any = true end
  if not any then return end

  for i, was in pairs(savedIcon) do
    local button = getglobal("TradeSkillSkill" .. i)
    if button then
      -- a row we hid must be visible again: the client's own draw fills the
      -- rows it needs and hides the rest, but it never shows one back
      if button.Show then button:Show() end
      if was and button.SetNormalTexture then
        pcall(button.SetNormalTexture, button, was)
      end
    end
  end
  savedIcon = {}
end

local function Draw()
  if inDraw then return end

  -- A fuse. Redrawing the list moves the scroll bar, moving the scroll bar
  -- asks for a redraw, and if the two ever disagree about how many rows
  -- there are they can bounce off each other inside a single frame and the
  -- client stops answering. The guards below should prevent that; this
  -- makes sure that even if they do not, the addon gives up instead of
  -- locking the game. GetTime does not move within a frame.
  local now = GetTime and GetTime() or 0
  if now == fuseAt then
    fuseCount = fuseCount + 1
    if fuseCount > 8 then return end
  else
    fuseAt, fuseCount = now, 1
  end
  if not Active() then
    if UpdatePanel then UpdatePanel() end
    return
  end

  inDraw = true

  BuildView()

  local scroll = getglobal("TradeSkillListScrollFrame")
  local rows   = RowCount()
  local step   = RowHeight()

  if scroll and type(FauxScrollFrame_Update) == "function" then
    pcall(FauxScrollFrame_Update, scroll, viewN, rows, step)
  end

  local offset = 0
  if scroll and type(FauxScrollFrame_GetOffset) == "function" then
    offset = FauxScrollFrame_GetOffset(scroll) or 0
  end
  if offset > viewN - rows then offset = viewN - rows end
  if offset < 0 then offset = 0 end

  local selected = 0
  if type(GetTradeSkillSelectionIndex) == "function" then
    selected = GetTradeSkillSelectionIndex() or 0
  end
  local highlight = getglobal("TradeSkillHighlightFrame")
  local seen = false

  local i = 1
  while i <= rows do
    local button = getglobal("TradeSkillSkill" .. i)
    if button then
      local entry = view[offset + i]
      if entry then
        local label = entry.name
        if entry.avail > 0 then label = label .. " [" .. entry.avail .. "]" end

        button:SetID(entry.id)
        drawn[i] = label
        if button.SetText then button:SetText(label) end
        ClearIcon(button, i)

        local fs = getglobal("TradeSkillSkill" .. i .. "Text")
        local c  = Color(entry.kind)
        if fs and fs.SetTextColor then fs:SetTextColor(c.r, c.g, c.b) end

        button:Show()

        if entry.id == selected then
          seen = true
          if button.LockHighlight then button:LockHighlight() end
          if highlight then
            highlight:ClearAllPoints()
            highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            highlight:Show()
          end
        elseif button.UnlockHighlight then
          button:UnlockHighlight()
        end
      else
        drawn[i] = nil
        if savedIcon[i] == nil then savedIcon[i] = false end   -- remember to show it again
        button:Hide()
      end
    end
    i = i + 1
  end

  if highlight and not seen then highlight:Hide() end
  if UpdatePanel then UpdatePanel() end

  inDraw = false
end

-- the player asked for our order or for a filter: that, and only that, is
-- when the categories may be opened for us
local function Apply()
  if SyncHook then SyncHook() end
  if type(TradeSkillFrame_Update) == "function" then TradeSkillFrame_Update() end
  if UpdatePanel then UpdatePanel() end
end

local function Redraw()
  if type(TradeSkillFrame_Update) == "function" then
    TradeSkillFrame_Update()
  end
end

local function TryHook()
  if hooked then return true end
  if type(TradeSkillFrame_Update) ~= "function" then return false end

  origUpdate = TradeSkillFrame_Update
  local orig = origUpdate

  myWrapper = function(a1, a2, a3)
    -- The client's own draw always runs, and it runs first. An earlier
    -- version held back a repeat call while it was busy; if the client is
    -- waiting for that call to finish a collapse, holding it back hangs the
    -- game. So: never swallow, never delay.
    orig(a1, a2, a3)
    if not Active() then
      pcall(ReleaseRows)
      return
    end
    pcall(Draw)
  end

  TradeSkillFrame_Update = myWrapper
  hooked = true
  return true
end

-- In the original order the addon leaves the window entirely: its own
-- function goes back in place, so there is not a single line of ours
-- between a click and the client. Only the panel above the window stays.
local function Unhook()
  if not hooked then return end
  pcall(ReleaseRows)
  if origUpdate and TradeSkillFrame_Update == myWrapper then
    TradeSkillFrame_Update = origUpdate
    hooked = false
    -- and let the client draw its own window at once, so that nothing this
    -- addon put on screen is left there: its own rows, its own text, its
    -- own colours, its own icons
    local frame = getglobal("TradeSkillFrame")
    if frame and frame.IsVisible and frame:IsVisible() then pcall(origUpdate) end
  end
  -- if someone else hooked on top of ours, our wrapper stays where it is:
  -- pulling it out would take theirs with it. It does nothing anyway.
end

SyncHook = function()
  if Active() then TryHook() else Unhook() end
end

----------------------------------------------------------------------
-- the panel
----------------------------------------------------------------------

local panel, countText = nil, nil
local LayoutPanel                     -- measures the row of buttons
local panelHintSaid = false
local swatches, sortBtn, bagBtn, watchBtn, bestBtn = {}, nil, nil, nil, nil
local ToggleWatchWindow               -- filled in by the watch section
local BestToLearn                     -- the same, from the merchant section


local function Tip(frame, lines)
  frame:SetScript("OnEnter", function()
    local self = this
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    local built = lines()
    local i = 1
    while built[i] do
      if i == 1 then
        GameTooltip:AddLine(built[i])
      else
        GameTooltip:AddLine("|cff9d9d9d" .. built[i] .. "|r")
      end
      i = i + 1
    end
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
end

----------------------------------------------------------------------
-- where the panel sits
----------------------------------------------------------------------

local function PlacePanel()
  if not panel then return end
  panel:ClearAllPoints()

  local pos = DB.pos
  if type(pos) == "table" and type(pos.left) == "number" and type(pos.top) == "number" then
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.left, pos.top)
    return
  end

  local frame = getglobal("TradeSkillFrame")
  if frame then
    -- Above the window, pinned by its left edge and clear of the portrait.
    -- Pinning by the right edge made the panel grow leftwards off the
    -- screen as buttons were added to it.
    panel:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 42, -12)
  else
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
  end
end

local function SavePosition()
  if not panel or not panel.GetLeft then return end
  local left, top = panel:GetLeft(), panel:GetTop()
  if type(left) ~= "number" or type(top) ~= "number" then return end
  DB.pos = { left = left, top = top }
end

----------------------------------------------------------------------
-- the pieces on it
----------------------------------------------------------------------

local function StyleSwatch(button, kind)
  local c    = Color(kind)
  local on   = (DB.show[kind] ~= false)
  local live = (DB.sort == "quality")

  if not live then
    -- the game draws the list in this order, so the filters are asleep
    button.fill:SetTexture(c.r * 0.45, c.g * 0.45, c.b * 0.45)
    button.fill:SetAlpha(0.45)
  elseif on then
    button.fill:SetTexture(c.r, c.g, c.b)
    button.fill:SetAlpha(1)
  else
    button.fill:SetTexture(c.r * 0.25, c.g * 0.25, c.b * 0.25)
    button.fill:SetAlpha(0.8)
  end

  if on then button.mark:Hide() else button.mark:Show() end
end

local function MakeSwatch(kind, x)
  local button = CreateFrame("Button", nil, panel)
  button:SetWidth(K.SW_W)
  button:SetHeight(K.SW_H)
  button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -4)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local edge = button:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints(button)
  edge:SetTexture(0, 0, 0, 1)

  local fill = button:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
  button.fill = fill

  -- a dark bar across a colour that is switched off
  local mark = button:CreateTexture(nil, "OVERLAY")
  mark:SetPoint("LEFT", button, "LEFT", 2, 0)
  mark:SetPoint("RIGHT", button, "RIGHT", -2, 0)
  mark:SetHeight(2)
  mark:SetTexture(0, 0, 0, 0.9)
  mark:Hide()
  button.mark = mark

  button:SetScript("OnClick", function()
    local which = arg1
    if which == "RightButton" then
      local i = 1
      while KEYS[i] do DB.show[KEYS[i]] = true; i = i + 1 end
    else
      -- filtering needs our own list, so asking for a filter asks for it
      DB.sort = "quality"
      DB.show[kind] = not (DB.show[kind] ~= false)
    end
    Apply()
  end)

  Tip(button, function()
    local lines = {
      Lf("ttColor", QName(kind), OnOff(DB.show[kind] ~= false)),
      L("ttColorHint"),
      L("ttReset"),
    }
    if DB.sort ~= "quality" then lines[4] = L("ttNeedQ") end
    return lines
  end)

  StyleSwatch(button, kind)
  return button
end

local function MakeTextButton(x, width, onClick, tip)
  local button = CreateFrame("Button", nil, panel)
  button:SetWidth(width)
  button:SetHeight(K.BTN_H)
  button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -4)

  local edge = button:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints(button)
  edge:SetTexture(0, 0, 0, 1)

  local fill = button:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
  fill:SetTexture(0.20, 0.20, 0.22)
  button.fill = fill

  local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not text:GetFont() or text:GetFont() == "" then
    text:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
  end
  text:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.text = text

  button:SetScript("OnClick", onClick)
  Tip(button, tip)
  return button
end

local function StyleToggle(button, on, live)
  if live == nil then live = true end
  if not live then
    button.fill:SetTexture(0.14, 0.14, 0.15)
    button.text:SetTextColor(0.45, 0.45, 0.45)
  elseif on then
    button.fill:SetTexture(0.16, 0.42, 0.18)
    button.text:SetTextColor(1, 1, 1)
  else
    button.fill:SetTexture(0.18, 0.18, 0.20)
    button.text:SetTextColor(0.65, 0.65, 0.65)
  end
end

UpdatePanel = function()
  if not panel then return end
  if not DB.panel then panel:Hide() return end

  local frame = getglobal("TradeSkillFrame")
  if frame and frame.IsVisible and frame:IsVisible() then
    panel:Show()
  else
    panel:Hide()
  end

  local i = 1
  while KEYS[i] do
    if swatches[i] then StyleSwatch(swatches[i], KEYS[i]) end
    i = i + 1
  end
  if bagBtn then
    bagBtn.text:SetText(BagLabel())
    StyleToggle(bagBtn, DB.reagents ~= "off", DB.sort == "quality")
  end
  if watchBtn then
    watchBtn.text:SetText(L("wBtn"))
    StyleToggle(watchBtn, DB.onlyWatched, DB.sort == "quality")
  end
  if sortBtn then
    sortBtn.text:SetText(DB.sort == "quality" and L("sortQBtn") or L("sortSBtn"))
    StyleToggle(sortBtn, DB.sort == "quality")
  end
  if bestBtn then
    bestBtn.text:SetText(L("bestBtn"))
    StyleToggle(bestBtn, false, true)
  end
  if LayoutPanel then LayoutPanel() end
  if countText then
    if DB.sort ~= "quality" then
      countText:SetText("")           -- nothing is counted in the original order
      return
    end
    local mark = ""
    if SomethingCollapsed() then mark = "*" end
    countText:SetText(viewN .. "/" .. totalN .. mark)
    if viewN < totalN or mark ~= "" then
      countText:SetTextColor(1, 0.82, 0)
    else
      countText:SetTextColor(0.7, 0.7, 0.7)
    end
  end
end

-- The row of buttons has to live inside the width of the trade skill window,
-- and the words in it change with the language. Measure, and drop whatever
-- does not fit onto a second row rather than letting it hang off the edge.
LayoutPanel = function()
  if not panel then return end

  local first = 8 + 4 * (K.SW_W + 2) + 6      -- past the colour swatches
  local room = 384
  local frame = getglobal("TradeSkillFrame")
  if frame and frame.GetWidth then
    local w = frame:GetWidth()
    if type(w) == "number" and w > 100 then room = w end
  end
  room = room - 48                            -- the counter keeps the right end

  local list = { bagBtn, sortBtn, watchBtn, bestBtn }
  local x, y, rows, i = first, 0, 1, 1
  while list[i] do
    local button = list[i]
    local w = button:GetWidth() or 50
    if x > first and x + w > room then
      x, y, rows = first, y + K.BTN_H + 3, 2   -- next row, under the swatches
    end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -4 - y)
    x = x + w + 4
    i = i + 1
  end

  local width = x + 44
  if rows > 1 then width = room + 48 end
  panel:SetWidth(width)
  panel:SetHeight(24 + (rows - 1) * (K.BTN_H + 3))
end

local function BuildPanel()
  if panel then return end
  if not getglobal("TradeSkillFrame") then return end

  -- a child of UIParent, not of the window: that is what lets it be dragged
  -- anywhere and keep the place; its visibility follows the window by hand
  panel = CreateFrame("Frame", "CraftFocusPanel", UIParent)
  panel:SetWidth(300)
  panel:SetHeight(24)
  panel:SetFrameStrata("DIALOG")
  panel:EnableMouse(true)
  panel:SetMovable(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  panel:SetBackdropColor(0, 0, 0, 0.85)
  local function PanelDown()
    local self = this or panel
    if self.StartMoving then self:StartMoving() end
  end
  local function PanelUp()
    local self = this or panel
    if self.StopMovingOrSizing then self:StopMovingOrSizing() end
    SavePosition()
  end
  panel:SetScript("OnDragStart", PanelDown)
  panel:SetScript("OnDragStop", PanelUp)
  panel:SetScript("OnMouseDown", PanelDown)
  panel:SetScript("OnMouseUp", PanelUp)
  PlacePanel()

  local x, i = 8, 1
  while KEYS[i] do
    swatches[i] = MakeSwatch(KEYS[i], x)
    x = x + K.SW_W + 2
    i = i + 1
  end

  x = x + 6
  bagBtn = MakeTextButton(x, 62, function()
    -- filtering needs our own list, so asking for a filter asks for it
    DB.sort = "quality"
    DB.reagents = REAGENT_ORDER[DB.reagents] or "any"
    Apply()
  end, function()
    local lines = { L("ttBag"), L("ttBagOff"), L("ttBagAny"), L("ttBagAll"), L("ttBagHint") }
    if DB.sort ~= "quality" then lines[6] = L("ttNeedQ") end
    return lines
  end)

  x = x + 66
  sortBtn = MakeTextButton(x, 62, function()
    if DB.sort == "quality" then SetSort("stock") else SetSort("quality") end
    Apply()
  end, function()
    local now = L("sortQuality")
    if DB.sort ~= "quality" then now = L("sortStock") end
    return { L("ttSort"), Lf("ttSortNow", now),
             L("ttSortQ"), L("ttSortS"), L("ttSortHint"), L("ttDrag") }
  end)

  x = x + 66
  watchBtn = MakeTextButton(x, 50, function()
    local which = arg1
    if which == "RightButton" then
      if ToggleWatchWindow then ToggleWatchWindow() end
      return
    end
    -- filtering is our own drawing, so asking for it asks for our order
    DB.sort = "quality"
    DB.onlyWatched = not DB.onlyWatched
    Apply()
  end, function()
    local lines = { L("wBtnTip"), L("wBtnHint"), L("wBtnRight"), OnOff(DB.onlyWatched) }
    return lines
  end)
  watchBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  bestBtn = MakeTextButton(0, 46, function()
    if BestToLearn then BestToLearn() end
  end, function()
    return { L("ttBest"), L("ttBestHint") }
  end)

  LayoutPanel()

  countText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not countText:GetFont() or countText:GetFont() == "" then
    countText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
  end
  countText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -8)
  Tip(panel, function()
    local lines, n = {}, 0
    n = n + 1; lines[n] = Lf("ttCount", viewN, totalN)
    if DB.sort == "quality" and SomethingCollapsed() then
      n = n + 1; lines[n] = L("ttCollapsed")
    end
    n = n + 1; lines[n] = L("ttDrag")
    return lines
  end)

  UpdatePanel()
end

----------------------------------------------------------------------
-- keeping the colours
--
-- the client repaints a row on its own when the mouse passes over it or
-- when a recipe is picked, and it paints by its own idea of what is in
-- that row. The row still carries the real recipe index, so the colour
-- can always be worked out again from that; this just puts it back.
----------------------------------------------------------------------

local keeper, since = nil, 0
local WatchTick                       -- filled in by the watch section

local lastFix = 0

local function KeepColors()
  if not Active() then return end
  if type(GetTradeSkillInfo) ~= "function" then return end

  local rows, i = RowCount(), 1
  while i <= rows do
    local button = getglobal("TradeSkillSkill" .. i)
    if button and button.IsVisible and button:IsVisible() then
      -- the row holds something we did not put there: draw the page again,
      -- but not more than twice a second, whatever the client is up to
      if drawn[i] and button.GetText and button:GetText() ~= drawn[i] then
        local now = GetTime and GetTime() or 0
        if now - lastFix > 0.5 then
          lastFix = now
          pcall(Draw)
        end
        return
      end
      local id = button.GetID and button:GetID() or 0
      if id and id > 0 then
        local _, kind = GetTradeSkillInfo(id)
        if kind then
          local fs = getglobal("TradeSkillSkill" .. i .. "Text")
          if fs and fs.SetTextColor then
            local c = Color(kind)
            fs:SetTextColor(c.r, c.g, c.b)
          end
          ClearIcon(button, i)
        end
      end
    end
    i = i + 1
  end
end

local function StartKeeper()
  if keeper then return end
  keeper = CreateFrame("Frame", "CraftFocusKeeper", UIParent)
  keeper:SetScript("OnUpdate", function()
    local step = arg1
    if type(step) ~= "number" then step = 0.05 end
    since = since + step
    if since < 0.05 then return end
    since = 0

    local frame = getglobal("TradeSkillFrame")
    local open  = (frame and frame.IsVisible and frame:IsVisible())
    if panel then
      if open and DB.panel then panel:Show() else panel:Hide() end
    end
    if open and Active() then pcall(KeepColors) end

    -- the watch side of the addon lives here too, so that it works with the
    -- profession window shut: boxes on the rows, a line on a tooltip, and a
    -- fresh count of the bags when something changed in them
    if WatchTick then pcall(WatchTick, step) end

    -- Telling the profession button apart from whatever else the client
    -- calls "current" takes two more looks, one of them after the window is
    -- shut, so it lives on this timer. Reached through a global because this
    -- chunk has run out of the 200 local slots the client allows.
    if CraftFocusProf and CraftFocusProf.tick then
      pcall(CraftFocusProf.tick, step, open)
    end
  end)
end

----------------------------------------------------------------------
-- watched recipes
--
-- A recipe is marked in the list; from then on the addon knows what it is
-- made of even with the profession window shut, counts the reagents in the
-- bags, says a word when one of them arrives, and writes on the reagent's
-- own tooltip what it is being saved for.
----------------------------------------------------------------------

local needIndex, needDirty, needGen = {}, true, 0
local CountKeys                        -- defined with the loot memory below
local pendingRecipe = nil             -- picked as soon as the window opens
local bagHave, bagKnown = {}, false
local bagDirty, bagAt = false, 0
local mapDirty, mapWait = true, 0

-- what a recipe is made of, read while the window is open
local function ReagentsOf(index)
  if type(GetTradeSkillNumReagents) ~= "function" then return nil end
  local n = GetTradeSkillNumReagents(index) or 0
  if n == 0 then return nil end

  local list, count = {}, 0
  local j = 1
  while j <= n do
    local rname, _, need = GetTradeSkillReagentInfo(index, j)
    if rname then
      count = count + 1
      list[count] = { name = rname, need = need or 1 }
    end
    j = j + 1
  end
  if count == 0 then return nil end
  return list
end

local function IsWatched(name)
  return name ~= nil and DB.watch[name] ~= nil
end

local function DropWatch(name)
  if not name or not DB.watch[name] then return false end
  DB.watch[name] = nil
  needDirty = true
  return true
end

-- What a recipe needs besides reagents: an anvil, a forge, a cooking fire.
-- The client returns them as one string of names, or as several returns; both
-- shapes are accepted, and a name may itself be a comma separated list.
local function ToolsOf(index)
  if type(GetTradeSkillTools) ~= "function" then return nil end
  local a, b, c, d, e, f = GetTradeSkillTools(index)
  local out, n = {}, 0
  local parts = { a, b, c, d, e, f }
  local i = 1
  while i <= 6 do
    local value = parts[i]
    if type(value) == "string" and value ~= "" then
      -- string.gfind is what this client's Lua calls gmatch
      local split = string.gfind or string.gmatch
      if split then
        for piece in split(value, "[^,]+") do
          local name = string.gsub(piece, "^%s*(.-)%s*$", "%1")
          if name ~= "" then
            n = n + 1
            out[n] = name
          end
        end
      else
        n = n + 1
        out[n] = value
      end
    end
    i = i + 1
  end
  if n == 0 then return nil end
  return out
end

-- How many the recipe yields per craft, so "0/12" can also say how many
-- finished items that is
local function MadeBy(index)
  if type(GetTradeSkillNumMade) ~= "function" then return nil, nil end
  local lo, hi = GetTradeSkillNumMade(index)
  if type(lo) ~= "number" then return nil, nil end
  return lo, (type(hi) == "number" and hi or lo)
end

-- Recipes marked before the addon knew about tools carry no record of them,
-- and a station can only be put on the map if the recipe says it needs one.
-- Fill that in quietly whenever the profession window is open.
local function TopUpWatch()
  if type(GetNumTradeSkills) ~= "function" then return end
  local total = GetNumTradeSkills() or 0
  if total == 0 then return end

  local touched = false
  local i = 1
  while i <= total do
    local name, kind = GetTradeSkillInfo(i)
    local entry = name and DB.watch[name]
    if entry and kind ~= "header" and not entry.toolsKnown then
      entry.tools = ToolsOf(i)
      entry.made, entry.madeMax = MadeBy(i)
      entry.toolsKnown = true
      touched = true
    end
    i = i + 1
  end
  if touched then mapDirty = true end
end

local function TakeWatch(index)
  local name, kind = GetTradeSkillInfo(index)
  if not name or kind == "header" then return end

  if DB.watch[name] then
    DropWatch(name)
    Print(Lf("wRemoved", name))
    return
  end

  local reagents = ReagentsOf(index)
  if not reagents then
    Print(L("wNeedWindow"))
    return
  end

  local line = nil
  if type(GetTradeSkillLine) == "function" then line = GetTradeSkillLine() end
  local lo, hi = MadeBy(index)
  DB.watch[name] = { name = name, line = line, reagents = reagents,
                     tools = ToolsOf(index), made = lo, madeMax = hi,
                     toolsKnown = true }
  needDirty = true
  Print(Lf("wAdded", name))
end

-- reagent name -> every watched recipe that wants it
local function BuildNeed()
  needIndex = {}
  for recipe, entry in pairs(DB.watch) do
    if type(entry) == "table" and type(entry.reagents) == "table" then
      local i = 1
      while entry.reagents[i] do
        local r = entry.reagents[i]
        if r.name then
          if not needIndex[r.name] then needIndex[r.name] = {} end
          local slot, k = needIndex[r.name], 1
          while slot[k] do k = k + 1 end
          slot[k] = { recipe = recipe, need = r.need or 1 }
        end
        i = i + 1
      end
    end
  end
  -- pairs() hands the recipes back in whatever order it likes; sorting by
  -- name keeps the tooltip and the chat from reshuffling between hovers
  for _, slot in pairs(needIndex) do
    pcall(table.sort, slot, function(a, b) return a.recipe < b.recipe end)
  end
  needDirty = false
  needGen   = needGen + 1
  dropDirty = true
  mapDirty  = true
end

-- How many recipes a list may name before it turns into "... and N more".
-- One number for the tooltip and for the chat, because they answer the same
-- question and a person who wants a short chat wants a short tooltip too.
local function MaxRec()
  local n = DB and DB.maxrec
  if type(n) ~= "number" then return 5 end
  if n < 1 then return 1 end
  if n > 12 then return 12 end
  return n
end

local function Need()
  if needDirty then BuildNeed() end
  return needIndex
end

local function WatchCount()
  local n = 0
  for _ in pairs(DB.watch) do n = n + 1 end
  return n
end

----------------------------------------------------------------------
-- what is in the bags
----------------------------------------------------------------------

local function ScanBags()
  local fresh = {}
  if type(GetContainerNumSlots) ~= "function" then return fresh end

  local bag = 0
  while bag <= 4 do
    local slots = GetContainerNumSlots(bag) or 0
    local slot = 1
    while slot <= slots do
      local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
      if link then
        local _, _, nm = string.find(link, "%[(.-)%]")
        if nm then
          local count = 1
          if type(GetContainerItemInfo) == "function" then
            local _, c = GetContainerItemInfo(bag, slot)
            if type(c) == "number" and c > 0 then count = c end
          end
          fresh[nm] = (fresh[nm] or 0) + count
        end
      end
      slot = slot + 1
    end
    bag = bag + 1
  end
  return fresh
end

local function Held(name)
  return bagHave[name] or 0
end

-- how far a recipe is: how many of its reagents are already covered
local function RecipeReady(entry)
  if type(entry) ~= "table" or type(entry.reagents) ~= "table" then return false end
  local i = 1
  while entry.reagents[i] do
    local r = entry.reagents[i]
    if Held(r.name) < (r.need or 1) then return false end
    i = i + 1
  end
  return true
end

local UpdateWatchWindow                 -- forward declaration
local MissingChanged                    -- set up with the map pins

-- Marking or forgetting a recipe changes what the "watched only" filter
-- keeps, so the list has to be drawn again. Without this the rows that no
-- longer pass sat there until something else redrew the window.
local function RefreshList()
  local frame = getglobal("TradeSkillFrame")
  if not frame or not frame.IsVisible or not frame:IsVisible() then return end
  if type(TradeSkillFrame_Update) == "function" then pcall(TradeSkillFrame_Update) end
  if UpdatePanel then UpdatePanel() end
end

-- Counting again after the bags changed, and saying what arrived. The very
-- first count of a session only sets the baseline: logging in is not news.
local function RefreshBags(quiet)
  local fresh = ScanBags()
  local index = Need()

  if bagKnown and not quiet and DB.signal then
    for name, wants in pairs(index) do
      local before, now = bagHave[name] or 0, fresh[name] or 0
      -- Only the FIRST of a reagent is worth a line. Everything after it is
      -- the same news repeated: a hide is a hide, and a player skinning for
      -- an hour does not want a hundred lines about it. The other thing worth
      -- saying -- that a recipe is now fully covered -- is said below.
      if now > before and before == 0 then
        -- One reagent can serve a dozen recipes. The whole announcement, the
        -- closing "and N more" included, never grows past the limit set in
        -- the settings -- the same limit the item tooltip obeys.
        local total = 0
        while wants[total + 1] do total = total + 1 end

        local cap  = MaxRec()
        local show = total
        if total > cap then show = cap - 1 end
        if show < 1 then show = 1 end

        local i = 1
        while i <= show do
          Print(Lf("wGot", name, now, wants[i].need, wants[i].recipe))
          i = i + 1
        end
        if total > show and show + 1 <= cap then
          Print("|cff9d9d9d" .. Lf("wMore", total - show) .. "|r")
        end
      end
    end
  end

  bagHave, bagKnown = fresh, true

  -- "You have everything now" is said once, at the moment it becomes true,
  -- and can be said again only after the pile has been spent. One reagent can
  -- complete eight recipes at once, so this list obeys the same limit.
  local ready, readyN = {}, 0
  for recipe, entry in pairs(DB.watch) do
    if RecipeReady(entry) then
      if not entry.said then
        entry.said = true
        if bagKnown and not quiet and DB.signal then
          readyN = readyN + 1
          ready[readyN] = recipe
        end
      end
    else
      entry.said = nil
    end
  end

  if readyN > 0 then
    pcall(table.sort, ready)
    local cap  = MaxRec()
    local show = readyN
    if readyN > cap then show = cap - 1 end
    if show < 1 then show = 1 end

    local i = 1
    while i <= show do
      Print("|cff40ff40" .. Lf("wReady", ready[i]) .. "|r")
      i = i + 1
    end
    if readyN > show and show + 1 <= cap then
      Print("|cff9d9d9d" .. Lf("wMore", readyN - show) .. "|r")
    end
  end

  -- The map only cares about WHICH reagents are still missing, not how many
  -- of each: picking up one more hide out of eight must not redraw every pin.
  if MissingChanged and MissingChanged() then mapDirty = true end

  if UpdateWatchWindow then UpdateWatchWindow() end
end

----------------------------------------------------------------------
-- where a reagent comes from
--
-- KoQuest carries the pfQuest database and hands it over in two globals:
-- KoDB[db]["data"] with the facts and KoDB[db]["loc"] with the localized
-- names, plus KoDatabase:GetIDByName to look an id up by name. Everything
-- below is guarded: without KoQuest the addon simply knows less.
----------------------------------------------------------------------

local koItemId, koUnitIds = {}, {}     -- name -> ids, worked out once
local ObjectName                       -- defined with the source lookups
local dropByUnit, dropDirty = {}, true

local function KoReady()
  if type(KoDB) ~= "table" or type(KoDatabase) ~= "table" then return false end
  if type(KoDB.items) ~= "table" or type(KoDB.units) ~= "table" then return false end
  if type(KoDB.items.data) ~= "table" then return false end
  return true
end

local function IdsByName(name, db)
  if not KoReady() or not name or name == "" then return nil end
  if type(KoDatabase.GetIDByName) ~= "function" then return nil end
  local ok, res = pcall(KoDatabase.GetIDByName, KoDatabase, name, db)
  if not ok or type(res) ~= "table" then return nil end
  return res
end

local function ItemIds(name)
  if koItemId[name] ~= nil then return koItemId[name] end
  local ids = IdsByName(name, "items") or false
  koItemId[name] = ids
  return ids
end

local function UnitIds(name)
  if koUnitIds[name] ~= nil then return koUnitIds[name] end
  local ids = IdsByName(name, "units") or false
  koUnitIds[name] = ids
  return ids
end

local function UnitName_(id)
  if not KoReady() then return nil end
  local loc = KoDB.units.loc
  if type(loc) ~= "table" then return nil end
  return loc[id]
end

local function ZoneName(id)
  if not KoReady() or type(KoDB.zones) ~= "table" then return nil end
  local loc = KoDB.zones.loc
  if type(loc) ~= "table" then return nil end
  return loc[id]
end

-- every unit that drops this item, with the chance; loot references are
-- followed one level, which is where a lot of the common stuff hides
local function UnitsForItem(itemId, out)
  out = out or {}
  if not KoReady() then return out end
  local entry = KoDB.items.data[itemId]
  if type(entry) ~= "table" then return out end

  if type(entry.U) == "table" then
    for unit, chance in pairs(entry.U) do
      if not out[unit] or out[unit] < chance then out[unit] = chance end
    end
  end

  if type(entry.R) == "table" and type(KoDB.refloot) == "table"
     and type(KoDB.refloot.data) == "table" then
    for ref in pairs(entry.R) do
      local pack = KoDB.refloot.data[ref]
      if type(pack) == "table" and type(pack.U) == "table" then
        for unit, chance in pairs(pack.U) do
          if not out[unit] or out[unit] < chance then out[unit] = chance end
        end
      end
    end
  end
  return out
end

-- the busiest zone a unit lives in
local function UnitZone(unitId)
  if not KoReady() then return nil end
  local entry = KoDB.units.data[unitId]
  if type(entry) ~= "table" or type(entry.coords) ~= "table" then return nil end

  local tally, best, bestN = {}, nil, 0
  local i = 1
  while entry.coords[i] do
    local zone = entry.coords[i][3]
    if zone then
      tally[zone] = (tally[zone] or 0) + 1
      if tally[zone] > bestN then best, bestN = zone, tally[zone] end
    end
    i = i + 1
  end
  if not best then return nil end
  return ZoneName(best), best
end

-- Which watched reagents each unit can give. Built from the watch list, so
-- a mouseover costs one table lookup instead of a walk through the base.
local function BuildDrops()
  local index = Need()                 -- may rebuild, and that sets the flag
  dropByUnit, dropDirty = {}, false
  if not DB.mobs then return end       -- switched off: nothing is built at all
  if not KoReady() then return end

  for reagent in pairs(index) do
    local ids = ItemIds(reagent)
    if ids then
      local units = {}
      for itemId in pairs(ids) do UnitsForItem(itemId, units) end
      for unitId, chance in pairs(units) do
        if not dropByUnit[unitId] then dropByUnit[unitId] = {} end
        local slot, k = dropByUnit[unitId], 1
        while slot[k] do k = k + 1 end
        slot[k] = { name = reagent, chance = chance }
      end
    end
  end
end

local function DropsFor(unitName)
  if dropDirty then BuildDrops() end
  local ids = UnitIds(unitName)
  if not ids then return nil end

  local out, n = {}, 0
  for unitId in pairs(ids) do
    local list = dropByUnit[unitId]
    if list then
      local i = 1
      while list[i] do
        n = n + 1
        out[n] = list[i]
        i = i + 1
      end
    end
  end
  if n == 0 then return nil end
  return out, n
end

----------------------------------------------------------------------
-- and what has dropped for this player, whatever the database says
----------------------------------------------------------------------


CountKeys = function(tbl)
  local n = 0
  if type(tbl) ~= "table" then return 0 end
  for _ in pairs(tbl) do n = n + 1 end
  return n
end

-- The oldest entry goes when the table is full. Refusing to learn anything
-- new once a cap is reached would be the worst of both: a table that is
-- full of whatever happened to come first, and no sign that it stopped.
local function EvictOldest(tbl, cap)
  while CountKeys(tbl) > cap do
    local worst, worstAt = nil, nil
    for key, entry in pairs(tbl) do
      local when = 0
      if type(entry) == "table" and type(entry.t) == "number" then when = entry.t end
      if not worstAt or when < worstAt then worst, worstAt = key, when end
    end
    if not worst then return end
    tbl[worst] = nil
  end
end

local function Now()
  if type(time) == "function" then return time() end
  if type(GetTime) == "function" then return GetTime() end
  return 0
end

-- Only what is actually being collected is worth remembering: that keeps
-- the record small and every line in it useful.
local function Wanted(item)
  return Need()[item] ~= nil
end

-- The last creature examined that turned out to have nothing worth showing:
-- its name and the generation of the watch list at that moment, in one string.
-- (One local rather than two -- this file sits close to the 200 local limit.)
local mobBlank = nil

local function RememberDrop(mob, item)
  mobBlank = nil
  if not DB.drops or not mob or not item then return end
  if not Wanted(item) then return end
  if type(CraftFocusDrops) ~= "table" then CraftFocusDrops = {} end

  local entry = CraftFocusDrops[mob]
  if type(entry) ~= "table" then entry = {} ; CraftFocusDrops[mob] = entry end
  -- a creature not known to give this before is a new place on the map
  if not entry[item] then mapDirty = true end
  entry[item] = true
  entry.t = Now()

  EvictOldest(CraftFocusDrops, K.DROPS_CAP)
end

-- Skinning is nowhere in the database, and a hide comes off a kind of beast
-- rather than off one named mob: a wolf of this level gives the same leather
-- as any other wolf of this level. So what came off whom is also remembered
-- as "creature type + level band", and that answers for a mob never met
-- before -- which is the whole point.
local function LevelBand(level)
  if type(level) ~= "number" or level < 1 then return nil end
  return math.floor(level / 5)          -- five levels to a band
end

local function KindKey(kind, level)
  local band = LevelBand(level)
  if not kind or kind == "" or not band then return nil end
  return kind .. ":" .. band
end

local function RememberKind(kind, level, item)
  mobBlank = nil
  if not DB.drops or not item then return end
  if not Wanted(item) then return end
  local key = KindKey(kind, level)
  if not key then return end

  if type(CraftFocusKinds) ~= "table" then CraftFocusKinds = {} end
  local pack = CraftFocusKinds[key]
  if type(pack) ~= "table" then pack = {} ; CraftFocusKinds[key] = pack end
  pack[item] = (type(pack[item]) == "number" and pack[item] or 0) + 1
  pack.t = Now()

  EvictOldest(CraftFocusKinds, K.KINDS_CAP)
end

local function KindDrops(kind, level)
  local key = KindKey(kind, level)
  if not key or type(CraftFocusKinds) ~= "table" then return nil end
  return CraftFocusKinds[key]
end

local function SeenFrom(mob, item)
  if type(CraftFocusDrops) ~= "table" then return false end
  local pack = CraftFocusDrops[mob]
  return (type(pack) == "table" and pack[item] == true)
end

local function ScanLoot()
  if not DB.drops then return end
  if type(GetNumLootItems) ~= "function" or type(GetLootSlotInfo) ~= "function" then return end
  if not UnitName or not UnitExists or not UnitIsDead then return end
  if not UnitExists("target") or not UnitIsDead("target") then return end

  local mob = UnitName("target")
  if not mob or mob == "" then return end

  local kind, level = nil, nil
  if type(UnitCreatureType) == "function" then kind = UnitCreatureType("target") end
  if type(UnitLevel) == "function" then level = UnitLevel("target") end

  local n, slot = GetNumLootItems() or 0, 1
  while slot <= n do
    local _, item = GetLootSlotInfo(slot)
    if item and item ~= "" then
      RememberDrop(mob, item)
      RememberKind(kind, level, item)
    end
    slot = slot + 1
  end
end

-- The stamp on an entry is the last time this creature actually gave
-- something that was being collected. Anything that has not given anything
-- for a month is dropped at login, and when the table is full the same
-- stamp decides who leaves first.

local function ForgetStale()
  if type(time) ~= "function" then return end
  local now = time()
  if type(now) ~= "number" or now < 1000 then return end

  local packs = { CraftFocusDrops, CraftFocusKinds }
  local i = 1
  while packs[i] do
    local tbl = packs[i]
    if type(tbl) == "table" then
      for key, entry in pairs(tbl) do
        local when = (type(entry) == "table" and type(entry.t) == "number") and entry.t or nil
        if when and (now - when) > K.FORGET_AFTER then tbl[key] = nil end
      end
    end
    i = i + 1
  end
end

----------------------------------------------------------------------
-- the boxes in the recipe list
----------------------------------------------------------------------

local marks = {}

local function StyleMark(box, on)
  if on then
    box.text:SetText("-")
    box.text:SetTextColor(1, 0.82, 0)
    box.fill:SetTexture(0.35, 0.25, 0.05)
  else
    box.text:SetText("+")
    box.text:SetTextColor(0.55, 0.55, 0.55)
    box.fill:SetTexture(0.14, 0.14, 0.16)
  end
end

local function MakeMark(i, row)
  local box = CreateFrame("Button", nil, row)
  box:SetWidth(13)
  box:SetHeight(13)
  box:SetPoint("RIGHT", row, "RIGHT", -3, 0)
  if row.GetFrameLevel and box.SetFrameLevel then
    box:SetFrameLevel(row:GetFrameLevel() + 4)
  end

  local edge = box:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints(box)
  edge:SetTexture(0, 0, 0, 1)

  local fill = box:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
  box.fill = fill

  local text = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not text:GetFont() or text:GetFont() == "" then
    text:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
  end
  text:SetPoint("CENTER", box, "CENTER", 0, 0)
  box.text = text

  box:SetScript("OnClick", function()
    local self = this or box
    local id = self.recipeId
    if not id then return end
    TakeWatch(id)
    needDirty = true
    RefreshBags(true)
    RefreshList()
    if UpdateWatchWindow then UpdateWatchWindow() end
  end)

  Tip(box, function()
    local id = box.recipeId
    local name = id and GetTradeSkillInfo(id) or nil
    local head = L("wMarkOff")
    if name and IsWatched(name) then head = L("wMarkOn") end
    return { head, name or "", L("wMarkHint") }
  end)

  StyleMark(box, false)
  marks[i] = box
  return box
end

-- The boxes ride on the client's own rows and are placed from the watcher
-- below, so they work the same whether this addon is drawing the list or
-- the client is. Nothing is written into the window: each row is only asked
-- which recipe it currently holds.
local function PlaceMarks()
  local open = getglobal("TradeSkillFrame")
  open = open and open.IsVisible and open:IsVisible()

  local rows, i = RowCount(), 1
  while i <= rows do
    local row = getglobal("TradeSkillSkill" .. i)
    local box = marks[i]

    if not open or not DB.marks or not row then
      if box then box:Hide() end
    else
      local shown = row.IsVisible and row:IsVisible()
      local id = row.GetID and row:GetID() or 0
      local name, kind = nil, nil
      if shown and id and id > 0 and type(GetTradeSkillInfo) == "function" then
        name, kind = GetTradeSkillInfo(id)
      end

      if name and kind ~= "header" then
        if not box then box = MakeMark(i, row) end
        box.recipeId = id
        StyleMark(box, IsWatched(name))
        box:Show()
      elseif box then
        box:Hide()
      end
    end
    i = i + 1
  end
end

----------------------------------------------------------------------
-- the line on an item's tooltip
----------------------------------------------------------------------


local function TooltipHasText(needle)
  if not needle or needle == "" then return false end
  local last = 30
  if GameTooltip.NumLines then
    local n = GameTooltip:NumLines()
    if type(n) == "number" and n > 0 then last = n end
  end
  local i = 2
  while i <= last do
    local fs = getglobal("GameTooltipTextLeft" .. i)
    if not fs then return false end
    local text = fs.GetText and fs:GetText()
    if text and text ~= "" and string.find(text, needle, 1, true) then return true end
    i = i + 1
  end
  return false
end

-- The tooltip is not hooked: it is read. Whoever filled it -- the stock bag,
-- the loot window, another addon's window -- the item name is in the first
-- line, and that is all this needs.
local function DecorateTooltip()
  if not DB.tips then return end
  if not GameTooltip or not GameTooltip.IsVisible or not GameTooltip:IsVisible() then return end
  if WatchCount() == 0 then return end

  local first = getglobal("GameTooltipTextLeft1")
  local name = first and first.GetText and first:GetText()
  if not name or name == "" then return end

  local wants = Need()[name]
  if not wants then
    -- Not a reagent. It may be a creature -- but only if the cursor is
    -- actually on one: asking the database about every item name would mean
    -- walking thirty thousand rows for nothing.
    if not DB.mobs then return end
    if not UnitExists or not UnitName then return end
    if not UnitExists("mouseover") then return end
    if UnitName("mouseover") ~= name then return end
    -- Both headers must be looked for: the tooltip driver runs several times
    -- a second while the cursor rests on a creature, and a guard that knows
    -- only one of them lets the other line pile up on every pass.
    if TooltipHasText(L("mobHead")) then return end
    if TooltipHasText(L("mobLike")) then return end
    -- A creature that gives nothing leaves no line behind, so there is no
    -- marker to find on the next pass. Remember the verdict instead: without
    -- this the database is walked several times a second for as long as the
    -- cursor rests on a creature that was never going to be useful.
    if mobBlank == name .. "#" .. needGen then return end
    local list, n = DropsFor(name)
    local seen = 0

    if list then
      -- most likely first
      pcall(table.sort, list, function(a, b) return (a.chance or 0) > (b.chance or 0) end)
      local i = 1
      while list[i] and i <= 4 do
        local r = list[i]
        local held, need = Held(r.name), 0
        local w = Need()[r.name]
        if w and w[1] then need = w[1].need or 0 end
        local left = need - held
        if left < 0 then left = 0 end

        local text = "   " .. r.name
        if r.chance and r.chance > 0 then
          text = text .. "  " .. string.format("%.1f", r.chance) .. "%"
        end
        if left > 0 then text = text .. "  |cffffd100(" .. left .. ")|r" end

        if seen == 0 then GameTooltip:AddLine(K.TIP_MARK .. L("mobHead"), 1, 0.82, 0) end
        seen = seen + 1
        GameTooltip:AddLine(text, 0.85, 0.85, 0.85)
        i = i + 1
      end
    end

    -- The database has nothing on skinning, so what a creature gives is
    -- known only from this player's own record -- and by kind and level
    -- rather than by name, so that a beast never met before still answers.
    if seen == 0 and DB.drops then
      local kind, level = nil, nil
      if type(UnitCreatureType) == "function" then kind = UnitCreatureType("mouseover") end
      if type(UnitLevel) == "function" then level = UnitLevel("mouseover") end
      local known = KindDrops(kind, level)
      if known then
        local shown = 0
        for item in pairs(known) do
          if item ~= "t" and Need()[item] and shown < 3 then
            if shown == 0 then
              GameTooltip:AddLine(K.TIP_MARK .. L("mobLike"), 1, 0.82, 0)
            end
            shown = shown + 1
            seen = seen + 1
            GameTooltip:AddLine("   " .. item, 0.75, 0.75, 0.75)
          end
        end
      end
    end

    if seen > 0 then
      mobBlank = nil
      GameTooltip:Show()
    else
      mobBlank = name .. "#" .. needGen
    end
    return
  end
  if TooltipHasText(L("tipNeed")) then return end

  GameTooltip:AddLine(K.TIP_MARK .. L("tipNeed"), 1, 0.82, 0)

  local have, total = Held(name), 0
  while wants[total + 1] do total = total + 1 end

  -- a common reagent can belong to a dozen recipes; the tooltip shows the
  -- first few and counts the rest
  local show = total
  if show > MaxRec() then show = MaxRec() end

  local i = 1
  while i <= show do
    local need = wants[i].need or 1
    local r, g, b = 1, 0.82, 0
    if have >= need then r, g, b = 0.4, 1, 0.4 end
    GameTooltip:AddLine("   " .. wants[i].recipe .. "  " .. have .. "/" .. need, r, g, b)
    i = i + 1
  end
  if total > show then
    GameTooltip:AddLine(Lf("wMore", total - show), 0.6, 0.6, 0.6)
  end
  GameTooltip:Show()
end

-- The stock bag button rebuilds its tooltip five times a second (its
-- OnUpdate calls OnEnter again), which wipes anything appended to it. Racing
-- that frame by frame does not work; wrapping the global that does the
-- rebuilding does, and our line lands last every time.
local stockHooked = false

local function HookStockBags()
  if stockHooked then return end
  if type(ContainerFrameItemButton_OnEnter) ~= "function" then return end

  local orig = ContainerFrameItemButton_OnEnter
  ContainerFrameItemButton_OnEnter = function()
    orig()
    pcall(DecorateTooltip)
  end
  stockHooked = (ContainerFrameItemButton_OnEnter ~= orig)
end

----------------------------------------------------------------------
-- the watch window
----------------------------------------------------------------------

local wnd, wndRows = nil, {}
local ToggleConfig                     -- from the settings section below
local wndOffset, wndLines, wndRowsFit = 0, 0, 14

local function SmallButton(parent, width, label, onClick, tip)
  local b = CreateFrame("Button", nil, parent)
  b:SetWidth(width)
  b:SetHeight(15)

  local edge = b:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints(b)
  edge:SetTexture(0, 0, 0, 1)

  local fill = b:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  fill:SetTexture(0.20, 0.20, 0.22)
  b.fill = fill

  local text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not text:GetFont() or text:GetFont() == "" then
    text:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
  end
  text:SetPoint("CENTER", b, "CENTER", 0, 0)
  text:SetText(label)
  text:SetTextColor(0.9, 0.9, 0.9)
  b.text = text

  b:SetScript("OnClick", onClick)
  if tip then Tip(b, tip) end
  return b
end

local function ScrollWatch(step)
  wndOffset = wndOffset + step
  if wndOffset > wndLines - wndRowsFit then wndOffset = wndLines - wndRowsFit end
  if wndOffset < 0 then wndOffset = 0 end
  if UpdateWatchWindow then UpdateWatchWindow() end
end

-- how many lines fit in the window as it is now
local function RowsFit()
  if not wnd then return 14 end
  local h = wnd:GetHeight() or 240
  local n = math.floor((h - K.WND_TOP - K.WND_BOTTOM) / K.WND_LINE)
  if n < 3 then n = 3 end
  if n > K.WND_MAXROWS then n = K.WND_MAXROWS end
  return n
end

local rowHit, rowDrop = {}, {}
local ShowRecipe                       -- filled in below
local SourceTag                        -- from the sources section below
local ListActions, RememberSlot        -- the same, for the slash commands
local LearnProfessionSlot

local function EnsureRow(i)
  if wndRows[i] then return wndRows[i] end

  local top = -K.WND_TOP - (i - 1) * K.WND_LINE

  local fs = wnd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not fs:GetFont() or fs:GetFont() == "" then
    fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
  end
  fs:SetPoint("TOPLEFT", wnd, "TOPLEFT", 18, top)
  fs:SetJustifyH("LEFT")
  wndRows[i] = fs

  -- an invisible button over the whole line: that is what makes a recipe
  -- name behave like a link
  local hit = CreateFrame("Button", nil, wnd)
  hit:SetPoint("TOPLEFT", wnd, "TOPLEFT", 14, top + 2)
  hit:SetPoint("RIGHT", wnd, "RIGHT", -34, 0)
  hit:SetHeight(K.WND_LINE)
  local glow = hit:CreateTexture(nil, "BACKGROUND")
  glow:SetAllPoints(hit)
  glow:SetTexture(1, 1, 1, 0.10)
  glow:Hide()
  hit.glow = glow
  hit:SetScript("OnEnter", function()
    local self = this or hit
    self.glow:Show()
    if GameTooltip and self.recipe then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.recipe)
      GameTooltip:AddLine("|cff9d9d9d" .. L("wOpen") .. "|r")
      GameTooltip:Show()
    end
  end)
  hit:SetScript("OnLeave", function()
    local self = this or hit
    self.glow:Hide()
    if GameTooltip then GameTooltip:Hide() end
  end)
  hit:SetScript("OnClick", function()
    local self = this or hit
    if self.recipe and ShowRecipe then ShowRecipe(self.recipe) end
  end)
  hit:Hide()
  rowHit[i] = hit

  -- and a small cross to forget it
  local drop = CreateFrame("Button", nil, wnd)
  drop:SetWidth(14)
  drop:SetHeight(K.WND_LINE)
  drop:SetPoint("TOPRIGHT", wnd, "TOPRIGHT", -16, top + 2)
  local dt = drop:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not dt:GetFont() or dt:GetFont() == "" then
    dt:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
  end
  dt:SetPoint("CENTER", drop, "CENTER", 0, 0)
  dt:SetText("x")
  dt:SetTextColor(0.75, 0.4, 0.4)
  drop.text = dt
  drop:SetScript("OnEnter", function()
    local self = this or drop
    self.text:SetTextColor(1, 0.3, 0.3)
    if GameTooltip and self.recipe then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L("wForget"))
      GameTooltip:AddLine("|cff9d9d9d" .. self.recipe .. "|r")
      GameTooltip:Show()
    end
  end)
  drop:SetScript("OnLeave", function()
    local self = this or drop
    self.text:SetTextColor(0.75, 0.4, 0.4)
    if GameTooltip then GameTooltip:Hide() end
  end)
  drop:SetScript("OnClick", function()
    local self = this or drop
    if not self.recipe then return end
    if DropWatch(self.recipe) then
      Print(Lf("wRemoved", self.recipe))
      RefreshList()
      if UpdateWatchWindow then UpdateWatchWindow() end
    end
  end)
  drop:Hide()
  rowDrop[i] = drop

  return fs
end

-- Dragging the corner. StartSizing is not trusted on this client, so the
-- size is worked out from the cursor by hand: the window is pinned by its
-- top left corner first, so it grows to the right and down and its title
-- stays where it was.
local sizing = nil

-- The window may not shrink below the row of buttons along its bottom edge:
-- the two scroll arrows on the left, then Settings, Clear and Close chained
-- from the right. Everything that sets a size goes through here, including a
-- size restored from saved variables, which may come from an older layout.
local function ClampSize(w, h)
  if type(w) ~= "number" or w < K.WND_MINW then w = K.WND_MINW end
  if w > 700 then w = 700 end
  if type(h) ~= "number" or h < 130 then h = 130 end
  if h > 700 then h = 700 end
  return w, h
end
local SaveWatchPos, PlaceWatch        -- defined with the window below

local function StopSizing()
  sizing = nil
  if wnd and wnd.grip then wnd.grip:SetScript("OnUpdate", nil) end
  if wnd then
    DB.wsize = { w = wnd:GetWidth(), h = wnd:GetHeight() }
    SaveWatchPos()
  end
  if UpdateWatchWindow then UpdateWatchWindow() end
end

local function DoSizing()
  if not sizing or not wnd then return end
  if not GetCursorPosition then StopSizing() return end

  local scale = 1
  if wnd.GetEffectiveScale then scale = wnd:GetEffectiveScale() or 1 end
  if scale == 0 then scale = 1 end

  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale

  local w = sizing.w + (cx - sizing.x)
  local h = sizing.h - (cy - sizing.y)
  w, h = ClampSize(w, h)

  wnd:SetWidth(w)
  wnd:SetHeight(h)
  if UpdateWatchWindow then UpdateWatchWindow() end
end

local function StartSizingNow()
  if not wnd or not GetCursorPosition then return end
  local scale = 1
  if wnd.GetEffectiveScale then scale = wnd:GetEffectiveScale() or 1 end
  if scale == 0 then scale = 1 end
  local cx, cy = GetCursorPosition()

  -- pin by the top left corner, so growing does not drag the window around
  local left, top = wnd:GetLeft(), wnd:GetTop()
  if type(left) == "number" and type(top) == "number" then
    DB.wpos = { left = left, top = top }
    PlaceWatch()
  end

  sizing = { x = cx / scale, y = cy / scale, w = wnd:GetWidth(), h = wnd:GetHeight() }
  if wnd.grip then wnd.grip:SetScript("OnUpdate", DoSizing) end
end

-- A recipe in the list is a link: clicking it picks that recipe in the
-- profession window. Opening the window itself is not possible --
-- CastSpellByName is protected here -- so if it is shut, say so.
-- Reading what sits in an action slot: the client has no API for it, but a
-- tooltip of our own drawn from that slot has the name in its first line.
local scanTip, scanReady = nil, nil

local function ScanTooltip()
  if scanReady ~= nil then return scanReady end
  scanReady = false
  if not CreateFrame or not getglobal then return false end
  pcall(function()
    scanTip = CreateFrame("GameTooltip", "CraftFocusScanTip", UIParent, "GameTooltipTemplate")
  end)
  if not scanTip then return false end
  pcall(function() scanTip:SetOwner(UIParent, "ANCHOR_NONE") end)
  scanReady = (getglobal("CraftFocusScanTipTextLeft1") ~= nil)
  return scanReady
end

local function ActionName(slot)
  if ScanTooltip() then
    pcall(function() scanTip:SetOwner(UIParent, "ANCHOR_NONE") end)
    if scanTip.ClearLines then pcall(function() scanTip:ClearLines() end) end
    local ok = pcall(function() scanTip:SetAction(slot) end)
    if ok then
      local fs = getglobal("CraftFocusScanTipTextLeft1")
      local text = fs and fs.GetText and fs:GetText()
      if text and text ~= "" then return text end
    end
  end
  -- a macro says its own name without any tooltip
  if type(GetActionText) == "function" then
    local text = GetActionText(slot)
    if text and text ~= "" then return text end
  end
  return nil
end

-- The window title and the spell on the bar do not always agree on a
-- language on this server -- the profession pane says "Leatherworking"
-- while the bar may say "Кожевничество". So the names are compared
-- loosely, and whatever worked is remembered for next time.
local function SameName(a, b)
  if not a or not b then return false end
  a, b = string.lower(a), string.lower(b)
  if a == b then return true end
  if string.find(a, b, 1, true) then return true end
  if string.find(b, a, 1, true) then return true end
  return false
end

RememberSlot = function(line, slot)
  if not line or not slot then return end
  if type(DB.profSlot) ~= "table" then DB.profSlot = {} end
  DB.profSlot[line] = slot
end

-- While a profession window is open the client marks its action button as
-- the current action. The trouble is that it marks other things current as
-- well: a spell in mid-cast, a stance, an aura. Taking the first current
-- slot is how pressing button 3 and then opening Tailoring taught the addon
-- slot 3 and kept it for good (reported by Servo, 01.09.2026).
--
-- Names cannot settle it: the bar and the profession pane answer in
-- different languages on this server, which is why this code went looking at
-- "current" in the first place. What does settle it is WHEN a slot is
-- current, in three looks:
--
--   1. the window opens      -- candidates: everything current right now
--   2. a couple of seconds later, window still open -- a finished cast has
--      stopped being current, so it drops out
--   3. the window is shut    -- a stance or an aura is still current, and
--      the profession button is not, so what remains is the profession
--
-- A name that does match is of course taken at once, and a lone candidate
-- needs no test at all. Where the answer stays ambiguous nothing is
-- remembered: a wrong slot kept for good is worse than no slot, and
-- /cf prof <number> sets it by hand.
-- A global, not a local: this chunk has used up all 200 local slots the
-- client allows, and fields on a table cost none of them.
CraftFocusProf = {}

CraftFocusProf.learned = function(line, slot, announce, known)
  RememberSlot(line, slot)
  if announce and known ~= slot then
    Print("|cff9d9d9d" .. Lf("wSlotLearn", slot, line) .. "|r")
  end
end

CraftFocusProf.current = function(line)
  local cand, n, named = {}, 0, nil
  local slot = 1
  while slot <= 120 do
    local live = (type(HasAction) ~= "function") or HasAction(slot)
    if live and IsCurrentAction(slot) then
      -- an attack or an autoshot is "current" too, and is not what we want
      local skip = false
      if type(IsAttackAction) == "function" and IsAttackAction(slot) then skip = true end
      if type(IsAutoRepeatAction) == "function" and IsAutoRepeatAction(slot) then skip = true end
      if not skip then
        n = n + 1
        cand[n] = slot
        if not named and line and SameName(ActionName(slot), line) then named = slot end
      end
    end
    slot = slot + 1
  end
  return cand, n, named
end

LearnProfessionSlot = function(announce)
  CraftFocusProf.pend = nil
  if type(IsCurrentAction) ~= "function" then return nil end
  if type(GetTradeSkillLine) ~= "function" then return nil end

  local line = GetTradeSkillLine()
  if not line or line == "" or line == "UNKNOWN" then return nil end

  local known = (type(DB.profSlot) == "table") and DB.profSlot[line] or nil
  local cand, n, named = CraftFocusProf.current(line)

  if named then
    CraftFocusProf.learned(line, named, announce, known)
    return named
  end
  if n == 1 then
    CraftFocusProf.learned(line, cand[1], announce, known)
    return cand[1]
  end
  if n == 0 then return known end

  -- ambiguous: let the timer below watch these slots
  CraftFocusProf.pend = { line = line, cand = cand, n = n, known = known,
                announce = announce, t = 0, stage = 1 }
  return known
end

-- steps 2 and 3 of the story above; called from the keeper
-- keeps the candidates whose "current" state is what we are looking for
CraftFocusProf.survivors = function(want)
  local left, k = {}, 0
  local i = 1
  while CraftFocusProf.pend.cand[i] do
    local slot = CraftFocusProf.pend.cand[i]
    local cur = IsCurrentAction(slot) and true or false
    if cur == want then k = k + 1; left[k] = slot end
    i = i + 1
  end
  return left, k
end

CraftFocusProf.tick = function(step, open)
  local pend = CraftFocusProf.pend
  if not pend then return end
  if type(IsCurrentAction) ~= "function" then CraftFocusProf.pend = nil; return end

  if open then
    if pend.stage ~= 1 then return end
    pend.t = pend.t + (type(step) == "number" and step or 0.05)
    if pend.t < 2.5 then return end
    -- still current with the window open: a cast that has ended drops out
    local left, k = CraftFocusProf.survivors(true)
    pend.stage = 2
    if k == 1 then
      CraftFocusProf.learned(pend.line, left[1], pend.announce, pend.known)
      CraftFocusProf.pend = nil
      return
    end
    if k == 0 then CraftFocusProf.pend = nil; return end
    pend.cand, pend.n = left, k
    return
  end

  -- the window is shut: a stance or an aura is still current, the
  -- profession button is not
  local left, k = CraftFocusProf.survivors(false)
  if k == 1 then
    CraftFocusProf.learned(pend.line, left[1], pend.announce, pend.known)
  end
  CraftFocusProf.pend = nil
end

ListActions = function()
  Print(L("wActHead"))
  local seen = 0
  local slot = 1
  while slot <= 120 do
    if type(HasAction) ~= "function" or HasAction(slot) then
      local name = ActionName(slot)
      local mark = ""
      if type(IsCurrentAction) == "function" and IsCurrentAction(slot) then
        mark = " |cff40ff40<- текущее|r"
      end
      if name and name ~= "" then
        seen = seen + 1
        Print(Lf("wActLine", slot, name) .. mark)
      elseif mark ~= "" then
        seen = seen + 1
        Print(Lf("wActLine", slot, "?") .. mark)
      end
    end
    slot = slot + 1
  end
  if seen == 0 then Print("|cffff8080" .. L("wActNone") .. "|r") end
end

-- CastSpellByName is protected here, so the profession cannot be cast by
-- name. UseAction is not protected: if the profession sits on an action
-- bar, pressing that slot opens the window exactly as a click would.
local function OpenProfession(line)
  if type(UseAction) ~= "function" then return false end

  local stored = (type(DB.profSlot) == "table") and line and DB.profSlot[line] or nil
  local live = stored and ((type(HasAction) ~= "function") or HasAction(stored))

  -- The stored slot goes first when it still says the right thing, or when
  -- it says nothing readable at all -- names differ by language here, so an
  -- unreadable or foreign name is no reason to distrust it.
  if live then
    local name = ActionName(stored)
    if not name or name == "" or SameName(name, line) then
      pcall(UseAction, stored)
      return true
    end
  end

  if not line or line == "" or line == "UNKNOWN" then
    -- with no profession name there is nothing to check against
    if live then pcall(UseAction, stored); return true end
    return false
  end

  -- a slot that names the profession is better evidence than a stored
  -- number, and it also heals a number that was learnt wrong
  local slot = 1
  while slot <= 120 do
    if type(HasAction) ~= "function" or HasAction(slot) then
      if SameName(ActionName(slot), line) then
        RememberSlot(line, slot)
        pcall(UseAction, slot)
        return true
      end
    end
    slot = slot + 1
  end

  -- nothing on the bar names it: the stored slot is all we have
  if live then pcall(UseAction, stored); return true end
  return false
end

ShowRecipe = function(name)
  if not name then return end

  local frame = getglobal("TradeSkillFrame")
  local open = frame and frame.IsVisible and frame:IsVisible()
  if not open or type(GetNumTradeSkills) ~= "function" or (GetNumTradeSkills() or 0) == 0 then
    -- try to open the profession ourselves, and finish the job when the
    -- window arrives
    local entry = DB.watch[name]
    local line = entry and entry.line
    if line and OpenProfession(line) then
      pendingRecipe = name
      Print(Lf("wOpening", line))
      return
    end
    Print(L("wNoWindow"))
    if line then Print("|cff9d9d9d" .. Lf("wNoAction", line) .. "|r") end
    return
  end

  local n, i = GetNumTradeSkills() or 0, 1
  while i <= n do
    local rname, kind = GetTradeSkillInfo(i)
    if rname == name and kind ~= "header" then
      if type(SelectTradeSkill) == "function" then
        pcall(SelectTradeSkill, i)
        if type(TradeSkillFrame_Update) == "function" then pcall(TradeSkillFrame_Update) end
      end
      return
    end
    i = i + 1
  end
  Print(Lf("wNotFound", name))
end

-- Where the window sits is kept as plain screen coordinates of its top left
-- corner. GetPoint on this client has surprised us more than once, and a
-- point saved as one anchor and restored as another is how a window ends up
-- pinned to the top of the screen after a relog.
SaveWatchPos = function()
  if not wnd or not wnd.GetLeft then return end
  local left, top = wnd:GetLeft(), wnd:GetTop()
  if type(left) == "number" and type(top) == "number" then
    DB.wpos = { left = left, top = top }
  end
end

PlaceWatch = function()
  if not wnd then return end
  wnd:ClearAllPoints()
  local p = DB.wpos
  if type(p) == "table" and type(p.left) == "number" and type(p.top) == "number" then
    wnd:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p.left, p.top)
  else
    wnd:SetPoint("CENTER", UIParent, "CENTER", 260, 60)
  end
end

local function BuildWatchWindow()
  if wnd then return end

  wnd = CreateFrame("Frame", "CraftFocusWatch", UIParent)
  wnd:SetFrameStrata("DIALOG")
  wnd:EnableMouse(true)
  wnd:SetMovable(true)
  if wnd.SetResizable then wnd:SetResizable(true) end
  wnd:RegisterForDrag("LeftButton")
  wnd:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  -- RegisterForDrag answers on buttons here, not on frames, so the plain
  -- mouse scripts do the moving
  local function StartMove()
    local self = this or wnd
    if self.StartMoving then self:StartMoving() end
  end
  local function StopMove()
    local self = this or wnd
    if self.StopMovingOrSizing then self:StopMovingOrSizing() end
    SaveWatchPos()
  end
  wnd:SetScript("OnDragStart", StartMove)
  wnd:SetScript("OnDragStop", StopMove)
  wnd:SetScript("OnMouseDown", StartMove)
  wnd:SetScript("OnMouseUp", StopMove)

  if wnd.EnableMouseWheel then
    wnd:EnableMouseWheel(true)
    wnd:SetScript("OnMouseWheel", function()
      local dir = arg1
      if type(dir) ~= "number" then return end
      if dir > 0 then ScrollWatch(-3) else ScrollWatch(3) end
    end)
  end

  local w, h = K.WND_MINW, 74 + 14 * K.WND_LINE
  if type(DB.wsize) == "table" then
    if type(DB.wsize.w) == "number" then w = DB.wsize.w end
    if type(DB.wsize.h) == "number" then h = DB.wsize.h end
  end
  -- A size saved by an older version can be narrower than the row of buttons
  -- now needs, and the settings button then sat on top of the scroll arrow.
  w, h = ClampSize(w, h)

  wnd:SetWidth(w)
  wnd:SetHeight(h)

  PlaceWatch()

  local title = wnd:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if not title:GetFont() or title:GetFont() == "" then
    title:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
  end
  title:SetPoint("TOP", wnd, "TOP", 0, -16)
  wnd.title = title

  local i = 1
  while i <= 14 do EnsureRow(i); i = i + 1 end

  local up = SmallButton(wnd, 22, "^", function() ScrollWatch(-3) end,
    function() return { L("wUp") } end)
  up:SetPoint("BOTTOMLEFT", wnd, "BOTTOMLEFT", 18, 16)
  wnd.up = up

  local down = SmallButton(wnd, 22, "v", function() ScrollWatch(3) end,
    function() return { L("wDown") } end)
  down:SetPoint("LEFT", up, "RIGHT", 3, 0)
  wnd.down = down

  local close = SmallButton(wnd, 62, L("wClose"), function() wnd:Hide() end, nil)
  close:SetPoint("BOTTOMRIGHT", wnd, "BOTTOMRIGHT", -18, 16)
  wnd.close = close

  -- clearing the whole list asks twice: one stray click should not undo an
  -- evening of marking recipes
  local clear
  local function Disarm()
    clear.armed = nil
    clear:SetScript("OnUpdate", nil)
    clear.text:SetText(L("wClear"))
    clear.text:SetTextColor(0.9, 0.9, 0.9)
    clear.fill:SetTexture(0.20, 0.20, 0.22)
  end

  clear = SmallButton(wnd, 72, L("wClear"), function()
    if clear.armed then
      Disarm()
      DB.watch = {}
      needDirty = true
      Print(L("wCleared"))
      RefreshList()
      if UpdateWatchWindow then UpdateWatchWindow() end
      return
    end
    clear.armed, clear.waited = true, 0
    clear.text:SetText(L("wClearSure"))
    clear.text:SetTextColor(1, 0.4, 0.4)
    clear.fill:SetTexture(0.35, 0.12, 0.12)
    clear:SetScript("OnUpdate", function()
      local step = arg1
      if type(step) ~= "number" then step = 0.05 end
      clear.waited = (clear.waited or 0) + step
      if clear.waited > 4 then Disarm() end
    end)
  end, function()
    return { L("wClearTip"), L("wClearHint") }
  end)
  clear:SetPoint("RIGHT", close, "LEFT", -6, 0)
  wnd.clear = clear
  wnd.disarmClear = Disarm

  local gear = SmallButton(wnd, 78, L("cfgBtn"), function()
    if ToggleConfig then ToggleConfig() end
  end, nil)
  gear:SetPoint("RIGHT", clear, "LEFT", -6, 0)
  wnd.gear = gear

  -- the corner grip
  local grip = CreateFrame("Button", nil, wnd)
  grip:SetWidth(16)
  grip:SetHeight(16)
  grip:SetPoint("BOTTOMRIGHT", wnd, "BOTTOMRIGHT", -6, 6)
  local gt = grip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not gt:GetFont() or gt:GetFont() == "" then
    gt:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  end
  gt:SetPoint("CENTER", grip, "CENTER", 0, 0)
  gt:SetText("//")
  gt:SetTextColor(0.7, 0.7, 0.7)
  grip:SetScript("OnMouseDown", function() StartSizingNow() end)
  grip:SetScript("OnMouseUp", function() StopSizing() end)
  grip:SetScript("OnHide", function() StopSizing() end)
  Tip(grip, function() return { L("wGrip") } end)
  wnd.grip = grip

  wnd:Hide()                          -- a new frame shows by default here
end

UpdateWatchWindow = function()
  if not wnd or not wnd.IsVisible or not wnd:IsVisible() then return end

  wnd.title:SetText(L("wTitle") .. " (" .. WatchCount() .. ")")
  wnd.close.text:SetText(L("wClose"))

  -- everything that could be shown, as flat lines, and only then the page
  local lines, n = {}, 0
  local function Add(text, r, g, b, recipe)
    n = n + 1
    lines[n] = { text = text, r = r, g = g, b = b, recipe = recipe }
  end

  if WatchCount() == 0 then
    Add(L("wNone"), 0.7, 0.7, 0.7)
  else
    local names, k = {}, 0
    for recipe in pairs(DB.watch) do k = k + 1; names[k] = recipe end
    pcall(table.sort, names)

    local at = 1
    while names[at] do
      local recipe = names[at]
      local entry = DB.watch[recipe]
      at = at + 1
      if RecipeReady(entry) then
        Add(recipe, 0.4, 1, 0.4, recipe)
      else
        Add(recipe, 1, 0.82, 0, recipe)
      end
      if type(entry.reagents) == "table" then
        local i = 1
        while entry.reagents[i] do
          local r = entry.reagents[i]
          local have, need = Held(r.name), r.need or 1
          local tail = ""
          local tag = SourceTag and SourceTag(r.name)
          if tag then tail = "  |cff9d9d9d" .. tag .. "|r" end
          if have >= need then
            Add("    " .. r.name .. "  " .. have .. "/" .. need .. tail, 0.4, 0.9, 0.4)
          else
            Add("    " .. r.name .. "  " .. have .. "/" .. need .. tail, 0.85, 0.85, 0.85)
          end
          i = i + 1
        end
      end

      -- what the recipe needs besides reagents, and what it yields
      if type(entry.tools) == "table" then
        local t = 1
        while entry.tools[t] do
          Add(Lf("wTool", entry.tools[t]), 0.6, 0.7, 0.85)
          t = t + 1
        end
      end
      if entry.made and entry.made > 1 then
        local made = tostring(entry.made)
        if entry.madeMax and entry.madeMax > entry.made then
          made = made .. "-" .. entry.madeMax
        end
        Add(Lf("wMade", made), 0.6, 0.6, 0.6)
      end
    end
  end

  wndLines = n
  wndRowsFit = RowsFit()
  if wndOffset > n - wndRowsFit then wndOffset = n - wndRowsFit end
  if wndOffset < 0 then wndOffset = 0 end

  local row = 1
  while row <= K.WND_MAXROWS do
    local fs = wndRows[row]
    if row <= wndRowsFit then
      fs = EnsureRow(row)
      local item = lines[wndOffset + row]
      if item then
        fs:SetText(item.text)
        fs:SetTextColor(item.r, item.g, item.b)
      else
        fs:SetText("")
      end
      fs:Show()

      local hit, drop = rowHit[row], rowDrop[row]
      if item and item.recipe then
        hit.recipe, drop.recipe = item.recipe, item.recipe
        hit:Show()
        drop:Show()
      else
        if hit then hit.recipe = nil; hit:Hide() end
        if drop then drop.recipe = nil; drop:Hide() end
      end
    elseif fs then
      fs:SetText("")
      fs:Hide()
      if rowHit[row] then rowHit[row]:Hide() end
      if rowDrop[row] then rowDrop[row]:Hide() end
    end
    row = row + 1
  end

  -- the arrows go dim when there is nowhere to go
  local canUp, canDown = wndOffset > 0, (wndOffset + wndRowsFit) < n
  if wnd.up then wnd.up.text:SetTextColor(canUp and 0.9 or 0.4, canUp and 0.9 or 0.4, canUp and 0.9 or 0.4) end
  if wnd.down then wnd.down.text:SetTextColor(canDown and 0.9 or 0.4, canDown and 0.9 or 0.4, canDown and 0.9 or 0.4) end
end

ToggleWatchWindow = function()
  BuildWatchWindow()
  if wnd:IsVisible() then
    if wnd.disarmClear then wnd.disarmClear() end
    wnd:Hide()
  else
    RefreshBags(true)
    wnd:Show()
    UpdateWatchWindow()
  end
end

----------------------------------------------------------------------
-- pins on the map
--
-- The pins are ours: our own frames on WorldMapButton and on the Minimap,
-- our own colour, our own tooltip. KoQuest is asked for facts only -- where
-- a creature spawns, how big a zone is in yards -- and never for drawing.
-- The first version handed the nodes to KoQuest instead, and on Emberveil
-- they were never shown: that fork renders from a spatial cache that only
-- KoQuest itself may mark stale, so a node from another addon sat in the
-- table, correct in every field, and invisible on both maps.
----------------------------------------------------------------------

-- One table rather than two dozen file locals: this file is close to the
-- 200 local limit that the client's Lua imposes on a chunk.
local Map = {
  UNITS      = 10,                     -- best sources per reagent
  COORDS     = 40,                     -- spawn points per source
  SPOTS      = 2000,                   -- and a ceiling over everything
  MIN_CHANCE = 1.0,                    -- ignore anything rarer than this
  PIN        = 16,                     -- a marker standing for several places
  PIN_ONE    = 10,                     -- and one standing alone
  MINI       = 13,                     -- the same two on the minimap
  MINI_ONE   = 9,
  GAP        = 3,                      -- centres this many marker-widths apart

  spots   = {},                        -- zone id -> list of places
  seen    = {},                        -- "who|what" already pinned
  fromDB  = 0,                         -- and where the places came from
  fromMe  = 0,
  fromTool = 0,
  stamp   = 0,                         -- bumped whenever those are rebuilt
  wkey    = nil,                       -- what the world map was last drawn for
  wpins   = {},                        -- frame pool, world map
  mpins   = {},                        -- frame pool, minimap
  placed  = 0,
  sign    = nil,                       -- signature of the missing set
  miniAt  = 0,

  -- How many yards across the minimap shows at each zoom step, outdoors and
  -- indoors. The same numbers pfQuest uses; the client exposes no API for it.
  ZOOM = {
    [0] = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
    [1] = { [0] = 466 + 2/3, [1] = 400, [2] = 333 + 1/3,
            [3] = 266 + 2/3, [4] = 200, [5] = 133 + 1/3 },
  },
}

-- How many of a reagent a watched recipe wants, at most. Taking the first
-- entry was a bug: the list is sorted by recipe name, so a reagent wanted 1
-- by one recipe and 12 by another counted as satisfied at 1, and everything
-- that gives it vanished off the map while it was still needed.
Map.Want = function(wants)
  local most, i = 0, 1
  while wants[i] do
    local need = wants[i].need or 1
    if need > most then most = need end
    i = i + 1
  end
  if most < 1 then most = 1 end
  return most
end

-- By default the map answers "where do I get what I still lack", so a pile
-- already collected takes its sources off the map. Someone who keeps a stock
-- and wants to know where to farm more can ask for everything instead.
Map.Missing = function(reagent, wants)
  if DB.mapall then return true end
  return Held(reagent) < Map.Want(wants)
end

-- pins are only rebuilt when the set of still missing reagents changes,
-- not every time a bag moves
MissingChanged = function()
  local parts = {}
  local n = 0
  for reagent, wants in pairs(Need()) do
    if Map.Missing(reagent, wants) then
      n = n + 1
      parts[n] = reagent
    end
  end
  pcall(table.sort, parts)
  local sign = table.concat(parts, "|")
  if sign == Map.sign then return false end
  Map.sign = sign
  return true
end

-- The zone id the coordinates are keyed by is pfQuest's own, and the client
-- knows nothing about it. The bridge is the zone name: the client lists the
-- zones of a continent in order, and the database keeps the same names.
Map.ZoneByName = function(name)
  if not name or name == "" or not KoReady() then return nil end
  if type(KoDB.zones) ~= "table" or type(KoDB.zones.loc) ~= "table" then return nil end
  if Map.byName and Map.byName[name] ~= nil then return Map.byName[name] or nil end
  Map.byName = Map.byName or {}
  local found = false
  for id, zoneName in pairs(KoDB.zones.loc) do
    if zoneName == name then found = id end
  end
  Map.byName[name] = found
  return found or nil
end

-- The zone the world map is currently showing. KoQuest already solved this
-- for Emberveil -- the client's zone index does not always follow the vanilla
-- GetMapZones order here -- so ask it first and work it out by hand only if
-- it is not around. Last resort: the zone the player is actually standing in,
-- which is right whenever the map was opened without being paged elsewhere.
Map.ShownZone = function()
  if type(KoQuestEV) == "table" and type(KoQuestEV.GetSelectedMapID) == "function" then
    local ok, id = pcall(KoQuestEV.GetSelectedMapID, KoQuestEV)
    if ok and type(id) == "number" and id > 0 then return id end
  end

  if type(GetCurrentMapContinent) == "function" and type(GetCurrentMapZone) == "function"
     and type(GetMapZones) == "function" then
    local c, z = GetCurrentMapContinent(), GetCurrentMapZone()
    if c and z and c > 0 and z > 0 then
      local list = { GetMapZones(c) }
      local id = Map.ZoneByName(list[z])
      if id then return id end

      -- a continent or world view carries no zone coordinates at all
      if type(GetRealZoneText) == "function" then
        return Map.ZoneByName(GetRealZoneText())
      end
    end
    return nil
  end

  if type(GetRealZoneText) == "function" then return Map.ZoneByName(GetRealZoneText()) end
  return nil
end

-- and the zone the player is standing in, with the player's place in it
Map.Here = function()
  -- KoQuest keeps a corrected position for this client; prefer it
  if type(KoQuestEV) == "table" and type(KoQuestEV.player) == "table" then
    local p = KoQuestEV.player
    if type(p.mapID) == "number" and type(p.x) == "number" and type(p.y) == "number"
       and (p.x ~= 0 or p.y ~= 0) then
      return p.mapID, p.x * 100, p.y * 100
    end
  end
  if type(GetPlayerMapPosition) ~= "function" then return nil end
  local x, y = GetPlayerMapPosition("player")
  if not x or not y or (x == 0 and y == 0) then return nil end
  local zone = nil
  if type(GetRealZoneText) == "function" then zone = Map.ZoneByName(GetRealZoneText()) end
  if not zone then zone = Map.ShownZone() end
  if not zone then return nil end
  return zone, x * 100, y * 100
end

----------------------------------------------------------------------
-- the pins themselves
----------------------------------------------------------------------

-- The world map has a tooltip of its own, and its own POIs use that one
-- rather than GameTooltip. Borrow whichever the pin's parent belongs to,
-- so a pin on the map behaves like every other thing on the map.
Map.TipFrame = function(pin)
  if pin.world then
    local wt = getglobal("WorldMapTooltip")
    if wt and wt.SetOwner and wt.AddLine then return wt end
  end
  return GameTooltip
end

Map.Tip = function(pin)
  local group = pin and pin.group
  if not group then return end
  local tip = Map.TipFrame(pin)
  if not tip then return end

  tip:SetOwner(pin, "ANCHOR_RIGHT")

  -- One marker can stand for a whole cluster of spawns, so the tooltip names
  -- who is there rather than repeating one spawn point. Identical sources are
  -- folded together and counted.
  local order, seen, kinds = {}, {}, 0
  local m = 1
  while group.members[m] do
    local spot = group.members[m].spot
    local key = (spot.who or "?") .. "|" .. spot.title
    if not seen[key] then
      kinds = kinds + 1
      seen[key] = { spot = spot, n = 0 }
      order[kinds] = key
    end
    seen[key].n = seen[key].n + 1
    m = m + 1
  end

  if group.n > 1 then
    tip:AddLine(Lf("mapMany", group.n), 0.7, 0.7, 0.7)
  end

  local cap, k = MaxRec(), 1
  while order[k] and k <= cap do
    local entry = seen[order[k]]
    local spot  = entry.spot

    local who = spot.who or "?"
    if entry.n > 1 then who = who .. "  x" .. entry.n end
    tip:AddLine(who, 1, 1, 1)

    if spot.station then
      tip:AddLine("   " .. L("mapStation"), 0.7, 0.8, 0.9)
    else
      local line = "   " .. spot.title
      if spot.chance and spot.chance > 0 then
        line = line .. "  " .. string.format("%.1f", spot.chance) .. "%"
      end
      if spot.level and spot.level ~= "" then
        line = line .. "  |cff9d9d9d" .. Lf("mapLevel", spot.level) .. "|r"
      end
      tip:AddLine(line, 1, 0.82, 0)
      if spot.mine then tip:AddLine("   " .. L("mapMine"), 0.6, 0.7, 0.6) end
    end
    k = k + 1
  end
  if order[k] then
    local rest = 0
    while order[k + rest] do rest = rest + 1 end
    tip:AddLine(Lf("wMore", rest), 0.6, 0.6, 0.6)
  end

  -- and what all of this was wanted for in the first place
  local first = group.members[1] and group.members[1].spot

  if first and first.station then
    local recipes = Map.NeedTool(first.title)
    if recipes then
      local total, cap = 0, MaxRec()
      while recipes[total + 1] do total = total + 1 end
      local show = total
      if show > cap then show = cap end
      local i = 1
      while i <= show do
        tip:AddLine("   " .. recipes[i], 0.55, 0.85, 0.55)
        i = i + 1
      end
      if total > show then tip:AddLine(Lf("wMore", total - show), 0.6, 0.6, 0.6) end
    end
    tip:Show()
    return
  end

  local wants = first and Need()[first.title]
  if wants then
    local have, total = Held(first.title), 0
    while wants[total + 1] do total = total + 1 end
    local show = total
    if show > MaxRec() then show = MaxRec() end
    local i = 1
    while i <= show do
      tip:AddLine("   " .. wants[i].recipe .. "  " .. have .. "/" .. (wants[i].need or 1),
                  0.55, 0.85, 0.55)
      i = i + 1
    end
    if total > show then
      tip:AddLine(Lf("wMore", total - show), 0.6, 0.6, 0.6)
    end
  end

  tip:Show()
end

Map.TipHide = function(pin)
  local tip = Map.TipFrame(pin)
  if tip and tip.Hide then tip:Hide() end
end

Map.DOT   = "Interface\\AddOns\\CraftFocus\\img\\dot"
Map.ANVIL = "Interface\\AddOns\\CraftFocus\\img\\anvil"

Map.NewPin = function(parent, size, world)
  local pin = CreateFrame("Button", nil, parent)
  pin:SetWidth(size)
  pin:SetHeight(size)
  pin.world = world
  pin:EnableMouse(true)

  -- Do NOT force a strata here. The world map runs in FULLSCREEN_DIALOG, and
  -- a pin pinned to "HIGH" ends up painted behind the map itself: present,
  -- correctly placed and invisible. Inheriting the parent's strata and
  -- sitting a few levels above it works on both the map and the minimap.
  if parent.GetFrameLevel and pin.SetFrameLevel then
    local base = parent:GetFrameLevel()
    if type(base) == "number" then pin:SetFrameLevel(base + 5) end
  end

  -- A round marker of our own, shipped with the addon as a TGA. KoQuest
  -- proves this client loads addon TGA files; a coloured square drawn out of
  -- textures was legible but looked nothing like a map marker.
  local dot = pin:CreateTexture(nil, "ARTWORK")
  dot:SetAllPoints(pin)
  dot:SetTexture(Map.DOT)
  pin.dot = dot
  pin.art = Map.DOT

  pin:SetScript("OnEnter", function() Map.Tip(this or pin) end)
  pin:SetScript("OnLeave", function() Map.TipHide(this or pin) end)
  pin:Hide()
  return pin
end

-- Greedy clustering by distance on screen. The first place of a group stays
-- its anchor and never moves, so two drawn markers are never closer than the
-- gap -- the rule being that two more markers must fit between any two of
-- them. A lone place gets the smaller marker, a group the bigger one.
Map.Cluster = function(points, gap)
  local cells, out, n = {}, {}, 0
  local limit = gap * gap
  local i = 1
  while points[i] do
    local p = points[i]
    local cx, cy = math.floor(p.px / gap), math.floor(p.py / gap)

    local best, ox = nil, -1
    while ox <= 1 do
      local oy = -1
      while oy <= 1 do
        local bucket = cells[(cx + ox + 4096) * 16384 + (cy + oy + 4096)]
        if bucket then
          local k = 1
          while bucket[k] do
            local c = bucket[k]
            local dx, dy = c.px - p.px, c.py - p.py
            if not best and dx * dx + dy * dy < limit then best = c end
            k = k + 1
          end
        end
        oy = oy + 1
      end
      ox = ox + 1
    end

    if best then
      best.n = best.n + 1
      -- the tooltip never lists more than a handful, so stop hoarding
      local m, j = best.members, 1
      while m[j] do j = j + 1 end
      if j <= 40 then m[j] = p end
    else
      local c = { px = p.px, py = p.py, n = 1, members = { p } }
      n = n + 1
      out[n] = c
      local key = (cx + 4096) * 16384 + (cy + 4096)
      if not cells[key] then cells[key] = {} end
      local b, j = cells[key], 1
      while b[j] do j = j + 1 end
      b[j] = c
    end
    i = i + 1
  end
  return out
end

-- Dress a pin for the group it stands for: the full size when it covers
-- several places, a smaller one when it is alone out there.
Map.Fit = function(pin, group, big, small)
  local size = (group.n > 1) and big or small
  if pin.size ~= size then
    pin:SetWidth(size)
    pin:SetHeight(size)
    pin.size = size
  end

  -- a station is a place you stand at, not a thing you kill, so it gets a
  -- marker of its own shape and colour
  local first = group.members[1] and group.members[1].spot
  local art = (first and first.station) and Map.ANVIL or Map.DOT
  if pin.art ~= art then
    pin.dot:SetTexture(art)
    pin.art = art
  end

  -- What this player saw themselves is the whole story for skinning, so it
  -- gets a colour of its own instead of being lost among the database pins.
  local tint = (first and first.mine) and "mine" or "plain"
  if pin.tint ~= tint and pin.dot.SetVertexColor then
    if tint == "mine" then
      pin.dot:SetVertexColor(0.45, 1.00, 0.55)
    else
      pin.dot:SetVertexColor(1, 1, 1)
    end
    pin.tint = tint
  end

  pin.group = group
  pin.spot  = first
end

-- Each kind of place is grouped on its own, so a lone anvil or a creature the
-- player found themselves is never swallowed by a crowd of database pins.
-- These append the result of one grouping to another.
Map.Join = function(into, extra)
  local j, k = 1, 1
  while into[j] do j = j + 1 end
  while extra[k] do
    into[j] = extra[k]
    j, k = j + 1, k + 1
  end
end

Map.HidePins = function(pool)
  local i = 1
  while pool[i] do pool[i]:Hide(); i = i + 1 end
end

----------------------------------------------------------------------
-- the world map
----------------------------------------------------------------------

-- Whether the world map is open. WorldMapFrame:IsShown is the answer KoQuest
-- trusts on this client; IsVisible on the canvas itself has been known to
-- disagree, and a wrong "no" here simply means no pins at all.
Map.MapOpen = function()
  local frame = getglobal("WorldMapFrame")
  if frame and frame.IsShown then
    local ok, shown = pcall(frame.IsShown, frame)
    if ok then return (shown and true or false) end
  end
  local canvas = getglobal("WorldMapButton")
  if canvas and canvas.IsVisible then return canvas:IsVisible() and true or false end
  return false
end

Map.DrawWorld = function()
  local canvas = getglobal("WorldMapButton")
  if not canvas or not Map.MapOpen() then
    Map.HidePins(Map.wpins)
    Map.wkey = nil
    return
  end

  if not DB.map then Map.HidePins(Map.wpins) Map.wkey = nil return end

  local zone = Map.ShownZone()
  local list = zone and Map.spots[zone]
  if not list then Map.HidePins(Map.wpins) Map.wkey = nil return end

  local w, h = canvas:GetWidth(), canvas:GetHeight()
  if not w or not h or w < 16 or h < 16 then Map.HidePins(Map.wpins) Map.wkey = nil return end

  -- Regrouping several thousand places is not free, and the map is redrawn
  -- five times a second while it is open. Nothing about the grouping changes
  -- unless the zone, the canvas size or the set of places does.
  local key = zone .. ":" .. math.floor(w) .. ":" .. math.floor(h) .. ":" .. Map.stamp
  if Map.wkey == key then return end
  Map.wkey = key

  -- Where each place falls on this canvas, then group what would overlap.
  -- Sources and stations are grouped apart from each other: one anvil among
  -- twenty spawn points must not be swallowed by them.
  local hunt, mine, stations, a, b, c = {}, {}, {}, 0, 0, 0
  local i = 1
  while list[i] do
    local point = { px = list[i].x / 100 * w, py = list[i].y / 100 * h, spot = list[i] }
    if list[i].station then
      c = c + 1
      stations[c] = point
    elseif list[i].mine then
      b = b + 1
      mine[b] = point
    else
      a = a + 1
      hunt[a] = point
    end
    i = i + 1
  end

  local groups = Map.Cluster(hunt, Map.PIN * Map.GAP)
  Map.Join(groups, Map.Cluster(mine, Map.PIN * Map.GAP))
  Map.Join(groups, Map.Cluster(stations, Map.PIN * Map.GAP))

  i = 1
  while groups[i] do
    local g = groups[i]
    local pin = Map.wpins[i]
    if not pin then
      pin = Map.NewPin(canvas, Map.PIN, true)
      Map.wpins[i] = pin
    end
    Map.Fit(pin, g, Map.PIN, Map.PIN_ONE)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", canvas, "TOPLEFT", g.px, -g.py)
    pin:Show()
    i = i + 1
  end

  while Map.wpins[i] do Map.wpins[i]:Hide(); i = i + 1 end
end

----------------------------------------------------------------------
-- the minimap
--
-- The client tells nobody how many yards the minimap covers, so the zoom
-- table above stands in for it, and the size of the zone in yards comes out
-- of the KoQuest database. Without either of those the pins simply stay
-- hidden rather than landing in the wrong place.
----------------------------------------------------------------------

Map.ZoneSize = function(zone)
  if not KoReady() or type(KoDB.minimap) ~= "table" then return nil end
  local size = KoDB.minimap[zone]
  if type(size) ~= "table" then return nil end
  if type(size[1]) ~= "number" or type(size[2]) ~= "number" then return nil end
  if size[1] <= 0 or size[2] <= 0 then return nil end
  return size[1], size[2]
end

Map.DrawMini = function()
  if not DB.map or not DB.mmap or not Minimap then Map.HidePins(Map.mpins) return end

  local zone, px, py = Map.Here()
  local list = zone and Map.spots[zone]
  if not list then Map.HidePins(Map.mpins) return end

  local zoneW, zoneH = Map.ZoneSize(zone)
  if not zoneW then Map.HidePins(Map.mpins) return end

  local indoors = 0
  if type(KoQuestEV) == "table" and type(KoQuestEV.GetMinimapEnvironment) == "function" then
    local ok, env = pcall(KoQuestEV.GetMinimapEnvironment, KoQuestEV)
    if ok and type(env) == "number" then indoors = env end
  end

  local step = 0
  if type(Minimap.GetZoom) == "function" then
    local ok, value = pcall(Minimap.GetZoom, Minimap)
    if ok and type(value) == "number" then step = value end
  end

  local across = Map.ZOOM[indoors] and Map.ZOOM[indoors][step]
  if not across or across <= 0 then Map.HidePins(Map.mpins) return end

  local width  = Minimap:GetWidth() or 0
  local height = Minimap:GetHeight() or 0
  if width < 16 or height < 16 then Map.HidePins(Map.mpins) return end

  -- pixels per one percent of the zone
  local perX = width  * zoneW / (across * 100)
  local perY = height * zoneH / (across * 100)

  local radius = width / 2 - 4
  local limit  = radius * radius

  local hunt, mine, stations, a, b, c = {}, {}, {}, 0, 0, 0
  local i = 1
  while list[i] do
    local dx = (list[i].x - px) * perX
    local dy = (list[i].y - py) * perY
    if dx * dx + dy * dy < limit then
      local point = { px = dx, py = dy, spot = list[i] }
      if list[i].station then
        c = c + 1
        stations[c] = point
      elseif list[i].mine then
        b = b + 1
        mine[b] = point
      else
        a = a + 1
        hunt[a] = point
      end
    end
    i = i + 1
  end

  local groups = Map.Cluster(hunt, Map.MINI * Map.GAP)
  Map.Join(groups, Map.Cluster(mine, Map.MINI * Map.GAP))
  Map.Join(groups, Map.Cluster(stations, Map.MINI * Map.GAP))

  i = 1
  while groups[i] do
    local g = groups[i]
    local pin = Map.mpins[i]
    if not pin then
      pin = Map.NewPin(Minimap, Map.MINI, false)
      Map.mpins[i] = pin
    end
    Map.Fit(pin, g, Map.MINI, Map.MINI_ONE)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", Minimap, "CENTER", g.px, -g.py)
    pin:Show()
    i = i + 1
  end

  while Map.mpins[i] do Map.mpins[i]:Hide(); i = i + 1 end
end

Map.Refresh = function()
  pcall(Map.DrawWorld)
  pcall(Map.DrawMini)
end

Map.Clear = function()
  Map.spots, Map.placed, Map.seen = {}, 0, {}
  Map.fromDB, Map.fromMe, Map.fromTool = 0, 0, 0
  Map.stamp, Map.wkey = Map.stamp + 1, nil
  Map.HidePins(Map.wpins)
  Map.HidePins(Map.mpins)
end

Map.Add = function(coords, title, who, level, chance, station, mine)
  local c = 1
  while coords[c] and c <= Map.COORDS and Map.placed < Map.SPOTS do
    local x, y, zone = coords[c][1], coords[c][2], coords[c][3]
    if x and y and zone and zone > 0 then
      Map.seen[(who or "") .. "|" .. (title or "")] = true
      if not Map.spots[zone] then Map.spots[zone] = {} end
      local list, n = Map.spots[zone], 1
      while list[n] do n = n + 1 end
      list[n] = { x = x, y = y, title = title, who = who, level = level,
                  chance = chance, station = station, mine = mine }
      Map.placed = Map.placed + 1
      if station then Map.fromTool = Map.fromTool + 1
      elseif mine then Map.fromMe = Map.fromMe + 1
      else Map.fromDB = Map.fromDB + 1 end
    end
    c = c + 1
  end
end

-- The database knows nothing about skinning, and little about a few other
-- trades, so for a leatherworker most of what is worth pinning is what this
-- player saw with their own eyes. The creature is known only by name -- but
-- the database does know where a creature of that name stands.
Map.Mine = function()
  if not DB.drops or type(CraftFocusDrops) ~= "table" then return end
  if not KoReady() then return end

  local index = Need()
  for mob, pack in pairs(CraftFocusDrops) do
    if type(pack) == "table" then
      -- what this creature gave that is still missing
      -- pairs() hands the items over in whatever order it likes; taking the
      -- first alphabetically keeps the marker's title steady between redraws
      local gives = nil
      for item in pairs(pack) do
        if item ~= "t" and index[item] and Map.Missing(item, index[item]) then
          if not gives or item < gives then gives = item end
        end
      end

      -- the database may already have pinned this creature for this reagent;
      -- pinning it again would only inflate the count on the marker
      if gives and not Map.seen[mob .. "|" .. gives] then
        local ids = UnitIds(mob)
        if ids then
          for id in pairs(ids) do
            local entry = KoDB.units.data[id]
            if type(entry) == "table" and type(entry.coords) == "table" then
              Map.Add(entry.coords, gives, mob, entry.lvl, nil, nil, true)
            end
          end
        end
      end
    end
  end
end

-- Which watched recipes want a given tool. Also the answer the tooltip on a
-- station marker gives.
Map.NeedTool = function(tool)
  local out, n = {}, 0
  for recipe, entry in pairs(DB.watch) do
    if type(entry) == "table" and type(entry.tools) == "table" then
      local i = 1
      while entry.tools[i] do
        if entry.tools[i] == tool then
          n = n + 1
          out[n] = recipe
        end
        i = i + 1
      end
    end
  end
  if n == 0 then return nil end
  pcall(table.sort, out)
  return out
end

-- An anvil is a world object like any other, so the database knows where they
-- stand -- it just files them under their name rather than under a recipe.
Map.Stations = function()
  if not DB.stations then return end
  if type(KoDB.objects) ~= "table" or type(KoDB.objects.data) ~= "table" then return end

  local wanted = {}
  for _, entry in pairs(DB.watch) do
    if type(entry) == "table" and type(entry.tools) == "table" then
      local i = 1
      while entry.tools[i] do
        wanted[entry.tools[i]] = true
        i = i + 1
      end
    end
  end

  for tool in pairs(wanted) do
    local ids = IdsByName(tool, "objects")
    if ids then
      for id in pairs(ids) do
        local entry = KoDB.objects.data[id]
        if type(entry) == "table" and type(entry.coords) == "table" then
          Map.Add(entry.coords, tool, tool, nil, nil, true)
        end
      end
    end
  end
end

Map.Build = function()
  Map.Clear()

  -- Record what this batch was drawn for, whatever the outcome: the signature
  -- is what later tells a bag change that nothing on the map has to move, and
  -- it must never be left describing an older set.
  MissingChanged()

  if not DB.map or not KoReady() then return end

  for reagent, wants in pairs(Need()) do
    -- only what is still missing: a pile already collected needs no map
    if Map.Missing(reagent, wants) then
      local ids = ItemIds(reagent)
      if ids then
        local units, objects = {}, {}
        for itemId in pairs(ids) do
          UnitsForItem(itemId, units)
          local entry = KoDB.items.data[itemId]
          if type(entry) == "table" and type(entry.O) == "table" then
            for obj, chance in pairs(entry.O) do objects[obj] = chance end
          end
        end

        -- the likeliest sources first, and only a handful of them
        local list, n = {}, 0
        for unitId, chance in pairs(units) do
          n = n + 1
          list[n] = { id = unitId, chance = chance }
        end
        pcall(table.sort, list, function(a, b) return (a.chance or 0) > (b.chance or 0) end)

        local u = 1
        while list[u] and u <= Map.UNITS do
          local chance = list[u].chance or 0
          if chance >= Map.MIN_CHANCE then
            local entry = KoDB.units.data[list[u].id]
            local who = UnitName_(list[u].id)
            if who and type(entry) == "table" and type(entry.coords) == "table" then
              Map.Add(entry.coords, reagent, who, entry.lvl, chance)
            end
          end
          u = u + 1
        end

        -- and the things standing in the world: nodes, chests
        if type(KoDB.objects) == "table" and type(KoDB.objects.data) == "table" then
          for obj, chance in pairs(objects) do
            local entry = KoDB.objects.data[obj]
            local who = ObjectName and ObjectName(obj)
            if who and type(entry) == "table" and type(entry.coords) == "table" then
              Map.Add(entry.coords, reagent, who, nil, chance)
            end
          end
        end
      end
    end
  end

  Map.Mine()
  Map.Stations()
  Map.Refresh()

  -- An empty map is an answer, not a fault -- but it looks exactly like a
  -- broken addon, so say it out loud. Once, and only when it changes.
  local quiet = (Map.fromDB + Map.fromMe == 0) and WatchCount() > 0 and not DB.mapall
  if quiet and not Map.saidEmpty then
    Map.saidEmpty = true
    Print(L("mapEmpty"))
  elseif not quiet then
    Map.saidEmpty = nil
  end
end

-- Why the map is empty, in two lines. Answers the questions that can go wrong
-- independently: is the database there, is there anything left to look for,
-- and did anything land in the zone being looked at.
local function MapWhy()
  local ko = KoReady() and "+" or "-"

  local missing, sourced = 0, 0
  for reagent, wants in pairs(Need()) do
    if Map.Missing(reagent, wants) then
      missing = missing + 1
      local ids, found = ItemIds(reagent), false
      if ids then
        for itemId in pairs(ids) do
          for _ in pairs(UnitsForItem(itemId, {})) do found = true end
        end
      end
      if found then sourced = sourced + 1 end
    end
  end

  local canvas = getglobal("WorldMapButton")
  Print(Lf("mapCanvas",
    canvas and "+" or "-",
    Map.MapOpen() and "+" or "-",
    (canvas and canvas.GetWidth and math.floor(canvas:GetWidth() or 0)) or 0))

  local shown = Map.ShownZone()
  local zoneName = "?"
  if shown and KoReady() and type(KoDB.zones) == "table" then
    zoneName = (KoDB.zones.loc and KoDB.zones.loc[shown]) or tostring(shown)
  end
  Print(Lf("mapWhy", ko, zoneName, missing, sourced))

  local here = 0
  if shown and Map.spots[shown] then
    while Map.spots[shown][here + 1] do here = here + 1 end
  end
  Print(Lf("mapNodes", here, Map.placed))

  -- where the places came from, and whether the memory of past kills is there
  local mobs = 0
  if type(CraftFocusDrops) == "table" then
    for _ in pairs(CraftFocusDrops) do mobs = mobs + 1 end
  end
  Print(Lf("mapFrom", Map.fromDB, Map.fromMe, Map.fromTool, mobs))

  -- The zones holding the most places. When the world map is shut, or the
  -- player is in an instance, "this zone" says nothing, and this line is the
  -- one that shows whether the pins exist at all and where they landed.
  local top, count = {}, 0
  for zone, list in pairs(Map.spots) do
    local n = 0
    while list[n + 1] do n = n + 1 end
    count = count + 1
    top[count] = { zone = zone, n = n }
  end
  pcall(table.sort, top, function(a, b) return a.n > b.n end)

  local text, i = "", 1
  while top[i] and i <= 3 do
    local zoneName = (KoDB.zones and KoDB.zones.loc and KoDB.zones.loc[top[i].zone])
                     or tostring(top[i].zone)
    if i > 1 then text = text .. ", " end
    text = text .. zoneName .. " " .. top[i].n
    i = i + 1
  end
  if text ~= "" then Print(Lf("mapTop", text)) end
end

----------------------------------------------------------------------
-- the settings window
----------------------------------------------------------------------

local cfg, cfgRows = nil, {}

local CFG_ITEMS = {
  { key = "signal",  label = "cfgSignal" },
  { key = "tips",    label = "cfgTips" },
  { key = "mobs",    label = "cfgMobs",   hint = "cfgMobsHint" },
  { key = "drops",   label = "cfgDrops" },
  { key = "marks",   label = "cfgMarks" },
  { key = "panel",   label = "cfgPanel" },
  { key = "minimap", label = "cfgMinimap" },
  { key = "map",     label = "cfgMap",  hint = "cfgMapHint" },
  { key = "mmap",    label = "cfgMmap", hint = "cfgMmapHint" },
  { key = "stations", label = "cfgStations", hint = "cfgStationsHint" },
  { key = "mapall",  label = "cfgMapAll", hint = "cfgMapAllHint" },
  { key = "shop",    label = "cfgShop",  hint = "cfgShopHint" },
}

local UpdateConfig
local Relabel                          -- redraws every label after a language change

local function ToggleSetting(key)
  DB[key] = not DB[key]
  if key == "minimap" and ApplyMinimapButton then ApplyMinimapButton() end
  if key == "panel" and UpdatePanel then UpdatePanel() end
  if key == "mobs" then dropDirty = true end
  if key == "map" or key == "mmap" or key == "stations" or key == "mapall" then
    mapDirty = true
  end
  if UpdateConfig then UpdateConfig() end
end

local function BuildConfig()
  if cfg then return end

  cfg = CreateFrame("Frame", "CraftFocusConfig", UIParent)
  cfg:SetWidth(300)
  local n = 1
  while CFG_ITEMS[n] do n = n + 1 end
  cfg:SetHeight(90 + 20 * (n + 1))     -- the toggles, plus the number and the language
  cfg:SetFrameStrata("DIALOG")
  cfg:EnableMouse(true)
  cfg:SetMovable(true)
  cfg:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  local function Down() local self = this or cfg if self.StartMoving then self:StartMoving() end end
  local function Up()
    local self = this or cfg
    if self.StopMovingOrSizing then self:StopMovingOrSizing() end
    local left, top = self:GetLeft(), self:GetTop()
    if type(left) == "number" and type(top) == "number" then
      DB.cpos = { left = left, top = top }
    end
  end
  cfg:SetScript("OnMouseDown", Down)
  cfg:SetScript("OnMouseUp", Up)

  if type(DB.cpos) == "table" and type(DB.cpos.left) == "number" then
    cfg:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", DB.cpos.left, DB.cpos.top)
  else
    cfg:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end

  local title = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if not title:GetFont() or title:GetFont() == "" then
    title:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
  end
  title:SetPoint("TOP", cfg, "TOP", 0, -16)
  title:SetText(L("cfgTitle"))
  cfg.title = title

  local i = 1
  while CFG_ITEMS[i] do
    local item = CFG_ITEMS[i]

    local row = CreateFrame("Button", nil, cfg)
    row:SetPoint("TOPLEFT", cfg, "TOPLEFT", 18, -40 - (i - 1) * 20)
    row:SetPoint("RIGHT", cfg, "RIGHT", -18, 0)
    row:SetHeight(18)

    local box = row:CreateTexture(nil, "BACKGROUND")
    box:SetWidth(12)
    box:SetHeight(12)
    box:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.box = box

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if not text:GetFont() or text:GetFont() == "" then
      text:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    end
    text:SetPoint("LEFT", row, "LEFT", 20, 0)
    text:SetJustifyH("LEFT")
    row.text = text

    row:SetScript("OnClick", function() ToggleSetting(item.key) end)
    if item.hint then
      Tip(row, function() return { L(item.label), L(item.hint) } end)
    end

    cfgRows[i] = row
    i = i + 1
  end

  -- One number rather than a switch: how many recipes a list names before it
  -- says "and N more". The same limit serves the tooltip and the chat.
  local num = CreateFrame("Frame", nil, cfg)
  num:SetPoint("TOPLEFT", cfg, "TOPLEFT", 18, -40 - (i - 1) * 20)
  num:SetPoint("RIGHT", cfg, "RIGHT", -18, 0)
  num:SetHeight(18)

  local numText = num:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not numText:GetFont() or numText:GetFont() == "" then
    numText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
  end
  numText:SetPoint("LEFT", num, "LEFT", 20, 0)
  numText:SetJustifyH("LEFT")
  numText:SetText(L("cfgMax"))
  cfg.numText = numText

  local function Step(by)
    DB.maxrec = MaxRec() + by
    if DB.maxrec < 1 then DB.maxrec = 1 end
    if DB.maxrec > 12 then DB.maxrec = 12 end
    if UpdateConfig then UpdateConfig() end
  end

  local plus = SmallButton(num, 18, "+", function() Step(1) end,
    function() return { L("cfgMax"), L("cfgMaxHint") } end)
  plus:SetPoint("RIGHT", num, "RIGHT", 0, 0)

  local value = num:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not value:GetFont() or value:GetFont() == "" then
    value:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
  end
  value:SetPoint("RIGHT", plus, "LEFT", -6, 0)
  cfg.numValue = value

  local minus = SmallButton(num, 18, "-", function() Step(-1) end,
    function() return { L("cfgMax"), L("cfgMaxHint") } end)
  minus:SetPoint("RIGHT", value, "LEFT", -6, 0)

  -- Three states rather than two, so this one is a button that steps through
  -- them instead of a tick: follow the client, Russian, English.
  local lang = CreateFrame("Frame", nil, cfg)
  lang:SetPoint("TOPLEFT", cfg, "TOPLEFT", 18, -40 - i * 20)
  lang:SetPoint("RIGHT", cfg, "RIGHT", -18, 0)
  lang:SetHeight(18)

  local langText = lang:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not langText:GetFont() or langText:GetFont() == "" then
    langText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
  end
  langText:SetPoint("LEFT", lang, "LEFT", 20, 0)
  langText:SetJustifyH("LEFT")
  cfg.langText = langText

  local langBtn = SmallButton(lang, 60, "", function()
    if DB.lang == "auto" then DB.lang = "ru"
    elseif DB.lang == "ru" then DB.lang = "en"
    else DB.lang = "auto" end
    if Relabel then Relabel() end
  end, function() return { L("cfgLang"), L("cfgLangHint") } end)
  langBtn:SetPoint("RIGHT", lang, "RIGHT", 0, 0)
  cfg.langBtn = langBtn

  local close = SmallButton(cfg, 66, L("wClose"), function() cfg:Hide() end, nil)
  close:SetPoint("BOTTOM", cfg, "BOTTOM", 0, 16)
  cfg.close = close

  cfg:Hide()                            -- a new frame shows by default here
end

UpdateConfig = function()
  if not cfg or not cfg:IsVisible() then return end
  cfg.title:SetText(L("cfgTitle"))
  cfg.close.text:SetText(L("wClose"))
  if cfg.numText then cfg.numText:SetText(L("cfgMax")) end
  if cfg.numValue then
    cfg.numValue:SetText(MaxRec())
    cfg.numValue:SetTextColor(1, 0.82, 0)
  end
  if cfg.langText then cfg.langText:SetText(L("cfgLang")) end
  if cfg.langBtn then
    cfg.langBtn.text:SetText(L("lang" .. (DB.lang or "auto")))
    cfg.langBtn.text:SetTextColor(1, 0.82, 0)
  end

  local i = 1
  while CFG_ITEMS[i] do
    local item, row = CFG_ITEMS[i], cfgRows[i]
    if row then
      local on = (DB[item.key] == true)
      row.text:SetText(L(item.label))
      if on then
        row.box:SetTexture(0.20, 0.75, 0.25)
        row.text:SetTextColor(1, 1, 1)
      else
        row.box:SetTexture(0.22, 0.22, 0.24)
        row.text:SetTextColor(0.6, 0.6, 0.6)
      end
    end
    i = i + 1
  end
end

ToggleConfig = function()
  BuildConfig()
  if cfg:IsVisible() then
    cfg:Hide()
  else
    cfg:Show()
    UpdateConfig()
  end
end

----------------------------------------------------------------------
-- the button on the minimap
----------------------------------------------------------------------

local mmButton = nil

local function Atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if x > 0 then return math.atan(y / x) end
  if x < 0 then
    if y >= 0 then return math.atan(y / x) + math.pi end
    return math.atan(y / x) - math.pi
  end
  if y > 0 then return math.pi / 2 end
  if y < 0 then return -math.pi / 2 end
  return 0
end

local function PlaceMinimapButton()
  if not mmButton or not Minimap then return end
  local angle = DB.mmangle
  if type(angle) ~= "number" then angle = 205 end
  local rad = angle * math.pi / 180
  mmButton:ClearAllPoints()
  mmButton:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(rad), 80 * math.sin(rad))
end

local function StopMMDrag(self)
  self = self or this
  if self and self.SetScript then self:SetScript("OnUpdate", nil) end
end

local function DragMMButton(self)
  self = self or this
  if not (IsShiftKeyDown and IsShiftKeyDown()) then StopMMDrag(self) return end
  if not GetCursorPosition or not Minimap or not Minimap.GetCenter then return end
  local mx, my = Minimap:GetCenter()
  if not mx then return end
  local scale = 1
  if Minimap.GetEffectiveScale then scale = Minimap:GetEffectiveScale() or 1 end
  if scale == 0 then scale = 1 end
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  DB.mmangle = math.deg(Atan2(cy - my, cx - mx))
  PlaceMinimapButton()
end

local ApplyMinimapButton

local function BuildMinimapButton()
  if mmButton or not Minimap then return end

  mmButton = CreateFrame("Button", "CraftFocusMinimapButton", Minimap)
  mmButton:SetWidth(31)
  mmButton:SetHeight(31)
  mmButton:SetFrameStrata("MEDIUM")
  mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mmButton:RegisterForDrag("LeftButton")

  local icon = mmButton:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\Trade_LeatherWorking")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetPoint("CENTER", mmButton, "CENTER", 0, 1)

  local border = mmButton:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(53)
  border:SetHeight(53)
  border:SetPoint("TOPLEFT", mmButton, "TOPLEFT", 0, 0)

  mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  mmButton:SetScript("OnClick", function()
    local btn = arg1
    if IsShiftKeyDown and IsShiftKeyDown() and btn ~= "RightButton" then
      ToggleConfig()
      return
    end
    if btn == "RightButton" then
      DB.minimap = false
      if mmButton then mmButton:Hide() end
      Print(Lf("mmState", OnOff(false)))
      return
    end
    ToggleWatchWindow()
  end)

  mmButton:SetScript("OnDragStart", function()
    local self = this or mmButton
    if not (IsShiftKeyDown and IsShiftKeyDown()) then return end
    self:SetScript("OnUpdate", DragMMButton)
  end)
  mmButton:SetScript("OnDragStop", StopMMDrag)
  mmButton:SetScript("OnMouseUp", StopMMDrag)
  mmButton:SetScript("OnHide", StopMMDrag)

  mmButton:SetScript("OnEnter", function()
    local self = this or mmButton
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(L("mmTitle"))
    local n = WatchCount()
    if n > 0 then
      GameTooltip:AddLine(L("wTitle") .. ": " .. n, 1, 0.82, 0)
    end
    GameTooltip:AddLine("|cff9d9d9d" .. L("mmLeft") .. "|r")
    GameTooltip:AddLine("|cff9d9d9d" .. L("cfgHint") .. "|r")
    GameTooltip:AddLine("|cff9d9d9d" .. L("mmRight") .. "|r")
    GameTooltip:AddLine("|cff9d9d9d" .. L("mmMove") .. "|r")
    GameTooltip:Show()
  end)
  mmButton:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)

  PlaceMinimapButton()
end

ApplyMinimapButton = function()
  if DB.minimap then
    local ok, err = pcall(BuildMinimapButton)
    if not ok then return end
    if mmButton then PlaceMinimapButton(); mmButton:Show() end
  elseif mmButton then
    mmButton:Hide()
  end
end

----------------------------------------------------------------------
-- the merchant window, and what to make next
----------------------------------------------------------------------

-- Everything about standing in front of a vendor lives in one table: this
-- file is close to the 200 local limit that the client's Lua imposes.
local Shop = {
  marks = {},                          -- one texture per visible vendor slot
  said  = nil,                         -- which vendor was already announced
}

-- What this vendor has that a watched recipe still wants
Shop.Wanted = function()
  if type(GetMerchantNumItems) ~= "function" then return nil, 0 end
  if type(GetMerchantItemInfo) ~= "function" then return nil, 0 end

  local out, n = {}, 0
  local total = GetMerchantNumItems() or 0
  local i = 1
  while i <= total do
    local name = GetMerchantItemInfo(i)
    if name then
      local wants = Need()[name]
      if wants then
        local need = 0
        local k = 1
        while wants[k] do
          if (wants[k].need or 1) > need then need = wants[k].need or 1 end
          k = k + 1
        end
        local left = need - Held(name)
        if left < 0 then left = 0 end
        n = n + 1
        out[n] = { slot = i, name = name, left = left }
      end
    end
    i = i + 1
  end
  return out, n
end

-- A star on the slots worth buying. The vendor window pages, so the marks are
-- placed by slot on the page rather than by item, and refreshed on every
-- update the client sends.
Shop.Mark = function()
  local page = 1
  while page <= 12 do
    local mark = Shop.marks[page]
    if mark then mark:Hide() end
    page = page + 1
  end

  if not DB.shop then return end
  local frame = getglobal("MerchantFrame")
  if not frame or not frame.IsVisible or not frame:IsVisible() then return end

  local list = Shop.Wanted()
  if not list then return end

  local perPage = 10
  if type(MERCHANT_ITEMS_PER_PAGE) == "number" then perPage = MERCHANT_ITEMS_PER_PAGE end
  local offset = ((frame.page or 1) - 1) * perPage

  local i = 1
  while list[i] do
    local slot = list[i].slot - offset
    if slot >= 1 and slot <= perPage then
      local button = getglobal("MerchantItem" .. slot .. "ItemButton")
      if button then
        local mark = Shop.marks[slot]
        if not mark then
          mark = button:CreateTexture(nil, "OVERLAY")
          mark:SetWidth(12)
          mark:SetHeight(12)
          mark:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
          mark:SetTexture(Map.DOT)
          Shop.marks[slot] = mark
        end
        mark:Show()
      end
    end
    i = i + 1
  end
end

Shop.Announce = function()
  if not DB.shop or not DB.signal then return end
  local list, n = Shop.Wanted()
  if not list or n == 0 then return end

  local who = "?"
  if type(UnitName) == "function" and UnitExists and UnitExists("npc") then
    who = UnitName("npc") or who
  elseif type(UnitName) == "function" then
    who = UnitName("target") or who
  end
  if Shop.said == who then return end
  Shop.said = who

  Print(Lf("shopHas", who))
  local cap, i = MaxRec(), 1
  local show = n
  if n > cap then show = cap - 1 end
  if show < 1 then show = 1 end
  while i <= show do
    Print("   " .. list[i].name .. "  |cffffd100" .. list[i].left .. "|r")
    i = i + 1
  end
  if n > show and show + 1 <= cap then
    Print("|cff9d9d9d" .. Lf("wMore", n - show) .. "|r")
  end
end

-- Which recipe raises the skill fastest for the fewest reagents: the ones
-- still orange, cheapest first, and only those the bags can actually make.
BestToLearn = function()
  if type(GetNumTradeSkills) ~= "function" then Print(L("wNeedWindow")) return end
  local total = GetNumTradeSkills() or 0
  if total == 0 then Print(L("wNeedWindow")) return end

  local line, rank, cap = nil, nil, nil
  if type(GetTradeSkillLine) == "function" then line, rank, cap = GetTradeSkillLine() end
  if line then Print(Lf("bestHead", line, rank or 0, cap or 0)) end

  -- What matters is not the colour but the price of one point of skill.
  -- An orange craft raises the skill every time, a yellow one about three
  -- times in four, a green one about one in four; a grey one never does and
  -- is the only colour left out. So a cheap green repeated ten times can beat
  -- one expensive yellow, and the sum below says which.
  --
  -- The colour filters on the panel are obeyed: unticking green is a way of
  -- saying "do not offer me green", and the answer should respect that.
  local list, n = {}, 0
  local i = 1
  while i <= total do
    local name, kind, avail = GetTradeSkillInfo(i)
    local chance = kind and K.CHANCE[kind]
    if chance and DB.show[kind] == false then chance = nil end
    if name and chance then
      local cost, r = 0, 1
      local slots = GetTradeSkillNumReagents(i) or 0
      while r <= slots do
        local _, _, need = GetTradeSkillReagentInfo(i, r)
        cost = cost + (need or 0)
        r = r + 1
      end
      -- reagents spent per point of skill actually gained
      n = n + 1
      list[n] = { name = name, cost = cost, avail = avail or 0,
                  kind = kind, per = cost / chance }
    end
    i = i + 1
  end

  if n == 0 then Print(L("bestNone")) return end

  pcall(table.sort, list, function(a, b)
    if a.per ~= b.per then return a.per < b.per end
    -- a tie goes to what can be made right now, then to the surer colour
    local ca = (a.avail > 0) and 0 or 1
    local cb = (b.avail > 0) and 0 or 1
    if ca ~= cb then return ca < cb end
    if RANK[a.kind] ~= RANK[b.kind] then return RANK[a.kind] < RANK[b.kind] end
    return a.name < b.name
  end)

  local room, k = MaxRec(), 1
  while list[k] and k <= room do
    local entry = list[k]
    local c = Color(entry.kind)
    local tail = ""
    if entry.avail > 0 then tail = "  |cff40ff40x" .. entry.avail .. "|r" end
    Print(Hex(c) .. "   " .. entry.name .. "|r  "
          .. Lf("bestPer", entry.cost, entry.per) .. tail)
    k = k + 1
  end
end

-- one beat of the watch side
WatchTick = function(step)
  PlaceMarks()
  DecorateTooltip()

  -- Marking or forgetting a recipe only sets a flag; the index behind it is
  -- rebuilt lazily, and that rebuild is what tells the map to redraw. Without
  -- this line the map waited for something else to ask a question first, and
  -- new pins appeared minutes later or not at all.
  if needDirty then Need() end

  if mapDirty then
    mapWait = mapWait + step
    if mapWait >= 1 then
      mapDirty, mapWait = false, 0
      pcall(Map.Build)
    end
  end

  -- The pins are ours, so keeping them in place is ours too: the minimap
  -- moves with the player and the world map can be dragged. Five times a
  -- second is enough to look glued and cheap enough not to be noticed.
  -- the vendor window changes pages without telling anyone
  if DB.shop then
    local frame = getglobal("MerchantFrame")
    if frame and frame.IsVisible and frame:IsVisible() and Shop.page ~= frame.page then
      Shop.page = frame.page
      pcall(Shop.Mark)
    end
  end

  Map.miniAt = Map.miniAt + step
  if Map.miniAt >= 0.2 then
    Map.miniAt = 0
    pcall(Map.DrawMini)
    if Map.MapOpen() then pcall(Map.DrawWorld) end
  end

  if bagDirty then
    bagAt = bagAt + step
    if bagAt >= 0.4 then
      bagDirty, bagAt = false, 0
      RefreshBags(false)
    end
  end
end

----------------------------------------------------------------------
-- diagnostics, kept from the probe
----------------------------------------------------------------------

local function LoadUI()
  if getglobal("TradeSkillFrame") then return true end
  if type(TradeSkillFrame_LoadUI) == "function" then pcall(TradeSkillFrame_LoadUI) end
  return (getglobal("TradeSkillFrame") ~= nil)
end

local function DumpRows(limit)
  if type(GetNumTradeSkills) ~= "function" then Print(L("openFirst")) return end
  local n = GetNumTradeSkills() or 0
  if n == 0 then Print(L("openFirst")) return end
  BuildView()
  local i = 1
  while i <= viewN and (limit == 0 or i <= limit) do
    local e = view[i]
    local c = Color(e.kind)
    Print(i .. ") #" .. e.id .. " " .. e.name .. " [" .. e.kind .. "] "
          .. (e.avail > 0 and ("x" .. e.avail) or "-")
          .. (AnyReagent(e.id) and (" |cff40ff40" .. L("dbgHave") .. "|r") or ""))
    i = i + 1
  end
  Print(Lf("stateCount", viewN, totalN))
end

local function DumpNames()
  LoadUI()
  local G
  if type(getfenv) == "function" then G = getfenv(0) end
  if type(G) ~= "table" then G = _G end
  if type(G) ~= "table" then return end
  local list, n = {}, 0
  for key in pairs(G) do
    if type(key) == "string" and string.find(key, "^TradeSkill") then
      n = n + 1
      list[n] = key
    end
  end
  pcall(table.sort, list)
  local line, i = "", 1
  while list[i] do
    if string.len(line) + string.len(list[i]) > 110 then Print(line) line = "" end
    line = line .. (line == "" and "" or ", ") .. list[i]
    i = i + 1
  end
  if line ~= "" then Print(line) end
  Print(Lf("dbgTotal", n))
end

local function Probe()
  LoadUI()
  BuildView()
  local function Mark(v) if v then return "+" end return "-" end
  Print("window=" .. Mark(getglobal("TradeSkillFrame"))
        .. " hook=" .. Mark(hooked)
        .. " btn=" .. (getglobal("TradeSkillSkill1") and RowCount() or 0)
        .. " step=" .. RowHeight()
        .. " active=" .. Mark(Active()))
  Print("list=" .. viewN .. "/" .. totalN
        .. " panel=" .. Mark(panel)
        .. " colors=" .. (getglobal("TradeSkillTypeColor") and "client" or "own")
        .. " sort=" .. DB.sort
        .. " bag=" .. DB.reagents)
end

ObjectName = function(id)
  if not KoReady() or type(KoDB.objects) ~= "table" then return nil end
  local loc = KoDB.objects.loc
  if type(loc) ~= "table" then return nil end
  return loc[id]
end

-- what the database has on an item, split by kind of source
local function ItemSources(name)
  local out = { units = {}, objects = {}, vendors = {}, nU = 0, nO = 0, nV = 0 }
  if not KoReady() then return out end

  local ids = ItemIds(name)
  if not ids then return out end

  for itemId in pairs(ids) do
    local entry = KoDB.items.data[itemId]
    if type(entry) == "table" then
      if type(entry.O) == "table" then
        for obj, chance in pairs(entry.O) do
          if not out.objects[obj] then out.nO = out.nO + 1 end
          out.objects[obj] = chance
        end
      end
      if type(entry.V) == "table" then
        for vendor in pairs(entry.V) do
          if not out.vendors[vendor] then out.nV = out.nV + 1 end
          out.vendors[vendor] = true
        end
      end
    end
  end

  local units = {}
  for itemId in pairs(ids) do UnitsForItem(itemId, units) end
  for unitId, chance in pairs(units) do
    out.units[unitId] = chance
    out.nU = out.nU + 1
  end
  return out
end

-- a short word for the watch window: where this reagent mostly comes from
SourceTag = function(name)
  if not KoReady() then return nil end
  local src = ItemSources(name)
  if src.nU > 0 then return nil end          -- mobs are the usual case, no need to say it
  if src.nV > 0 then return L("srcVendor") end
  if src.nO > 0 then return L("srcObject") end
  return nil
end

-- every mob this player has personally seen drop the thing
local function SeenSources(item)
  if type(CraftFocusDrops) ~= "table" then return nil, 0 end
  local out, n = {}, 0
  for mob, pack in pairs(CraftFocusDrops) do
    if item ~= "t" and type(pack) == "table" and pack[item] == true then
      n = n + 1
      out[n] = mob
    end
  end
  if n == 0 then return nil, 0 end
  pcall(table.sort, out)
  return out, n
end

-- /cf where: the short answer to "and where do I get this"
local function WhereFrom(name)
  if not name or name == "" then Print(L("whereBad")) return end

  local said = false
  local src = { nU = 0, nO = 0, nV = 0, units = {}, objects = {}, vendors = {} }
  if KoReady() then src = ItemSources(name) else Print(L("whereNoKo")) end

  Print(Lf("whereHead", name))

  -- mobs, the most likely first
  if src.nU > 0 then
    local list, n = {}, 0
    for unitId, chance in pairs(src.units) do
      n = n + 1
      list[n] = { id = unitId, chance = chance }
    end
    pcall(table.sort, list, function(a, b) return (a.chance or 0) > (b.chance or 0) end)

    local i, shown = 1, 0
    while list[i] and shown < 8 do
      local who = UnitName_(list[i].id)
      if who then
        shown = shown + 1
        said = true
        local zone = UnitZone(list[i].id)
        local tail = string.format("%.1f", list[i].chance or 0) .. "%"
        if zone then tail = tail .. "  |cff9d9d9d" .. zone .. "|r" end
        Print(Lf("whereLine", who, tail))
      end
      i = i + 1
    end
  end

  -- gathered from something standing in the world
  if src.nO > 0 then
    local names, n = "", 0
    for obj in pairs(src.objects) do
      local who = ObjectName(obj)
      if who and n < 4 then
        names = names .. (n > 0 and ", " or "") .. who
        n = n + 1
      end
    end
    if names ~= "" then
      said = true
      Print(Lf("whereObject", names))
    end
  end

  -- or simply bought
  if src.nV > 0 then
    local names, n = "", 0
    for vendor in pairs(src.vendors) do
      local who = UnitName_(vendor)
      if who and n < 3 then
        names = names .. (n > 0 and ", " or "") .. who
        n = n + 1
      end
    end
    said = true
    Print(Lf("whereVendor", src.nV, names ~= "" and names or "?"))
  end

  -- and what this player has seen with their own eyes
  local seen, sn = SeenSources(name)
  if seen then
    local text, i = "", 1
    while seen[i] and i <= 5 do
      text = text .. (i > 1 and ", " or "") .. seen[i]
      i = i + 1
    end
    if sn > 5 then text = text .. ", ..." end
    said = true
    Print(Lf("whereSeen", text))
  end

  if not said then
    Print(Lf("whereNone", name))
    Print(L("whereSkin"))
  end
end

----------------------------------------------------------------------
-- commands
----------------------------------------------------------------------

local function ShowState()
  local shown, i = "", 1
  while KEYS[i] do
    if DB.show[KEYS[i]] ~= false then
      shown = shown .. (shown == "" and "" or ", ") .. QName(KEYS[i])
    end
    i = i + 1
  end
  if shown == "" then shown = "-" end
  Print(Lf("stateSort", DB.sort == "quality" and L("sortQuality") or L("sortStock")))
  Print(Lf("stateShow", shown))
  Print(Lf("stateBag", BagLabel() .. " (" .. DB.reagents .. ")"))
  Print(Lf("wOnlyState", OnOff(DB.onlyWatched)))
  Print(Lf("statePanel", OnOff(DB.panel)))
  Print(Lf("wSignal", OnOff(DB.signal)) .. " | " .. Lf("wTips", OnOff(DB.tips))
        .. " | " .. Lf("wMarks", OnOff(DB.marks)))
  if WatchCount and WatchCount() > 0 then
    Print(L("wTitle") .. ": " .. WatchCount())
  end
  if totalN > 0 then
    Print(Lf("stateCount", viewN, totalN))
  elseif not getglobal("TradeSkillFrame") then
    Print(L("noWindow"))
  end
end

local QALIAS = {
  opt = "optimal", optimal = "optimal", orange = "optimal", ["оранж"] = "optimal",
  med = "medium", medium = "medium", yellow = "medium", ["жёлт"] = "medium", ["желт"] = "medium",
  easy = "easy", green = "easy", ["зел"] = "easy",
  triv = "trivial", trivial = "trivial", grey = "trivial", gray = "trivial", ["сер"] = "trivial",
}

-- Everything on screen that carries a word. Called when the language changes:
-- the panel redraws itself anyway, but the two windows keep static labels put
-- there when they were built, and those would stay in the old language until
-- the next reload.
Relabel = function()
  if UpdatePanel then UpdatePanel() end
  if UpdateConfig then UpdateConfig() end
  if UpdateWatchWindow then UpdateWatchWindow() end

  if wnd then
    if wnd.close and wnd.close.text then wnd.close.text:SetText(L("wClose")) end
    if wnd.gear and wnd.gear.text then wnd.gear.text:SetText(L("cfgBtn")) end
    -- the clear button says "Sure?" while it is armed; leave that alone
    if wnd.clear and wnd.clear.text and not wnd.clear.armed then
      wnd.clear.text:SetText(L("wClear"))
    end
  end

  if cfg and cfg.title then cfg.title:SetText(L("cfgTitle")) end
end

local function HandleSlash(msg)
  msg = string.lower(msg or "")
  local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.*)$")
  cmd = cmd or ""

  if cmd == "" then
    ShowState()

  elseif cmd == "help" or cmd == "?" then
    Print(L("help1"))
    Print(L("help2"))
    Print(L("help3"))

  elseif cmd == "sort" then
    if DB.sort == "quality" then SetSort("stock") else SetSort("quality") end
    Apply()
    Print(Lf("stateSort", DB.sort == "quality" and L("sortQuality") or L("sortStock")))

  elseif cmd == "bag" then
    if rest == "off" or rest == "any" or rest == "all" then
      DB.reagents = rest
    else
      DB.reagents = REAGENT_ORDER[DB.reagents] or "any"
    end
    Apply()
    Print(Lf("stateBag", BagLabel() .. " (" .. DB.reagents .. ")"))

  elseif cmd == "q" then
    local key = QALIAS[rest]
    if not key then
      Print(L("help2"))
    else
      DB.show[key] = not (DB.show[key] ~= false)
      Apply()
      Print(Lf("ttColor", QName(key), OnOff(DB.show[key] ~= false)))
    end

  elseif cmd == "all" or cmd == "none" then
    local want = (cmd == "all")
    local i = 1
    while KEYS[i] do DB.show[KEYS[i]] = want; i = i + 1 end
    Apply()
    ShowState()

  elseif cmd == "watch" or cmd == "w" then
    if rest == "clear" then
      DB.watch = {}
      needDirty = true
      RefreshList()
      if UpdateWatchWindow then UpdateWatchWindow() end
      Print(L("wCleared"))
    else
      ToggleWatchWindow()
    end

  elseif cmd == "where" then
    WhereFrom(rest)

  elseif cmd == "config" or cmd == "cfg" or cmd == "options" then
    ToggleConfig()

  elseif cmd == "max" then
    local n = tonumber(rest)
    if n then
      DB.maxrec = n
      DB.maxrec = MaxRec()
      if UpdateConfig then UpdateConfig() end
    end
    Print(Lf("maxState", MaxRec()))

  elseif cmd == "best" then
    BestToLearn()

  elseif cmd == "shop" then
    DB.shop = not DB.shop
    if UpdateConfig then UpdateConfig() end
    pcall(Shop.Mark)
    Print(Lf("shopState", OnOff(DB.shop)))

  elseif cmd == "stations" then
    DB.stations = not DB.stations
    mapDirty = true
    if UpdateConfig then UpdateConfig() end
    Print(Lf("stationsState", OnOff(DB.stations)))

  elseif cmd == "mapall" then
    DB.mapall = not DB.mapall
    mapDirty = true
    if UpdateConfig then UpdateConfig() end
    Print(Lf("mapAllState", OnOff(DB.mapall)))

  elseif cmd == "mmap" then
    DB.mmap = not DB.mmap
    mapDirty = true
    if UpdateConfig then UpdateConfig() end
    Print(Lf("mmapState", OnOff(DB.mmap)))

  elseif cmd == "map" then
    DB.map = not DB.map
    mapDirty = true
    if UpdateConfig then UpdateConfig() end
    Print(Lf("mapState", OnOff(DB.map)))
    if DB.map and not KoReady() then Print(L("mapNoKo")) end
    if DB.map then
      pcall(Map.Build)
      Print(Lf("mapCount", Map.placed))
      pcall(MapWhy)
    end

  elseif cmd == "mobs" then
    DB.mobs = not DB.mobs
    dropDirty = true
    if UpdateConfig then UpdateConfig() end
    Print(Lf("mobsState", OnOff(DB.mobs)))

  elseif cmd == "drops" then
    if rest == "clear" then
      CraftFocusDrops, CraftFocusKinds = {}, {}
      Print(L("dropsWiped"))
    else
      DB.drops = not DB.drops
      Print(Lf("dropsState", OnOff(DB.drops)))
      Print(Lf("dropsCount", CountKeys(CraftFocusDrops), CountKeys(CraftFocusKinds)))
    end

  elseif cmd == "actions" then
    if ListActions then ListActions() end

  elseif cmd == "prof" then
    local slot = tonumber(rest)
    if not slot or slot < 1 or slot > 120 then
      Print(L("wSlotBad"))
    elseif type(HasAction) == "function" and not HasAction(slot) then
      Print(Lf("wSlotNone", slot))
    else
      local line = nil
      if type(GetTradeSkillLine) == "function" then line = GetTradeSkillLine() end
      if not line or line == "" or line == "UNKNOWN" then
        Print(L("wNoWindow"))
      else
        if RememberSlot then RememberSlot(line, slot) end
        Print(Lf("wSlotSet", slot, line))
      end
    end

  elseif cmd == "only" then
    DB.sort = "quality"
    DB.onlyWatched = not DB.onlyWatched
    Apply()
    Print(Lf("wOnlyState", OnOff(DB.onlyWatched)))

  elseif cmd == "minimap" then
    DB.minimap = not DB.minimap
    ApplyMinimapButton()
    Print(Lf("mmState", OnOff(DB.minimap)))

  elseif cmd == "signal" then
    DB.signal = not DB.signal
    Print(Lf("wSignal", OnOff(DB.signal)))

  elseif cmd == "tips" then
    DB.tips = not DB.tips
    Print(Lf("wTips", OnOff(DB.tips)))

  elseif cmd == "marks" then
    DB.marks = not DB.marks
    Print(Lf("wMarks", OnOff(DB.marks)))

  elseif cmd == "safe" then
    -- the panic switch: put the client's own function back, stop the
    -- watcher, hide the panel, and stay that way after a reload
    Unhook()
    if keeper then keeper:SetScript("OnUpdate", nil) end
    if panel then panel:Hide() end
    pcall(ReleaseRows)
    if type(TradeSkillFrame_Update) == "function" then pcall(TradeSkillFrame_Update) end
    DB.enabled = false
    Print(L("safeDone"))

  elseif cmd == "pos" then
    DB.pos = false
    PlacePanel()
    UpdatePanel()
    Print(L("posReset"))

  elseif cmd == "panel" then
    DB.panel = not DB.panel
    UpdatePanel()
    Print(Lf("statePanel", OnOff(DB.panel)))

  elseif cmd == "on" or cmd == "off" then
    DB.enabled = (cmd == "on")
    Apply()
    Print(ADDON .. ": " .. OnOff(DB.enabled))

  elseif cmd == "reset" then
    CraftFocusDB = nil
    InitDB()
    PlacePanel()
    Apply()
    Print(L("resetDone"))

  elseif cmd == "lang" then
    if rest == "ru" or rest == "en" or rest == "auto" then
      DB.lang = rest
    elseif rest == "" then
      -- bare /cl lang steps through the three settings, like the other switches
      if DB.lang == "auto" then DB.lang = "ru"
      elseif DB.lang == "ru" then DB.lang = "en"
      else DB.lang = "auto" end
    else
      Print(L("help1"))
      return
    end
    Relabel()
    Print(Lf("langSet", DB.lang))

  elseif cmd == "probe" then
    Probe()

  elseif cmd == "names" then
    DumpNames()

  elseif cmd == "dump" then
    DumpRows(tonumber(rest) or 20)

  elseif cmd == "full" then
    DumpRows(0)

  else
    Print(L("help1"))
    Print(L("help2"))
  end
end

----------------------------------------------------------------------
-- wiring
----------------------------------------------------------------------

local driver = CreateFrame("Frame", "CraftFocusDriver")

local function OnEvent()
  local e = event

  if e == "VARIABLES_LOADED" or e == "PLAYER_LOGIN" then
    InitDB()
    pcall(ForgetStale)
    StartKeeper()
    HookStockBags()
    ApplyMinimapButton()
    RefreshBags(true)            -- a baseline; logging in is not news

  elseif e == "ADDON_LOADED" then
    if arg1 == "Blizzard_TradeSkillUI" then
      SyncHook()
    end

  elseif e == "TRADE_SKILL_SHOW" then
    InitDB()
    SyncHook()
    BuildPanel()
    pcall(TopUpWatch)
    if LearnProfessionSlot then pcall(LearnProfessionSlot, true) end
    if pendingRecipe and ShowRecipe then
      local want = pendingRecipe
      pendingRecipe = nil
      pcall(ShowRecipe, want)
    end
    if not DB.panel and not panelHintSaid then
      panelHintSaid = true
      Print(L("mmPanelHint"))
    end
    StartKeeper()
    if Active() then Apply() else UpdatePanel() end

  elseif e == "TRADE_SKILL_UPDATE" then
    -- the window redraws itself; the hook picks it up
    pcall(TopUpWatch)

  elseif e == "PLAYER_ENTERING_WORLD" then
    StartKeeper()
    HookStockBags()
    ApplyMinimapButton()
    bagDirty = true

  elseif e == "WORLD_MAP_UPDATE" then
    pcall(Map.DrawWorld)

  elseif e == "MERCHANT_SHOW" then
    pcall(Shop.Announce)
    pcall(Shop.Mark)

  elseif e == "MERCHANT_UPDATE" then
    pcall(Shop.Mark)

  elseif e == "MERCHANT_CLOSED" then
    Shop.said = nil
    pcall(Shop.Mark)

  elseif e == "LOOT_OPENED" then
    pcall(ScanLoot)

  elseif e == "BAG_UPDATE" then
    bagDirty = true
    -- only matters while the reagent filter is on and the window is open
    if DB and DB.reagents ~= "off" and Active() and getglobal("TradeSkillFrame")
       and getglobal("TradeSkillFrame"):IsVisible() then
      Redraw()
    end
  end
end

driver:SetScript("OnEvent", OnEvent)
driver:RegisterEvent("VARIABLES_LOADED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("TRADE_SKILL_SHOW")
driver:RegisterEvent("TRADE_SKILL_UPDATE")
driver:RegisterEvent("BAG_UPDATE")
driver:RegisterEvent("LOOT_OPENED")
driver:RegisterEvent("WORLD_MAP_UPDATE")
driver:RegisterEvent("MERCHANT_SHOW")
driver:RegisterEvent("MERCHANT_UPDATE")
driver:RegisterEvent("MERCHANT_CLOSED")

InitDB()
SyncHook()

SLASH_CRAFTFOCUS1 = "/craftfocus"
SLASH_CRAFTFOCUS2 = "/cf"
-- the old names keep working, so nothing typed out of habit is lost
SLASH_CRAFTFOCUS3 = "/craftlens"
SLASH_CRAFTFOCUS4 = "/cl"
SlashCmdList["CRAFTFOCUS"] = HandleSlash

Print(Lf("loaded", ADDON .. " " .. VERSION))
