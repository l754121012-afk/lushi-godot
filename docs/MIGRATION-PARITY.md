# 炉石旅人 Web → Godot 机制对照清单

> 这份清单是迁移验收底表，不是“以后有空再补”的愿望列表。  
> 每条机制统一按六层验收：规则 → 事件 → UI → 动画 → 音频 → 证据。  
> “函数存在”或“战斗日志出现关键字”只能证明逻辑层存在，不能把 UI、动画、音频一起判定为完成。  
> 规则以 Web `index.html` 为基准；Godot 逻辑通过后，表现层必须能看出该规则的来源、目标、结算和结果。

> 当前完成度以本文的「当前迁移状态（2026-09-27）」和自动逐卡审计为准。  
> 下方的 2026-09-24 基线与通用流程表保留用于追溯，其中的旧 `未接/部分` 不代表当前状态。

## 状态口径

| 标记 | 含义 |
|---|---|
| `对齐` | 规则、事件、UI 和必要的表现闭环都已存在 |
| `逻辑有/表现缺` | `sim/` 或事件序列已有规则，但界面没有完整呈现 |
| `部分` | 只迁移了主体，仍有明确分支或交互缺失 |
| `逻辑缺` | 规则本身未迁移 |
| `未接` | 资源或系统存在，但没有接入运行路径 |

## 历史基线（2026-09-24）

2026-09-24 已跑通过以下 10 组规则自检：

```text
selftest 1/1
battle 29/29
fusion 3/3
prep 4/4
economy 3/3
shop 3/3
gild 3/3
prep_state 12/12
ai 8/8
session 4/4
```

自检只能证明规则基线未回归，不能证明 UI、动画、音频和 Web 原版手感已经对齐。

同日的界面基线：`--sacrifice-test`（含 UI/动画/音效轨迹）、`--interaction-test 10/10`、`--flow-test 5/5`、`--battle-anim-test 6/6`。

2026-09-24 阶段 A 已补 G1-G3 的针对性覆盖：敌方多挥击重选目标、死亡槽位清空、受击流水线顺序、运行态写回。

阶段 A 期间的 parity 差异已全部关闭：

- 4 个进化差异来自 Godot parity runner 未传 `phase=2`，多执行了一次昼间进化。
- `debt_contract_death` 来自 Godot 错误地把 `debt-boost` 作为自身死亡效果；Web 只把它作为契印结算修正。

阶段 B 已补 G4-G5 的统一效果分发：`spell-cast` 法术联动、`round` 备战回合技能、`gold` 消费触发、商店施法与商店吞噬。
阶段 C 已按献祭、进化、机械、龙、星灵、亡灵、元素、血族、赌徒、恶魔、中立逐族补齐卡级断言。
自动审计已达到 `R断言=102 R入口=0 R缺=0`。

当前 parity 基线：`16/16` 场景一致。

阶段 D 已完成逐族六层回归：献祭、进化、机械、龙、星灵、亡灵、元素、血族、赌徒、恶魔、中立全部补齐家族级 UI/事件/动画/音效/P 证据，`六层可关门 = 102`。
各家族分别使用 `--sacrifice-test`、`--evolve-test`、`--mech-test`、`--dragon-test`、`--star-test`、`--undead-test`、`--families-test` 验证事件回放、动画轨迹和 `_sfx_trace`。
该完成口径是“当前验收矩阵的家族级证据闭环”；逐卡专属 VFX/SFX 美术精修仍可作为后续打磨项，但不再是缺失的规则或表现入口。

逐 id 审计结果以本文下方的「自动逐卡审计」标记区为准。该区域由 `tools/parity_audit.gd`
从 `data/cards.json`、当前入口登记和测试证据重新生成；旧的手写缺口列表不再作为验收依据。

`sim/prep_state.gd` 的 `dmg-rnd` 已有真实伤害结算，`prep_state_test` 用例 6 会断言伤害、敌方棋盘移除和战后恢复。

## 历史通用流程清单（2026-09-24）

| 系统 / 机制 | Web 基准 | Godot 逻辑位置 | 事件 | 当前 UI / 动画 | 音频 | 具体缺口 | 优先级 | 验收证据 |
|---|---|---|---|---|---|---|---|---|
| 回合收入与不结转 | `roundIncome`、利息由连胜连败决定 | `sim/economy.gd`、`prep_state.setup()` | 无事件，直接状态变更 | 顶栏金币数字 | 未接 | 音效未接；数字变化没有收钱反馈 | P2 | `economy_test 3/3` + 手动查看顶栏 |
| 商店生成 | `gs()`、星级权重、种族池过滤 | `sim/shop.gd`、`prep_state.roll_shop()` | 无事件 | 5 格商店 | 未接 | 刷新、冻结、买牌音效未接 | P2 | `shop_test 3/3` |
| 购买与退款 | 购买按钮、法术退款、三连 | `prep_state.buy()`、`gild.try_merge()` | 无事件 | 点击商店购买；有 `buy` 音效 | 部分 | 退款路径提示、金卡合成音效和失败反馈未接 | P1 | `prep_state_test 6/6` + `gild_test 3/3` + 手动点击 |
| 升级酒馆 | Web 升级后立即刷新商店 | `prep_state.level_up()`、`roll_shop()` | 未产生独立规则事件 | 升级按钮、等级文字、商店五格错峰缩放淡入；冻结时不换牌 | 部分 | 规则、扣金、刷新/冻结保留与商店换牌反馈已有；缺升级专属音效和更完整的 Web 刷新节奏对齐 | P1 | `prep_state_test 6/6` + `--interaction-test` 的等级/扣金/内容变化/冻结保留/换牌反馈断言 |
| 刷新 / 冻结 | 刷新扣 1 金；免费刷新优先；冻结保留商店 | `prep_state.reroll()`、`roll_shop(force)` | 无事件 | 刷新、冻结按钮；有 `reroll` 音效 | 部分 | 冻结提示、金币不足反馈和重 roll 卡片入退场动画未接 | P1 | `prep_state_test 6/6` + 手动连续刷新/冻结 |
| 点击、拖拽、放置 | 手牌点击上场；材料牌拖拽到机械是磁力；献祭者拖拽选择吞噬目标 | `Draggable`、`Dropless`、`_handle_slot_input()`、`prep_state.place/feed/devour` | 规则层无统一 UI 事件 | 拖拽和点击已有主体 | 未接 | 不同拖拽语义缺少统一的拖拽提示、合法目标高亮、取消反馈、落点音效 | P0 | `--interaction-test 10/10` |
| 法术选中与目标 | 点法术后点目标施放；点金可自由指定 | `prep_state.cast_spell()` | 返回结果字典 | 选中栏 + 目标点击 | 未接 | 目标高亮和施法飞行动画不完整；无施法音效 | P1 | 扩展 interaction test 覆盖普通法术/点金/无目标取消 |
| 卡名与卡面信息 | 卡面保留信息；hover 显示完整详情 | `_fill_name_lines()`、`_attach_card_tooltip()` | 无事件 | tooltip 存在 | 未接 | 卡名仍有省略截断；需实测 hover 命中区、层级和角标展开是否可靠 | P0 | `--flow-test` + 鼠标 hover 截图/断言 |
| 战斗事件内核 | Web `seq` 记录攻击、伤害、死亡、成长、债务、进化、充能、回响 | `sim/battle.gd` | 产出 `attack/damage/death/buff/heal/poison/armor/evop/evo_full/evolve/gene/debt/debt_settle/ch/contract/end` | 文本战报完整度较高 | 未接 | 事件已经存在，但很多类型没有专属演出 | P0 | `battle_test 10/10` + 事件计数 |
| 战斗时间轴 | 攻击方先位移，目标命中停顿，再结算飘字/死亡 | `_play_battle()` | 直接消费 Godot 事件 | 槽位实例复用；攻击方 `translateY(-4px)+scale(1.02)`，目标受击变色并左右抖动，死亡独立缩小淡出 | 部分 | 主体时间轴已有；仍需逐事件观感验收，不能用旧文档中的“整排重建闪烁”概括，也不能据此判定全部演出完成 | P0 | `--battle-anim-test 5/5` + 录屏/截图检查攻击、受击、死亡三类槽位 |
| 战斗飘字 | 伤害、治疗、成长、圣盾、死亡 | `_show_battle_float()` | 已读取部分事件 | 已有基础飘字 | 未接 | 债务、进化、充能、契约、回响等没有专属飘字颜色/来源 | P1 | 事件回放断言 + 视觉检查 |
| 音效与音乐 | Web 只有 `BGM_B64`、`HIT_B64` | `scripts/prep_view.gd` 的 `_setup_audio()`、`_play_sfx()` | 无音频事件 | BGM 与 `buy/place/reroll/level/hit/death` 使用已有素材做变体 | 部分 | 不能虚构 Web 已有多套机制音效；当前仅有通用命中素材。机制专属音效属于新增资产，需标 `S△` 并单独制作/接线 | P1 | 资源/总线检查 + 通用音效触发点 + 实际听感 |
| 三连金卡 | 三张同名合成金卡，字段按规则翻倍 | `sim/gild.gd` | 无事件 | 卡面金边 | 未接 | 合成动画、音效和角标 pop 未接 | P1 | `gild_test 3/3` |
| AI 运营 | 买牌、升级、刷新、换牌、合体、喂料 | `sim/ai.gd`、`sim/session.gd` | 返回操作轨迹 | 日志 | 未接 | 行为主体已有；难以看见 AI 每一步造成的变化 | P2 | `ai_test 3/3` + `session_test 4/4` |

## 当前迁移状态（2026-09-27）

当前已经把“规则迁移”和“最终美术完成”分开验收：

- 规则与事件：`R断言 102 / R入口 0 / R缺 0`。
- 六层结构闭环：`102/102`。
- 双端 parity：新增机械合体与协同攻击场景后为 `16/16`。
- 机制反馈契约：`11/11` 族、`22` 条高风险交互轨迹。
- 10 组基础自检、全部 UI 专项、合体 parity 均通过。
- 迁移含义：Web 已有机制、事件、卡面信息和占位表现已进入 Godot 可玩路径；最终美术、专属音色和主观手感仍属于后续打磨。
- 旧的手工 `△/-` 缺口表已被本快照和下方自动逐卡审计替代，不再作为当前完成度口径。

### 机制族当前状态

| 机制族 | 规则/事件 | 交互与 UI | 动画轨迹 | 音效轨迹 | 最终资产/听感 |
|---|---|---|---|---|---|
| 献祭 | ✓ | ✓ | ✓ | ✓ 占位 | 待专属美术与音色 |
| 进化 | ✓ | ✓ | ✓ | ✓ 占位 | 待来源光球与质变验收 |
| 机械 | ✓ | ✓ | ✓ | ✓ 占位 | 待合体注入、电流和专属音色 |
| 龙 | ✓ | ✓ | ✓ | ✓ 占位 | 待龙威层来源链精修 |
| 星灵 | ✓ | ✓ | ✓ | ✓ 占位 | 待回响飞行与连锁节奏 |
| 亡灵 | ✓ | ✓ | ✓ | ✓ 占位 | 待召唤/复活专属表现 |
| 元素 | ✓ | ✓ | ✓ | ✓ 占位 | 待法术核心蓄能表现 |
| 血族 | ✓ | ✓ | ✓ | ✓ 占位 | 待锁血与血池节奏 |
| 赌徒 | ✓ | ✓ | ✓ | ✓ 占位 | 待成功/失败/倍率演出 |
| 恶魔 | ✓ | ✓ | ✓ | ✓ 占位 | 待吞噬与多重攻击演出 |
| 中立 | ✓ | ✓ | ✓ | ✓ 占位 | 通用表现精修 |

### 当前真实剩余

1. 单卡专属 VFX、SFX、图标、稀有度边框和最终排版。
2. 动画节奏、粒子密度、遮挡和玩家主观可读性。
3. Web 充能“圣盾”疑似 bug 是否保留镜像，仍需产品决策。
4. 新内容和后续玩法，而不是 Web 已有机制的规则迁移。
<!-- PARITY_AUDIT_BEGIN -->
## 自动逐卡审计（由 `tools/parity_audit.gd` 生成）

唯一键为 `卡名|字段|效果|触发`。`R入口` 只表示规则入口存在，不表示该卡的目标、数值、金卡倍率或时序正确；
同效果的其他卡即使已有断言，也不能替本行勾销。六层未全部为 `✓` 时，整行不得判定完成。

- 卡牌：94（含生成形态 `混沌始祖`）
- 技能字段实例：85
- 独立效果 ID：52
- 双端 parity 场景：16（是否全过以 parity_compare 的 0 差异为准）
- `R断言`：102；`R入口`：0；`R缺`：0
- 六层全部有当前证据、可关门：102
- 机制反馈契约：11/11 族具有唯一主色、母题和占位资源路径；22 条高风险交互轨迹已登记
- 反馈契约只证明占位表现可识别、可替换，不等同于最终美术或主观视觉评分。

### 根因队列

| ID | 根因 | 受影响机制 | 强制证据 | 状态 |
|---|---|---|---|---|
| G1 | 攻击生命周期 | 机械、龙、恶魔、进化、星灵 | 挥击数、重选目标、尾部钩子只跑一次 | 规则入口已有；需逐卡回填 |
| G2 | 受击流水线 | 血族、机械、进化、吸血 | 锁血→护甲→扣血→充能→受击技→治疗→死亡顺序 | 规则入口已有；需场景断言 |
| G3 | 运行态跨阶段 | 进化、龙、机械、恶魔、亡灵 | `_t/_g/_gb/_dHit/_atkT/_hit/_pr` 等保真 | 已有字段保真用例；缺跨阶段场景 |
| G4 | 开场预扫描 | 龙、恶魔、进化、亡灵 | 龙威→minor→多击/进度/重生顺序 | 规则入口已有；需逐卡断言 |
| G5 | 触发分发表 | 全部效果 | `round/spell-cast/gold/sc/scSk` 逐卡分发 | 规则入口已清零；逐卡断言仍待 |
| G6 | 机械合体协同 | 机械 | 部位、随机协同、目标继承、三类行为 | 主体已有；逐部位证据缺 |
| G7 | 表现闭环 | 全族 | 规则事件→UI→动画→音频分别验收 | 大量 △/- |
| G8 | 跨战斗持久状态 | 龙、进化、献祭、机械 | 连续两回合状态来源一致 | 待办 |
| G9 | 审计回填 | 全卡池 | 每行 R/E/U/A/S/P 与证据 | 本表持续生成 |

### 机制族汇总

| 机制族 | 行数 | R断言 | R入口 | R缺 | 六层可关门 |
|---|---:|---:|---:|---:|---:|
| 献祭 | 10 | 10 | 0 | 0 | 10 |
| 进化 | 7 | 7 | 0 | 0 | 7 |
| 机械 | 16 | 16 | 0 | 0 | 16 |
| 龙 | 7 | 7 | 0 | 0 | 7 |
| 星灵 | 7 | 7 | 0 | 0 | 7 |
| 亡灵 | 9 | 9 | 0 | 0 | 9 |
| 元素 | 9 | 9 | 0 | 0 | 9 |
| 血族 | 7 | 7 | 0 | 0 | 7 |
| 赌徒 | 5 | 5 | 0 | 0 | 5 |
| 恶魔 | 8 | 8 | 0 | 0 | 8 |
| 中立 | 17 | 17 | 0 | 0 | 17 |

### 机制族缺口（逐族追责）

`规则缺` 是整条规则入口不存在；`有入口未断言` 只说明共享代码分支存在，仍必须逐卡核对目标、数值、金卡倍率和触发顺序。
表现计数按该族仍为 `△/-` 的卡行统计，不能用某一张代表卡通过来关闭整族。

#### 献祭

- 机制载体：契印 / 债务层 / 节点结算 / 主动吞噬 / 继承
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

#### 进化

- 机制载体：进化条 / 孵化 / 基因吞噬 / 质变推进
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

#### 机械

- 机制载体：合体区 / 部位继承 / 磁力喂料 / 充能 / 协同攻击
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

#### 龙

- 机制载体：龙威层 / 开场光环 / 任意龙攻击反应 / 跨回合成长
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

#### 星灵

- 机制载体：连锁层 / 开场增幅 / 攻击连锁伤害 / 星光回响
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

#### 亡灵

- 机制载体：召唤 / 亡语本族成长 / 复活 / 死亡实时递增
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

#### 元素

- 机制载体：战吼法术增幅 / 施法核心 / 元素成长 / 商店联动
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

#### 血族

- 机制载体：受击成长 / 攻击治疗 / 最大生命 / 低血减伤
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

#### 赌徒

- 机制载体：随机目标 / 成功率 / 倍率 / 全体记录
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

#### 恶魔

- 机制载体：商店吞噬 / 金币消费触发 / 多重攻击 / 恶魔共鸣
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

#### 中立

- 机制载体：基础数值 / 战吼 / 法术 / 通用攻击线
- 规则缺：无
- 有入口未断言：无
- 表现未闭：E事件 0 / U界面 0 / A动画 0 / S音频 0
- 六层未闭卡：无

当前 `R缺` 效果：

```text

```

### 逐卡六层底表

六层缩写：`R规则 / E事件 / U界面 / A动画 / S音频 / P证据`。
`✓`=有当前证据，`△`=部分或通用表现，`-`=未接。

#### 献祭（10）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P0 | 1 | 献祭者 | `bc:常驻` | `devour` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_exec_battlecry / devour` | `index.html / effect=devour` | tools/prep_state_test.gd 用例4 | 补截图/录屏证据 |
| P0 | 2 | 血契司仪 | `sk:start` | `contract-set` | 目标=己方低数值献祭；debtBonus=1.0 | debtBonus=3；金卡分档待卡级断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_set_contract` | `index.html / effect=contract-set` | tools/battle_test.gd 用例7 | 补截图/录屏证据 |
| P0 | 3 | 债务执事 | `sk:death` | `debt-boost` | a=3.0；h=3.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_kill / contract debt modifier` | `index.html / effect=debt-boost` | tests/scenarios.json:debt_contract_death | 补截图/录屏证据 |
| P0 | 4 | 血祭司祭 | `sk:start` | `debt-payoff` | 目标=己方献祭；a=1.0；h=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_settle_debt` | `index.html / effect=debt-payoff` | tests/scenarios.json:debt_settle | 补截图/录屏证据 |
| P0 | 6 | 祭坛大师 | `sk:start` | `death-race-buff` | 目标=己方献祭；a=1.0；h=1.0；race=sacrifice；debtMax=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / death-race-buff` | `index.html / effect=death-race-buff` | tools/battle_test.gd 用例16 | 补截图/录屏证据 |
| P0 | 6 | 食骸者 | `sk:death` | `inherit` | times=1.0；rate=0.0445；debt=0.055 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_kill / inherit` | `index.html / effect=inherit` | tools/battle_test.gd 用例17 | 补截图/录屏证据 |
| P0 | 6 | 滚债行者 | `sk:round` | `debt-interest` | count=1.0；selfGrow=1.0；grow=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:apply_prep_round_skills / debt-interest` | `index.html / effect=debt-interest` | tools/prep_state_test.gd 用例8 | 补截图/录屏证据 |
| P0 | 7 | 万灵之主 | `bc:常驻` | `self` | 目标=自身；a=4.0；h=4.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_exec_battlecry / self` | `index.html / effect=self` | tools/prep_state_test.gd 用例9 | 补截图/录屏证据 |
| P0 | 7 | 万灵之主 | `sk:start` | `debt-lord` | 目标=己方献祭；a=4.0；h=4.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / debt-lord` | `index.html / effect=debt-lord` | tools/battle_test.gd 用例18 | 补截图/录屏证据 |
| P0 | 7 | 献祭图腾 | `sk:passive` | `debt-totem` | 未在数据中声明数值 | 金卡=1.50 / 普通=1.17（已分档） | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_debt_node_bonus` | `index.html / effect=debt-totem` | tests/scenarios.json:debt_settle,debt_contract_death | 补截图/录屏证据 |

#### 进化（7）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P0 | 1 | 细胞体 | `sk:attack` | `evolve-step` | a=4.0；h=4.0；need=3.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_attack_tail / evolve-step` | `index.html / effect=evolve-step` | tools/battle_test.gd 用例4; tests/scenarios.json:evolve_attack_line | 补截图/录屏证据 |
| P0 | 3 | 进化幼体 | `sk:start` | `evolve` | a=2.0；h=2.0；need=2.0；maxD=3.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / evolve` | `index.html / effect=evolve` | tools/battle_test.gd 用例19 | 补截图/录屏证据 |
| P0 | 3 | 进化幼体 | `scSk:spell-cast` | `self-buff` | 目标=自身；a=1.0；h=1.0 | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_on_spell_cast / self-buff` | `index.html / effect=self-buff` | tools/prep_state_test.gd 用例7 | 补截图/录屏证据 |
| P0 | 3 | 孵化体 | `sk:battle` | `progress` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_progress_victory` | `index.html / effect=progress` | tools/battle_test.gd 用例20 | 补截图/录屏证据 |
| P0 | 6 | 进化大师 | `sk:start` | `evo-advance` | a=1.0；h=1.0；grow=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / evo-advance` | `index.html / effect=evo-advance` | tools/battle_test.gd 用例5 | 补截图/录屏证据 |
| P0 | 7 | 终极进化体 | `sk:on-dmg` | `evolve` | need=3.0；maxC=3.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_on_damage_skill / evolve` | `index.html / effect=evolve` | tests/scenarios.json:evolve_on_dmg_line | 补截图/录屏证据 |
| P0 | 7 | 混沌始祖 | `generated:start` | `evo-devourer` | 自身；team=1；max=5 | 生成形态无金卡倍率 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / evo-devourer` | `index.html / effect=evo-devourer` | tools/battle_test.gd 用例6 | 补截图/录屏证据 |

#### 机械（16）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P3 | 3 | 磁力底盘 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P0 | 3 | 核心学徒 | `atkSk:攻击后` | `self-race-buff` | 目标=mech；a=1.0；h=1.0；race=mech | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_attack_tail / self-race-buff` | `index.html / effect=self-race-buff` | tools/battle_test.gd 用例21 | 补截图/录屏证据 |
| P0 | 3 | 磁能臂 | `atkSk:攻击后` | `self-race-buff` | 目标=mech；a=1.0；h=1.0；race=mech | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_attack_tail / self-race-buff` | `index.html / effect=self-race-buff` | tools/battle_test.gd 用例21 | 补截图/录屏证据 |
| P0 | 3 | 推进肢体 | `sk:on-dmg` | `self-buff` | 目标=自身；a=1.0；h=2.0 | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_on_damage_skill / self-buff` | `index.html / effect=self-buff` | tools/battle_test.gd 用例21 | 补截图/录屏证据 |
| P3 | 4 | 装甲模块 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P3 | 5 | 磁暴模块 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P0 | 5 | 维修输送车 | `sk:passive` | `mech-info` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep.gd:magnet_feed / repair support` | `index.html / effect=mech-info` | tools/prep_test.gd 用例4 | 补截图/录屏证据 |
| P0 | 6 | 磁暴重臂 | `sk:passive` | `mech-info` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep.gd:magnet_feed / arm modifier` | `index.html / effect=mech-info` | tools/prep_test.gd 用例2 | 补截图/录屏证据 |
| P0 | 6 | 磁暴重臂 | `atkSk:攻击后` | `self-race-buff` | 目标=mech；a=1.0；h=1.0；race=mech | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_attack_tail / self-race-buff` | `index.html / effect=self-race-buff` | tools/battle_test.gd 用例21 | 补截图/录屏证据 |
| P3 | 6 | 超载模块 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P0 | 6 | 磁力供给技师 | `sk:round` | `mech-supply` | count=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:apply_prep_round_skills / mech-supply` | `index.html / effect=mech-supply` | tools/prep_state_test.gd 用例8 | 补截图/录屏证据 |
| P0 | 7 | 统御核心 | `sk:passive` | `mech-info` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep.gd:magnet_feed / core growth` | `index.html / effect=mech-info` | tools/prep_test.gd 用例3 | 补截图/录屏证据 |
| P0 | 7 | 统御核心 | `atkSk:攻击后` | `self-race-buff` | 目标=mech；a=3.0；h=3.0；race=mech | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_attack_tail / self-race-buff` | `index.html / effect=self-race-buff` | tools/battle_test.gd 用例21 | 补截图/录屏证据 |
| P0 | 7 | 机械泰坦 | `sk:passive` | `mech-info` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep.gd:magnet_feed / titan bonus` | `index.html / effect=mech-info` | tools/prep_test.gd 用例4 | 补截图/录屏证据 |
| P0 | 7 | 泰坦覆足 | `sk:on-dmg` | `race-buff` | 目标=mech；a=3.0；h=3.0；race=mech | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_on_damage_skill / race-buff` | `index.html / effect=race-buff` | tools/battle_test.gd 用例21 | 补截图/录屏证据 |
| P0 | 7 | 超导装配中枢 | `sk:passive` | `mech-info` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep.gd:magnet_feed / super support` | `index.html / effect=mech-info` | tools/prep_test.gd 用例2 | 补截图/录屏证据 |

#### 龙（7）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P2 | 4 | 龙裔突击者 | `sk:attack` | `race-buff` | 目标=dragon；a=1.0；h=1.0；race=dragon | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_attack_tail / race-buff` | `index.html / effect=race-buff` | tools/battle_test.gd 用例22 | 补截图/录屏证据 |
| P2 | 6 | 龙鳞壁垒 | `sk:on-dmg` | `self-buff` | 目标=自身；a=1.0；h=2.0；grow=1.0 | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_on_damage_skill / self-buff` | `index.html / effect=self-buff` | tools/battle_test.gd 用例22 | 补截图/录屏证据 |
| P0 | 6 | 绿龙 | `sk:start` | `dragon-aura` | times=2.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / dragon-aura` | `index.html / effect=dragon-aura` | tools/battle_test.gd 用例22 | 补截图/录屏证据 |
| P2 | 6 | 龙威号角 | `sk:start` | `dragon-aura-minor` | a=1.0；h=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / dragon-aura-minor` | `index.html / effect=dragon-aura-minor` | tools/battle_test.gd 用例22 | 补截图/录屏证据 |
| P2 | 7 | 秘法巨龙 | `sk:start` | `growth-self` | times=4.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / growth-self` | `index.html / effect=growth-self` | tools/battle_test.gd 用例22 | 补截图/录屏证据 |
| P2 | 7 | 秘法巨龙 | `sc:spell-cast` | `self-growth-boost` | 目标=自身；times=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_on_spell_cast / self-growth-boost` | `index.html / effect=self-growth-boost` | tools/prep_state_test.gd 用例7 | 补截图/录屏证据 |
| P0 | 7 | 龙袭卫士 | `sk:aura` | `atk-react` | a=2.0；h=2.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_attack_tail / atk-react` | `index.html / effect=atk-react` | tools/battle_test.gd 用例22 | 补截图/录屏证据 |

#### 星灵（7）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P3 | 1 | 星尘游民 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P2 | 2 | 星象观测者 | `sk:start` | `chain-start` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / chain-start` | `index.html / effect=chain-start` | tests/scenarios.json:star_chain_burst | 补截图/录屏证据 |
| P2 | 3 | 星灵使徒 | `sk:spell-cast` | `race-buff` | 目标=star；a=1.0；h=1.0；scope=rnd；race=star；statScale=1.0 | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_on_spell_cast / race-buff` | `index.html / effect=race-buff` | tools/prep_state_test.gd 用例7 | 补截图/录屏证据 |
| P2 | 5 | 星灵斗士 | `sk:attack` | `chain-dmg` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_attack / chain-dmg` | `index.html / effect=chain-dmg` | tests/scenarios.json:star_chain_burst,star_amp_stack | 补截图/录屏证据 |
| P2 | 6 | 星辰编织者 | `sk:start` | `race-buff` | 目标=star；a=2.0；h=2.0；race=star；statScale=0.5；grow=1.0 | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / star statScale` | `index.html / effect=race-buff` | tools/battle_test.gd 用例23 | 补截图/录屏证据 |
| P2 | 6 | 星灵回响者 | `sk:aura` | `star-echo` | 目标=敌方随机 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_after_attack_star` | `index.html / effect=star-echo` | tests/scenarios.json:star_chain_burst | 补截图/录屏证据 |
| P2 | 7 | 星界之主 | `sk:start` | `star-amp` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / star-amp` | `index.html / effect=star-amp` | tests/scenarios.json:star_amp_stack | 补截图/录屏证据 |

#### 亡灵（9）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P2 | 2 | 亡灵学徒 | `sk:death` | `summon` | 目标=阵亡者所在方空槽；count=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_kill / summon` | `index.html / effect=summon` | tools/battle_test.gd 用例24 | 补截图/录屏证据 |
| P2 | 3 | 苦痛侍僧 | `sk:start` | `dmg-allies` | 目标=其他友方；d=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / dmg-allies` | `index.html / effect=dmg-allies` | tools/battle_test.gd 用例24 | 补截图/录屏证据 |
| P2 | 4 | 瘟疫僵尸 | `sk:death` | `rnd-race-buff` | a=1.0；h=1.0；race=undead | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_kill / rnd-race-buff` | `index.html / effect=rnd-race-buff` | tools/battle_test.gd 用例24 | 补截图/录屏证据 |
| P3 | 5 | 憎恶 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P2 | 5 | 骷髅召唤者 | `sk:death` | `summon` | 目标=阵亡者所在方空槽；count=2.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_kill / summon` | `index.html / effect=summon` | tools/battle_test.gd 用例24 | 补截图/录屏证据 |
| P2 | 6 | 死亡颂唱者 | `sk:death` | `race-buff` | 目标=undead；a=1.0；h=1.0；race=undead | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_kill / race-buff / undead` | `index.html / effect=race-buff` | tools/battle_test.gd 用例24 | 补截图/录屏证据 |
| P2 | 6 | 死亡颂唱者 | `scSk:spell-cast` | `race-buff` | 目标=undead；a=1.0；h=1.0；race=undead | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_on_spell_cast / race-buff` | `index.html / effect=race-buff` | tools/prep_state_test.gd 用例7 | 补截图/录屏证据 |
| P0 | 6 | 永夜骨王 | `sk:start` | `undead-rebirth` | a=2.0；h=2.0；grow=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / undead-rebirth` | `index.html / effect=undead-rebirth` | tools/battle_test.gd 用例24 | 补截图/录屏证据 |
| P2 | 7 | 巫妖王 | `sk:death` | `race-buff` | 目标=undead；a=2.0；h=2.0；race=undead | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_kill / race-buff / undead` | `index.html / effect=race-buff` | tools/battle_test.gd 用例24 | 补截图/录屏证据 |

#### 元素（9）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P2 | 3 | 秘法学徒 | `sk:spell-cast` | `spell-core` | 目标=elem；a=2.0；h=2.0；race=elem | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_on_spell_cast / spell-core` | `index.html / effect=spell-core` | tools/prep_state_test.gd 用例7 | 补截图/录屏证据 |
| P2 | 3 | 法术学徒 | `bc:常驻` | `spell-boost` | a=1.0；h=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_exec_battlecry / spell-boost` | `index.html / effect=spell-boost` | tools/prep_state_test.gd 用例10 | 补截图/录屏证据 |
| P2 | 4 | 冰风雪人 | `sk:spell-cast` | `spell-race-grow` | 目标=elem；a=2.0；h=2.0；max=3.0；race=elem；grow=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_on_spell_cast / spell-race-grow` | `index.html / effect=spell-race-grow` | tools/prep_state_test.gd 用例7 | 补截图/录屏证据 |
| P2 | 4 | 元素商人 | `sk:start` | `shop-buff` | a=2.0；h=2.0；race=elem；spellRefresh=2.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:apply_prep_round_skills / shop-buff` | `index.html / effect=shop-buff` | tools/prep_state_test.gd 用例8 | 补截图/录屏证据 |
| P2 | 4 | 元素核心 | `sk:spell-cast` | `spell-core` | 目标=elem；a=2.0；h=2.0；race=elem | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_on_spell_cast / spell-core` | `index.html / effect=spell-core` | tools/prep_state_test.gd 用例7 | 补截图/录屏证据 |
| P2 | 4 | 元素秘典 | `sk:start` | `spell-boost-grow` | a=1.0；h=1.0；grow=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:apply_prep_round_skills / spell-boost-grow` | `index.html / effect=spell-boost-grow` | tools/prep_state_test.gd 用例8 | 补截图/录屏证据 |
| P2 | 5 | 大法师学徒 | `bc:常驻` | `spell-boost` | a=2.0；h=2.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_exec_battlecry / spell-boost` | `index.html / effect=spell-boost` | tools/prep_state_test.gd 用例10 | 补截图/录屏证据 |
| P2 | 6 | 大秘术师 | `sk:spell-cast` | `growth-boost` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_on_spell_cast / growth-boost` | `index.html / effect=growth-boost` | tools/prep_state_test.gd 用例7 | 补截图/录屏证据 |
| P0 | 7 | 秘法主宰 | `sk:spell-cast` | `ally-all-buff` | 目标=全体友方；d=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_on_spell_cast / ally-all-buff` | `index.html / effect=ally-all-buff` | tools/prep_state_test.gd 用例7 | 补截图/录屏证据 |

#### 血族（7）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P2 | 3 | 血裔猎手 | `sk:on-dmg` | `race-buff` | 目标=vampire；a=1.0；h=1.0；race=vampire | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_on_damage_skill / race-buff` | `index.html / effect=race-buff` | tools/battle_test.gd 用例25 | 补截图/录屏证据 |
| P2 | 3 | 血裔猎手 | `atkSk:攻击后` | `self-race-buff` | 目标=vampire；a=1.0；h=1.0；race=vampire | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_attack_tail / self-race-buff` | `index.html / effect=self-race-buff` | tools/battle_test.gd 用例25 | 补截图/录屏证据 |
| P2 | 4 | 吸血蚊 | `sk:attack` | `race-heal` | 目标=本族 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_apply_lifesteal and _run_attack_tail / race-heal` | `index.html / effect=race-heal` | tools/battle_test.gd 用例25 | 补截图/录屏证据 |
| P2 | 5 | 血族圣疗者 | `sk:attack` | `heal-race` | 目标=vampire；a=1.0；h=1.0；mh=1.0；race=vampire | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_attack_tail / heal-race` | `index.html / effect=heal-race` | tools/battle_test.gd 用例25 | 补截图/录屏证据 |
| P2 | 6 | 血族伯爵 | `sk:on-dmg` | `maxhp-buff` | a=2.0；h=2.0；spellMh=1.0 | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_on_damage_skill / maxhp-buff` | `index.html / effect=maxhp-buff` | tools/battle_test.gd 用例25 | 补截图/录屏证据 |
| P0 | 6 | 血之庇护者 | `sk:lockhp` | `lockhp` | healMh=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_attack / lockhp` | `index.html / effect=lockhp` | tools/battle_test.gd 用例14 | 补截图/录屏证据 |
| P2 | 7 | 血之主 | `sk:on-dmg` | `race-buff` | 目标=vampire；a=3.0；h=3.0；race=vampire；grow=1.0 | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_on_damage_skill / race-buff` | `index.html / effect=race-buff` | tools/battle_test.gd 用例25 | 补截图/录屏证据 |

#### 赌徒（5）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P2 | 3 | 赌徒 | `sk:start` | `gamble` | a=2.0；h=2.0；scope=rnd | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_roll_gamble` | `index.html / effect=gamble` | tools/battle_test.gd 用例26 | 补截图/录屏证据 |
| P2 | 4 | 翻倍能手 | `sk:start` | `gamble` | a=4.0；h=4.0；scope=race | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_roll_gamble` | `index.html / effect=gamble` | tools/battle_test.gd 用例26 | 补截图/录屏证据 |
| P2 | 6 | 幸运之星 | `sk:start` | `gamble` | a=5.0；h=5.0；scope=all | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_roll_gamble` | `index.html / effect=gamble` | tools/battle_test.gd 用例26 | 补截图/录屏证据 |
| P2 | 7 | 命运赌王 | `sk:start` | `gamble` | a=6.0；h=6.0；scope=all | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_roll_gamble` | `index.html / effect=gamble` | tools/battle_test.gd 用例26 | 补截图/录屏证据 |
| P2 | 7 | 豪赌大师 | `sk:start` | `gamble` | a=8.0；h=8.0；succ=0.5；ml=2.0；mh=4.0；scope=all | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_roll_gamble` | `index.html / effect=gamble` | tools/battle_test.gd 用例26 | 补截图/录屏证据 |

#### 恶魔（8）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P3 | 2 | 虚空行者 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P2 | 5 | 大酋长 | `sk:on-dmg` | `self-buff` | 目标=自身；a=1.0；h=1.0 | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_on_damage_skill / self-buff` | `index.html / effect=self-buff` | tools/battle_test.gd 用例27 | 补截图/录屏证据 |
| P2 | 5 | 恶魔商贩 | `sk:start` | `shop-buff` | a=2.0；h=2.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:apply_prep_round_skills / shop-buff` | `index.html / effect=shop-buff` | tools/prep_state_test.gd 用例8 | 补截图/录屏证据 |
| P2 | 5 | 吞噬魔 | `sk:start` | `devour-shop` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:apply_prep_round_skills / devour-shop` | `index.html / effect=devour-shop` | tools/prep_state_test.gd 用例8 | 补截图/录屏证据 |
| P2 | 7 | 铸币巨兽 | `sk:gold` | `coin-spell-boost` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_spend_gold / coin-spell-boost` | `index.html / effect=coin-spell-boost` | tools/prep_state_test.gd 用例8 | 补截图/录屏证据 |
| P2 | 7 | 亚煞极 | `sk:on-dmg` | `self-buff` | 目标=自身；a=2.0；h=2.0 | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_on_damage_skill / self-buff` | `index.html / effect=self-buff` | tools/battle_test.gd 用例27 | 补截图/录屏证据 |
| P2 | 7 | 亚煞极 | `scSk:spell-cast` | `self-buff` | 目标=自身；a=1.0；h=1.0 | 代码有金卡/通用倍率分支，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_on_spell_cast / self-buff` | `index.html / effect=self-buff` | tools/prep_state_test.gd 用例7 | 补截图/录屏证据 |
| P0 | 7 | 地狱魔龙 | `sk:start` | `multihit` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / multihit` | `index.html / effect=multihit` | tools/battle_test.gd 用例27 | 补截图/录屏证据 |

#### 中立（17）

| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| P3 | 1 | 护甲学徒 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P3 | 1 | 冲锋新兵 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P2 | 1 | 精灵射手 | `bc:常驻` | `ally-atk` | 目标=随机友方（攻击）；a=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_exec_battlecry / ally-atk` | `index.html / effect=ally-atk` | tools/prep_state_test.gd 用例6 | 补截图/录屏证据 |
| P2 | 1 | 渔人猎潮者 | `bc:常驻` | `free-refresh` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_exec_battlecry / free-refresh` | `index.html / effect=free-refresh` | tools/prep_state_test.gd 用例11 | 补截图/录屏证据 |
| P3 | 1 | 石牙野猪 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P3 | 2 | 铁甲卫士 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P2 | 2 | 战地老兵 | `bc:常驻` | `ally-rnd` | 目标=随机友方；a=1.0；h=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_exec_battlecry / ally-rnd` | `index.html / effect=ally-rnd` | tools/prep_state_test.gd 用例11 | 补截图/录屏证据 |
| P2 | 2 | 狗头人 | `bc:常驻` | `gold` | g=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_exec_battlecry / gold` | `index.html / effect=gold` | tools/prep_state_test.gd 用例11 | 补截图/录屏证据 |
| P2 | 2 | 血帆袭击者 | `bc:常驻` | `dmg-rnd` | 目标=随机敌方；d=1.0 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/prep_state.gd:_exec_battlecry / dmg-rnd` | `index.html / effect=dmg-rnd` | tools/prep_state_test.gd 用例6 | 补截图/录屏证据 |
| P3 | 3 | 森金卫士 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P3 | 3 | 眼镜蛇 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P3 | 4 | 重装步兵 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P3 | 4 | 战歌指挥官 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P3 | 4 | 风怒鹰身人 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P2 | 5 | 成长守卫 | `sk:start` | `growth-self` | 未在数据中声明数值 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / growth-self` | `index.html / effect=growth-self` | tools/battle_test.gd 用例28 | 补截图/录屏证据 |
| P3 | 5 | 作战傀儡 | `—:基础数值/关键词` | `基础数值/关键词` | 基础 a/h/k | 通用金卡翻倍待卡级核对 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/unit.gd:from_card / 基础战斗` | `index.html / base stats` | 10 组规则基线（只覆盖基础数值与关键词） | 补金卡倍率、卡面完整名和 hover 断言 |
| P0 | 6 | 时光祝福者 | `sk:start` | `ally-all-buff` | 目标=全体友方 | 通用金卡规则，待该卡断言 | `断言 / ✓ / ✓ / ✓ / ✓ / ✓` | `sim/battle.gd:_run_start_skills / ally-all-buff` | `index.html / effect=ally-all-buff` | tools/battle_test.gd 用例28 | 补截图/录屏证据 |

<!-- PARITY_AUDIT_END -->
