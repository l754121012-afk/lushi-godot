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

## 更新（P1c-4）

- parity 当前结果：**15/15 场景一致**（新增 机械：维修护甲吸收、充能展开圣盾）
- 机械充能时机已对齐 Web：出手动作充能 1 次（不是每段挥击）、受击充能只在随从存活时结算
- 发现并镜像一条疑似 Web bug：充能"圣盾"只对带 d 关键词的随从生效，磁力底盘带的是 t，其充能盾实际无效
- 待迁移：机械合体（合体区判定 / 四部位继承 / 协同随从与协同攻击）+ 磁力喂料

## 更新（P1c-5）

- 新增 sim/fusion.gd：合体区判定（连续4格 首脑core+另外三部位）、四部位数值继承、协同随从生成
  · 合体体：攻击=四部位相加(+modAtk)、生命/上限=相加、关键词取并集(+modShield)、星级=1+floor(mechLevel/2)
  · 协同随从：磁暴僚机(strike) / 维修无人机(repair) / 电磁拦截者(guard)，按合体体 45%/25%/30% 攻击与 30%/40%/50% 生命 + mechLevel 生成
- tools/fusion_test.gd：3 条自检（合体体数值 19/31 k=tw、协同随从 13/13|9/16|10/20、合体区判定与整排后移）
- 待办：协同攻击(mechFollowAttack)接入战斗循环 + 磁力喂料，然后纳入 parity 场景

## 更新（P1c-6）

- mechFollowAttack（协同攻击）已接入战斗循环：合体体出手后，协同随从各跟随攻击一次（不消耗自身出手）
  · strike 型造成合体攻击 50%，其余 25%；目标优先嘲讽，护甲/圣盾判定与普通攻击一致
- sim/unit.gd 补 mech_body / follow_type / follow_body_id 字段；parity runner 支持 fusionP/mechLevel/magT/mechRepair
- 合体战的 Web 侧对照会卡住（Web 的合体流程含 UI 相关调用），暂未纳入 parity；已通过 fusion_test 3/3 与规则自检 6/6 验证
- 待办：磁力喂料（可用 Web 的 magnetFeed 直接对拍）

## 更新（P1c-7）

- 新增 sim/prep.gd：磁力喂料 magnet_feed —— 材料牌数值按机械支援加成后转移给目标机械
  · 金卡翻倍 / 磁暴重臂 ×2 攻击 / 超导装配中枢 ×1.5（金 2.5）/ matBoost 加成 / 关键词转移
  · 机械泰坦在场：目标额外 +30% 转移攻击；统御核心在场：每次喂料 modGrow +1（金 +2）
  · TODO：超导装配中枢的"其他部位按比例追加"分支待逐行核对后补
- tools/prep_test.gd：3 条自检通过（基础 4/6、支援加成 18/9、核心成长 +1/+2）
- 机械族至此：护甲/充能/合体继承/协同攻击/磁力喂料均已迁移；合体战与喂料的双端 parity 待补

## 更新（P2-1）

- 进入 P2 备战流程，第一块：经济系统 sim/economy.gd（数据全部查 data/config.json，不写死数值）
  · 每回合收入 = 基础金币 + 连胜/连败利息 + 节奏奖励（金币不结转，直接覆盖）
  · 升级花费 L1→6 … L6→16；刷新 1 金；can_level_up 判定
- tools/economy_test.gd：3 条自检通过（升级花费 / 回合收入 R1=3 R5=7 / 利息 1连胜=1 3连胜=3 3连败=3）
- 下一步 P2：商店生成（星级概率 + 本局种族池过滤）、手牌与拖拽（含磁力吸附）、布阵与合体区高亮、AI 运营

## 更新（P2-2）

- 新增 sim/shop.gd：商店生成（对齐 Web 的 gs()）
  · 5 格；每格 20% 出法术牌；否则按酒馆等级查星级概率（8% 概率 +1 星），再从该星级池抽牌
  · 只抽本局种族池内的牌（无种族的牌放行），最多重试 30 次后兜底纯随机
  · 纯逻辑：卡池/法术池由调用方注入，RNG 可播种 → 商店可复现
- tools/shop_test.gd：3 条自检通过（Lv1 只出 1-2★；200 张无越界种族；5 格 + 同种子可复现 + 能出法术）
- 下一步 P2：手牌与拖拽（含磁力吸附）、布阵与合体区高亮、AI 运营决策

## 更新（P2-3）

- 新增 sim/gild.gd：三连金卡（对齐 Web 三连规则）
  · 3 张同名且非金卡 → 合成金卡：身材翻倍、技能/法术联动/战吼数值与次数翻倍（need 等条件不翻倍）
  · try_merge 只找第一组三连；merge_in_place 就地合成（原位放金卡，另两格清空）；金卡不再参与三连
- tools/gild_test.gd：3 条自检通过
- **P2 剩余（下一轮从这里继续）**
  1. 手牌与拖拽：手牌拖到场上；材料牌拖到机械显示磁力吸附特效并调用 magnet_feed
  2. 布阵与合体区：前四格合体区高亮 / 部位标注 / 满足条件时电流特效（复用 sim/fusion.gd）
  3. AI 运营：买牌、刷新、升级、卖牌换牌、凑阵容、机械合体与喂料（复用 economy/shop/fusion/prep）
  4. 回合三选一（3/6/9 回合）与备战倒计时
  5. 补合体战与磁力喂料的双端 parity（Web 合体流程带 UI 调用，等备战界面做好后再对拍）

## 更新（P2-4）

- 新增 sim/prep_state.gd：备战期状态机，把已迁移的规则层接起来（经济/商店/三连金卡/合体判定/磁力喂料）
  · setup(回合, 本局种族, 卡池, 法术池, 种子) → 自动结算本回合收入并生成商店
  · buy(下标) / reroll() / level_up() / place(手牌,格子) / sell(格子) / try_gild_in_hand()
  · has_formation() 判定合体区；prepare_fusion() 开打前合体；feed(手牌,格子) 磁力喂料
  · 购买价 = 星级 × BUY_COST_PER_STAR（常数，便于与 Web 定价对齐后统一调整）
- tools/prep_state_test.gd：3 条自检通过（买牌上场 / 经济与升级 / 喂料与合体）
- 下一步：把 prep_state 接到 Godot 节点与鼠标事件（手牌拖拽、合体区高亮、按钮），随后做 AI 运营

## 更新（P2-5）

- 新增 scenes/prep.tscn + scripts/prep_scene.gd：**可点击的备战界面骨架**
  · 顶栏：回合 / 金币 / 等级 / 连胜连败 + 刷新 / 升级 / 开打按钮
  · 商店 5 格（点击购买，显示 名字/攻血/价格）、手牌区（点击选中）、战场 7 格（前 4 格为合体区，满足时金色高亮）
  · 开打：调用 sim/battle.gd 跑一场并在日志里给出胜负与事件条数；合体就绪会自动合体
  · 主场景已切到 prep.tscn（卡池浏览器仍在 scenes/main.tscn，可单独打开）
- 交互本轮为"点手牌 → 点空格"；真拖拽（含材料牌磁力吸附特效）与合体区电流特效留到下一轮

## 更新（P2-6）

- 新增 sim/ai.gd：AI 备战决策（薄决策层，规则仍走 prep_state）
  · 优先级：手牌上场 → 升级（留够买牌钱）→ 买本阵容牌（择优取高星）→ 刷新找牌 → 攒钱
  · run_turn() 会连续执行到无事可做，返回执行轨迹（便于日志/复盘）
- tools/ai_test.gd：3 条自检通过（会买牌/会升级/零金不乱花）
- **P2 剩余**：真拖拽（手牌→场上、材料牌→机械磁力吸附特效）、合体区电流特效、回合三选一与备战倒计时
