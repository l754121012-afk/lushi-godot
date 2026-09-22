# SESSION-HANDOFF · 炉石旅人（Web → Godot 迁移）

> 给下一个会话（尤其是**能看图的会话**）的冷启动文档。先读这份，再决定动手。

## 0. 一句话现状

Web 版是**数值与手感基准**，Godot 版是**主开发线**。机制层（10 种族战斗 + 经济/商店/三连/磁力/合体/AI/整局循环）已全部迁移并通过 10 组自检 + 15 项双端 parity；
**当前瓶颈是视觉还原**——布局与配色已按原版 CSS 做坐标级对齐，但"像不像"需要会看图的人来判断。

## 1. 两个仓库

| 仓库 | 路径 | 角色 | 最近提交 |
|---|---|---|---|
| Web 原版 | `C:\Users\李泽文\Documents\Codex\2026-07-26\xian\lushi-like` | 数值/手感基准，单人单文件 `index.html`（约 1.7MB） | `c0e3a1f` 无头开关（方向 B） |
| Godot 版 | `C:\Users\李泽文\Documents\Codex\2026-07-26\xian\lushi-godot` | 主开发线 | 见 `git log` |

辅助材料：`C:\Users\李泽文\Documents\Codex\2026-07-26\xian\_diag_sac\`（Playwright 诊断脚本、导出脚本、对照脚本）

## 2. 环境

- Godot：`F:\Godot\4.7.2\godot.cmd`（编辑器）、`Godot_v4.7.2-stable_win64_console.exe`（无头自检）
- Web 服务：`node server.js`（在 lushi-like 目录），端口 **8080**；重启命令见第 6 节
- 中文字体：Godot 用 `SystemFont`（Microsoft YaHei UI 等）否则雅黑缺失会出方块
- 注意：Godot **把警告当错误**，`:=` 从 Variant 推断类型会直接编译失败，凡 `min()/max()/字典取值` 赋值都要显式写类型

## 3. 常用命令

```powershell
cd C:\Users\李泽文\Documents\Codex\2026-07-26\xian\lushi-godot
$exe = 'F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'

# 打开游戏（主场景 = 备战界面 scenes/prep.tscn）
F:\Godot\4.7.2\godot.cmd --path .

# 10 组自检（每次改完都跑）
foreach($t in @('selftest','battle_test','fusion_test','prep_test','economy_test','shop_test','gild_test','prep_state_test','ai_test','session_test')){
  "{0,-16} {1}" -f $t, (& $exe --headless --path . --script "res://tools/$t.gd" 2>&1 | Select-Object -Last 1)
}

# 界面布局核对（打印各区块坐标 + 顺序/不重叠断言）
& $exe --headless --path . --resolution 1440x900 res://scenes/prep.tscn -- --selftest

# 截图（输出 user://prep_view.png）
& $exe --path . --resolution 1440x900 res://scenes/prep.tscn -- --shot
# → 拷到项目里：Copy-Item "$env:APPDATA\Godot\app_userdata\炉石旅人\prep_view.png" docs\prep_view.png -Force

# 双端一致性对照（先起 Web 服务）
node tools\parity_web.cjs
& $exe --headless --path . --script res://tools/parity_run.gd
node tools\parity_compare.cjs

# 原版 vs Godot 并排对照图（★ 视觉工作主要看这个）
node ..\_diag_sac\compare_ui.cjs     # → docs/compare_ui.png（左原版 右Godot）
```

## 4. 代码地图

```
lushi-godot/
  project.godot            主场景=scenes/prep.tscn；自动加载 game_data.gd
  autoload/game_data.gd    读 data/*.json 的唯一入口
  data/*.json              ★ 从 Web 导出，不要手改（改数值请改 Web 后重跑导出脚本）
  sim/                     纯逻辑层（无节点依赖，可无头跑）
    unit.gd                战斗单位（攻血/关键词/进化条/基因/充能/部位/协同随从）
    battle.gd              战斗结算内核，输出事件序列
    fusion.gd              合体区判定 / 四部位继承 / 协同随从生成
    prep.gd                磁力喂料
    economy.gd             回合收入 / 利息 / 升级花费（读 config.json）
    shop.gd                商店生成（星级概率 + 种族池过滤，RNG 可播种）
    gild.gd                三连金卡
    prep_state.gd          备战状态机（buy/reroll/level_up/place/sell/feed/prepare_fusion）
    ai.gd                  AI 决策（上场→升级→买牌→刷新→攒钱）
    session.gd             无头整局循环
  scripts/
    prep_view.gd           ★ 备战界面（按原版 CSS 还原，含布局自检 _dump_layout）
    main.gd                P0 的卡池浏览器（仍在 scenes/main.tscn）
    ui_theme.gd            主题 + 中文字体
  tools/*.gd               10 组自检 + parity_run
  tests/scenarios.json     双端共用战斗场景（15 个）
  docs/compare_ui.png      ★ 原版 vs Godot 并排对照图（最新）
```

## 5. 视觉还原的当前状态

### 已按原版 CSS 对齐（可自动核对）

原版配色（`index.html` 的 `<style>`）→ Godot 常量（`scripts/prep_view.gd` 顶部）：

| 用途 | 原版 | Godot |
|---|---|---|
| 页面底色 | `#1a1a2e` | `C_BG` |
| 面板 | `#16213e` | `C_PANEL` |
| 空槽 / 有牌 | `#0f0f1a` + 虚线`#2d3047` / `#2d3047` + 实线`#4a4d6b` | `C_SLOT_EMPTY` / `C_SLOT_FILL` / `C_LINE` / `C_LINE_FILL` |
| 攻击 / 生命 | `#ff6b6b` / `#55efc4` | `C_ATK` / `C_HP` |
| 金 / 次要文字 | `#fdcb6e` / `#636e72` | `C_GOLD` / `C_MUTED` |
| 按钮 刷新·冻结·升级·开打 | `#636e72` `#0984e3` `#74b9ff` `#e17055` | `C_BTN_*` |

尺寸与坐标（1440×900，同场景）：

| 区块 | 原版 | Godot |
|---|---|---|
| 顶栏 | y=4 h=29 | y=4 h=33 |
| 战场起点 | y=49 | y=53 |
| 手牌 | y=640 h=79 | y=636 h=78 |
| 商店 | y=721 h=101 | y=717 h=102 |
| 操作栏 | y=822 h=32 | y=822 h=30 |
| 日志 | y=856 h=40 | y=858 h=38 |
| 内容宽 | 992 | 1000 |

槽位 80×88 / 手牌 72×54 / 商店卡 85×75（同 `.sl/.hc/.sc`）。

### ⚠️ 需要"会看图"的人来判断的（当前模型做不到）

1. **字重与字号手感**：卡面名字、攻血数字、按钮文字在原版里的视觉重量
2. **留白与疏密**：槽位间距 3px、手牌居中留白是否观感一致
3. **合体区虚线/金色描边的粗细与脉冲节奏**
4. **战斗逐条播放的节奏**（0.28s/条是否合适）与飘字位置
5. 原版那些我**尚未实现**的表现：种族图标（原版部分是内联 SVG，部分是 emoji）、稀有度边框、卡面 hover 效果、磁力吸附时的电流线（原版 `#spl` 箭头）、攻击位移与受击闪白

## 6. 本次交接前刚完成 / 未完成

### 刚完成：方向 B（给 Web 加无头开关）

`lushi-like/index.html` 已加：

```javascript
window.HEADLESS = /headless=1/.test(location.href);   // 用 hash，因为本地 server 不剥离 query
var dl = function(ms){ if(window.HEADLESS) return Promise.resolve(); ... }   // 无头时跳过动画延时
```

用法：访问 `http://localhost:8080/#headless=1`（**必须是 hash**，用 `?headless=1` 会 404，因为 `server.js` 直接按 url 找文件）。

已用 `_diag_sac/headless_probe.cjs` 验证：机械合体战斗在无头下 **47ms** 跑完，日志确认
`我方合体出击存活，出击等级3，零件+(12/+12)`、`磁暴僚机:随同攻击-10`、`同族共鸣:mech+1/+1` 都正常触发。

### 未完成（下一步优先级从高到低）

1. **合体战的 parity 场景**：Web 侧现在能无头跑了，可以加进 `tests/scenarios.json`。但要注意 Web 有**"合体存活 → 战后零件永久成长"**（日志里的 `零件+(12/+12)`），Godot 侧**还没实现这条**，要补上才能真正对齐。
2. **磁力喂料的 parity**：`sim/prep.gd` 已实现主体，但 Web 的 `magnetFeed` 里"超导装配中枢 → 其他部位按比例追加"分支还没逐行核对。
3. **充能"圣盾"的疑似 Web bug**：Web 判圣盾只认 `d` 关键词，而磁力底盘带的是 `t`，所以它的充能盾实际无效。Godot 按现状镜像了。**需要用户拍板**：改判定，还是给机械牌补 `d`。
4. **视觉表现**（第 5 节 ⚠️ 那几项）。
5. 回合三选一/倒计时已做，但冻结、设置面板还是占位。

## 7. 给新会话的开场建议

让新会话说：

> 读 `lushi-godot/SESSION-HANDOFF.md` 与 `README.md`，跑一遍 10 组自检确认基线，
> 然后生成 `docs/compare_ui.png`（原版 vs Godot 并排）**看图**说出 Godot 版与原版在布局、
> 配色、字号、留白上的具体差异，按你看到的逐条修，不要凭猜测改。

## 8. 约定（别破坏）

- **数据从 Web 导出**：改卡牌/配置一律改 `lushi-like/index.html`，再跑
  `node ..\_diag_sac\extract_for_godot.cjs` 重新导出 `data/*.json`
- 改机制**先在 Web 验证手感**，再同步到 `sim/`；两边行为要一致，靠 parity 场景守着
- 每次改动都跑自检；加了新机制就往 `tests/scenarios.json` 加对照场景
- Godot 类型推断严格（见第 2 节），写代码时显式标注类型
