# 迁移状态一页版

更新日期：2026-09-27

## 结论

Web 版已有机制的功能迁移已经完成。

这里的“完成”指：

- 规则、事件、卡面信息和占位表现已进入 Godot 可玩路径；
- 每个效果有规则入口或卡级断言；
- 11 个机制族有可识别的 UI、动画、音效轨迹和证据；
- 双端战斗结果继续由 parity 场景守护。

这里的“完成”不指：

- 最终美术资源已经替换；
- 机制专属音色已经制作；
- 动画节奏和玩家主观可读性已经全部验收；
- Web 充能圣盾疑似 bug 已经做产品决策。

## 当前数字

| 项目 | 当前值 |
|---|---:|
| 卡牌 | 94（含生成形态） |
| 技能字段实例 | 85 |
| 独立效果 ID | 52 |
| R断言 | 102 |
| R入口 | 0 |
| R缺 | 0 |
| 六层结构可关门 | 102/102 |
| 机制反馈契约 | 11/11 族，22 条轨迹 |
| 双端 parity | 16/16 |

## 直接核验

规则：

```powershell
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/battle_test.gd
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/prep_state_test.gd
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/ai_test.gd
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/quest_test.gd
```

界面：

```powershell
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/prep.tscn -- --interaction-test
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/prep.tscn -- --battle-anim-test
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/prep.tscn -- --families-test
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . res://scenes/prep.tscn -- --quest-test
```

审计：

```powershell
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/parity_audit.gd
```

双端 parity：

```powershell
node tools\parity_web.cjs
F:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/parity_run.gd
node tools\parity_compare.cjs
```

## 本轮新增

- 进化宣言/任务奖励接入：昼夜池、实时进度、三选一、AI 独立任务、达成 +2/未达成 +1 奖励。
- `mech_fusion_followup`：验证四部位合体、协同随从生成和跟随攻击。
- parity 提升到 `16/16`。
- 清理旧的 `△/-` 手工缺口矩阵，自动逐卡审计成为细表。
- 交接、README 和迁移底表统一为当前口径。

## 实际剩余

1. 最终 VFX、SFX、图标、稀有度边框和排版。
2. 动画节奏、粒子密度、遮挡和主观可读性。
3. Web 充能“圣盾”疑似 bug 的产品决策。
4. 新玩法、新种族、战役或多人等新内容。
