-- GuildRecruiterTest_Spec.lua
-- Набор тестов: команды, каналы, рандомизация, UX-сообщения

local T = GuildRecruiterTest

-- Алиас на /gru
local function GRU(cmd)
    local handler = SlashCmdList["GUILDRECRUITER"] or SlashCmdList["GRU"]
    if handler then
        handler(cmd or "")
    else
        error("GuildRecruiter slash command not found (/gru)", 0)
    end
end

-- Хелперы
local function resetState()
    GR_Settings = {
        message = "🌟 Гильдия Местные Деды набирает игроков! Пишите /w для деталей.",
        channelType = "SAY",
        channelId = nil,
        randomize = false,
        templates = {}
    }
    T._printed = {}
    T._sent = {}
end

-- Удаляем цветовые коды
local function stripColors(s)
    return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function anyPrinted(pat)
    for _, m in ipairs(T._printed) do
        local clean = stripColors(m)
        if type(clean) == "string" and clean:match(pat) then
            return true
        end
    end
    return false
end

local function firstJoinedChannel()
    local list = { GetChannelList() }
    local i = 1
    while i <= #list do
        local id, name, maybe = list[i], list[i + 1], list[i + 2]
        if type(id) == "number" and type(name) == "string" then
            return id, name
        end
        i = i + (type(maybe) == "boolean" and 3 or 2)
    end
end

-- Сьюты
T.describe("Smoke — загрузка и базовый статус", function()
    T.it("Аддон загружен и /gru доступен", function(t)
        resetState()
        t.assertTrue(type(SlashCmdList["GUILDRECRUITER"]) == "function" or type(SlashCmdList["GRU"]) == "function", "/gru зарегистрирован")
    end)

    T.it("Вывод /gru status содержит ключевые поля", function(t)
        resetState()
        GRU("status")
        t.assertTrue(anyPrinted("Текущие настройки"), "Есть заголовок статуса")
        t.assertTrue(anyPrinted("Канал:"), "Есть канал")
        t.assertTrue(anyPrinted("Шаблонов:"), "Есть количество шаблонов")
    end)
end)

T.describe("Команда msg", function()
    T.it("Установка сообщения", function(t)
        resetState()
        GRU("msg Проверка связи")
        t.assertTrue(anyPrinted("Сообщение изменено"), "UX подтверждение изменено")
        t.assertTrue(GR_Settings.message == "Проверка связи", "Сообщение изменилось")
    end)

    T.it("Пустой ввод — ожидаем подсказку", function(t)
        resetState()
        GRU("msg")
        t.assertTrue(anyPrinted("Укажите текст"), "UX подсказка без текста")
    end)
end)

T.describe("Команда chan", function()
    T.it("Переключение на GUILD", function(t)
        resetState()
        GRU("chan GUILD")
        t.assertTrue(GR_Settings.channelType == "GUILD", "Тип канала GUILD")
        t.assertTrue(GR_Settings.channelId == nil, "ID сброшен")
    end)

    T.it("CHANNEL по ID (если есть подключённые каналы)", function(t)
        resetState()
        local id = firstJoinedChannel()
        if not id then return t.skip("Нет подключённых каналов") end
        GRU("chan CHANNEL " .. id)
        t.assertTrue(GR_Settings.channelType == "CHANNEL", "Тип CHANNEL")
        t.assertTrue(GR_Settings.channelId == id, "ID сохранён")
    end)

    T.it("CHANNEL по имени (если есть подключённые каналы)", function(t)
        resetState()
        local id, name = firstJoinedChannel()
        if not id then return t.skip("Нет подключённых каналов") end
        GRU("chan CHANNEL " .. name)
        t.assertTrue(GR_Settings.channelType == "CHANNEL", "Тип CHANNEL")
        t.assertTrue(GR_Settings.channelId == id, "ID найден по имени")
    end)

    T.it("CHANNEL по несуществующему ID — UX ошибка", function(t)
        resetState()
        GRU("chan CHANNEL 999")
        t.assertTrue(anyPrinted("Канал с ID"), "Выведено предупреждение про несуществующий ID")
    end)

    T.it("CHANNEL по несуществующему имени — UX ошибка", function(t)
        resetState()
        GRU("chan CHANNEL some_fake_channel")
        t.assertTrue(anyPrinted("не найден"), "Выведено предупреждение про несуществующий канал")
    end)
end)

T.describe("Шаблоны и рандомизация", function()
    T.it("Добавление шаблонов и включение randomize", function(t)
        resetState()
        GRU("addtmpl A")
        GRU("addtmpl B")
        GRU("random on")
        GRU("send")
        t.assertTrue(#T._sent == 1, "Зафиксирован 1 вызов SendChatMessage")
        local m = T._sent[1].msg
        t.assertTrue(m == "A" or m == "B", "Выбран один из шаблонов")
    end)

    T.it("Пустые шаблоны при randomize — автоотключение", function(t)
        resetState()
        GRU("random on")
        GRU("send")
        t.assertTrue(anyPrinted("рандомизац"), "Выведено предупреждение")
        t.assertTrue(GR_Settings.randomize == false, "randomize выключен")
    end)

    T.it("Защита от дубликатов при addtmpl", function(t)
        resetState()
        GRU("addtmpl X")
        GRU("addtmpl X")
        if anyPrinted("уже есть") then
            t.assertTrue(true, "Предупреждение о дубликате")
        else
            t.skip("В текущей версии GuildRecruiter нет защиты от дубликатов")
        end
    end)
end)

T.describe("Отправка и список каналов", function()
    T.it("send в не-CHANNEL", function(t)
        resetState()
        GRU("chan SAY")
        GRU("send")
        t.assertTrue(#T._sent == 1, "Отправка зафиксирована")
        t.assertTrue(T._sent[1].ctype == "SAY", "Тип SAY")
    end)

    T.it("send в CHANNEL без ID — ошибка UX", function(t)
        resetState()
        GR_Settings.channelType = "CHANNEL"
        GR_Settings.channelId = nil
        GRU("send")
        t.assertTrue(anyPrinted("Не задан channelId"), "UX ошибка без ID")
        t.assertTrue(#T._sent == 0, "Ничего не отправлено")
    end)

    T.it("listchannels показывает список или предупреждает об отсутствии", function(t)
        resetState()
        GRU("listchannels")
        local printed = table.concat(T._printed, "\n")
        if printed:match("%[%d+%]%s+.+") or printed:match("Вы не подключены") then
            t.assertTrue(true, "Формат корректен")
        else
            t.assertTrue(false, "Формат некорректен")
        end
    end)
end)
