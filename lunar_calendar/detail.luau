--!nonstrict
-- detail.luau — 单日台历详情视图（纯展示）
-- 输入 calendar.dayInfo 的 info 表，输出页面上层的 ui 内容数组。
-- 布局：大字"初八" + 公历/农历/干支标题 + 节气/月相色块 + 冲煞/值神/建除 + 宜忌。

-- 节气给一个柔和背景色，让当日节气一眼可见
local JIEQI_BG = {
  ["立春"]= "primary/0.18", ["雨水"]= "primary/0.13", ["惊蛰"]= "primary/0.18", ["春分"]= "primary/0.13",
  ["清明"]= "secondary/0.18", ["谷雨"]= "secondary/0.13", ["立夏"]= "secondary/0.18", ["小满"]= "secondary/0.13",
  ["芒种"]= "tertiary/0.18", ["夏至"]= "tertiary/0.13", ["小暑"]= "tertiary/0.18", ["大暑"]= "tertiary/0.13",
  ["立秋"]= "primary/0.22", ["处暑"]= "primary/0.12", ["白露"]= "primary/0.18", ["秋分"]= "primary/0.12",
  ["寒露"]= "secondary/0.18", ["霜降"]= "secondary/0.12", ["立冬"]= "secondary/0.18", ["小雪"]= "secondary/0.12",
  ["大雪"]= "tertiary/0.18", ["冬至"]= "tertiary/0.12", ["小寒"]= "tertiary/0.18", ["大寒"]= "tertiary/0.12",
}

-- 胶囊标签：用 column 包 fill+padding+radius，内嵌 label
local function chip(text, color, fill)
  return ui.column({ padding = 4, radius = 6, fill = fill or "surface_variant/0.2" }, {
    ui.label({ text = text, fontSize = 11, color = color or "on_surface", maxLines = 1, textAlign = "center" }),
  })
end

-- 自适应胶囊：flexGrow 均分列宽，label maxLines=0 允许英文长文本在列内换行
local function chipCol(text, color, fill)
  return ui.column({ padding = 4, radius = 6, fill = fill or "surface_variant/0.2", flexGrow = 1 }, {
    ui.label({ text = text, fontSize = 11, color = color or "on_surface", maxLines = 0, textAlign = "center" }),
  })
end

local M = {}

-- 返回详情内容数组（panel 负责外层容器 + 导航行）
function M.view(d)
  local header = ui.row({ gap = 4, align = "center", justify = "space_between" }, {
    chip(d.solar .. "  " .. d.weekCn),
    chip(d.labelType),
  })

  -- 大区: 农历日大字 + 农历月
  local bigBlock = ui.row({ gap = 14, align = "center" }, {
    ui.label({
      text = d.lunarStr or "",
      fontSize = 46,
      fontWeight = "bold",
      color = "on_surface",
      flexGrow = 1,
      maxLines = 1,
    }),
    ui.column({ gap = 4, align = "end" }, {
      ui.label({
        text = d.monthStr .. (d.isLeap and "（闰）" or ""),
        fontSize = 20,
        fontWeight = "bold",
        color = "primary",
        maxLines = 1,
      }),
      ui.label({ text = d.dayNian, fontSize = 12, color = "on_surface_variant", maxLines = 1 }),
    }),
  })

  -- 节气 / 月相 条
  local bannerCells = {}
  if d.jieQi and d.jieQi ~= "" then
    table.insert(bannerCells, chip("节气 · " .. d.jieQi, "on_surface", JIEQI_BG[d.jieQi] or "error/0.2"))
  end
  if d.yueXiang and d.yueXiang ~= "" then
    table.insert(bannerCells, chip("月相 · " .. d.yueXiang))
  end
  local banner
  if #bannerCells > 0 then
    banner = ui.row({ gap = 6, align = "center" }, bannerCells)
  else
    banner = ui.spacer()
  end

  -- 信息网格：建除 / 值神 / 冲煞 / 干支（用 chipCol 均分列宽，英文长文本自动换行）
  local infoRows = ui.column({ gap = 4 }, {
    ui.row({ gap = 4, align = "center" }, {
      chipCol("建除 · " .. d.jianChu),
      chipCol("值神 · " .. d.tianShen),
      chipCol("冲" .. d.chong .. " 煞" .. d.sha),
    }),
    ui.row({ gap = 4, align = "center" }, {
      chipCol("日 · " .. d.dayGanZhi),
      chipCol("月 · " .. d.monthGanZhi),
      chipCol("年 · " .. d.yearGanZhi .. d.yearAnimal),
    }),
  })

  -- 宜 / 忌：把数组拼接成多行文本
  local function wrapLines(title, items, color)
    local ret = { ui.label({ text = title, fontSize = 12, fontWeight = "bold", color = color, maxLines = 1 }) }
    if not items or #items == 0 then
      table.insert(ret, ui.label({ text = "—", fontSize = 12, color = "on_surface_variant", maxLines = 1 }))
      return ui.column({ gap = 4 }, ret)
    end
    local line = {}
    for i, v in ipairs(items) do
      table.insert(line, v)
      -- 每 4 个一组换行
      if #line == 4 or i == #items then
        table.insert(ret, ui.label({ text = table.concat(line, "、"), fontSize = 11, color = color, maxLines = 0 }))
        line = {}
      end
    end
    return ui.column({ gap = 4 }, ret)
  end

  local yiBlock = ui.column({ gap = 8, padding = 10, radius = 10, fill = "primary/0.08", flexGrow = 1 }, {
    wrapLines("宜", d.yi, "primary"),
  })
  local jiBlock = ui.column({ gap = 8, padding = 10, radius = 10, fill = "error/0.08", flexGrow = 1 }, {
    wrapLines("忌", d.ji, "error"),
  })

  local yiJi = ui.row({ gap = 10, align = "center" }, { yiBlock, jiBlock })

  return {
    header,
    bigBlock,
    banner,
    infoRows,
    yiJi,
  }
end

return M
