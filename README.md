# Lunar Calendar —— noctalia 农历日历插件

为 [noctalia](https://noctalia.dev) 桌面环境提供农历日历：状态栏显示今日农历，点击弹出完整月历，点任意日期可查看**单日黄历详情**。

> 🌀 **Vibe Coding**：本项目由 [DeepSeek](https://deepseek.com) 协同 vibe-coding 完成——从农历算法移植、noctalia 插件适配，到调试与发布，全程 AI 结对协作。欢迎借鉴或一起完善。

![noctalia](https://img.shields.io/badge/noctalia-plugin-3b82f6)
![license](https://img.shields.io/badge/license-MIT-green)
![vibe-coding](https://img.shields.io/badge/vibe--coding-by%20deepseek-8b5cf6)

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

仓库遵循 noctalia 的「源」规范：根目录 `catalog.toml` 为插件索引，插件源码位于同名子目录。

```
lunar-calendar/          # 源仓库根
├── catalog.toml         # 插件索引（[[plugin]]，noctalia 据此发现插件）
└── lunar_calendar/      # 插件子目录（对应 id coldneight/lunar_calendar）
    ├── plugin.toml      # 插件清单（ID、widget、panel、service 注册）
    ├── bar.luau         # 状态栏 widget（已内联依赖，require 清零）
    ├── panel.luau       # 月历 + 单日详情双视图面板（已内联依赖）
    ├── service.luau     # 后台服务（已内联依赖）
    ├── calendar.luau    # 黄历引擎源码（农历/干支/值神/冲煞/宜忌）
    ├── lunar.luau       # 农历日期核心源码（公农历转换）
    ├── jieqi_data.luau  # 24 节气数据表源码
    ├── detail.luau      # 单日黄历详情渲染源码
    └── translations/    # 翻译
```

> **关于 `require`**：当前 noctalia（`plugin_api` 支持范围 3–20）不支持跨文件 `require()` 模块加载，因此 `bar/panel/service` 三个入口文件已把核心逻辑**物理内联合并**（`require` 清零）。`calendar/lunar/jieqi_data/detail.luau` 为各算法模块的独立源码，便于阅读与维护；如日后 noctalia 提升 `plugin_api` 支持 `require`，可改回标准模块引用方式。

## 🔬 算法正确性

引擎核心已用权威 Python 库 [`lunar_python`](https://pypi.org/project/lunar_python/) 交叉验证，覆盖跨年、闰月、节气转换等 16 个边界日期，全部一致（详见 `_test_engine.lua`，开发期脚本，不随仓库发布）。

## 🧩 项目总结

本项目是一个**功能完整、开箱即用的农历黄历插件**，历经多轮 `vibe-coding` 迭代打磨，当前稳定版位于 `1.0.x`。已有能力沉淀为可复用的经验：

- **算法可靠性**：公农历转换、干支纪年、24 节气、月相、建除十二神、值神、冲煞、宜忌等核心逻辑，已用权威库交叉验证，边界正确。
- **noctalia 适配**：因 `plugin_api`（范围 3–20）不支持跨文件 `require()`，入口文件采用**物理内联合并**，`require` 清零，保证插件在受支持范围内可直接运行。
- **i18n 双语文案**：内置中 / 英两套文案，覆盖界面结构词、干支拼音、农历月日数字、节气、月相、建除、值神、宜忌等，并通过 `ui_lang` 跟随系统或手动指定。

**开发过程中沉淀的关键经验**（尤其针对 UTF-8 多字节中文、noctalia 渲染特性）：

- 处理多字节中文时，**绝不能按字节偏移做 `sub`/`find` 切割**——例如用 `string.sub(s, 1, -2)` 剥离末尾“年”字，会因三字节编码残留字节碎片，渲染层会把它 fallback 成 `??` 乱码。应使用**字符感知**的写法（`string.gsub(s, "年$", "")`、`utf8CharLen` + `string.sub` 逐字符推进）。
- noctalia 高度依赖相邻 `label` 的 `textAlign` 与列分配：英文长文本默认不换行会**穿出面板边界**，须配合 `ui.scroll` 容器 + `maxLines`/`flexGrow` 灵活布局；`textAlign` 需显式声明（如 `end` 右对齐）。
- 干支等文化专名的英文表达，采用**罗马拼音 + 紧凑后缀**（如 `BingWu-year`），既保留文化含义，又避免长文本占用过多空间。状态栏若追求精简，可进一步缩略。

## 🌐 英文排版与后续调整

**当前状态**：英文模式下已消除多字节中文导致的 `?`/`?` 乱码，主要干支 / 农历月日 / 节气 / 宜忌等均已正确翻译与排布。

**仍待打磨的英文排版项**（如需美观完善，可作为后续调整方向）：

- **长文本换行策略**：部分英文黄历长文本（值神 / 宜忌等）在窄列中可能仍显拥挤，可进一步统一 `maxLines` 与换行规则，或对超长短语做缩略。
- **序数后缀标准化**：当前农历月使用 `1th / 11th / 12th`，建议优化为标准序数 `1st / 11th / 12th`，提升英文观感。
- **状态栏精简**：`bar_format = "lunar_full"` 时信息较多，英文下更长，可考虑提供更紧凑的参考格式或省略干支。
- **字体回退**：英文模式下若中文字体未加载，缺失字形会显示 `?`，建议文档说明或提供 `ui_lang` 与字体的配套建议。

如你对上述任一项有调整意向，欢迎提 issue 或直接参与完善（`vibe-coding` 亦可）。

## 📄 License

[MIT](LICENSE)
