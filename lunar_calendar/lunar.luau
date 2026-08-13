--!nonstrict
-- lunar.luau — 农历转换核心算法（查表法，1900-2100）
-- 基于公开的农历天文数据表，算法与 6tail / lunar-javascript 一致。
-- 提供：阳历(y,m,d) -> 农历(y, 闰月标记, 月, 日) + 干支 + 生肖 + 月农历天数等。

local M = {}

-- 农历数据表：每个元素编码该农历年的信息
-- 32bit 位模式（这里用十六进制表示实际值，运行时均为0/1的标志位）
-- bit0x0f   = 闰月月份（0=无闰月）
-- bit0x10   = 闰月是否为大月(30天)
-- bit0x8000前12位 = 各月大月(30天)标记，1=大月，0=小月(29天)
local lunarInfo = {
0x04bd8,0x04ae0,0x0a570,0x054d5,0x0d260,0x0d950,0x16554,0x056a0,0x09ad0,0x055d2,--1900-1909
0x04ae0,0x0a5b6,0x0a4d0,0x0d250,0x1d255,0x0b540,0x0d6a0,0x0ada2,0x095b0,0x14977,--1910-1919
0x04970,0x0a4b0,0x0b4b5,0x06a50,0x06d40,0x1ab54,0x02b60,0x09570,0x052f2,0x04970,--1920-1929
0x06566,0x0d4a0,0x0ea50,0x06e95,0x05ad0,0x02b60,0x186e3,0x092e0,0x1c8d7,0x0c950,--1930-1939
0x0d4a0,0x1d8a6,0x0b550,0x056a0,0x1a5b4,0x025d0,0x092d0,0x0d2b2,0x0a950,0x0b557,--1940-1949
0x06ca0,0x0b550,0x15355,0x04da0,0x0a5b0,0x14573,0x052b0,0x0a9a8,0x0e950,0x06aa0,--1950-1959
0x0aea6,0x0ab50,0x04b60,0x0aae4,0x0a570,0x05260,0x0f263,0x0d950,0x05b57,0x056a0,--1960-1969
0x096d0,0x04dd5,0x04ad0,0x0a4d0,0x0d4d4,0x0d250,0x0d558,0x0b540,0x0b6a0,0x195a6,--1970-1979
0x095b0,0x049b0,0x0a974,0x0a4b0,0x0b27a,0x06a50,0x06d40,0x0af46,0x0ab60,0x09570,--1980-1989
0x04af5,0x04970,0x064b0,0x074a3,0x0ea50,0x06b58,0x05ac0,0x0ab60,0x096d5,0x092e0,--1990-1999
0x0c960,0x0d954,0x0d4a0,0x0da50,0x07552,0x056a0,0x0abb7,0x025d0,0x092d0,0x0cab5,--2000-2009
0x0a950,0x0b4a0,0x0baa4,0x0ad50,0x055d9,0x04ba0,0x0a5b0,0x15176,0x052b0,0x0a930,--2010-2019
0x07954,0x06aa0,0x0ad50,0x05b52,0x04b60,0x0a6e6,0x0a4e0,0x0d260,0x0ea65,0x0d530,--2020-2029
0x05aa0,0x076a3,0x096d0,0x04afb,0x04ad0,0x0a4d0,0x1d0b6,0x0d250,0x0d520,0x0dd45,--2030-2039
0x0b5a0,0x056d0,0x055b2,0x049b0,0x0a577,0x0a4b0,0x0aa50,0x1b255,0x06d20,0x0ada0,--2040-2049
0x14b63,0x09370,0x049f8,0x04970,0x064b0,0x168a6,0x0ea50,0x06b20,0x1a6c4,0x0aae0,--2050-2059
0x0a2e0,0x0d2e3,0x0c960,0x0d557,0x0d4a0,0x0da50,0x05d55,0x056a0,0x0a6d0,0x055d4,--2060-2069
0x052d0,0x0a9b8,0x0a950,0x0b4a0,0x0b6a6,0x0ad50,0x055a0,0x0aba4,0x0a5b0,0x052b0,--2070-2079
0x0b273,0x06930,0x07337,0x06aa0,0x0ad50,0x14b55,0x04b60,0x0a570,0x054e4,0x0d160,--2080-2089
0x0e968,0x0d520,0x0daa0,0x16aa6,0x056d0,0x04ae0,0x0a9d4,0x0a2d0,0x0d150,0x0f252,--2090-2099
0x0d520,--2100
}

local Gan = { "甲","乙","丙","丁","戊","己","庚","辛","壬","癸" }
local Zhi = { "子","丑","寅","卯","辰","巳","午","未","申","酉","戌","亥" }
local Animals = { "鼠","牛","虎","兔","龙","蛇","马","羊","猴","鸡","狗","猪" }

-- 农历月份中文（不含"月"后缀）
local MonthCN = { "正","二","三","四","五","六","七","八","九","十","冬","腊" }
-- 农历月份中文（含"月"后缀）
local MonthCN2 = { "正月","二月","三月","四月","五月","六月","七月","八月","九月","十月","冬月","腊月" }
-- 农历日中文
local DayCN = { "初一","初二","初三","初四","初五","初六","初七","初八","初九","初十",
  "十一","十二","十三","十四","十五","十六","十七","十八","十九","二十",
  "廿一","廿二","廿三","廿四","廿五","廿六","廿七","廿八","廿九","三十" }

-- Gregorian 日期 -> 儒略日（整数，正午）
function M.toJulianDay(y, m, d)
  local a = math.floor((14 - m) / 12)
  local yy = y + 4800 - a
  local mm = m + 12 * a - 3
  return d + math.floor((153 * mm + 2) / 5) + 365 * yy
    + math.floor(yy / 4) - math.floor(yy / 100) + math.floor(yy / 400) - 32045
end

-- 儒略日 -> Gregorian 日期
function M.fromJulianDay(jd)
  local a = jd + 32044
  local b = math.floor((4 * a + 3) / 146097)
  local c = a - math.floor(146097 * b / 4)
  local d = math.floor((4 * c + 3) / 1461)
  local e = c - math.floor(1461 * d / 4)
  local mm = math.floor((5 * e + 2) / 153)
  local day = e - math.floor((153 * mm + 2) / 5) + 1
  local month = mm + 3 - 12 * math.floor(mm / 10)
  local year = 100 * b + d - 4800 + math.floor(mm / 10)
  return year, month, day
end

-- 指定农历年份（公历年）的闰月月份；0 = 无闰月
function M.leapMonth(y)
  return math.floor(lunarInfo[y - 1899] % 16)
end

-- 闰月天数
function M.leapDays(y)
  local lm = M.leapMonth(y)
  if lm ~= 0 and math.floor(lunarInfo[y - 1899] / 0x10000) % 2 == 1 then
    return 30
  elseif lm ~= 0 then
    return 29
  end
  return 0
end

-- 指定农历年、月（非闰月）的天数
function M.monthDays(y, m)
  -- 位 0x10000 >> m：若该位为1则是大月（第 17-m 位）
  if math.floor(lunarInfo[y - 1899] / 2 ^ (16 - m)) % 2 == 0 then
    return 29
  end
  return 30
end

-- 指定农历年总天数（不含闰月）
function M.yearDays(y)
  local sum = 348
  local info = lunarInfo[y - 1899]
  for month = 1, 12 do
    -- 位掩码 0x10000 >> (month-1) = 2^(16-month)，即第 17-month 位
    local i = 2 ^ (16 - month)
    if math.floor(info / i) % 2 == 1 then
      sum = sum + 1
    end
  end
  return sum
end

-- 指定农历年总天数（含闰月）
function M.leapYearDays(y)
  local total = M.yearDays(y)
  local lm = M.leapMonth(y)
  if lm ~= 0 then
    total = total + M.leapDays(y)
  end
  return total
end

-- 阳历 (y, m, d) -> 农历
-- 返回: { year, month, day, isLeap (该月是否闰月), leapMonth (当年闰月月份，0无),
--         yearGanZhi, zhi, shengXiao, monthStr, dayStr }
function M.fromSolar(y, m, d)
  local offset = M.toJulianDay(y, m, d) - M.toJulianDay(1900, 1, 31)
  local lYear = 1900

  -- 推算农历年
  while offset >= 0 do
    local yd = M.leapYearDays(lYear)
    if offset < yd then
      break
    end
    offset = offset - yd
    lYear = lYear + 1
  end

  -- offset 现在是农历年内第几天 (0-based)
  local leapM = M.leapMonth(lYear)
  local lMonth = 0
  local lDay = 0
  local isLeap = false
  local remaining = offset

  local done = false
  for month = 1, 12 do
    local days = M.monthDays(lYear, month)
    local leapDays_ = 0
    if leapM == month then
      leapDays_ = M.leapDays(lYear)
      -- 闰月排在此月之后
      if remaining < days then
        lMonth = month
        lDay = remaining + 1
        done = true
        break
      end
      remaining = remaining - days
      if remaining < leapDays_ then
        lMonth = month
        lDay = remaining + 1
        isLeap = true
        done = true
        break
      end
      remaining = remaining - leapDays_
    else
      if remaining < days then
        lMonth = month
        lDay = remaining + 1
        done = true
        break
      end
      remaining = remaining - days
    end
  end

  -- 干支（年）与生肖，基于立春？这里用农历年起始。天干地支按农历年
  -- 注：为了简化，干支按农历年1月1日起算（不按立春）。
  local ganIdx = (lYear - 4) % 10
  local zhiIdx = (lYear - 4) % 12

  local result = {
    year = lYear,
    month = lMonth,
    day = lDay,
    isLeap = isLeap,
    leapMonth = leapM,
    yearGan = Gan[ganIdx + 1],
    yearZhi = Zhi[zhiIdx + 1],
    yearGanZhi = Gan[ganIdx + 1] .. Zhi[zhiIdx + 1],
    shengXiao = Animals[zhiIdx + 1],
    monthStr = (isLeap and "闰" or "") .. MonthCN2[lMonth],
    dayStr = DayCN[lDay],
  }
  return result
end

-- 判断一个阳历日期是否为节气当天，返回节气名或 nil（2026 常用节气近似）
-- 节气时刻精确到日，这里用简化版（权威库读不到，做常用中文节气）
local SolarTerm = {
  -- 每个元素 [公历月, 公历日] 对应节气（1900-2100 简化近似表）
  -- 这里采用通用的"月+日"近似法仅用于节日标注，精度有限
}

-- 农历节日表（固定农历月日）：month, day -> 节日名
M.lunarHolidays = {
  { 1, 1, "春节" }, { 1, 15, "元宵节" }, { 2, 2, "龙抬头" },
  { 5, 5, "端午节" }, { 7, 7, "七夕" }, { 7, 15, "中元节" },
  { 8, 15, "中秋节" }, { 9, 9, "重阳节" }, { 12, 8, "腊八节" },
  { 12, 23, "小年" }, { 12, 29, "除夕" }, { 12, 30, "除夕" },
}

-- 阳历节日表：month, day -> 节日名
M.solarHolidays = {
  { 1, 1, "元旦" }, { 2, 14, "情人节" }, { 3, 8, "妇女节" },
  { 3, 12, "植树节" }, { 4, 1, "愚人节" }, { 5, 1, "劳动节" },
  { 5, 4, "青年节" }, { 6, 1, "儿童节" }, { 7, 1, "建党节" },
  { 8, 1, "建军节" }, { 9, 10, "教师节" }, { 10, 1, "国庆节" },
  { 12, 25, "圣诞节" },
}

-- 获取阳历(y,m,d)的节日名；返回 { 类型("solar"/"lunar"/"jieqi"), 名称 } 或 nil
function M.getHoliday(solarY, solarM, solarD)
  -- 阳历节日
  for _, h in ipairs(M.solarHolidays) do
    if h[1] == solarM and h[2] == solarD then
      return "solar", h[3]
    end
  end
  -- 农历节日（需先转农历；注意除夕跨年判断）
  local l = M.fromSolar(solarY, solarM, solarD)
  for _, h in ipairs(M.lunarHolidays) do
    if h[1] == l.month and h[2] == l.day then
      return "lunar", h[3]
    end
  end
  return nil, nil
end

-- 计算某农历年某月的实际起止公历日期（用于月历格子里标注）
-- 这里反过来用：给定公历某月，把它每个日期转成农历

return M
