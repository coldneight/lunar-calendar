--!nonstrict
-- bar.luau — 状态栏农历 widget
-- 显示今天的农历日期（格式可配置），点击打开月历面板。

local PANEL_ID = "coldneight/lunar_calendar:panel"
local lunar = require("lunar")

-- 当前状态（由 service 推送，或用 formatTime 获取）
local today = nil
local todayLunar = nil
local todayHoliday = nil

-- 从当前时间获取今天的(y,m,d)
local function getToday()
  local fmt = noctalia.formatTime("{t.year};{t.month};{t.day}", nil, "") -- 占位，实际用下面
  -- 用 strftime 取年月日
  local y = tonumber(noctalia.formatTime("%Y", nil, "") or "")
  local m = tonumber(noctalia.formatTime("%m", nil, "") or "")
  local d = tonumber(noctalia.formatTime("%d", nil, "") or "")
  return y, m, d
end

-- 计算并缓冲今天的农历信息
local function computeToday()
  local y, m, d = getToday()
  if not (y and m and d) then
    return y, m, d
  end
  today = { y = y, m = m, d = d }
  todayLunar = lunar.fromSolar(y, m, d)
  local htype, hname = lunar.getHoliday(y, m, d)
  todayHoliday = htype and hname or nil
  return y, m, d
end

local function barFormat()
  local v = noctalia.getConfig("bar_format")
  if type(v) ~= "string" then v = "lunar_day" end
  return v
end

local function render()
  if not todayLunar then
    computeToday()
  end
  if not todayLunar then
    barWidget.render(ui.glyph({ name = "calendar" }))
    return
  end

  local l = todayLunar
  local glyph = noctalia.getConfig("show_glyph") ~= false

  local container = barWidget.isVertical() and ui.column or ui.row
  local children = {}
  if glyph then
    table.insert(children, ui.glyph({ name = "calendar" }))
  end

  local fmt = barFormat()
  local text = ""
  if fmt == "lunar_day" then
    text = l.monthStr .. l.dayStr
  elseif fmt == "solar_lunar" then
    text = string.format("%d-%02d-%02d %s%s", today.y, today.m, today.d, l.monthStr, l.dayStr)
  elseif fmt == "lunar_full" then
    text = today.y .. " " .. l.yearGanZhi .. l.shengXiao .. "年 " .. l.monthStr .. l.dayStr
  end

  if text ~= "" and not barWidget.isVertical() then
    table.insert(children, ui.label({ text = text, fontWeight = "bold" }))
  end

  -- tooltip
  local tooltipLines = {
    string.format("%d年%d月%d日", today.y, today.m, today.d),
    ("%s%s年 %s%s"):format(l.yearGanZhi, l.shengXiao, l.monthStr, l.dayStr),
  }
  if todayHoliday then
    table.insert(tooltipLines, "节日: " .. todayHoliday)
  end
  barWidget.setTooltip(table.concat(tooltipLines, "\n"))

  barWidget.render(container({ gap = 6, align = "center" }, children))
end

function update()
  noctalia.setUpdateInterval(60000) -- 每分钟刷一次
  computeToday()
  render()
end

-- 接收 service 推送的实时农历
noctalia.state.watch("lunar.todayYmd", function(ymd)
  if type(ymd) == "table" and ymd.y then
    today = ymd
    todayLunar = lunar.fromSolar(ymd.y, ymd.m, ymd.d)
    local htype, hname = lunar.getHoliday(ymd.y, ymd.m, ymd.d)
    todayHoliday = htype and hname or nil
    render()
  end
end)

-- 配置变化时刷新
function onConfigChanged()
  render()
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end

function onIpc(event, _payload)
  if event == "toggle" then
    noctalia.togglePanel(PANEL_ID)
  elseif event == "today" then
    computeToday()
    render()
  end
end

computeToday()
render()
