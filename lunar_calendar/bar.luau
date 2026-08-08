local lunar = (function()
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

end)()

--!nonstrict
local i18n = (function()
-- i18n.luau — 农历插件「中英文切换」共享模块
-- 读取 plugin.toml 的 ui_lang 设置（auto/zh/en），提供术语翻译与结构文案。
-- 供 bar.luau、panel.luau 共同 require 使用。
--
-- 设计：黄历术语（干支/生肖/节气/月相/建除/值神/冲煞/宜忌/黄黑道）大多为文化专名，
--       中文保留原文，英文用通用译法（生肖/节气/月相等），干支采用罗马拼音。
-- 依赖：noctalia.getConfig / noctalia.getenv

local M = {}

---------------------------------------------------------------------
-- 语言判定
---------------------------------------------------------------------

-- 判定当前 ui_lang：返回 "zh" 或 "en"
function M.lang()
  local v = noctalia.getConfig("ui_lang")
  if v == "zh" or v == "en" then
    return v
  end
  -- auto：跟随系统（LC_ALL / LC_MESSAGES / LANG）
  for _, name in ipairs({ "LC_ALL", "LC_MESSAGES", "LANG" }) do
    local raw = (noctalia.getenv and noctalia.getenv(name)) or ""
    if raw ~= "" then
      local low = string.lower(raw)
      if low:find("zh") then return "zh" end
      return "en"
    end
  end
  return "en"
end

local function isEn()
  return M.lang() == "en"
end

---------------------------------------------------------------------
-- 结构文案：T[zh] = en
---------------------------------------------------------------------
local STRUCT = {
  ["节气"] = "Solar Term",  ["月相"] = "Moon Phase", ["建除"] = "Jian-Chu",
  ["值神"] = "Guardian Deity", ["日"] = "Day", ["月"] = "Month", ["年"] = "Year",
  ["宜"] = "Auspicious", ["忌"] = "Inauspicious", ["冲"] = "Clash", ["煞"] = "Sha",
  ["闰"] = "leap", ["今日"] = "Today", ["回到今日"] = "Back to Today",
  ["上一月"] = "Prev month", ["上一年"] = "Prev year", ["下一月"] = "Next month",
  ["下一年"] = "Next year", ["返回月历"] = "Back to calendar",
  ["节日"] = "Holiday", ["农历"] = "Lunar", ["阳历"] = "Solar", ["日期"] = "Date",
  ["点击任意日期查看单日黄历"] = "Click any date for daily almanac",
}

-- 结构文案单条翻译（译回中文）
function M.struct(zh)
  if not isEn() then return zh end
  return STRUCT[zh] or zh
end

---------------------------------------------------------------------
-- 干支（天干/地支）—— 英文用罗马拼音
---------------------------------------------------------------------
local GAN_EN = {
  ["甲"]="Jia", ["乙"]="Yi", ["丙"]="Bing", ["丁"]="Ding", ["戊"]="Wu",
  ["己"]="Ji", ["庚"]="Geng", ["辛"]="Xin", ["壬"]="Ren", ["癸"]="Gui",
}
local ZHI_EN = {
  ["子"]="Zi", ["丑"]="Chou", ["寅"]="Yin", ["卯"]="Mao", ["辰"]="Chen", ["巳"]="Si",
  ["午"]="Wu", ["未"]="Wei", ["申"]="Shen", ["酉"]="You", ["戌"]="Xu", ["亥"]="Hai",
}

-- 按 UTF-8 判定单个字符的字节数（兼容中英文）。注意：#s 是字节数不是字符数，
-- 直接 string.sub(s,i,i) 会切碎多字节中文，必须用本函数逐字符推进。
local function utf8CharLen(b)
  if b == nil then return 1 end
  if b < 0x80 then return 1 end
  if b < 0xE0 then return 2 end
  if b < 0xF0 then return 3 end
  return 4
end
-- 将一个干支串（如"甲子"）翻译。按"字符"而非"字节"遍历，避免多字节中文被切碎成乱码（??）。
function M.romanizeGanzhi(s)
  if not isEn() then return s end
  local parts = {}
  local i, n = 1, #s
  while i <= n do
    local clen = utf8CharLen(s:byte(i))
    local ch = string.sub(s, i, i + clen - 1)
    parts[#parts + 1] = GAN_EN[ch] or ZHI_EN[ch] or ch
    i = i + clen
  end
  return table.concat(parts)
end

local ANIMALS_EN = {
  ["鼠"]="Rat", ["牛"]="Ox", ["虎"]="Tiger", ["兔"]="Rabbit", ["龙"]="Dragon",
  ["蛇"]="Snake", ["马"]="Horse", ["羊"]="Goat", ["猴"]="Monkey", ["鸡"]="Rooster",
  ["狗"]="Dog", ["猪"]="Pig",
}

function M.animal(zh)
  if not isEn() then return zh end
  return ANIMALS_EN[zh] or zh
end

---------------------------------------------------------------------
-- 值神（黄黑道十二神）
---------------------------------------------------------------------
local TIAN_SHEN_EN = {
  ["青龙"]="Azure Dragon", ["明堂"]="Brilliant Hall", ["天刑"]="Heavenly Punishment",
  ["朱雀"]="Vermilion Bird", ["金匮"]="Golden Casket", ["天德"]="Heavenly Virtue",
  ["白虎"]="White Tiger", ["玉堂"]="Jade Hall", ["天牢"]="Heavenly Prison",
  ["玄武"]="Black Tortoise", ["司命"]="Determining Fate", ["勾陈"]="Gou Chen",
}

function M.tianShen(zh)
  if not isEn() then return zh end
  return TIAN_SHEN_EN[zh] or zh
end

local WAY_EN = { ["黄道"]="Auspicious Way", ["黑道"]="Inauspicious Way" }
local LUCK_EN = { ["吉"]="Auspicious", ["凶"]="Inauspicious" }

function M.way(zh)  if not isEn() then return zh end return WAY_EN[zh] or zh end
function M.luck(zh) if not isEn() then return zh end return LUCK_EN[zh] or zh end

---------------------------------------------------------------------
-- 月相
---------------------------------------------------------------------
-- 因月相同名出现多次（如"渐盈凸"），用数组映射同一套译名
local yueXiangPairs = {
  {"朔","New Moon"}, {"既朔","New Moon (1st)"}, {"蛾眉新","Early Crescent"},
  {"蛾眉","Waxing Crescent"}, {"蛾眉夕","Evening Crescent"}, {"上弦月","First Quarter"},
  {"上弦","First Quarter"}, {"渐盈凸","Waxing Gibbous"}, {"宵","Waxing Gibbous"},
  {"盈凸","Waxing Gibbous"}, {"望","Full Moon"}, {"既望","Full Moon (1st)"},
  {"立待","Waxing Gibbous"}, {"居待","Waxing Gibbous"}, {"寝待","Waxing Gibbous"},
  {"更待","Waxing Gibbous"}, {"渐亏凸","Waning Gibbous"}, {"下弦","Last Quarter"},
  {"有明","Waning Crescent"}, {"蛾眉残","Waning Crescent"}, {"残","Waning Crescent"},
  {"晦","Dark Moon"},
}
local YUE_XIANG_EN = {}
for _, p in ipairs(yueXiangPairs) do
  if not YUE_XIANG_EN[p[1]] then YUE_XIANG_EN[p[1]] = p[2] end
end

function M.yueXiang(zh)
  if not isEn() then return zh end
  return YUE_XIANG_EN[zh] or zh
end

---------------------------------------------------------------------
-- 建除十二神
---------------------------------------------------------------------
local JIAN_CHU_EN = {
  ["建"]="Establish", ["除"]="Remove", ["满"]="Fill", ["平"]="Level", ["定"]="Settle",
  ["执"]="Hold", ["破"]="Break", ["危"]="Danger", ["成"]="Succeed", ["收"]="Receive",
  ["开"]="Open", ["闭"]="Close",
}

function M.jianChu(zh)
  if not isEn() then return zh end
  return JIAN_CHU_EN[zh] or zh
end

---------------------------------------------------------------------
-- 节气（完整 24 节气；不足时回退原文）
---------------------------------------------------------------------
local JIEQI_EN = {
  ["立春"]="Start of Spring", ["雨水"]="Rain Water", ["惊蛰"]="Awakening of Insects",
  ["春分"]="Spring Equinox", ["清明"]="Qingming", ["谷雨"]="Grain Rain",
  ["立夏"]="Start of Summer", ["小满"]="Grain Full", ["芒种"]="Grain in Ear",
  ["夏至"]="Summer Solstice", ["小暑"]="Minor Heat", ["大暑"]="Major Heat",
  ["立秋"]="Start of Autumn", ["处暑"]="End of Heat", ["白露"]="White Dew",
  ["秋分"]="Autumn Equinox", ["寒露"]="Cold Dew", ["霜降"]="Frost Descent",
  ["立冬"]="Start of Winter", ["小雪"]="Minor Snow", ["大雪"]="Major Snow",
  ["冬至"]="Winter Solstice", ["小寒"]="Minor Cold", ["大寒"]="Major Cold",
}

function M.jieQi(zh)
  if not isEn() then return zh end
  return JIEQI_EN[zh] or zh
end

---------------------------------------------------------------------
-- 宜忌活动（涵盖 YI_FOR_TYPE / JI_FOR_TYPE / JIAN_CHU_YI / JIAN_CHU_JI 全部条目）
---------------------------------------------------------------------
local ACTIVITY_EN = {
  -- 婚嫁喜庆
  ["嫁娶"]="Wedding", ["订婚"]="Engagement", ["领证"]="Getting Married",
  ["约会"]="Dating", ["求嗣"]="Praying for Offspring", ["求财"]="Seeking Wealth",
  ["纳采"]="Accepting Betrothal Gifts", ["结婚"]="Getting Married",
  -- 家居建造
  ["入宅"]="Moving In", ["搬迁"]="Moving", ["修造"]="Renovating", ["动土"]="Breaking Ground",
  ["上梁"]="Laying the Main Beam", ["安床"]="Placing the Bed", ["安灶"]="Installing Stove",
  ["开市"]="Opening Business", ["开业"]="Grand Opening", ["筑堤"]="Building a Dike",
  ["破屋"]="Dismantling a House", ["坏垣"]="Repairing Walls",
  -- 出行祭祀
  ["出行"]="Traveling", ["会友"]="Meeting Friends", ["祭祀"]="Worshipping",
  ["开光"]="Consecrating", ["祈福"]="Praying for Blessings", ["斋醮"]="Taoist Ritual",
  ["安葬"]="Burying", ["行丧"]="Holding a Funeral",
  -- 日常工作
  ["签约"]="Signing a Contract", ["交易"]="Trading", ["纳财"]="Acquiring Wealth",
  ["入殓"]="Encoffining", ["收帐"]="Collecting Debts", ["上任"]="Taking Office",
  -- 其他
  ["理发"]="Haircut", ["沐浴"]="Bathing", ["扫舍"]="House Cleaning", ["栽种"]="Planting",
  ["放水"]="Draining Water", ["捕捉"]="Hunting", ["开仓"]="Opening the Granary",
}

function M.activity(zh)
  if not isEn() then return zh end
  return ACTIVITY_EN[zh] or zh
end

-- 宜/忌列表整体翻译
function M.activityList(items)
  if not isEn() then return items end
  if not items then return items end
  local out = {}
  for _, v in ipairs(items) do
    table.insert(out, ACTIVITY_EN[v] or v)
  end
  return out
end

---------------------------------------------------------------------
-- 节日
---------------------------------------------------------------------
local HOLIDAY_EN = {
  -- 农历
  ["春节"]="Spring Festival", ["元宵节"]="Lantern Festival", ["龙抬头"]="Dragon Head Festival",
  ["端午节"]="Dragon Boat Festival", ["七夕"]="Qixi Festival", ["中元节"]="Ghost Festival",
  ["中秋节"]="Mid-Autumn Festival", ["重阳节"]="Double Ninth Festival",
  ["腊八节"]="Laba Festival", ["小年"]="Little New Year", ["除夕"]="Chinese New Year's Eve",
  -- 阳历
  ["元旦"]="New Year's Day", ["情人节"]="Valentine's Day", ["妇女节"]="Women's Day",
  ["植树节"]="Arbor Day", ["愚人节"]="April Fools' Day", ["劳动节"]="Labour Day",
  ["青年节"]="Youth Day", ["儿童节"]="Children's Day", ["建党节"]="Party Day",
  ["建军节"]="Army Day", ["教师节"]="Teachers' Day", ["国庆节"]="National Day",
  ["圣诞节"]="Christmas",
}

function M.holiday(zh)
  if not isEn() then return zh end
  return HOLIDAY_EN[zh] or zh
end

---------------------------------------------------------------------
-- 星期
---------------------------------------------------------------------
local WEEK_EN = {
  ["星期一"]="Mon", ["星期二"]="Tue", ["星期三"]="Wed", ["星期四"]="Thu",
  ["星期五"]="Fri", ["星期六"]="Sat", ["星期日"]="Sun",
}

function M.weekday(zh)
  if not isEn() then return zh end
  return WEEK_EN[zh] or zh
end

---------------------------------------------------------------------
-- 月份（农历月，如"六月"）与农历日（如"初八"）
-- 英文模式直接给数字/序数形式
---------------------------------------------------------------------
-- 中文数字 -> 阿拉伯数字
local CH_NUM = { ["一"]="1", ["二"]="2", ["三"]="3", ["四"]="4", ["五"]="5",
                 ["六"]="6", ["七"]="7", ["八"]="8", ["九"]="9", ["十"]="10" }
local MONTH_NUM = { ["正"]="1", ["二"]="2", ["三"]="3", ["四"]="4", ["五"]="5",
                    ["六"]="6", ["七"]="7", ["八"]="8", ["九"]="9", ["十"]="10",
                    ["冬"]="11", ["腊"]="12" }

-- 农历日（英文数字）：初八->8 / 十一->11 / 廿六->26 / 三十->30 / 二十->20
-- 按"字符"而非"字节"处理：中文 UTF-8 一字 3 字节，原 #dayStr/sub() 会切碎导致英文残留中文。
function M.lunarDay(dayStr)
  if not isEn() then return dayStr end
  if not dayStr or #dayStr == 0 then return dayStr end
  -- 逐字节推进取第一个字符
  local headLen = utf8CharLen(dayStr:byte(1))
  local head = string.sub(dayStr, 1, headLen)
  local restHead = string.sub(dayStr, headLen + 1) -- 其余字节段（可能为空或剩余一个汉字）
  -- 剩余部分第一个字符（用于取第二位的数字）
  local n2 = ""
  if #restHead > 0 then
    local rl = utf8CharLen(restHead:byte(1))
    n2 = CH_NUM[string.sub(restHead, 1, rl)] or ""
  end
  if head == "初" then
    return n2 == "" and dayStr or n2
  elseif head == "十" then
    -- 十日(整个只有"十") = 10；十一/十二等 = 1X
    if #restHead == 0 then return "10" end
    return "1" .. n2
  elseif head == "廿" then
    return "2" .. n2
  elseif head == "二" then
    return "20"
  elseif head == "三" then
    return "30"
  end
  return CH_NUM[head] or dayStr
end

-- 农历月（英文：6th lunar month；闰月加 leap）
function M.lunarMonth(monthStr, isLeap)
  if not isEn() then return monthStr .. (isLeap and "（闰）" or "") end
  if not monthStr then return monthStr end
  local zh = string.gsub(monthStr, "闰", "")
  local num = MONTH_NUM[zh]
  local pre = (isLeap and "Leap " or "")
  if num then
    return pre .. num .. "th lunar month"
  end
  return monthStr
end

-- 列表分隔符：中文用顿号，英文用逗号+空格
function M.sepList()
  if isEn() then return ", " end
  return "、"
end

-- 月份标题："2026年6月" / "2026.06"
function M.monthTitle(y, m)
  if isEn() then return string.format("%04d.%02d", y, m) end
  return string.format("%d年%d月", y, m)
end

-- 星期表头：中文"一二三四五六日"，英文"M T W T F S S"
function M.weekHeader()
  if isEn() then return { "M", "T", "W", "T", "F", "S", "S" } end
  return { "一", "二", "三", "四", "五", "六", "日" }
end

-- 月历格子副文字：可能是农历日("初八")或农历月("六月")
-- 英文模式统一转成数字；中文原样
function M.lunarSub(s)
  if not isEn() then return s end
  if not s then return s end
  -- 若是月份（如"六月"/"闰六月"）
  local numM = MONTH_NUM[string.gsub(s, "闰", "")]
  if numM then return numM end
  -- 否则当农历日转换
  return M.lunarDay(s)
end

-- 详情页"丙午年 六月廿六"式的年干支+农历年月日组合串
-- 输入如 "丙午年 六月廿六"，拆成 干支年 + 月 + 日 分别翻译
function M.dayNian(s)
  if not isEn() then return s end
  if not s then return s end
  -- 形如 "甲子年 六月廿六"
  local yearPart, rest = string.match(s, "^(.-年)%s*(.*)$")
  if not yearPart then return s end
  local ganzhi = string.sub(yearPart, 1, -2) -- 去掉"年"
  local zhMonth, zhDay = string.match(rest, "^(.-)(%S+)$")
  if not zhMonth then return s end
  local romanized = M.romanizeGanzhi(ganzhi) .. " Year"
  local mth = M.lunarMonth(zhMonth, false)
  local day = M.lunarDay(zhDay)
  return romanized .. ", " .. mth .. " " .. day
end

---------------------------------------------------------------------
-- 方向（煞方）东南北西
---------------------------------------------------------------------
local DIR_EN = { ["南"]="South", ["东"]="East", ["北"]="North", ["西"]="West" }
function M.dir(zh)
  if not isEn() then return zh end
  return DIR_EN[zh] or zh
end

  return M
end)()
-- bar.luau — 状态栏农历 widget
-- 显示今天的农历日期（格式可配置），点击打开月历面板。

local PANEL_ID = "coldneight/lunar_calendar:panel"

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

-- 把混合中西文的文本按字符集拆段（方案A），每段内部是统一字符集，
-- 这样每个 label 内只有一种字体的基线，避免中西文混排时的高低差。
-- 段间空格归入前一段，保证换段处不留多余空位（label 间用容器 gap 补距离）。
local function utf8CharLen(b)
  if b == nil then return 1 end
  if b < 0x80 then return 1 end
  if b < 0xE0 then return 2 end
  if b < 0xF0 then return 3 end
  return 4
end
local function splitByCharset(s)
  local segs = {}
  local curCjk = nil
  local start = 1
  local i = 1
  local n = #s
  while i <= n do
    local b = s:byte(i)
    local clen = utf8CharLen(b)
    local isCjk = b >= 0x80
    if b == 0x20 then
      -- 空格：归属当前段（若当前段存在），否则归入后续首个段
      if curCjk == nil then
        curCjk = false
      end
      i = i + clen
    else
      if curCjk == nil then
        curCjk = isCjk
      elseif isCjk ~= curCjk then
        table.insert(segs, s:sub(start, i - 1))
        curCjk = isCjk
        start = i
      end
      i = i + clen
    end
  end
  if curCjk ~= nil and start <= n then
    table.insert(segs, s:sub(start, n))
  end
  return segs
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
  -- 中英文自适应（读取 ui_lang 设置）
  local dayTxt = i18n.lunarDay(l.dayStr)
  local monthTxt = i18n.lunarMonth(l.monthStr, l.isLeap and true or false)
  local ganZhiTxt = i18n.romanizeGanzhi(l.yearGanZhi)
  local shengXiaoTxt = i18n.animal(l.shengXiao)

  local text = ""
  if fmt == "lunar_day" then
    text = monthTxt .. " " .. dayTxt
  elseif fmt == "solar_lunar" then
    text = string.format("%04d-%02d-%02d %s%s", today.y, today.m, today.d, monthTxt, dayTxt)
  elseif fmt == "lunar_full" then
    text = today.y .. " " .. ganZhiTxt .. " " .. shengXiaoTxt .. i18n.struct("年") .. " " .. monthTxt .. " " .. dayTxt
  end

  -- 方案A：把混合中西文的文本按字符集拆成多个 label，避免单 label 内中西文基线高低差。
  if text ~= "" and not barWidget.isVertical() then
    for _, seg in ipairs(splitByCharset(text)) do
      table.insert(children, ui.label({ text = seg, fontWeight = "bold" }))
    end
  end

  -- tooltip
  local tooltipLines = {
    string.format("%04d-%02d-%02d", today.y, today.m, today.d),
    ganZhiTxt .. " " .. shengXiaoTxt .. i18n.struct("年") .. " " .. monthTxt .. " " .. dayTxt,
  }
  if todayHoliday then
    table.insert(tooltipLines, i18n.struct("节日") .. ": " .. i18n.holiday(todayHoliday))
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
