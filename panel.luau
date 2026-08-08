--!nonstrict
-- panel.luau — 农历月历面板
-- 点开是完整月历（周一起始），点击任意格子进入单日台历详情（◀▶ 前后天切换）。
-- 顶部 bar widget 点开此面板。

local lunar = require("lunar")
local calendar = require("calendar")
local detail = require("detail")

-- 视图状态
local view = {
  mode = "month", -- "month" 月历 / "detail" 单日详情
  y = 0, m = 0, d = 0, -- 当前查看的年/月/（详情时的日）
}

-- 今天
local todayY, todayM, todayD = 0, 0, 0

-- 某日在一周中的索引 0=周一 ... 6=周日
local function weekday1Monday(y, m, d)
  local jd = lunar.toJulianDay(y, m, d)
  local w = (jd + 1) % 7
  return (w + 6) % 7 -- 0=周一
end

local function monthGridInfo(y, m)
  local firstDow = weekday1Monday(y, m, 1)
  local nextY, nextM = y, m + 1
  if nextM > 12 then nextM = 1; nextY = y + 1 end
  local daysInMonth = lunar.toJulianDay(nextY, nextM, 1) - lunar.toJulianDay(y, m, 1)
  return firstDow, daysInMonth
end

local function nextMonth(y, m)
  if m == 12 then return y + 1, 1 else return y, m + 1 end
end
local function prevMonth(y, m)
  if m == 1 then return y - 1, 12 else return y, m - 1 end
end
-- 前后一天（从儒略日编号算）
local function addDays(y, m, d, n)
  return lunar.fromJulianDay(lunar.toJulianDay(y, m, d) + n)
end

function init()
  todayY = tonumber(noctalia.formatTime("%Y", nil, "") or "0")
  todayM = tonumber(noctalia.formatTime("%m", nil, "") or "0")
  todayD = tonumber(noctalia.formatTime("%d", nil, "") or "0")
  if view.y == 0 then
    view.y, view.m, view.d = todayY, todayM, todayD
  end
end

-- 点击某格 -> 跳到详情
local function openDetail(y, m, d)
  view.mode = "detail"
  view.y, view.m, view.d = y, m, d
  render()
end
local function backToMonth()
  view.mode = "month"
  render()
end
local function stepDay(n)
  view.y, view.m, view.d = addDays(view.y, view.m, view.d, n)
  render()
end

-- ============ 月历视图 ============

local function dayCell(y, m, d, isCurrentMonth)
  local l = lunar.fromSolar(y, m, d)
  local isToday = (y == todayY and m == todayM and d == todayD)
  local isWeekend = (weekday1Monday(y, m, d) >= 5)
  local htype, hname = lunar.getHoliday(y, m, d)

  local sub = l.dayStr
  if l.day == 1 then
    sub = l.monthStr
  end

  local mainColor = "on_surface"
  if isToday then
    mainColor = "primary"
  elseif not isCurrentMonth then
    mainColor = "on_surface_variant"
  elseif hname then
    mainColor = "error"
  elseif isWeekend then
    mainColor = "secondary"
  end

  local subText = hname or sub
  local subColor = "on_surface_variant"
  if hname then
    subColor = "error"
  elseif l.day == 1 then
    subColor = "secondary"
  end

  local onClick = function() openDetail(y, m, d) end
  local inner
  if isToday then
    inner = ui.column({ fill = "primary/0.18", radius = 6, padding = 2, align = "center", onClick = onClick }, {
      ui.label({ text = tostring(d), color = mainColor, fontWeight = "bold", fontSize = 13 }),
      ui.label({ text = subText, color = subColor, fontSize = 9 }),
    })
  else
    inner = ui.column({ padding = 2, align = "center", onClick = onClick }, {
      ui.label({ text = tostring(d), color = mainColor, fontWeight = "bold", fontSize = 13 }),
      ui.label({ text = subText, color = subColor, fontSize = 9 }),
    })
  end
  return inner
end

local function renderMonth()
  local y, m = view.y, view.m
  local titleText = string.format("%d年%d月", y, m)
  local firstDow, daysInMonth = monthGridInfo(y, m)

  local rows = {}
  local weekHeader = {
    ui.label({ text = "一", color = "on_surface_variant", fontSize = 11 }),
    ui.label({ text = "二", color = "on_surface_variant", fontSize = 11 }),
    ui.label({ text = "三", color = "on_surface_variant", fontSize = 11 }),
    ui.label({ text = "四", color = "on_surface_variant", fontSize = 11 }),
    ui.label({ text = "五", color = "on_surface_variant", fontSize = 11 }),
    ui.label({ text = "六", color = "secondary", fontSize = 11 }),
    ui.label({ text = "日", color = "secondary", fontSize = 11 }),
  }
  table.insert(rows, ui.row({ gap = 2 }, weekHeader))

  local cellY, cellM, cellD = y, m, 1
  local prefix = firstDow
  if prefix > 0 then
    cellY, cellM, cellD = lunar.fromJulianDay(lunar.toJulianDay(y, m, 1) - prefix)
  end

  local cells = {}
  for i = 1, 42 do
    local isCurrent = (cellY == y and cellM == m)
    if cellD > 0 and isCurrent then
      table.insert(cells, dayCell(cellY, cellM, cellD, true))
    else
      table.insert(cells, ui.box({ height = 24 }))
    end
    cellY, cellM, cellD = lunar.fromJulianDay(lunar.toJulianDay(cellY, cellM, cellD) + 1)
  end

  for row = 0, 5 do
    local week = {}
    for col = 1, 7 do
      table.insert(week, cells[row * 7 + col])
    end
    table.insert(rows, ui.row({ gap = 6 }, week))
  end

  local lNow = lunar.fromSolar(todayY, todayM, todayD)

  panel.render(ui.column({ gap = 8, padding = 10 }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.button({ glyph = "chevron-left", variant = "ghost", onClick = function()
        view.y, view.m = prevMonth(view.y, view.m)
        render()
      end }),
      ui.spacer(),
      ui.label({ text = titleText, fontWeight = "bold", fontSize = 16, expand = true }),
      ui.spacer(),
      ui.button({ glyph = "chevron-right", variant = "ghost", onClick = function()
        view.y, view.m = nextMonth(view.y, view.m)
        render()
      end }),
    }),
    ui.label({
      text = string.format("今日：%d-%02d-%02d  %s", todayY, todayM, todayD, lNow.monthStr .. lNow.dayStr),
      color = "secondary",
      fontSize = 11,
    }),
    rows[1],
    (function()
      local grid = {}
      for i = 2, #rows do
        table.insert(grid, rows[i])
      end
      return ui.column({ gap = 4 }, grid)
    end)(),
    -- 提示
    ui.label({ text = "点击任意日期查看单日黄历", color = "on_surface_variant", fontSize = 9, textAlign = "center" }),
  }))
end

-- ============ 单日详情视图 ============

local function renderDetail()
  local d = calendar.dayInfo(view.y, view.m, view.d)
  local titleText = string.format("%d年%d月%d日  %s", view.y, view.m, view.d, d.weekCn)

  panel.render(ui.column({ gap = 8, padding = 10 }, {
    -- 顶栏：返回 + 标题 + 前后天
    ui.row({ align = "center", gap = 6 }, {
      ui.button({ glyph = "arrow-left", variant = "ghost", tooltip = "返回月历", onClick = backToMonth }),
      ui.spacer(),
      ui.label({ text = titleText, fontWeight = "bold", fontSize = 14, maxLines = 1, flexGrow = 1 }),
      ui.spacer(),
      ui.button({ glyph = "chevron-left", variant = "ghost", onClick = function() stepDay(-1) end }),
      ui.button({ glyph = "chevron-right", variant = "ghost", onClick = function() stepDay(1) end }),
    }),
    -- 详情主体
    ui.column({ gap = 8 }, detail.view(d)),
  }))
end

-- ============ 渲染入口 ============

function render()
  init()
  if view.mode == "detail" then
    renderDetail()
  else
    renderMonth()
  end
end

function onOpen()
  init()
  render()
end

function update()
  noctalia.setUpdateInterval(60000)
  local ny = tonumber(noctalia.formatTime("%Y", nil, "") or "0")
  local nm = tonumber(noctalia.formatTime("%m", nil, "") or "0")
  local nd = tonumber(noctalia.formatTime("%d", nil, "") or "0")
  if ny ~= todayY or nm ~= todayM or nd ~= todayD then
    init()
    render()
  end
end

init()
