--!nonstrict
-- calendar.luau — 黄历引擎（纯离线算法）
-- 农历带范围 1900-2100（lunar 模块），节气表 1901-2100（jieqi_data）。
-- 提供单日完整"台历"信息：干支、生肖、节气、月相、冲煞、值神、黄黑道、宜忌（权威黄历数据）。
--
-- 主要接口：
--   M.init()             —— 必须先调用，加载节气表
--   M.dayInfo(y, m, d)   —— 返回单日完整黄历信息（见 dayInfo 注释）
--   M.jieQiOf(y, m, d)   —— 返回当日节气名或 nil

local M = {}

local lunar = require("./lunar.luau")
local JIE  = require("./jieqi_data.luau") -- JIE[year-1900] = 12 x {月,日}：立春,惊蛰,清明,立夏,芒种,小暑,立秋,白露,寒露,立冬,大雪,小寒
local yiji = require("./yiji_data.luau") -- 宜忌数据（自 6tail/lunar-javascript 导入）

-- 节气名（与 JIE 顺序对应）
local JIE_NAMES = { "立春","惊蛰","清明","立夏","芒种","小暑","立秋","白露","寒露","立冬","大雪","小寒" }

-- ============ 基础表 ============
local Gan  = { "甲","乙","丙","丁","戊","己","庚","辛","壬","癸" }
local Zhi  = { "子","丑","寅","卯","辰","巳","午","未","申","酉","戌","亥" }
local Animals = { "鼠","牛","虎","兔","龙","蛇","马","羊","猴","鸡","狗","猪" }
local ZHI_IDX = { ["子"]=0,["丑"]=1,["寅"]=2,["卯"]=3,["辰"]=4,["巳"]=5,["午"]=6,["未"]=7,["申"]=8,["酉"]=9,["戌"]=10,["亥"]=11 }

-- 建除十二神（月建循环）
local JIAN_CHU = { "建","除","满","平","定","执","破","危","成","收","开","闭" }

-- 值神（黄黑道十二神）
local TIAN_SHEN = { "青龙","明堂","天刑","朱雀","金匮","天德","白虎","玉堂","天牢","玄武","司命","勾陈" }
-- 值神 -> 黄道/黑道 与 吉凶
local TS_TYPE = {
  ["青龙"]="黄道", ["明堂"]="黄道", ["金匮"]="黄道", ["天德"]="黄道", ["玉堂"]="黄道", ["司命"]="黄道",
  ["天刑"]="黑道", ["朱雀"]="黑道", ["白虎"]="黑道", ["天牢"]="黑道", ["玄武"]="黑道", ["勾陈"]="黑道",
}
local TS_LUCK = {
  ["青龙"]="吉", ["明堂"]="吉", ["金匮"]="吉", ["天德"]="吉", ["玉堂"]="吉", ["司命"]="吉",
  ["天刑"]="凶", ["朱雀"]="凶", ["白虎"]="凶", ["天牢"]="凶", ["玄武"]="凶", ["勾陈"]="凶",
}

-- 值神 offset：月支 -> 青龙起始偏移（值神序号 = (月支offset + 日支idx) % 12）
-- 权威 cross-check (lunar_python) 反推，2026 全年12月支采样逐月一致、且对仗对称：
--   寅=0 卯=10 辰=8 巳=6 午=4 未=2 申=0 酉=10 戌=8 亥=6 子=4 丑=2
local TS_OFFSET = {
  ["子"]=4,["丑"]=2,["寅"]=0,["卯"]=10,["辰"]=8,["巳"]=6,
  ["午"]=4,["未"]=2,["申"]=0,["酉"]=10,["戌"]=8,["亥"]=6,
}

-- 日支 -> 冲（对冲地支）所冲生肖、煞方
local function chongShengXiao(dayZhi)
  local opp = (ZHI_IDX[dayZhi] + 6) % 12
  return Animals[opp + 1]
end
-- 日支 -> 煞方
local SHA = { ["子"]="南",["丑"]="东",["寅"]="北",["卯"]="西",["辰"]="南",["巳"]="东",["午"]="北",["未"]="西",["申"]="南",["酉"]="东",["戌"]="北",["亥"]="西" }

-- 月相（农历日索引 1..30；表格为传统月相名，与农历日对应）
local YUE_XIANG = {
  "朔","既朔","蛾眉新","蛾眉","蛾眉夕","上弦月","渐盈凸","上弦","渐盈凸","宵",
  "宵","渐盈凸","盈凸","望","望","既望","立待","居待","寝待","更待",
  "渐亏凸","渐亏凸","下弦","下弦","有明","有明","蛾眉残","蛾眉残","残","晦","晦",
}

-- ============ 宜忌（权威黄历数据，自 6tail/lunar-javascript 导入） ============
local YI_JI = yiji.YI_JI

-- 六十甲子 -> 0..59 索引（转 hex 后用于查表）
local JIA_ZI_IDX = {}
for i, gz in ipairs(yiji.JIA_ZI) do
  JIA_ZI_IDX[gz] = i - 1
end

-- 预解析 DAY_YI_JI 压缩串 -> dayHex -> { {months=..., yi=..., ji=...}, ... }
local DAY_MAP = {}
do
  local s = yiji.DAY_YI_JI
  local n = #s
  local pos = 1
  while true do
    local eq = s:find("=", pos, true)
    if not eq then break end
    local day = s:sub(eq - 2, eq - 1)
    local nextEq = s:find("=", eq + 1, true)
    local payloadEnd = nextEq and (nextEq - 3) or n
    local payload = s:sub(eq + 1, payloadEnd)
    local colon = payload:find(":", 1, true)
    local comma = payload:find(",", colon + 1, true)
    local months = payload:sub(1, colon - 1)
    local yiHex = payload:sub(colon + 1, comma - 1)
    local jiHex = payload:sub(comma + 1)
    local list = DAY_MAP[day]
    if not list then list = {}; DAY_MAP[day] = list end
    list[#list + 1] = { months = months, yi = yiHex, ji = jiHex }
    if not nextEq then break end
    pos = nextEq - 2
  end
end

local function hex2(n)
  return string.format("%02X", n)
end

-- 把 hex 串（每 2 字符一个索引）解码成活动名列表
local function decodeYijiList(hex)
  local out = {}
  local i = 1
  while i <= #hex do
    out[#out + 1] = YI_JI[tonumber(hex:sub(i, i + 1), 16) + 1]
    i = i + 2
  end
  return out
end

-- 宜/忌查找：给定月柱、日柱干支（如 "丙申"、"己未"），返回宜列表、忌列表
local function dayYiJi(monthGZ, dayGZ)
  local day = hex2(JIA_ZI_IDX[dayGZ])
  local month = hex2(JIA_ZI_IDX[monthGZ])
  local yi, ji
  local list = DAY_MAP[day]
  if list then
    for _, e in ipairs(list) do
      local i = 1
      local matched = false
      while i <= #e.months do
        if e.months:sub(i, i + 1) == month then matched = true; break end
        i = i + 2
      end
      if matched then
        yi = decodeYijiList(e.yi)
        ji = decodeYijiList(e.ji)
        break
      end
    end
  end
  if not yi or #yi == 0 then yi = { "无" } end
  if not ji or #ji == 0 then ji = { "无" } end
  return yi, ji
end

-- 干支纪年偏移（农历年）
local function yearGanZhi(lYear)
  local gi = (lYear - 4) % 10
  local zi = (lYear - 4) % 12
  return Gan[gi + 1], Zhi[zi + 1], Animals[zi + 1]
end

-- 日本干支（儒略日公式，已验证）：stem=(jd+9)%10, branch=(jd+1)%12
local function dayGanZhi(jdNum)
  local g = Gan[(jdNum + 9) % 10 + 1]
  local z = Zhi[(jdNum + 1) % 12 + 1]
  return g, z
end

-- 节气月支（用 jieqi 判断某公历日位于哪个节月），用于建除
-- 农历月支：立春->寅, 惊蛰->卯, 清明->辰, 立夏->巳, 芒种->午, 小暑->未,
--           立秋->申, 白露->酉, 寒露->戌, 立冬->亥, 大雪->子, 小寒->丑
local JIE_ZHI = { "寅","卯","辰","巳","午","未","申","酉","戌","亥","子","丑" }

-- ============ 对外功能 ============

-- 返回公历(y,m,d)当日节气名（"节"），无则 nil
local jieqiCache = {}
function M.jieQiOf(y, m, d)
  local key = y * 10000 + m * 100 + d
  if jieqiCache[key] then
    return jieqiCache[key]
  end
  local row = JIE[y - 1900]
  local result = nil
  if row then
    for i, pair in ipairs(row) do
      if pair[1] == m and pair[2] == d then
        result = JIE_NAMES[i]
        break
      end
    end
  end
  jieqiCache[key] = result
  return result
end

-- 根据日期算出所在节月地支索引(0..11)，用于建除
-- 规则：找一个 <= 该日 的最近节（立春~小寒），对应地支。若在一月且未到小寒则为前一年的丑(小寒前)。
local function monthZhiIndex(y, m, d)
  local jdNum = lunar.toJulianDay(y, m, d)
  -- 从该日往回找节（最多回 60 天），找到即其地支
  for back = 0, 62 do
    local yy, mm, dd = lunar.fromJulianDay(jdNum - back)
    local jq = M.jieQiOf(yy, mm, dd)
    if jq then
      for i, name in ipairs(JIE_NAMES) do
        if name == jq then
          return JIE_ZHI[i]
        end
      end
    end
  end
  -- 兜底：按公历月近似（1-2月寅春前…）——极少用到
  local fallback = { "丑","寅","卯","辰","巳","午","未","申","酉","戌","亥","子" }
  return fallback[m]
end

-- 农历月干支（节月），用年干 + 五虎遁 求月干
-- 月支 mzIdx 对应 寅=2 起，正月的天干由年干决定：
--   甲己之年丙作首、乙庚之岁戊为头、丙辛必定寻庚起、丁壬壬位顺行流、戊癸甲寅好追求
--   即 月干 idx = (年干idx*2 + 2 + 月支序) % 10；且年干按立春切换（干支年），非农历年。
local function monthGanZhiFor(y, m, d, mzIdx)
  -- 干支年天干（立春切换）：已过(含)立春用公历年，否则用公历年-1
  local effYear = y
  local lchun = JIE[y - 1900] and JIE[y - 1900][1]
  if lchun and not ((m > lchun[1]) or (m == lchun[1] and d >= lchun[2])) then
    effYear = y - 1
  end
  local ygIdx = (effYear - 4) % 10
  -- 五虎遁：寅月起。月支在寅=2..丑=11 序列中的序号 = (mzIdx - 2 + 12) % 12 (寅=0)
  local pos = (mzIdx - 2 + 12) % 12 -- 寅=0,卯=1,...丑=11
  -- 月干 idx = (ygIdx * 2 + 2 + pos) % 10
  local mgIdx = (ygIdx * 2 + 2 + pos) % 10
  return Gan[mgIdx + 1] .. Zhi[mzIdx + 1]
end

-- 星期中文
local WEEK = { "星期一","星期二","星期三","星期四","星期五","星期六","星期日" }
local function weekdayCn(y, m, d)
  local w = (lunar.toJulianDay(y, m, d) + 1) % 7 -- 0=周日
  return WEEK[w + 1]
end

-- 单日完整黄历信息
-- 返回字段见 doc 注释
local dayCache = {}
function M.dayInfo(y, m, d)
  local key = y * 10000 + m * 100 + d
  if dayCache[key] then
    return dayCache[key]
  end
  local jdNum = lunar.toJulianDay(y, m, d)
  local l = lunar.fromSolar(y, m, d) -- {year,month,day,isLeap,monthStr,dayStr,yearGanZhi,shengXiao}
  local dayG, dayZ = dayGanZhi(jdNum)
  local mzIndexName = monthZhiIndex(y, m, d) -- 返回地支名
  local mzIdx = ZHI_IDX[mzIndexName]

  -- 建除十二神：月支 -> "建"位置；日支递增。建 = (月支idx 对应) + 日支差
  -- 传统：正月建寅，即月支即"建"。十二神序号 = (日支idx - 月支idx) mod 12
  local dZhiIdx = ZHI_IDX[dayZ]
  local jianChuIdx = (dZhiIdx - mzIdx + 12) % 12
  local jianChuName = JIAN_CHU[jianChuIdx + 1]

  -- 值神：序号 = (月支offset + 日支idx) mod 12
  local tsIdx = (TS_OFFSET[mzIndexName] + dZhiIdx) % 12
  local tsName = TIAN_SHEN[tsIdx + 1]

  -- 节气
  local jq = M.jieQiOf(y, m, d)
  -- 月相
  local lDay = l.day
  local yueXiang = YUE_XIANG[lDay] or YUE_XIANG[#YUE_XIANG]
  -- 冲煞
  local chong = chongShengXiao(dayZ)
  local sha = SHA[dayZ]

  -- 干支年（农历年，**立春切换**）
  -- 黄历"太岁"年干支按立春切换：公历日已过(含)当年立春 -> 用公历年对应干支；立春前 -> 公历年-1
  -- 而农历 l.year 要到正月初一才切到公历年，二者在"立春~正月初一"窗口内不同，故须按立春现判。
  local effYear = l.year
  local lchun = JIE[y - 1900] and JIE[y - 1900][1] -- 立春 {月,日}
  if lchun and ((m > lchun[1]) or (m == lchun[1] and d >= lchun[2])) then
    effYear = y -- 已过立春，黄历干支年 = 公历年
  else
    effYear = y - 1 -- 立春前，干支年为公历年-1
  end
  local yg, yz, animal = yearGanZhi(effYear)

  -- 节气月干支：月支 + 由年干推月干（五虎遁年上起月，简化用节气月支）
  local monthGanZhiS = monthGanZhiFor(y, m, d, mzIdx)

  -- 值神黄黑道 / 吉凶
  local tsType = TS_TYPE[tsName]
  local tsLuck = TS_LUCK[tsName]

  -- 宜/忌：权威黄历数据（按 月柱+日柱 查表，与 lunar_python/6tail 一致）
  local yi, ji = dayYiJi(monthGanZhiS, dayG .. dayZ)

  local info = {
    -- 基础
    solar    = string.format("%04d.%02d.%02d", y, m, d),
    weekCn   = weekdayCn(y, m, d),
    -- 农历
    lunarY   = l.year,
    lunarM   = l.month,
    lunarD   = l.day,
    isLeap   = l.isLeap,
    lunarStr = l.dayStr,             -- "初八"
    monthStr = l.monthStr,           -- "六月"/"闰六月"
    -- 干支
    yearGanZhi  = yg .. yz,          -- "丙午"
    yearAnimal  = animal,            -- "马"
    dayGanZhi   = dayG .. dayZ,      -- "甲寅"
    dayNian     = string.format("%s%s年 %s%s", yg, yz, l.monthStr, l.dayStr),
    -- 月支（节月地支）
    monthZhi    = mzIndexName,
    monthGanZhi = monthGanZhiS,      -- "甲申"
    -- 择吉
    jianChu     = jianChuName,       -- "建"/"除"...
    tianShen    = tsName,            -- "青龙"
    tianShenType= tsType,            -- "黄道"/"黑道"
    tianShenLuck= tsLuck,            -- "吉"/"凶"
    chong       = chong,             -- "虎"
    sha         = sha,               -- "南"
    yueXiang    = yueXiang,          -- "望"
    jieQi       = jq,                -- "立秋" or nil
    yi          = yi,                -- 宜列表
    ji          = ji,                -- 忌列表
    -- 简化的"冲X煞Y" / "黄黑道吉凶" 组合串
    labelChong  = "冲" .. chong .. " 煞" .. sha,
    labelType   = tsName .. "(" .. tsType .. tsLuck .. ")",
  }
  dayCache[key] = info
  return info
end

-- 星期中文
local WEEK = { "星期一","星期二","星期三","星期四","星期五","星期六","星期日" }
-- 农历日数字中文（大写的"初八"）
-- lunar.fromSolar 已给 dayStr，这里补充一个简化纯数字版用于大字展示
local DayNum = { "一","二","三","四","五","六","七","八","九","十",
  "十一","十二","十三","十四","十五","十六","十七","十八","十九","二十",
  "廿一","廿二","廿三","廿四","廿五","廿六","廿七","廿八","廿九","三十" }

-- 生成某农历月的起始公历日（用于月历标注该月首日），可选
function M.monthStartPivot()

end

return M
