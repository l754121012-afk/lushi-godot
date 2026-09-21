extends SceneTree
## 战斗内核自检：godot --headless --path <项目> --script res://tools/battle_test.gd
## 逐条验证核心规则（数值对抗 / 嘲讽 / 圣盾 / 进化条 / 推进器 / 基因领主）

const UnitScript := preload("res://sim/unit.gd")
const BattleScript := preload("res://sim/battle.gd")

var failures: Array[String] = []
var cases_run: int = 0

func _init() -> void:
	_case_bigger_wins()
	_case_taunt_first()
	_case_shield_blocks()
	_case_evolve_bar()
	_case_evo_advance()
	_case_gene_lord()

	_check(cases_run == 6, "有用例因脚本错误未跑完：实际执行 %d/6" % cases_run)
	if failures.is_empty():
		print("[battle_test] 通过：核心战斗规则 6/6")
		quit(0)
	else:
		for f in failures:
			printerr("[battle_test] 失败：", f)
		quit(1)

func _mk(card: Dictionary, uid: int):
	return UnitScript.from_card(card, uid)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

## 1) 数值对抗：3/3 打 2/2 应该赢
func _case_bigger_wins() -> void:
	var a = _mk({"n": "大个", "a": 3, "h": 3, "star": 2, "race": "neutral"}, 1)
	var b = _mk({"n": "小个", "a": 2, "h": 2, "star": 1, "race": "neutral"}, 2)
	var r: Dictionary = BattleScript.new().resolve([a], [b], 7)
	_check(r["winner"] == "p", "3/3 应战胜 2/2，实际 winner=%s" % r["winner"])
	print("[battle_test] 用例1 数值对抗: winner=", r["winner"], " 回合=", r["rounds"])
	cases_run += 1

## 2) 嘲讽优先：必须先打嘲讽单位
func _case_taunt_first() -> void:
	var atk = _mk({"n": "打手", "a": 2, "h": 20, "star": 2, "race": "neutral"}, 1)
	var tank = _mk({"n": "盾卫", "a": 0, "h": 10, "star": 2, "race": "neutral", "k": "t"}, 2)
	var dps = _mk({"n": "刺客", "a": 5, "h": 1, "star": 2, "race": "neutral"}, 3)
	var r: Dictionary = BattleScript.new().resolve([atk], [tank, dps], 11)
	var first_attack: Dictionary = {}
	for ev in r["events"]:
		if ev["t"] == "attack":
			first_attack = ev
			break
	# 第 1 回合敌方嘲讽还没被打掉前，玩家所有攻击都应指向嘲讽
	var first_round_targets: Array = []
	for ev in r["events"]:
		if ev["t"] == "attack" and ev["src"] == 1:
			first_round_targets.append(ev["dst"])
			break
	_check(not first_round_targets.is_empty() and first_round_targets[0] == 2,
		"嘲讽在场时应优先攻击嘲讽单位，实际打到了 %s" % str(first_round_targets))
	print("[battle_test] 用例2 嘲讽优先: 首个目标=", first_round_targets)
	cases_run += 1

## 3) 圣盾：挡掉第一次伤害
func _case_shield_blocks() -> void:
	var atk = _mk({"n": "打手", "a": 5, "h": 30, "star": 2, "race": "neutral"}, 1)
	var guard = _mk({"n": "圣盾兵", "a": 1, "h": 10, "star": 2, "race": "neutral", "k": "d"}, 2)
	var r: Dictionary = BattleScript.new().resolve([atk], [guard], 3)
	var has_shield_break := false
	var first_damage_hp := -1
	var saw_shield := false
	for ev in r["events"]:
		if ev["t"] == "shield_break" and int(ev["id"]) == 2:
			has_shield_break = true
			saw_shield = true
		elif ev["t"] == "damage" and int(ev["dst"]) == 2 and first_damage_hp < 0:
			first_damage_hp = int(ev["hp"])
	_check(has_shield_break, "圣盾应产生 shield_break 事件")
	_check(saw_shield and first_damage_hp == 5,
		"圣盾应吸掉第一击（首次数值伤害后应为 10-5=5），实际 %d" % first_damage_hp)
	print("[battle_test] 用例3 圣盾: shield_break=", has_shield_break, " 首次实伤后血量=", first_damage_hp)
	cases_run += 1

## 4) 进化条：细胞体攻击 3 次应完成一次质变（+4/+4 档）
func _case_evolve_bar() -> void:
	var cell = _mk({"n": "细胞体", "a": 10, "h": 10, "star": 1, "race": "evolve",
		"sk": {"t": "attack", "e": "evolve-step", "need": 3, "a": 4, "h": 4}}, 1)
	var bag = _mk({"n": "木桩", "a": 0, "h": 999, "star": 1, "race": "neutral"}, 2)
	var battle = BattleScript.new()
	var r: Dictionary = battle.resolve([cell], [bag], 5)
	var full_events := 0
	for ev in r["events"]:
		if ev["t"] == "evo_full":
			full_events += 1
	_check(full_events >= 1, "细胞体攻击 3 次应至少完成 1 次质变，实际 %d" % full_events)
	_check(cell.evo < 3, "质变后进化条应清零，实际 evo=%d" % cell.evo)
	print("[battle_test] 用例4 进化条: 质变次数=", full_events, " 当前 evo=", cell.evo, " 数值=", cell.atk, "/", cell.hp)
	cases_run += 1

## 5) 推进器：回合开始给全队进化随从 +1 格
func _case_evo_advance() -> void:
	var master = _mk({"n": "进化大师", "a": 5, "h": 6, "star": 6, "race": "evolve",
		"sk": {"t": "start", "e": "evo-advance", "a": 1, "h": 1}}, 1)
	var cell = _mk({"n": "细胞体", "a": 2, "h": 2, "star": 1, "race": "evolve",
		"sk": {"t": "attack", "e": "evolve-step", "need": 3, "a": 4, "h": 4}}, 2)
	var bag = _mk({"n": "木桩", "a": 0, "h": 999, "star": 1, "race": "neutral"}, 3)
	var r: Dictionary = BattleScript.new().resolve([master, cell], [bag], 9)
	# 推进器效果应发生在"第一次攻击之前"：给全队 +1/+1 并推进 1 格
	var before_first_attack: Array = []
	for ev in r["events"]:
		if ev["t"] == "attack":
			break
		before_first_attack.append(ev)
	var ticked := false
	var buffed := false
	for ev in before_first_attack:
		if ev["t"] in ["evop", "evo_full"] and int(ev.get("id", -1)) == cell.uid:
			ticked = true
		if ev["t"] == "buff" and int(ev.get("id", -1)) == cell.uid and int(ev.get("a", 0)) >= 1:
			buffed = true
	_check(ticked, "推进器应在回合开始给细胞体推进 1 格（首个攻击前应有 evop）")
	_check(buffed, "推进器应在回合开始给细胞体 +1/+1")
	_check(cell.atk > 2, "推进器后细胞体攻击应高于初始 2，实际 %d" % cell.atk)
	print("[battle_test] 用例5 推进器: 开场事件=", before_first_attack.size(), " tick=", ticked, " buff=", buffed, " 数值=", cell.atk, "/", cell.hp)
	cases_run += 1

## 6) 基因领主：己方进化随从质变时，混沌始祖永久+2/+2 且全队+1/+1
func _case_gene_lord() -> void:
	var lord = _mk({"n": "混沌始祖", "a": 20, "h": 20, "star": 7, "race": "evolve",
		"sk": {"t": "start", "e": "evo-devourer", "a": 2, "h": 2, "team": 1, "max": 5}}, 1)
	var cell = _mk({"n": "细胞体", "a": 10, "h": 10, "star": 1, "race": "evolve",
		"sk": {"t": "attack", "e": "evolve-step", "need": 3, "a": 4, "h": 4}}, 2)
	var bag = _mk({"n": "木桩", "a": 0, "h": 999, "star": 1, "race": "neutral"}, 3)
	var battle = BattleScript.new()
	battle.resolve([lord, cell], [bag], 13)
	_check(lord.atk > 22, "混沌始祖应因队友质变永久成长，实际 %d" % lord.atk)
	_check(lord.gene == 1, "混沌始祖回合开始应吞噬 1 层基因，实际 %d" % lord.gene)
	print("[battle_test] 用例6 基因领主: 混沌始祖=", lord.atk, "/", lord.hp, " 基因=", lord.gene)
	cases_run += 1
