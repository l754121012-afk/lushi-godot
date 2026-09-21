# 炉石旅人 · Godot 版

从单文件 Web 版（`../lushi-like/index.html`）迁移到 Godot 4.7.2，为后续更全面、更优质的内容做准备。
Web 版继续作为**数值/机制基准**与对照，Godot 版是**后续主开发线**。

## 当前进度

| 阶段 | 内容 | 状态 |
|---|---|---|
| P0 | 数据管线 + 卡池浏览器 + 无头自检 | ✅ 已完成 |
| P1 | 战斗结算内核（纯逻辑、可无头跑、可单测） | ⬜ 下一步 |
| P2 | 备战流程（商店/手牌/布阵/拖拽 + 经济 + AI 运营） | ⬜ |
| P3 | 表现层（动画/特效/音效/中文排版） | ⬜ |
| P4 | 内容扩展（新种族、新机制、战役/多人） | ⬜ |

### P0 已交付

- `data/*.json`：从 Web 版导出的 93 张卡、10 个种族、宣言池、经济配置、星级概率、AI 模板、法术池
- `autoload/game_data.gd`：统一数据入口（按种族/星级/关键字查询）
- `scripts/main.gd` + `scenes/main.tscn`：卡池与配置浏览器（左侧列表 + 右侧详情，可筛选/搜索）
- `tools/selftest.gd`：数据自检（数量、种族、星级、经济、进化随从名单校验）
- 系统中文字体（SystemFont）接入，避免 CJK 显示成方块

## 运行

```powershell
# 编辑器（推荐日常开发）
F:\Godot\4.7.2\godot.cmd --path C:\Users\李泽文\Documents\Codex\2026-07-26\xian\lushi-godot -e

# 直接跑卡池浏览器
F:\Godot\4.7.2\godot.cmd --path C:\Users\李泽文\Documents\Codex\2026-07-26\xian\lushi-godot

# 无头自检（数据完整性）
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path <项目路径> --script res://tools/selftest.gd

# 无头跑一遍主场景（校验脚本与自动加载）
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path <项目路径> --quit-after 120 -- --selftest

# 截图模式（渲染后存 user://godot_card_browser.png 并退出）
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --path <项目路径> -- --shot
```

## 数据来源与更新

卡牌与配置**不在 Godot 里手改**，统一从 Web 版导出，保证两边一致：

```powershell
cd C:\Users\李泽文\Documents\Codex\2026-07-26\xian\lushi-like
# 需要 localhost:8080 正在服务 index.html
node ..\_diag_sac\extract_for_godot.cjs
```

导出内容：

| 文件 | 内容 |
|---|---|
| `data/cards.json` | 7 个星级 × 93 张卡（原始字段全保留） |
| `data/races.json` | 10 个种族 id / 名称 / 图标 |
| `data/config.json` | 升级花费、每回合基础金币、连胜连败利息、AI 分阶段补给、槽位与初始资源 |
| `data/star_odds.json` | 酒馆等级 → 各星级出现权重 |
| `data/quests.json` | 进化双相宣言池（昼/夜各 3 条） |
| `data/keywords.json` | 关键词图标/名称 |
| `data/ai_templates.json` | AI 阵容模板与法术池 |

## 目录结构

```
lushi-godot/
  project.godot          # 主场景 / 自动加载 / 分辨率
  autoload/game_data.gd  # 数据入口
  scripts/main.gd        # 卡池浏览器（P0 工具，后续会并入正式 UI）
  scripts/ui_theme.gd    # 深色主题 + 中文字体
  scenes/main.tscn
  tools/selftest.gd      # 数据自检
  data/*.json            # 导出数据（不要手改）
  docs/                  # 截图与文档
```

## 迁移原则

1. **逻辑与表现分离**：战斗结算先写成纯逻辑类（不依赖节点），可无头跑、可单测；动画只订阅结算产生的“事件序列”
2. **数据驱动**：卡牌/技能/宣言/经济全部来自 JSON，新内容尽量只加数据不改代码
3. **以 Web 版为基准**：每次机制改动先在 Web 版验证手感，再同步到 Godot；数值曲线用同一套模拟脚本对照（R11 主C 100-150、R16 300-400）
4. **中文优先**：默认字体走系统 CJK，文案与卡面字段保持中文
