# Lunar Calendar —— noctalia 农历日历插件

为 [noctalia](https://noctalia.dev) 桌面环境提供农历日历：状态栏显示今日农历，点击弹出完整月历，点任意日期可查看**单日黄历详情**。

![noctalia](https://img.shields.io/badge/noctalia-plugin-3b82f6)
![license](https://img.shields.io/badge/license-MIT-green)

## ✨ 功能

- **状态栏 widget**：显示今日农历（`六月初八` 等），格式可配置
- **完整月历面板**：周一起始的月度网格，农历日 + 节日 + 节气标注，今天高亮
- **单日黄历详情**：点击任一日期，展示该日完整黄历：
  - 农历日大字（初八 / 十五 / 三十…）
  - 农历月（含闰月标记）、干支纪年（含生肖）
  - 节气色块标注（当日是节气时醒目显示）
  - 月相（朔 / 上弦 / 望 / 下弦…）
  - 建除十二神、值神（黄道 / 黑道 / 吉凶）
  - 冲 X 煞 Y、日 / 月 / 年干支
  - **宜 / 忌** 双列表
  - ◀ 前一天 / ▶ 后一天 便捷切换

## 📦 安装

### 本地开发直挂

1. 将插件目录复制/链接到 noctalia 的插件目录，例如：
   ```
   ~/.local/state/noctalia/plugins/materialized/community/lunar_calendar/
   ```
2. 在 `settings.toml` 的 `[plugins] enabled` 中加入插件 ID：
   ```toml
   [plugins]
   enabled = [ "coldneight/lunar_calendar" ]
   ```
3. 热重载：
   ```
   noctalia msg config-reload
   ```

### 通过 Git 源安装（GitHub）

```bash
# 添加源
noctalia msg plugins source add lunar git https://github.com/coldneight/lunar-calendar.git
# 启用插件
noctalia msg plugins enable coldneight/lunar_calendar
```

## ⚙️ 配置（widget）

| 键 | 类型 | 默认 | 说明 |
|----|------|------|------|
| `bar_format` | select | `lunar_day` | 状态栏显示格式：仅农历日 / 阳历+农历 / 带干支生肖完整 |
| `show_glyph` | bool | `true` | 是否显示日历 icon |

## 📁 文件结构

```
lunar_calendar/
├── plugin.toml      # 插件清单（ID、widget、panel、service 注册）
├── bar.luau         # 状态栏 widget
├── panel.luau       # 月历 + 单日详情双视图面板
├── detail.luau      # 单日黄历详情渲染
├── calendar.luau    # 黄历引擎（农历/干支/值神/冲煞/宜忌）
├── lunar.luau       # 农历日期核心（公农历转换）
├── jieqi_data.luau  # 24 节气数据表
├── service.luau     # 后台服务（推送今日实时农历）
└── translations/    # 翻译
```

## 🔬 算法正确性

引擎核心已用权威 Python 库 [`lunar_python`](https://pypi.org/project/lunar_python/) 交叉验证，覆盖跨年、闰月、节气转换等 16 个边界日期，全部一致（详见 `_test_engine.lua`，开发期脚本，不随仓库发布）。

## 📄 License

[MIT](LICENSE)
