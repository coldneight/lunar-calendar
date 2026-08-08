--!nonstrict
-- service.luau — 后台服务：每分钟推送今天的农历信息到共享状态。

local lunar = require("lunar")

function update()
  noctalia.setUpdateInterval(60000)
  publish()
end

function publish()
  local y = tonumber(noctalia.formatTime("%Y", nil, "") or "")
  local m = tonumber(noctalia.formatTime("%m", nil, "") or "")
  local d = tonumber(noctalia.formatTime("%d", nil, "") or "")
  if not (y and m and d) then return end

  local l = lunar.fromSolar(y, m, d)
  local htype, hname = lunar.getHoliday(y, m, d)

  noctalia.state.set("lunar.todayYmd", { y = y, m = m, d = d })
  noctalia.state.set("lunar.todayFull", {
    solar = string.format("%d年%d月%d日", y, m, d),
    lunar = l.monthStr .. l.dayStr,
    ganzhi = l.yearGanZhi .. l.shengXiao .. "年",
    holiday = (htype and hname) or nil,
    lunarYear = l.year,
    lunarMonth = l.month,
    lunarDay = l.day,
    isLeap = l.isLeap,
    leapMonth = l.leapMonth,
  })
end

function onIpc(event, _payload)
  if event == "refresh" then
    publish()
  end
end

publish()
