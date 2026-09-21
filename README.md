# 炉石旅人 · Godot 版

从单文件 Web 版（`../lushi-like/index.html`）迁移到 Godot 4.7.2，为后续更全面、更优质的内容做准备。
Web 版继续作为**数值/机制基准**与对照，Godot 版是**后续主开发线**。

## 当前进度

| 阶段 | 内容 | 状态 |
|---|---|---|
| P0 | 数据管线 + 卡池浏览器 + 无头自检 | ✅ 已完成 |
| P1 | 战斗结算内核（纯逻辑、可无头跑、可单测） | 🟡 献祭债务链 + 星灵连锁已迁移，出手模型与 Web 对齐（13 场景全绿） |
| P2 | 备战流程（商店/手牌/布阵/拖拽 + 经济 + AI 运营） | ⬜ |
| P3 | 表现层（动画/特效/音效/中文排版） | ⬜ |
| P4 | 内容扩展（新种族、新机制、战役/多人） | ⬜ |

### P0 已交付

- `data/*.json`：从 Web 版导出的 93 张卡、10 个种族、宣言池、经济配置、星级概率、AI 模板、法术池
- `autoload/game_data.gd`：统一数据入口（按种族/星级/关键字查询）
- `scripts/main.gd` + `scenes/main.tscn`：卡池与配置浏览器（左侧列表 + 右侧详情，可筛选/搜索）
- `tools/selftest.gd`：数据自检（数量、种族、星级、经济、进化随从名单校验）
- 系统中文字体（SystemFont）接入，避免 CJK 显示成方块

### P1a 已交付（战斗内核骨架）

- `sim/unit.gd`：战斗单位（攻/血/关键词/技能/进化条/基因层），纯数据对象
- `sim/battle.gd`：结算内核，输出**事件序列**（attack/damage/shield_break/taunt_break/death/buff/evop/evo_full/evolve/gene/end），表现层后续直接订阅
- 已覆盖规则：出手顺序、目标选择与嘲讽优先、圣盾、风怒、伤害与死亡、进化条（攒格→质变：身材×2 / 攻击×1.5）、
  进化大师（推进器）、混沌始祖（回合吞噬基因 + 基因领主）、回合开始光环
- `tools/battle_test.gd`：6 条核心规则用例（数值对抗 / 嘲讽优先 / 圣盾吸伤 / 进化条 / 推进器 / 基因领主）全部通过

**待补（P1b）**：机械合体与磁力、献祭契印与债务、星灵连锁、法术与战吼全表、金卡三连、AI 运营决策。
与 Web 版的逐条一致性会用「同一套场景 JSON 两边跑、对比结果」的 parity 用例来保证。

### P1b 已交付（Web ⇄ Godot 一致性对照）

- `tests/scenarios.json`：两端共用的战斗场景（9 个：数值对抗 / 嘲讽 / 圣盾 / 风怒 / 剧毒 / 攻线进化 / 受击线进化 / 推进器 / 基因领主）
- `tools/parity_run.gd`：Godot 侧跑场景 → `tests/out/godot.json`
- `tools/parity_web.cjs`：Web 侧跑同一批场景（关动画、播种 RNG、关闭昼夜加格与宣言奖励，隔离出"卡自身机制"）→ `tests/out/web.json`
- `tools/parity_compare.cjs`：对比胜负 / 败方掉血 / 每张卡最终攻击与最大生命
- 当前结果：**13/13 场景一致**
- 机械族：维修护甲吸收与充能（shield/heal/rally/buff）已进内核并通过规则自检，但**尚未纳入 parity 场景**
  （充能场景首次对照即发现行为差异，需要下轮逐条核对：受击充能应只在随从存活时结算等）；合体/磁力仍待迁移（献祭·债务：节点结算、契印死亡转债务；星灵：连锁爆发、星界增幅叠加）
- 出手模型已对齐 Web：每次迭代 = 我方按格位顺序轮转一只出手 → 敌方随机一只出手（交替结算，不是整轮双方依次出手）；
  这条差异是靠 `star_chain_burst`（多打多）暴露出来的，1v1 场景看不出来
- 多单位 + 随机选敌的场景（如 `star_chain_burst`）因两端 RNG 流不同，存活者会不同，
  在 scenarios.json 里标 `nondeterministic`，对比器只校验胜负/连锁/债务等确定性结果

这条通道已经抓到并修掉两个真实 bug（都在 lushi-like 仓库）：
1. 基因领主加成改的是真实卡而非战斗克隆，同一份加成被回放重复叠加（+6/+6 应为 +3/+3）
2. 食骸者带 rate 的继承与战后 times/5 总量继承同时生效，实际收益约为卡面的 5 倍

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

# 战斗内核自检（6 条核心规则）
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path <项目路径> --script res://tools/battle_test.gd

# 双端一致性：先跑 Web 侧（需要 localhost:8080 服务着 lushi-like），再跑 Godot 侧，最后对比
node tools\parity_web.cjs
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path <项目路径> --script res://tools/parity_run.gd
node tools\parity_compare.cjs
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
  sim/unit.gd            # 战斗单位
  sim/battle.gd          # 战斗结算内核（输出事件序列）
  scripts/main.gd        # 卡池浏览器（P0 工具，后续会并入正式 UI）
  scripts/ui_theme.gd    # 深色主题 + 中文字体
  scenes/main.tscn
  tools/selftest.gd      # 数据自检
  tools/battle_test.gd   # 战斗规则自检
  tools/parity_run.gd    # 一致性对照（Godot 侧）
  tools/parity_web.cjs   # 一致性对照（Web 侧）
  tools/parity_compare.cjs
  tests/scenarios.json   # 双端共用场景
  data/*.json            # 导出数据（不要手改）
  docs/                  # 截图与文档
```

## 迁移原则

1. **逻辑与表现分离**：战斗结算先写成纯逻辑类（不依赖节点），可无头跑、可单测；动画只订阅结算产生的“事件序列”
2. **数据驱动**：卡牌/技能/宣言/经济全部来自 JSON，新内容尽量只加数据不改代码
3. **以 Web 版为基准**：每次机制改动先在 Web 版验证手感，再同步到 Godot；数值曲线用同一套模拟脚本对照（R11 主C 100-150、R16 300-400）
4. **中文优先**：默认字体走系统 CJK，文案与卡面字段保持中文
