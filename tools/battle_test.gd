extends SceneTree
## 战斗内核自检：godot --headless --path <项目> --script res://tools/battle_test.gd
## 逐条验证核心规则（数值对抗 / 嘲讽 / 圣盾 / 进化条 / 推进器 / 基因领主）

const UnitScript := preload("res://sim/unit.gd")
const BattleScript := preload("res://sim/battle.gd")
const Sacrifice := preload("res://sim/sacrifice.gd")
const PrepState := preload("res://sim/prep_state.gd")

var failures: Array[String] = []
var cases_run: int = 0

func _init() -> void:
	_case_bigger_wins()
	_case_taunt_first()
	_case_shield_blocks()
	_case_evolve_bar()
	_case_evo_advance()
	_case_gene_lord()
	_case_contract_debt_event()
	_case_debt_node_jump()
	_case_skill_fields_preserved()
	_case_runtime_state_preserved()
	_case_attack_lifecycle()
	_case_enemy_retarget_after_taunt_break()
	_case_dead_slots_cleared()
	_case_damage_pipeline_order()
	_case_runtime_state_writeback()
	_case_altar_master()
	_case_eater_inherit()
	_case_warlord_debt_lord()
	_case_evolve_larva_start()
	_case_hatchling_progress()
	_case_mech_card_effects()
	_case_dragon_card_effects()
	_case_star_weaver()
	_case_undead_card_effects()
	_case_vampire_card_effects()
	_case_gambler_card_effects()
	_case_demon_card_effects()
	_case_neutral_card_effects()
	_case_persistent_side_state()
	_case_hero_attack_events()

	_check(cases_run == 30, "有用例因脚本错误未跑完：实际执行 %d/30" % cases_run)
	if failures.is_empty():
		print("[battle_test] 通过：核心战斗规则 30/30")
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
	for ev in _first_action(r["events"], 1):
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
		elif ev["t"] == "damage" and int(ev["dst"]) == 2 and int(ev.get("dmg", 0)) > 0 and first_damage_hp < 0:
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

## 7) 契印死亡：债务事件必须携带来源、原因、旧值、变化量和节点跃迁。
func _case_contract_debt_event() -> void:
	var attacker = _mk({"n": "打手", "a": 20, "h": 20, "star": 3, "race": "neutral"}, 1)
	var contract_target = _mk({"n": "契印目标", "a": 2, "h": 4, "star": 2, "race": "sacrifice"}, 2)
	var r: Dictionary = BattleScript.new().resolve(
		[contract_target], [attacker], 21, 30,
		{"round": 8, "contractP": 2, "contractBonusP": 3})
	var debt_event: Dictionary = {}
	for ev in r["events"]:
		if String(ev.get("t", "")) == "debt" and String(ev.get("reason", "")) == "contract_death":
			debt_event = ev
			break
	_check(not debt_event.is_empty(), "契印目标死亡应产生 contract_death 债务事件")
	_check(int(debt_event.get("src", -1)) == 2, "债务事件应记录契印死亡来源 uid=2")
	_check(int(debt_event.get("old", -1)) == 0 and int(debt_event.get("delta", 0)) == 4,
		"契印目标死亡应按负生命精确结算 4 点债务，实际 old=%d delta=%d" % [
			int(debt_event.get("old", -1)), int(debt_event.get("delta", 0))])
	_check(int(debt_event.get("contract_bonus", -1)) == 3,
		"债务事件应记录契印额外债务 +3")
	print("[battle_test] 用例7 契印事件: src=", debt_event.get("src", -1),
		" old=", debt_event.get("old", -1), " delta=", debt_event.get("delta", -1),
		" tier=", debt_event.get("tier", -1))
	cases_run += 1

## 8) 债务节点跃迁：7→8 时应追加 1 债务并保留完整变化信息。
func _case_debt_node_jump() -> void:
	var change: Dictionary = Sacrifice.add_debt(7, 1)
	_check(int(change["old"]) == 7, "债务节点测试旧值应为 7")
	_check(int(change["new"]) == 9, "7+1 跨过 8 点节点后应追加 1，实际 %d" % int(change["new"]))
	_check(int(change["tier"]) == 1, "跨过 8 点后应进入债务一档")
	_check(change["node_rewards"] == [1], "应记录节点奖励 [1]，实际 %s" % str(change["node_rewards"]))
	print("[battle_test] 用例8 债务节点: 7+1 -> ", change["new"],
		" 档位=", change["tier"], " 节点奖励=", change["node_rewards"])
	cases_run += 1

## 9) 卡牌四类技能字段必须全部进入战斗单位，不能再只保留 sk/bc。
func _case_skill_fields_preserved() -> void:
	var u = _mk({
		"n": "字段保真", "a": 3, "h": 4, "s": 5, "race": "dragon",
		"sk": {"t": "attack", "e": "evolve-step"},
		"bc": {"e": "gold", "g": 2},
		"sc": {"t": "spell-cast", "e": "self-growth-boost", "times": 3},
		"scSk": {"t": "spell-cast", "e": "self-buff", "a": 2, "h": 2},
		"atkSk": {"e": "self-race-buff", "race": "dragon", "a": 1, "h": 1},
	}, 91)
	_check(String(u.skill.get("e", "")) == "evolve-step", "from_card 未保留 sk")
	_check(String(u.battlecry.get("e", "")) == "gold", "from_card 未保留 bc")
	_check(String(u.spell_skill.get("e", "")) == "self-growth-boost", "from_card 未保留 sc")
	_check(String(u.spell_cast_skill.get("e", "")) == "self-buff", "from_card 未保留 scSk")
	_check(String(u.attack_skill.get("e", "")) == "self-race-buff", "from_card 未保留 atkSk")
	print("[battle_test] 用例9 技能字段保真: sk/bc/sc/scSk/atkSk 全部保留")
	cases_run += 1

## 10) 备战期写入的运行态必须跨入战斗，不能被重建单位时清零。
func _case_runtime_state_preserved() -> void:
	var u = _mk({
		"n": "运行态保真", "a": 2, "h": 2, "s": 3, "race": "evolve",
		"_t": 2, "_g": 3, "_gb": 4, "_dHit": 5, "_mhT": 6, "_iceT": 7,
		"_coreT": 8, "_atkT": 9, "_di": 10, "_udBase": 11, "_hit": 12, "_pr": 4,
	}, 92)
	_check(u._t == 2 and u._g == 3 and u._gb == 4, "from_card 未保留成长运行态 _t/_g/_gb")
	_check(u._dHit == 5 and u._atkT == 9, "from_card 未保留受击/攻击反应计数")
	_check(u._iceT == 7 and u._coreT == 8, "from_card 未保留元素施法运行态")
	_check(u._di == 10 and u._udBase == 11 and u._hit == 12 and u._pr == 4,
		"from_card 未保留债务/亡灵/多次攻击/孵化运行态")
	print("[battle_test] 用例10 运行态保真: _t/_g/_gb/_dHit/_atkT/_iceT/_coreT/_di/_udBase/_hit/_pr 全部保留")
	cases_run += 1

## 11) 攻击生命周期：风怒 + 额外攻击次数、剧毒仅首挥、首挥致死后重选目标、攻击尾部只跑一次
func _case_attack_lifecycle() -> void:
	# 风怒 + _extraAtk=2 → 一次行动 4 次挥击
	var wf = _mk({"n": "风怒机", "a": 1, "h": 30, "star": 2, "race": "neutral", "k": "w", "_extraAtk": 2}, 1)
	var wall = _mk({"n": "高墙", "a": 0, "h": 200, "star": 3, "race": "neutral"}, 2)
	var swings := 0
	var r: Dictionary = BattleScript.new().resolve([wf], [wall], 17, 10)
	for ev in _first_action(r["events"], 1):
		if ev["t"] == "attack" and int(ev["src"]) == 1:
			swings += 1
	_check(swings == 4, "风怒 + 额外攻击应共 4 次挥击，实际 %d" % swings)

	# 剧毒仅首挥：第一次中毒击杀，第二次仍按普通伤害
	var poisoner = _mk({"n": "毒刃", "a": 7, "h": 30, "star": 2, "race": "neutral", "k": "pw"}, 3)
	var first = _mk({"n": "先手", "a": 0, "h": 6, "star": 2, "race": "neutral"}, 4)
	var second = _mk({"n": "后手", "a": 0, "h": 10, "star": 2, "race": "neutral"}, 5)
	var r2: Dictionary = BattleScript.new().resolve([poisoner], [first, second], 19, 10)
	var poison_hits := 0
	for ev in _first_action(r2["events"], 3):
		if ev["t"] == "poison":
			poison_hits += 1
	_check(poison_hits == 1, "剧毒应只在首挥触发，实际 %d 次" % poison_hits)

	# 首挥致死后，下一挥必须重新选目标：圣盾嘲讽承伤后死亡，第二挥应打到另一只
	var striker = _mk({"n": "破盾者", "a": 9, "h": 30, "star": 2, "race": "neutral", "k": "w"}, 6)
	var taunt = _mk({"n": "残盾卫", "a": 0, "h": 5, "star": 1, "race": "neutral", "k": "t"}, 7)
	var other = _mk({"n": "旁观者", "a": 0, "h": 20, "star": 2, "race": "neutral"}, 8)
	var r3: Dictionary = BattleScript.new().resolve([striker], [taunt, other], 23, 1)
	var attack_targets: Array = []
	for ev in _first_action(r3["events"], 6):
		if ev["t"] == "attack" and int(ev["src"]) == 6:
			attack_targets.append(int(ev["dst"]))
	_check(attack_targets.size() >= 2 and attack_targets[0] == 7 and attack_targets.has(8),
		"首挥致死后下一挥应重新选目标，实际 %s" % str(attack_targets))

	# 攻击尾部钩子只执行一次：星灵随从攻击后连锁 +1（不是每挥 +1）
	var star = _mk({"n": "星灵", "a": 2, "h": 40, "star": 2, "race": "star"}, 9)
	var echo_bag = _mk({"n": "回响木桩", "a": 0, "h": 300, "star": 3, "race": "neutral"}, 10)
	var battle = BattleScript.new()
	battle.resolve([star], [echo_bag], 29, 1)
	_check(int(battle.chain["p"]) == 1, "星灵攻击尾部应只执行一次（连锁 = 1），实际 %d" % int(battle.chain["p"]))
	print("[battle_test] 用例11 攻击生命周期: 挥击=", swings, " 剧毒=", poison_hits,
		" 目标序列=", attack_targets, " 连锁=", int(battle.chain["p"]))
	cases_run += 1

## 12) 敌方风怒重选目标：打掉嘲讽后应优先回到刚才行动的我方随从。
func _case_enemy_retarget_after_taunt_break() -> void:
	var ok := true
	var sample: Array = []
	for seed_value in range(1, 21):
		var actor = _mk({"n": "我方行动者", "a": 0, "h": 30, "star": 2, "race": "neutral"}, 1)
		var taunt = _mk({"n": "我方嘲讽", "a": 0, "h": 30, "star": 2, "race": "neutral", "k": "t"}, 2)
		var enemy = _mk({"n": "敌方风怒", "a": 1, "h": 30, "star": 2, "race": "neutral", "k": "w"}, 3)
		var r: Dictionary = BattleScript.new().resolve([actor, taunt], [enemy], seed_value, 3)
		var targets: Array = []
		for ev in _first_action(r["events"], 3):
			if ev["t"] == "attack" and int(ev["src"]) == 3:
				targets.append(int(ev["dst"]))
		if targets.size() != 2 or targets[0] != 2 or targets[1] != 1:
			ok = false
			sample = targets
			break
	_check(ok, "敌方第二挥应在嘲讽破后回到刚行动的我方随从，实际 %s" % str(sample))
	print("[battle_test] 用例12 敌方重选目标: 20 个种子全部回到行动者")
	cases_run += 1

## 13) 死亡单位必须从返回棋盘槽位移除，不能留下 h<=0 的对象。
func _case_dead_slots_cleared() -> void:
	var striker = _mk({"n": "连击者", "a": 5, "h": 30, "star": 2, "race": "neutral", "k": "w"}, 1)
	var dead = _mk({"n": "将死嘲讽", "a": 0, "h": 1, "star": 1, "race": "neutral", "k": "t"}, 2)
	var survivor = _mk({"n": "幸存者", "a": 0, "h": 20, "star": 2, "race": "neutral"}, 3)
	var r: Dictionary = BattleScript.new().resolve([striker], [dead, survivor], 7, 1)
	var board: Array = r["e_board"]
	var stale_dead := false
	for u in board:
		if u != null and not bool(u.alive):
			stale_dead = true
	_check(board[0] == null, "首挥致死的单位应立即从返回棋盘清空")
	_check(board[1] != null and bool(board[1].alive), "幸存者应保留在棋盘")
	_check(not stale_dead, "返回棋盘不应残留 dead 对象")
	print("[battle_test] 用例13 死亡槽位: slot0=null 幸存者=", board[1] != null, " 残留死亡=", stale_dead)
	cases_run += 1

## 14) 受击流水线：锁血→护甲→扣血→充能→合体成长→受击技→吸血。
func _case_damage_pipeline_order() -> void:
	var attacker = _mk({"n": "吸血打手", "a": 9, "h": 5, "mh": 30, "star": 2, "race": "neutral", "k": "l"}, 1)
	var target = _mk({
		"n": "流水线目标", "a": 0, "h": 20, "star": 2, "race": "mech",
		"battleArmor": 2, "chargeMax": 1, "chargeFx": "heal",
		"_mechDmgGrow": 1,
		"sk": {"t": "on-dmg", "e": "self-buff", "a": 1, "h": 1},
	}, 2)
	var r: Dictionary = BattleScript.new().resolve([attacker], [target], 11, 1)
	var events: Array = _first_action(r["events"], 1)
	var order: Array[String] = []
	for ev in events:
		var kind := String(ev.get("t", ""))
		var source := String(ev.get("source", ""))
		if kind == "armor":
			order.append("armor")
		elif kind == "damage" and int(ev.get("dst", -1)) == 2:
			order.append("damage")
		elif kind == "ch":
			if order.is_empty() or order[order.size() - 1] != "charge":
				order.append("charge")
		elif kind == "buff" and source == "mech_dmg":
			order.append("mech_growth")
		elif kind == "buff" and source == "on_dmg":
			order.append("on_dmg")
		elif kind == "heal" and int(ev.get("id", -1)) == 1:
			order.append("lifesteal")
			break
	var expected: Array[String] = ["armor", "damage", "charge", "mech_growth", "on_dmg", "lifesteal"]
	_check(order == expected, "受击流水线顺序应为 %s，实际 %s" % [str(expected), str(order)])

	var locked = _mk({"n": "血之庇护者", "a": 0, "h": 5, "mh": 20, "star": 3, "race": "vampire",
		"battleArmor": 1, "sk": {"t": "on-dmg", "e": "lockhp"}}, 4)
	var hitter = _mk({"n": "十攻", "a": 10, "h": 20, "star": 3, "race": "neutral"}, 5)
	var lr: Dictionary = BattleScript.new().resolve([hitter], [locked], 13, 1)
	var actual_damage := -1
	for ev in lr["events"]:
		if ev["t"] == "damage" and int(ev.get("dst", -1)) == 4:
			actual_damage = int(ev.get("dmg", -1))
			break
	_check(actual_damage == 6, "锁血应将 10 降到 7，再被 1 点护甲吸收到 6，实际 %d" % actual_damage)
	print("[battle_test] 用例14 受击流水线: ", order, " 锁血后实伤=", actual_damage)
	cases_run += 1

## 15) 运行态可从 Unit 写回卡牌，再由 PrepState 映射到原槽位。
func _case_runtime_state_writeback() -> void:
	var card := {"n": "运行态写回", "a": 2, "h": 2, "mh": 2, "star": 3, "race": "evolve",
		"_t": 2, "_g": 3, "_gb": 4, "_mhT": 1, "_iceT": 2, "_coreT": 3,
		"_hit": 2, "_pr": 4, "_sc": 1, "_srT": 1, "_healT": 1, "_hT": 1, "_ev": 2,
		"_atkLeft": 4, "_extraAtk": 2, "_skipOnce": false, "_noTurn": false, "_phase": 0,
		"_atkDone": false, "_poisonAtk": false, "_dAtk": 0, "_phA": 1, "_phH": 2,
		"evo": 1, "vd": 1, "vc": 2, "gene": 3, "_gene": 3,
		"charge": 1, "_charge": 1, "_mechHeadGrow": 3, "_mechDmgGrow": 4,
		"_headDouble": true, "_repair": 2}
	var u: Variant = _mk(card, 1)
	u.set("atk", 9)
	u.set("hp", 11)
	u.set("max_hp", 14)
	u.set("_t", 7)
	u.set("_g", 8)
	u.set("_gb", 5)
	u.set("_mhT", 6)
	u.set("_iceT", 7)
	u.set("_coreT", 8)
	u.set("_di", 9)
	u.set("_udBase", 10)
	u.set("_hit", 11)
	u.set("_pr", 5)
	u.set("_sc", 12)
	u.set("_srT", 13)
	u.set("_healT", 14)
	u.set("_hT", 15)
	u.set("_ev", 16)
	u.set("_atkLeft", 1)
	u.set("_extraAtk", 9)
	u.set("_skipOnce", true)
	u.set("_noTurn", true)
	u.set("_phase", 1)
	u.set("_atkDone", true)
	u.set("_poisonAtk", true)
	u.set("_dAtk", 3)
	u.set("_phA", 9)
	u.set("_phH", 9)
	u.set("shield", true)
	u.set("taunt_active", true)
	u.set("alive", false)
	u.set("evo", 2)
	u.set("vd", 3)
	u.set("vc", 4)
	u.set("gene", 5)
	u.set("charge", 6)
	u.set("mech_head_grow", 7)
	u.set("mech_dmg_grow", 6)
	u.set("head_double", true)
	u.set("repair", 9)
	UnitScript.sync_runtime_to_card(card, u)
	var ps = PrepState.new()
	ps.board = [null, null, null, null, null, null, null]
	ps.board[0] = card
	u.set("alive", true)
	var copied: int = ps.sync_runtime_from_units([u], 1)
	var restored = _mk(card, 2)
	_check(copied == 1, "PrepState 应写回 1 张卡，实际 %d" % copied)
	_check(restored.atk == 9 and restored.hp == 14 and restored.max_hp == 14,
		"攻击/生命/最大生命写回失败，实际 %d/%d/%d" % [restored.atk, restored.hp, restored.max_hp])
	_check(restored._t == 7 and restored._g == 8 and restored._gb == 5, "永久成长 _t/_g/_gb 写回失败")
	_check(restored._mhT == 6 and restored._iceT == 7 and restored._coreT == 8,
		"元素与最大生命运行态写回失败")
	_check(restored._di == 9 and restored._udBase == 10 and restored._hit == 11,
		"债务/亡灵/多次攻击运行态写回失败")
	_check(restored._pr == 5 and restored._sc == 12 and restored._srT == 13
		and restored._healT == 14 and restored._hT == 15 and restored._ev == 16,
		"孵化/法术/进化累计运行态写回失败")
	_check(restored.evo == 2 and restored.vd == 3 and restored.vc == 4
		and restored.gene == 5 and restored.charge == 6,
		"进化/基因/充能运行态写回失败")
	_check(restored.mech_head_grow == 7 and restored.mech_dmg_grow == 6
		and restored.head_double and restored.repair == 9,
		"机械成长运行态写回失败")
	_check(int(card.get("_atkLeft", -1)) == 4 and int(card.get("_extraAtk", -1)) == 2
		and not bool(card.get("_skipOnce", true)) and not bool(card.get("_noTurn", true))
		and int(card.get("_phase", -1)) == 0,
		"本场攻击/跳过/相位状态被错误持久化")
	_check(not card.has("alive") and not card.has("shield") and not card.has("taunt_active"),
		"死亡、圣盾或临时嘲讽被错误持久化")

	u.set("card_name", "混沌始祖")
	u.set("star", 7)
	u.set("race", "evolve")
	u.set("skill", {"t": "start", "e": "evo-devourer", "a": 2, "h": 2})
	u.set("spell_skill", {"t": "spell-cast", "e": "self-growth-boost"})
	u.set("max_hp", 23)
	u.set("hp", 23)
	UnitScript.sync_runtime_to_card(card, u)
	_check(String(card.get("n", "")) == "混沌始祖" and int(card.get("s", 0)) == 7
		and int(card.get("mh", 0)) == 23 and String(card.get("sk", {}).get("e", "")) == "evo-devourer"
		and String(card.get("sc", {}).get("e", "")) == "self-growth-boost",
		"孵化替换形态的名称/星级/技能没有同步回备战卡牌")

	var dead_card := {"n": "死亡不写回", "a": 4, "h": 5, "mh": 6}
	var dead_u: Variant = _mk(dead_card, 1)
	dead_u.set("alive", false)
	dead_u.set("atk", 99)
	dead_u.set("hp", 0)
	dead_u.set("max_hp", 99)
	ps.board[0] = dead_card
	var dead_copied: int = ps.sync_runtime_from_units([dead_u], 1)
	_check(dead_copied == 0 and int(dead_card["a"]) == 4 and int(dead_card["h"]) == 5
		and int(dead_card["mh"]) == 6,
		"阵亡随从的运行态被错误写回备战卡牌")
	print("[battle_test] 用例15 运行态写回: a=", restored.atk, " h/mh=", restored.hp, "/",
		restored.max_hp, " _pr=", restored._pr, " evo=", restored.evo, " copied=", copied)
	cases_run += 1

## 16) 祭坛大师：按上回合死亡数给献祭成长，并可按债务节点结算。
func _case_altar_master() -> void:
	var altar = _mk({
		"n": "祭坛大师", "a": 6, "h": 6, "star": 6, "race": "sacrifice",
		"sk": {"t": "start", "e": "death-race-buff", "race": "sacrifice", "a": 1, "h": 1, "debtMax": 1},
	}, 1)
	var ally = _mk({"n": "献祭盟友", "a": 2, "h": 2, "star": 2, "race": "sacrifice"}, 2)
	var bag = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 3)
	BattleScript.new().resolve([altar, ally], [bag], 31, 1,
		{"round": 10, "prevDeathTickP": 3, "debtP": 0})
	_check(altar.atk == 7 and altar.hp == 7, "祭坛大师应按 3 次死亡获得 +1/+1，实际 %d/%d" % [altar.atk, altar.hp])
	_check(ally.atk == 3 and ally.hp == 3, "祭坛大师应给其他献祭 +1/+1，实际 %d/%d" % [ally.atk, ally.hp])

	var pay_altar = _mk({
		"n": "祭坛大师", "a": 6, "h": 6, "star": 6, "race": "sacrifice",
		"sk": {"t": "start", "e": "death-race-buff", "race": "sacrifice", "a": 1, "h": 1, "debtMax": 1},
	}, 4)
	var pay_ally = _mk({"n": "献祭盟友", "a": 2, "h": 2, "star": 2, "race": "sacrifice"}, 5)
	var bag2 = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 6)
	var r: Dictionary = BattleScript.new().resolve([pay_altar, pay_ally], [bag2], 37, 1,
		{"round": 10, "prevDeathTickP": 3, "debtP": 8})
	var settled := false
	for ev in r["events"]:
		if ev["t"] == "debt_settle" and String(ev.get("reason", "")) == "payoff":
			settled = true
	_check(settled and int(r["debt_p"]) == 0, "祭坛大师债务节点应结算 8 点债务")
	print("[battle_test] 用例16 祭坛大师: +1/+1, 债务结算=", settled, " debt=", int(r["debt_p"]))
	cases_run += 1

## 17) 食骸者：友方死亡按 4.45% 实时继承，至少 +1/+1。
func _case_eater_inherit() -> void:
	var eater = _mk({
		"n": "食骸者", "a": 4, "h": 6, "star": 6, "race": "sacrifice",
		"sk": {"t": "death", "e": "inherit", "times": 1, "rate": 0.0445, "debt": 0.055},
	}, 1)
	var victim = _mk({"n": "献祭品", "a": 100, "h": 50, "star": 4, "race": "sacrifice"}, 2)
	var battle = BattleScript.new()
	battle._kill(victim, "p", {"p": [eater, victim], "e": []})
	_check(eater.atk == 8 and eater.hp == 8,
		"食骸者应按 100/50 的 4.45%% 继承 +4/+2，实际 %d/%d" % [eater.atk, eater.hp])
	print("[battle_test] 用例17 食骸者: ", eater.atk, "/", eater.hp)
	cases_run += 1

## 18) 万灵之主：债务二档时给全献祭 +4/+4。
func _case_warlord_debt_lord() -> void:
	var lord = _mk({
		"n": "万灵之主", "a": 6, "h": 6, "star": 7, "race": "sacrifice",
		"sk": {"t": "start", "e": "debt-lord", "a": 4, "h": 4},
	}, 1)
	var ally = _mk({"n": "献祭盟友", "a": 2, "h": 2, "star": 2, "race": "sacrifice"}, 2)
	var bag = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 3)
	BattleScript.new().resolve([lord, ally], [bag], 41, 1, {"round": 10, "debtP": 18})
	_check(lord.atk == 10 and lord.hp == 10, "万灵之主二档债务应 +4/+4，实际 %d/%d" % [lord.atk, lord.hp])
	_check(ally.atk == 6 and ally.hp == 6, "万灵之主应给全献祭 +4/+4，实际 %d/%d" % [ally.atk, ally.hp])
	print("[battle_test] 用例18 万灵之主: ", lord.atk, "/", lord.hp, " ally=", ally.atk, "/", ally.hp)
	cases_run += 1

## 19) 进化幼体：开局推进 1 格并即时 +1/+1。
func _case_evolve_larva_start() -> void:
	var larva = _mk({
		"n": "进化幼体", "a": 2, "h": 2, "star": 3, "race": "evolve",
		"sk": {"t": "start", "e": "evolve", "need": 2, "maxD": 3, "a": 2, "h": 2},
	}, 1)
	var bag = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 2)
	var r: Dictionary = BattleScript.new().resolve([larva], [bag], 43, 1, {"phaseP": 2})
	var evop := false
	for ev in r["events"]:
		if ev["t"] == "evop" and int(ev.get("id", -1)) == 1:
			evop = true
	_check(evop and larva.evo == 1 and larva.atk == 3 and larva.hp == 3,
		"进化幼体开局应推进 1 格并 +1/+1，实际 evo=%d %d/%d" % [larva.evo, larva.atk, larva.hp])
	print("[battle_test] 用例19 进化幼体: evo=", larva.evo, " ", larva.atk, "/", larva.hp)
	cases_run += 1

## 20) 孵化体：胜利进度满 5 后蜕变为混沌始祖并继承基因层。
func _case_hatchling_progress() -> void:
	var hatch = _mk({
		"n": "孵化体", "a": 4, "h": 20, "star": 3, "race": "evolve",
		"sk": {"t": "battle", "e": "progress", "times": 1}, "_pr": 4,
	}, 1)
	var weak = _mk({"n": "弱敌", "a": 0, "h": 1, "star": 1, "race": "neutral"}, 2)
	var r: Dictionary = BattleScript.new().resolve([hatch], [weak], 47, 3)
	var evolved = r["p_board"][0]
	_check(r["winner"] == "p", "孵化体场景应胜利")
	_check(evolved != null and String(evolved.card_name) == "混沌始祖" and evolved.gene == 5,
		"孵化体满 5 进度应蜕变为混沌始祖并继承 5 层基因")
	print("[battle_test] 用例20 孵化体: ", evolved.card_name if evolved != null else "null",
		" gene=", evolved.gene if evolved != null else -1)
	cases_run += 1

## 21) 机械逐卡：攻击后本族成长、泰坦覆足受击共鸣、推进肢体自成长。
func _case_mech_card_effects() -> void:
	for card_name in ["核心学徒", "磁能臂", "磁暴重臂", "统御核心"]:
		var mech = _mk({"n": card_name, "a": 2, "h": 30, "star": 6, "race": "mech",
			"k": "w" if card_name == "磁能臂" else "",
			"atkSk": {"e": "self-race-buff", "race": "mech", "a": 1, "h": 1}}, 1)
		var ally = _mk({"n": "机械盟友", "a": 0, "h": 10, "star": 2, "race": "mech"}, 2)
		var bag = _mk({"n": "木桩", "a": 0, "h": 200, "star": 1, "race": "neutral"}, 3)
		BattleScript.new().resolve([mech, ally], [bag], 53, 1, {"phaseP": 2})
		_check(mech.atk == 3 and mech.hp == 31, "%s 攻击后自身应 +1/+1，实际 %d/%d" % [
			card_name, mech.atk, mech.hp])
		_check(ally.atk == 1 and ally.hp == 11, "%s 攻击后全机械应 +1/+1，实际 %d/%d" % [
			card_name, ally.atk, ally.hp])

	var titan = _mk({"n": "泰坦覆足", "a": 3, "h": 30, "star": 7, "race": "mech",
		"sk": {"t": "on-dmg", "e": "race-buff", "race": "mech", "a": 3, "h": 3}}, 4)
	var titan_ally = _mk({"n": "机械盟友", "a": 0, "h": 10, "star": 2, "race": "mech"}, 5)
	var hitter = _mk({"n": "打手", "a": 1, "h": 200, "star": 1, "race": "neutral"}, 6)
	BattleScript.new().resolve([titan, titan_ally], [hitter], 59, 2, {"phaseP": 2})
	_check(titan.atk >= 4 and titan_ally.atk >= 1,
		"泰坦覆足受击后应给全机械至少 +3/+3")

	var limb = _mk({"n": "推进肢体", "a": 2, "h": 30, "star": 3, "race": "mech",
		"sk": {"t": "on-dmg", "e": "self-buff", "a": 1, "h": 2}}, 7)
	var hitter2 = _mk({"n": "打手", "a": 1, "h": 200, "star": 1, "race": "neutral"}, 8)
	BattleScript.new().resolve([limb], [hitter2], 61, 2, {"phaseP": 2})
	_check(limb.atk >= 3 and limb.hp >= 32, "推进肢体受击应至少 +1/+2，实际 %d/%d" % [limb.atk, limb.hp])
	print("[battle_test] 用例21 机械逐卡: 攻击后本族 / 泰坦覆足 / 推进肢体 通过")
	cases_run += 1

## 22) 龙族逐卡：成长、龙威、龙威号角、攻击反应与受击成长。
func _case_dragon_card_effects() -> void:
	var arcane = _mk({"n": "秘法巨龙", "a": 10, "h": 14, "star": 7, "race": "dragon",
		"sk": {"t": "start", "e": "growth-self", "times": 4}}, 1)
	var bag1 = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 2)
	BattleScript.new().resolve([arcane], [bag1], 67, 1, {"phaseP": 2})
	_check(arcane._g == 4 and arcane.atk == 14 and arcane.hp == 18,
		"秘法巨龙开局应成长 +4/+4，实际 _g=%d %d/%d" % [arcane._g, arcane.atk, arcane.hp])

	var green = _mk({"n": "绿龙", "a": 8, "h": 14, "star": 6, "race": "dragon",
		"sk": {"t": "start", "e": "dragon-aura", "times": 2}}, 3)
	var dragon_ally = _mk({"n": "龙盟友", "a": 3, "h": 3, "star": 3, "race": "dragon"}, 4)
	var bag2 = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 5)
	var green_battle = BattleScript.new()
	green_battle.resolve([green, dragon_ally], [bag2], 71, 1, {"phaseP": 2})
	_check(green.atk == 12 and green.hp == 18 and dragon_ally.atk == 7 and dragon_ally.hp == 7,
		"绿龙二层龙威应给两只龙 +4/+4，实际 %d/%d 和 %d/%d" % [
			green.atk, green.hp, dragon_ally.atk, dragon_ally.hp])

	var horn = _mk({"n": "龙威号角", "a": 12, "h": 12, "star": 6, "race": "dragon",
		"sk": {"t": "start", "e": "dragon-aura-minor", "a": 1, "h": 1}}, 6)
	var horn_ally = _mk({"n": "龙盟友", "a": 3, "h": 3, "star": 3, "race": "dragon"}, 7)
	var bag3 = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 8)
	BattleScript.new().resolve([horn, horn_ally], [bag3], 73, 1, {"phaseP": 2})
	_check(horn.atk == 13 and horn_ally.atk == 4,
		"龙威号角无龙威层时至少给全龙 +1/+1，实际 %d/%d" % [horn.atk, horn_ally.atk])

	var attacker = _mk({"n": "普通龙", "a": 2, "h": 30, "star": 3, "race": "dragon"}, 9)
	var watcher = _mk({"n": "龙袭卫士", "a": 10, "h": 14, "star": 7, "race": "dragon",
		"sk": {"t": "aura", "e": "atk-react", "a": 2, "h": 2}}, 10)
	var bag4 = _mk({"n": "木桩", "a": 0, "h": 200, "star": 1, "race": "neutral"}, 11)
	BattleScript.new().resolve([attacker, watcher], [bag4], 79, 1, {"phaseP": 2})
	_check(watcher.atk == 12 and watcher.hp == 16,
		"龙袭卫士首次攻击反应应 +2/+2，实际 %d/%d" % [watcher.atk, watcher.hp])

	var raider = _mk({"n": "龙裔突击者", "a": 3, "h": 4, "star": 4, "race": "dragon",
		"sk": {"t": "attack", "e": "race-buff", "race": "dragon", "a": 1, "h": 1}}, 12)
	var raider_ally = _mk({"n": "龙盟友", "a": 3, "h": 3, "star": 3, "race": "dragon"}, 13)
	var bag5 = _mk({"n": "木桩", "a": 0, "h": 200, "star": 1, "race": "neutral"}, 14)
	BattleScript.new().resolve([raider, raider_ally], [bag5], 83, 1, {"phaseP": 2})
	_check(raider.atk == 4 and raider_ally.atk == 4,
		"龙裔突击者攻击后应给全龙 +1/+1，实际 %d/%d" % [raider.atk, raider_ally.atk])

	var wall = _mk({"n": "龙鳞壁垒", "a": 12, "h": 30, "star": 6, "race": "dragon", "k": "t",
		"sk": {"t": "on-dmg", "e": "self-buff", "a": 1, "h": 2, "grow": 1, "regenTaunt": 1}}, 15)
	var hitter = _mk({"n": "打手", "a": 1, "h": 200, "star": 1, "race": "neutral"}, 16)
	BattleScript.new().resolve([wall], [hitter], 89, 2, {"phaseP": 2})
	_check(wall.atk >= 13 and wall.hp >= 32,
		"龙鳞壁垒受击应至少 +1/+2，实际 %d/%d" % [wall.atk, wall.hp])
	print("[battle_test] 用例22 龙族逐卡: 成长/龙威/号角/反应/突击/壁垒 通过")
	cases_run += 1

## 23) 星辰编织者：开局连锁+1，并给全星灵 +当前连锁×0.5。
func _case_star_weaver() -> void:
	var weaver = _mk({"n": "星辰编织者", "a": 6, "h": 7, "star": 6, "race": "star",
		"sk": {"t": "start", "e": "race-buff", "race": "star", "a": 2, "h": 2, "grow": 1, "statScale": 0.5}}, 1)
	var star_ally = _mk({"n": "星灵盟友", "a": 3, "h": 3, "star": 3, "race": "star"}, 2)
	var bag = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 3)
	var battle = BattleScript.new()
	battle.resolve([weaver, star_ally], [bag], 97, 0, {"phaseP": 2})
	_check(int(battle.chain["p"]) == 1 and weaver.atk == 7 and star_ally.atk == 4,
		"星辰编织者应连锁+1并给全星灵 +1/+1，实际 chain=%d weaver=%d ally=%d" % [
			int(battle.chain["p"]), weaver.atk, star_ally.atk])
	print("[battle_test] 用例23 星辰编织者: chain=", int(battle.chain["p"]),
		" weaver=", weaver.atk, "/", weaver.hp)
	cases_run += 1

## 24) 亡灵逐卡：召唤、亡语成长、随机成长、死亡召唤与开局重生。
func _case_undead_card_effects() -> void:
	var apprentice = _mk({"n": "亡灵学徒", "a": 2, "h": 2, "star": 2, "race": "undead",
		"sk": {"t": "death", "e": "summon", "count": 1}}, 1)
	var apprentice_board: Array = [apprentice, null, null]
	BattleScript.new()._kill(apprentice, "p", {"p": apprentice_board, "e": []})
	_check(_count_name(apprentice_board, "骷髅兵") == 1,
		"亡灵学徒应召唤 1 个骷髅兵，实际 %d" % _count_name(apprentice_board, "骷髅兵"))

	var summoner = _mk({"n": "骷髅召唤者", "a": 3, "h": 4, "star": 5, "race": "undead",
		"sk": {"t": "death", "e": "summon", "count": 2}}, 2)
	var summon_board: Array = [summoner, null, null, null]
	BattleScript.new()._kill(summoner, "p", {"p": summon_board, "e": []})
	_check(_count_name(summon_board, "骷髅兵") == 2,
		"骷髅召唤者应召唤 2 个骷髅兵，实际 %d" % _count_name(summon_board, "骷髅兵"))

	var priest = _mk({"n": "苦痛侍僧", "a": 1, "h": 10, "star": 5, "race": "undead",
		"sk": {"t": "start", "e": "dmg-allies", "d": 1, "times": 1}}, 3)
	var priest_ally = _mk({"n": "亡灵盟友", "a": 1, "h": 2, "star": 2, "race": "undead"}, 4)
	var bag1 = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 5)
	BattleScript.new().resolve([priest, priest_ally], [bag1], 101, 0, {"phaseP": 2})
	_check(priest.hp == 10 and priest_ally.hp == 1,
		"苦痛侍僧应只伤害其他友方，实际 self=%d ally=%d" % [priest.hp, priest_ally.hp])

	var zombie = _mk({"n": "瘟疫僵尸", "a": 3, "h": 3, "star": 4, "race": "undead",
		"sk": {"t": "death", "e": "rnd-race-buff", "race": "undead", "a": 1, "h": 1}}, 6)
	var z_ally = _mk({"n": "亡灵盟友", "a": 1, "h": 1, "star": 2, "race": "undead"}, 7)
	BattleScript.new()._kill(zombie, "p", {"p": [zombie, z_ally], "e": []})
	_check(z_ally.atk >= 2 and z_ally.hp >= 2,
		"瘟疫僵尸亡语应至少给亡灵 +2/+2，实际 %d/%d" % [z_ally.atk, z_ally.hp])

	var lich = _mk({"n": "巫妖王", "a": 8, "h": 8, "star": 7, "race": "undead",
		"sk": {"t": "death", "e": "race-buff", "race": "undead", "a": 2, "h": 2}}, 8)
	var lich_ally = _mk({"n": "亡灵盟友", "a": 1, "h": 1, "star": 2, "race": "undead"}, 9)
	BattleScript.new()._kill(lich, "p", {"p": [lich, lich_ally], "e": []})
	_check(lich_ally.atk >= 3 and lich_ally.hp >= 3,
		"巫妖王亡语应至少给亡灵 +3/+3，实际 %d/%d" % [lich_ally.atk, lich_ally.hp])

	var singer = _mk({"n": "死亡颂唱者", "a": 6, "h": 7, "star": 6, "race": "undead",
		"sk": {"t": "death", "e": "race-buff", "race": "undead", "a": 1, "h": 1, "sum": "general"}}, 10)
	var singer_ally = _mk({"n": "亡灵盟友", "a": 1, "h": 1, "star": 2, "race": "undead"}, 11)
	var singer_board: Array = [singer, singer_ally, null, null]
	BattleScript.new()._kill(singer, "p", {"p": singer_board, "e": []})
	_check(_count_name(singer_board, "骷髅将军") == 1, "死亡颂唱者亡语应召唤骷髅将军")
	_check(singer_ally.atk >= 2, "死亡颂唱者亡语应给亡灵成长")

	var king = _mk({"n": "永夜骨王", "a": 6, "h": 6, "star": 6, "race": "undead",
		"sk": {"t": "start", "e": "undead-rebirth", "a": 2, "h": 2, "grow": 1}}, 12)
	var king_ally = _mk({"n": "亡灵盟友", "a": 1, "h": 1, "star": 2, "race": "undead"}, 13)
	var bag2 = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 14)
	BattleScript.new().resolve([king, king_ally], [bag2], 103, 0, {"phaseP": 2})
	_check(king._t == 1 and king.atk == 8 and king.hp == 8 and king_ally.atk >= 2,
		"永夜骨王开局应重生 +2/+2 并给亡灵成长，实际 king=%d/%d _t=%d ally=%d" % [
			king.atk, king.hp, king._t, king_ally.atk])
	print("[battle_test] 用例24 亡灵逐卡: 召唤/亡语/随机成长/重生 通过")
	cases_run += 1

## 25) 血族逐卡：攻击治疗、治疗转成长、受击成长、最大生命和攻击后自成长。
func _case_vampire_card_effects() -> void:
	var mosquito = _mk({"n": "吸血蚊", "a": 3, "h": 3, "star": 4, "race": "vampire", "k": "l",
		"sk": {"t": "attack", "e": "race-heal"}}, 1)
	var hurt_ally = _mk({"n": "受伤血族", "a": 1, "h": 5, "mh": 20, "star": 2, "race": "vampire"}, 2)
	BattleScript.new()._apply_lifesteal(mosquito, "p", {"p": [mosquito, hurt_ally], "e": []}, 10)
	_check(hurt_ally.hp == 10, "吸血蚊攻击应治疗全血族 5，实际 %d" % hurt_ally.hp)

	var healer = _mk({"n": "血族圣疗者", "a": 3, "h": 5, "mh": 5, "star": 5, "race": "vampire",
		"sk": {"t": "attack", "e": "heal-race", "race": "vampire", "a": 1, "h": 1, "mh": 1}}, 3)
	var healer_ally = _mk({"n": "受伤血族", "a": 1, "h": 2, "mh": 20, "star": 2, "race": "vampire"}, 4)
	BattleScript.new()._run_attack_tail(healer, "p", "e", {"p": [healer, healer_ally], "e": []})
	_check(healer_ally.hp == 6 and healer.atk == 4 and healer_ally.atk == 2,
		"血族圣疗者应治疗并给全血族成长，实际 ally=%d/%d healerA=%d" % [
			healer_ally.atk, healer_ally.hp, healer.atk])

	var hunter = _mk({"n": "血裔猎手", "a": 3, "h": 10, "star": 3, "race": "vampire",
		"sk": {"t": "on-dmg", "e": "race-buff", "race": "vampire", "a": 1, "h": 1},
		"atkSk": {"e": "self-race-buff", "race": "vampire", "a": 1, "h": 1}}, 5)
	var hunter_ally = _mk({"n": "血族盟友", "a": 1, "h": 1, "star": 2, "race": "vampire"}, 6)
	var hunter_boards := {"p": [hunter, hunter_ally], "e": []}
	BattleScript.new()._run_on_damage_skill(hunter, "p", hunter_boards)
	BattleScript.new()._run_attack_tail(hunter, "p", "e", hunter_boards)
	_check(hunter.atk == 5 and hunter_ally.atk == 3,
		"血裔猎手受击和攻击后应共给全血族 +2/+2，实际 hunter=%d ally=%d" % [hunter.atk, hunter_ally.atk])

	var lord = _mk({"n": "血之主", "a": 5, "h": 5, "star": 7, "race": "vampire",
		"sk": {"t": "on-dmg", "e": "race-buff", "race": "vampire", "a": 3, "h": 3, "grow": 1}}, 7)
	var lord_ally = _mk({"n": "血族盟友", "a": 1, "h": 1, "star": 2, "race": "vampire"}, 8)
	BattleScript.new()._run_on_damage_skill(lord, "p", {"p": [lord, lord_ally], "e": []})
	_check(lord.atk == 8 and lord_ally.atk == 4,
		"血之主受击一次应给全血族 +3/+3，实际 lord=%d ally=%d" % [lord.atk, lord_ally.atk])

	var count = _mk({"n": "血族伯爵", "a": 5, "h": 6, "mh": 6, "star": 6, "race": "vampire",
		"sk": {"t": "on-dmg", "e": "maxhp-buff", "a": 2, "h": 2}}, 9)
	BattleScript.new()._run_on_damage_skill(count, "p", {"p": [count], "e": []})
	_check(count.atk == 7 and count.hp == 8 and count.max_hp == 8,
		"血族伯爵受击应 +2/+2 并增加最大生命，实际 %d/%d max=%d" % [count.atk, count.hp, count.max_hp])
	print("[battle_test] 用例25 血族逐卡: 治愈/受击成长/最大生命 通过")
	cases_run += 1

## 26) 赌徒逐卡：随机、本族、全体和豪赌倍率范围。
func _case_gambler_card_effects() -> void:
	var specs := [
		{"n": "赌徒", "scope": "rnd", "base": 2, "sk": {"t": "start", "e": "gamble", "scope": "rnd", "a": 2, "h": 2}},
		{"n": "翻倍能手", "scope": "race", "base": 4, "sk": {"t": "start", "e": "gamble", "scope": "race", "a": 4, "h": 4}},
		{"n": "幸运之星", "scope": "all", "base": 5, "sk": {"t": "start", "e": "gamble", "scope": "all", "a": 5, "h": 5}},
		{"n": "命运赌王", "scope": "all", "base": 6, "sk": {"t": "start", "e": "gamble", "scope": "all", "a": 6, "h": 6}},
		{"n": "豪赌大师", "scope": "all", "base": 8, "sk": {"t": "start", "e": "gamble", "scope": "all", "a": 8, "h": 8, "succ": 0.5, "ml": 2, "mh": 4}},
	]
	for spec in specs:
		var found := false
		for seed_value in range(1, 201):
			var gambler = _mk({"n": spec["n"], "a": 2, "h": 2, "star": 7, "race": "gambler",
				"sk": spec["sk"]}, 1)
			var gambler_ally = _mk({"n": "赌徒盟友", "a": 1, "h": 1, "star": 3, "race": "gambler"}, 2)
			var neutral = _mk({"n": "中立盟友", "a": 1, "h": 1, "star": 2, "race": "neutral"}, 3)
			var board: Array = [gambler, gambler_ally, neutral]
			var before: Array = []
			for u in board:
				before.append([u.atk, u.hp])
			var battle = BattleScript.new()
			battle.rng.seed = seed_value
			battle._roll_gamble(gambler, "p", {"p": board, "e": []})
			var ev: Dictionary = battle.events[0]
			if not bool(ev.get("success", false)):
				continue
			var mult := int(ev.get("mult", 0))
			var changed := 0
			var gains_ok := true
			for i in range(board.size()):
				var u = board[i]
				var da: int = u.atk - int(before[i][0])
				var dh: int = u.hp - int(before[i][1])
				if da != 0 or dh != 0:
					changed += 1
					if da != int(spec["base"]) * mult or dh != int(spec["base"]) * mult:
						gains_ok = false
			var expected_count: int = 1 if String(spec["scope"]) == "rnd" else (2 if String(spec["scope"]) == "race" else 3)
			_check(changed == expected_count and gains_ok, "%s 目标数量/倍率应用错误，实际 %d 人，gain_ok=%s" % [
				String(spec["n"]), changed, gains_ok])
			if String(spec["n"]) == "豪赌大师":
				_check(mult >= 2 and mult <= 4, "豪赌大师倍率应在 2-4，实际 %d" % mult)
			found = true
			break
		_check(found, "%s 在 200 个种子内应有成功结果" % String(spec["n"]))
	print("[battle_test] 用例26 赌徒逐卡: 5 张卡种成功与目标范围通过")
	cases_run += 1

## 27) 恶魔逐卡：大酋长/亚煞极受击成长，地狱魔龙多次攻击入口。
func _case_demon_card_effects() -> void:
	for spec in [
		{"n": "大酋长", "a": 1, "h": 1},
		{"n": "亚煞极", "a": 2, "h": 2},
	]:
		var demon = _mk({"n": spec["n"], "a": 5, "h": 5, "star": 7, "race": "demon",
			"sk": {"t": "on-dmg", "e": "self-buff", "a": spec["a"], "h": spec["h"]}}, 1)
		BattleScript.new()._run_on_damage_skill(demon, "p", {"p": [demon], "e": []})
		_check(demon.atk == 5 + int(spec["a"]) and demon.hp == 5 + int(spec["h"]),
			"%s 受击应自身 +%d/+%d" % [String(spec["n"]), int(spec["a"]), int(spec["h"])])

	var hell = _mk({"n": "地狱魔龙", "a": 8, "h": 8, "star": 7, "race": "demon",
		"sk": {"t": "start", "e": "multihit"}}, 3)
	var bag = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 4)
	BattleScript.new().resolve([hell], [bag], 109, 0, {"phaseP": 2})
	_check(hell._hit >= 1 and hell._t >= 1 and hell._atkLeft >= 1,
		"地狱魔龙开局应建立多次攻击运行态，实际 _hit=%d _t=%d _atkLeft=%d" % [
			hell._hit, hell._t, hell._atkLeft])
	print("[battle_test] 用例27 恶魔逐卡: 大酋长/亚煞极/地狱魔龙 通过")
	cases_run += 1

## 28) 中立开局：成长守卫递增，时光祝福者给全体成长。
func _case_neutral_card_effects() -> void:
	var guard = _mk({"n": "成长守卫", "a": 2, "h": 6, "star": 5, "race": "neutral",
		"sk": {"t": "start", "e": "growth-self"}}, 1)
	var blesser = _mk({"n": "时光祝福者", "a": 6, "h": 8, "star": 6, "race": "neutral",
		"sk": {"t": "start", "e": "ally-all-buff"}}, 2)
	var bag = _mk({"n": "木桩", "a": 0, "h": 100, "star": 1, "race": "neutral"}, 3)
	BattleScript.new().resolve([guard, blesser], [bag], 113, 0, {"phaseP": 2})
	_check(guard._g == 1 and guard.atk == 4 and guard.hp == 8,
		"成长守卫应自身成长 +1/+1 并被祝福 +1/+1，实际 _g=%d %d/%d" % [guard._g, guard.atk, guard.hp])
	_check(blesser._t == 1 and blesser.atk == 7 and blesser.hp == 9,
		"时光祝福者应累计 1 层并给全体 +1/+1，实际 _t=%d %d/%d" % [blesser._t, blesser.atk, blesser.hp])
	print("[battle_test] 用例28 中立开局: 成长守卫/时光祝福者 通过")
	cases_run += 1

## 29) 侧级特色状态：龙威层、亡灵累计死亡和本场死亡增量必须随战斗结果返回。
func _case_persistent_side_state() -> void:
	var dragon = _mk({"n": "龙威探针", "a": 1, "h": 1, "star": 3, "race": "dragon",
		"sk": {"t": "start", "e": "dragon-aura", "times": 2}}, 1)
	var weak = _mk({"n": "亡灵计数探针", "a": 1, "h": 1, "star": 1, "race": "undead"}, 2)
	var killer = _mk({"n": "杀手", "a": 20, "h": 20, "star": 5, "race": "neutral"}, 101)
	var resolved = BattleScript.new().resolve(
		[dragon, weak], [killer], 117, 10,
		{"round": 6, "dragonLayerP": 3, "undeadTickP": 4})
	_check(int(resolved.get("dragon_layer_p", 0)) == 5,
		"龙威层没有按“旧层+本场新增”返回，实际 %d" % int(resolved.get("dragon_layer_p", 0)))
	_check(int(resolved.get("death_delta_p", 0)) > 0,
		"本场死亡增量没有返回，亡灵成长无法跨回合稳定累计")
	_check(int(resolved.get("undead_tick_p", 0)) == 4 + int(resolved.get("death_delta_p", 0)),
		"亡灵累计死亡没有从上一回合继续，实际 %d" % int(resolved.get("undead_tick_p", 0)))
	print("[battle_test] 用例29 侧级持久状态: 龙威=", resolved.get("dragon_layer_p", 0),
		" 亡灵累计=", resolved.get("undead_tick_p", 0), " 本场死亡=", resolved.get("death_delta_p", 0))
	cases_run += 1

## 30) 战斗收尾：胜方每个存活随从按自身星级追加一次攻击玩家事件。
func _case_hero_attack_events() -> void:
	var star_3 = _mk({"n": "三星幸存者", "a": 20, "h": 20, "star": 3, "race": "star"}, 1)
	var star_5 = _mk({"n": "五星幸存者", "a": 20, "h": 20, "star": 5, "race": "star"}, 2)
	var weak = _mk({"n": "收尾木桩", "a": 0, "h": 1, "star": 1, "race": "neutral"}, 101)
	var resolved = BattleScript.new().resolve([star_3, star_5], [weak], 122, 10, {"phaseP": 2})
	var hero_events: Array = []
	var total_star := 0
	for ev in resolved.get("events", []):
		if String(ev.get("t", "")) == "hero_attack":
			hero_events.append(ev)
			total_star += int(ev.get("star", 0))
	_check(hero_events.size() == 2, "胜方存活随从应各产生一次攻击玩家事件，实际 %d" % hero_events.size())
	_check(total_star == 8, "攻击玩家事件星级总和应为 3+5=8，实际 %d" % total_star)
	_check(String(resolved["winner"]) == "p", "收尾事件场景应由玩家方获胜")
	print("[battle_test] 用例30 收尾攻击: 事件=", hero_events.size(), " 星级总和=", total_star)
	cases_run += 1

func _count_name(board: Array, name: String) -> int:
	var count := 0
	for u in board:
		if u != null and String(u.card_name) == name:
			count += 1
	return count

## 截取某角色第一次行动产生的事件。一次行动可含多次挥击，下一行动的首次挥击从 swing=0 重新开始。
func _first_action(events: Array, attacker_uid: int) -> Array:
	var out: Array = []
	var started := false
	for ev in events:
		var kind := String(ev.get("t", ""))
		if kind == "attack" and int(ev.get("src", -1)) == attacker_uid:
			if started and int(ev.get("swing", -1)) == 0:
				break
			started = true
		if started:
			out.append(ev)
		if started and kind == "end":
			break
	return out
