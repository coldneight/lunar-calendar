--!nonstrict
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
