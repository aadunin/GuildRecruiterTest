-- GuildRecruiterTest_Core.lua
-- Мини-фреймворк + безопасный раннер для автотестов в игре
-- Фичи: перехват SendChatMessage (без спама), прогресс-бар, Summary, SKIP, JUnit экспорт

local addonName = "GuildRecruiterTest"

local GRTest = {
  suites = {},
  results = { passed = 0, failed = 0, skipped = 0, list = {} },
  _currentSuite = nil,
  _printed = {},
  _sent = {},
}

-- Цветной вывод
local function cpass(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00PASS|r " .. msg) end
local function cfail(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffff0000FAIL|r " .. msg) end
local function cinfo(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[TEST]|r " .. msg) end
local function cskip(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff999999SKIP|r " .. msg) end

-- Ассерты
local function tostr(v)
  local t = type(v)
  if t == "string" then return v end
  if t == "number" or type(v) == "boolean" or v == nil then return tostring(v) end
  return ("<%s>"):format(t)
end
local function assertEqual(a, e, ctx)
  if a ~= e then error((ctx or "assertEqual")..": expected="..tostr(e)..", got="..tostr(a), 0) end
end
local function assertTrue(v, ctx)
  if not v then error((ctx or "assertTrue")..": expected truthy, got "..tostr(v), 0) end
end
local function assertMatch(s, pat, ctx)
  if type(s) ~= "string" or not s:match(pat) then
    error((ctx or "assertMatch")..": pattern '"..pat.."' not found in '"..tostr(s).."'", 0)
  end
end

-- Регистрация
function GRTest.describe(name, fn)
  table.insert(GRTest.suites, { name = name, fn = fn })
end

-- Прогресс по сьютам
local function suiteProgress(i, total)
  local barLen = 20
  local filled = math.floor((i / total) * barLen)
  local bar = string.rep("█", filled) .. string.rep("░", barLen - filled)
  cinfo(("[%s] suite %d/%d"):format(bar, i, total))
end

function GRTest.it(name, fn)
  local full = GRTest._currentSuite .. " › " .. name
  local ok, err = pcall(fn, {
    assertEqual = assertEqual,
    assertTrue  = assertTrue,
    assertMatch = assertMatch,
    getPrinted  = function() return GRTest._printed end,
    getSent     = function() return GRTest._sent end,
    clearIO     = function() GRTest._printed = {}; GRTest._sent = {} end,
    skip        = function(reason) error({ __skip = true, reason = reason or "" }, 0) end,
  })
  if ok then
    GRTest.results.passed = GRTest.results.passed + 1
    cpass(full)
  else
    if type(err) == "table" and err.__skip then
      GRTest.results.skipped = GRTest.results.skipped + 1
      cskip(full .. (err.reason ~= "" and (" — " .. tostring(err.reason)) or ""))
      table.insert(GRTest.results.list, { name = full, skipped = true, reason = err.reason })
    else
      GRTest.results.failed = GRTest.results.failed + 1
      local emsg = tostring(err)
      cfail(full .. " — " .. emsg)
      table.insert(GRTest.results.list, { name = full, error = emsg })
    end
  end
end

-- Перехват I/O
local origPrint, origSend
local function startHooks()
  GRTest._printed = {}
  GRTest._sent = {}
  origPrint = print
  print = function(...)
    local parts, raw = { ... }, {}
    for i = 1, select("#", ...) do raw[i] = tostring(select(i, ...)) end
    local msg = table.concat(raw, " ")
    table.insert(GRTest._printed, msg)
    return origPrint(unpack(parts))
  end
  origSend = SendChatMessage
  SendChatMessage = function(msg, ctype, lang, target)
    table.insert(GRTest._sent, { msg = msg, ctype = ctype, lang = lang, target = target })
    -- не отправляем в реальный чат
  end
end
local function stopHooks()
  if origPrint then print = origPrint end
  if origSend then SendChatMessage = origSend end
end

-- Экспорт в JUnit
local function escapeXml(str)
  return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end
local function exportJUnit()
  local xml = {}
  table.insert(xml, '<?xml version="1.0" encoding="UTF-8"?>')
  table.insert(xml, ('<testsuites name="%s">'):format(addonName))
  table.insert(xml, ('  <testsuite name="%s" tests="%d" failures="%d" skipped="%d">')
    :format(addonName, GRTest.results.passed + GRTest.results.failed + GRTest.results.skipped,
      GRTest.results.failed, GRTest.results.skipped))
  for _, r in ipairs(GRTest.results.list) do
    local caseName = escapeXml(r.name)
    if r.skipped then
      table.insert(xml, ('    <testcase name="%s"><skipped>%s</skipped></testcase>')
        :format(caseName, escapeXml(r.reason or "")))
    elseif r.error then
      table.insert(xml, ('    <testcase name="%s"><failure>%s</failure></testcase>')
        :format(caseName, escapeXml(r.error)))
    else
      table.insert(xml, ('    <testcase name="%s"/>'):format(caseName))
    end
  end
  table.insert(xml, "  </testsuite>")
  table.insert(xml, "</testsuites>")
  _G.GuildRecruiterTest_JUnit = table.concat(xml, "\n")
  cinfo("JUnit report saved to SavedVariables: GuildRecruiterTest_JUnit")
end

-- Запуск
function GRTest.run(filter)
  startHooks()
  GRTest.results = { passed = 0, failed = 0, skipped = 0, list = {} }
  cinfo("Running tests" .. (filter and (" (filter: " .. filter .. ")") or ""))
  local totalSuites = #GRTest.suites
  local executedSuites = 0
  for _, s in ipairs(GRTest.suites) do
    if not filter or s.name:lower():find(filter:lower(), 1, true) then
      executedSuites = executedSuites + 1
      GRTest._currentSuite = s.name
      suiteProgress(executedSuites, totalSuites)
      local ok, err = pcall(s.fn)
      if not ok then
        GRTest.results.failed = GRTest.results.failed + 1
        cfail("Suite " .. s.name .. " crashed: " .. tostring(err))
      end
    end
  end
  local summary = ("Summary: %d passed, %d failed, %d skipped"):format(
    GRTest.results.passed, GRTest.results.failed, GRTest.results.skipped)
  if GRTest.results.failed == 0 then cpass(summary) else cfail(summary) end
  stopHooks()
end

_G.GuildRecruiterTest = GRTest

-- Slash-команда
SLASH_GRUTEST1 = "/grutest"
SlashCmdList["GRUTEST"] = function(msg)
  local cmd, flt = msg:match("^(%S*)%s*(.*)$")
  cmd = (cmd or ""):lower()
  if cmd == "" or cmd == "run" then
    GuildRecruiterTest.run(flt ~= "" and flt or nil)
  elseif cmd == "list" then
    for _, s in ipairs(GuildRecruiterTest.suites) do cinfo("• " .. s.name) end
  elseif cmd == "junit" then
    exportJUnit()
  else
    cinfo("Usage: /grutest run [filter] | list | junit")
  end
end

-- Автосообщение
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  cinfo("GuildRecruiterTest loaded. Use /grutest run")
end)
