extends RefCounted
## 战斗结算内核（P1a）：纯逻辑、无节点依赖、带事件序列输出。
## 事件序列给后续表现层订阅（动画/飘字/音效），逻辑本身可无头批量跑。
##
## 已覆盖：出手顺序、嘲讽、圣盾、风怒、剧毒、伤害/死亡、进化条（攒格→质变）、
##         进化大师（推进器）、混沌始祖（吞噬基因 / 基因领主）、回合开始光环。
## 待接入（P1b）：机械合体与磁力、献祭契印与债务、星灵连锁、法术、金卡三连、AI 运营。

const UnitScript := preload("res://sim/unit.gd")

const SIDE_P := "p"
const SIDE_E := "e"

var events: Array = []
var rng := RandomNumberGenerator.new()
var log_lines: Array[String] = []

# 献祭·债务（P1c）：契印死亡→债务；债务节点；祭坛大师/血祭司祭节点结算
var round_no: int = 1
var debt := {"p": 0, "e": 0}
var debt_tier := {"p": 0, "e": 0}
var contract_id := {"p": -1, "e": -1}
var contract_bonus := {"p": 0, "e": 0}
var debt_settled := {"p": false, "e": false}
var debt_pay_bonus := {"p": 1.0, "e": 1.0}
var devour_boost: int = 0
var death_stat_a: int = 0
var death_stat_h: int = 0

# 机械：维修护甲（战斗内吸收伤害）
var armor := {"p": 0, "e": 0}

# 星灵连锁
var chain := {"p": 0, "e": 0}
var star_amp := {"p": 0, "e": 0}
const ECHO_RATIOS := [1.5, 1.0, 0.7, 0.5, 0.4, 0.3, 0.25]

func resolve(p_board: Array, e_board: Array, seed_value: int = 1, max_rounds: int = 30, opts: Dictionary = {}) -> Dictionary:
	rng.seed = seed_value
	events.clear()
	log_lines.clear()
	round_no = int(opts.get("round", 1))
	death_stat_a = 0
	death_stat_h = 0
	for side in [SIDE_P, SIDE_E]:
		var suffix: String = "P" if side == SIDE_P else "E"
		debt[side] = int(opts.get("debt" + suffix, 0))
		debt_tier[side] = _debt_tier(int(debt[side]))
		contract_id[side] = int(opts.get("contract" + suffix, -1))
		contract_bonus[side] = int(opts.get("contractBonus" + suffix, 0))
		debt_settled[side] = false
		debt_pay_bonus[side] = 1.0
		chain[side] = int(opts.get("chain" + suffix, 0))
		star_amp[side] = int(opts.get("amp" + suffix, 0))
		armor[side] = int(opts.get("armor" + suffix, 0))
	var boards := {SIDE_P: _clean(p_board), SIDE_E: _clean(e_board)}
	# 顺序与 Web 一致：同族共鸣 → 再快照债务结算基准（血祭司祭/祭坛大师的攻击/生命）
	_apply_race_synergy(SIDE_P, boards)
	_apply_race_synergy(SIDE_E, boards)
	_prepare_debt(SIDE_P, boards)
	_prepare_debt(SIDE_E, boards)

	_run_start_skills(SIDE_P, boards)
	_run_start_skills(SIDE_E, boards)

	var round := 0
	# 与 Web 一致：每轮 = 我方按格位顺序轮转一只出手，然后敌方随机一只出手（交替结算）
	while _alive_count(boards[SIDE_P]) > 0 and _alive_count(boards[SIDE_E]) > 0 and round < max_rounds:
		round += 1
		var p = _next_actor(boards[SIDE_P])
		if p == null:
			break
		_swing(p, SIDE_P, SIDE_E, boards)
		if p.alive and _alive_count(boards[SIDE_E]) > 0:
			var e = _random_actor(boards[SIDE_E])
			if e != null:
				_swing(e, SIDE_E, SIDE_P, boards)

	var p_alive := _alive_count(boards[SIDE_P])
	var e_alive := _alive_count(boards[SIDE_E])
	var winner := "draw"
	if p_alive > 0 and e_alive == 0:
		winner = SIDE_P
	elif e_alive > 0 and p_alive == 0:
		winner = SIDE_E
	_emit({"t": "end", "winner": winner, "rounds": round})
	return {
		"winner": winner,
		"rounds": round,
		"p_alive": p_alive,
		"e_alive": e_alive,
		"p_board": boards[SIDE_P],
		"e_board": boards[SIDE_E],
		"events": events,
		"log": log_lines,
		"debt_p": int(debt[SIDE_P]),
		"debt_e": int(debt[SIDE_E]),
		"chain_p": int(chain[SIDE_P]),
		"chain_e": int(chain[SIDE_E]),
		"armor_p": int(armor[SIDE_P]),
		"armor_e": int(armor[SIDE_E]),
	}

func _clean(board: Array) -> Array:
	var out: Array = []
	for u in board:
		if u != null:
			u.alive = u.hp > 0
			u.attacked_this_round = false
			u.shield = u.has_kw("d")
			u.taunt_active = u.has_kw("t")
			out.append(u)
		else:
			out.append(null)
	return out

func _alive_count(board: Array) -> int:
	var n := 0
	for u in board:
		if u != null and u.alive:
			n += 1
	return n

func _alive_units(board: Array) -> Array:
	var out: Array = []
	for u in board:
		if u != null and u.alive:
			out.append(u)
	return out

func _pick_target(foe_board: Array) -> Variant:
	var alive := _alive_units(foe_board)
	if alive.is_empty():
		return null
	var taunts: Array = []
	for u in alive:
		if u.taunt_active:
			taunts.append(u)
	var pool: Array = taunts if not taunts.is_empty() else alive
	return pool[rng.randi_range(0, pool.size() - 1)]

func _attack(attacker, target, side: String, foe: String, boards: Dictionary, first_swing: bool = true) -> void:
	var dmg: int = attacker.atk
	# 星灵连锁：星灵随从/星灵斗士的额外连锁伤害（连锁层数×1.5×星界增幅）
	var sk_e := String(attacker.skill.get("e", ""))
	if attacker.race == "star" or sk_e == "chain-dmg":
		var amp := int(star_amp[side]) + 1
		var bonus := int(round(float(chain[side]) * 1.5 * float(amp)))
		if attacker.race == "star":
			dmg += bonus
		if sk_e == "chain-dmg":
			dmg += bonus
	_emit({"t": "attack", "src": attacker.uid, "dst": target.uid, "atk": dmg})
	# 剧毒：仅首次挥击生效，直接击杀（与 Web 版一致）
	if first_swing and attacker.has_kw("p") and dmg > 0:
		target.hp = 0
		_emit({"t": "poison", "src": attacker.uid, "dst": target.uid})
		_log("%s 剧毒击杀 %s" % [attacker.card_name, target.card_name])
		if target.taunt_active:
			target.taunt_active = false
			_emit({"t": "taunt_break", "id": target.uid})
		_on_attacked(attacker, side, boards)
		if target.hp <= 0 and target.alive:
			_kill(target, foe, boards)
		_after_attack_star(attacker, side, foe, boards)
		return
	# 与 Web 一致：圣盾只对带 d 关键词的随从生效（充能盾也一样）
	if target.shield and target.has_kw("d"):
		target.shield = false
		_emit({"t": "shield_break", "id": target.uid})
		dmg = 0
	if target.taunt_active:
		target.taunt_active = false
		_emit({"t": "taunt_break", "id": target.uid})
	var absorbed := 0
	if int(armor[foe]) > 0 and dmg > 0:
		absorbed = min(dmg, int(armor[foe]))
		armor[foe] = int(armor[foe]) - absorbed
		dmg -= absorbed
		_emit({"t": "armor", "side": foe, "absorbed": absorbed, "left": int(armor[foe])})
		_log("维修护甲吸收 %d（剩余 %d）" % [absorbed, int(armor[foe])])
	if dmg > 0:
		target.hp -= dmg
		_emit({"t": "damage", "src": attacker.uid, "dst": target.uid, "dmg": dmg, "hp": max(0, target.hp)})
		_log("%s 攻击 %s，造成 %d 伤害" % [attacker.card_name, target.card_name, dmg])
	_on_attacked(attacker, side, boards)
	if target.hp <= 0 and target.alive:
		_kill(target, foe, boards)
		_log("%s 阵亡" % target.card_name)
	else:
		# Web：受击充能/受击技能只在随从存活时结算
		_on_damaged(target, side, foe, boards)
	_after_attack_star(attacker, side, foe, boards)

func _on_attacked(u, side: String, boards: Dictionary) -> void:
	var sk: Dictionary = u.skill
	if sk.is_empty():
		return
	if String(sk.get("e", "")) == "evolve-step" and String(sk.get("t", "")) == "attack":
		_evolve_tick(u, side, boards)
	elif String(sk.get("e", "")) == "self-buff":
		var a := int(sk.get("a", 1))
		var h := int(sk.get("h", 1))
		u.gain(a, h)
		_emit({"t": "buff", "id": u.uid, "a": a, "h": h})
	elif String(sk.get("e", "")) == "race-buff":
		var race := String(sk.get("race", u.race))
		var a2 := int(sk.get("a", 1))
		var h2 := int(sk.get("h", 1))
		for ally in _alive_units(boards[side]):
			if ally.race == race:
				ally.gain(a2, h2)
				_emit({"t": "buff", "id": ally.uid, "a": a2, "h": h2})

func _on_damaged(u, side: String, foe: String, boards: Dictionary) -> void:
	_charge_tick(u, side, boards)
	var sk: Dictionary = u.skill
	if sk.is_empty():
		return
	if String(sk.get("t", "")) != "on-dmg":
		return
	match String(sk.get("e", "")):
		"evolve":
			_evolve_tick(u, side, boards)
		"self-buff":
			var a := int(sk.get("a", 0))
			var h := int(sk.get("h", 0))
			u.gain(a, h)
			_emit({"t": "buff", "id": u.uid, "a": a, "h": h})
		"maxhp-buff":
			var a2 := int(sk.get("a", 2))
			var h2 := int(sk.get("h", 2))
			u.gain(a2, h2)
			_emit({"t": "buff", "id": u.uid, "a": a2, "h": h2})

func _run_start_skills(side: String, boards: Dictionary) -> void:
	for u in _alive_units(boards[side]):
		var sk: Dictionary = u.skill
		if sk.is_empty():
			continue
		var t := String(sk.get("t", ""))
		var e := String(sk.get("e", ""))
		if t == "start" and (e == "evolve" or e == "evolve-step"):
			_evolve_tick(u, side, boards)
		elif t == "start" and e == "evo-advance":
			var a := int(sk.get("a", 1))
			var h := int(sk.get("h", 1))
			for ally in _alive_units(boards[side]):
				if ally.race == "evolve":
					ally.gain(a, h)
					_emit({"t": "buff", "id": ally.uid, "a": a, "h": h})
					if not ally.skill.is_empty() and String(ally.skill.get("e", "")).begins_with("evolve"):
						_evolve_tick(ally, side, boards)
			_log("%s 推进全场进化" % u.card_name)
		elif t == "start" and e == "evo-devourer":
			var max_gene := int(sk.get("max", 5))
			if u.gene < max_gene:
				u.gene += 1
				var a2 := int(sk.get("a", 2))
				var h2 := int(sk.get("h", 2))
				u.gain(a2, h2)
				_emit({"t": "gene", "id": u.uid, "gene": u.gene, "a": a2, "h": h2})
		elif t == "start" and (e == "debt-payoff" or (e == "death-race-buff" and int(sk.get("debtMax", 0)) > 0)):
			_settle_debt(side, boards, u)
		elif t == "start" and e == "chain-start":
			chain[side] = int(chain[side]) + 1
			_log("%s：连锁 +1（当前 %d）" % [u.card_name, int(chain[side])])
		elif t == "start" and e == "star-amp":
			chain[side] = int(chain[side]) + 1
			star_amp[side] = int(star_amp[side]) + 1
			_log("%s：连锁 +1，星灵连锁伤害翻倍（增幅 %d）" % [u.card_name, int(star_amp[side])])
		elif t == "start" and e == "race-buff" and String(sk.get("race", "")) == "star":
			var base_chain: int = int(chain[side]) if int(chain[side]) > 0 else 1
			var scale := float(sk.get("statScale", 1.0))
			var g := int(round(float(base_chain) * scale))
			for ally in _alive_units(boards[side]):
				if ally.race == "star":
					ally.gain(g, g)
					_emit({"t": "buff", "id": ally.uid, "a": g, "h": g})
			_log("%s：全星灵 +%d/+%d（连锁 %d）" % [u.card_name, g, g, int(chain[side])])
		elif t == "start" and e == "debt-lord":
			var tier: int = int(debt_tier[side])
			if tier > 0:
				var per := int(sk.get("a", 2))
				var gain_lord: int = per / 3 if tier == 1 else (per if tier == 2 else per * 2)
				gain_lord = int(max(1, round(gain_lord)))
				for ally in _alive_units(boards[side]):
					if ally.race == "sacrifice":
						ally.gain(gain_lord, gain_lord)
						_emit({"t": "buff", "id": ally.uid, "a": gain_lord, "h": gain_lord})
				_log("%s：债务节点 %d，全献祭 +%d/+%d" % [u.card_name, tier, gain_lord, gain_lord])
		elif t == "start" and e == "race-buff":
			var race := String(sk.get("race", u.race))
			var a3 := int(sk.get("a", 1))
			var h3 := int(sk.get("h", 1))
			for ally in _alive_units(boards[side]):
				if ally.race == race:
					ally.gain(a3, h3)
					_emit({"t": "buff", "id": ally.uid, "a": a3, "h": h3})

## 进化条：攒一格 → 满格质变（身材×2 / 攻击×1.5），并通知混沌始祖
func _evolve_tick(u, side: String, boards: Dictionary) -> void:
	var sk: Dictionary = u.skill
	if sk.is_empty():
		return
	var e := String(sk.get("e", ""))
	if e != "evolve" and e != "evolve-step":
		return
	var need := int(sk.get("need", 2 if sk.has("maxD") else 3))
	u.evo += 1
	# 每格即时收益：受击线+1攻，其它+1/+1
	if String(sk.get("t", "")) == "on-dmg":
		u.atk += u.stat_gain
		_emit({"t": "buff", "id": u.uid, "a": u.stat_gain, "h": 0})
	else:
		u.gain(u.stat_gain, u.stat_gain)
		_emit({"t": "buff", "id": u.uid, "a": u.stat_gain, "h": u.stat_gain})
	if u.evo < need:
		_emit({"t": "evop", "id": u.uid, "evo": u.evo, "need": need})
		return
	u.evo = 0
	_emit({"t": "evo_full", "id": u.uid})
	if String(sk.get("t", "")) == "on-dmg":
		var max_c := int(sk.get("maxC", 3))
		if u.vc < max_c:
			u.vc += 1
			u.atk = int(round(u.atk * 1.5))
		else:
			u.atk += 4
		_emit({"t": "evolve", "id": u.uid, "kind": "atk_x1.5", "atk": u.atk})
	else:
		var max_d := int(sk.get("maxD", 0))
		if max_d > 0 and u.vd < max_d:
			u.vd += 1
			var a: int = u.atk
			var h: int = u.hp
			u.atk *= 2
			u.hp *= 2
			u.max_hp *= 2
			_emit({"t": "buff", "id": u.uid, "a": u.atk - a, "h": u.hp - h})
			_emit({"t": "evolve", "id": u.uid, "kind": "stat_x2"})
		else:
			var ga := int(sk.get("a", 2))
			var gh := int(sk.get("h", 2))
			u.gain(ga, gh)
			_emit({"t": "buff", "id": u.uid, "a": ga, "h": gh})
			_emit({"t": "evolve", "id": u.uid, "kind": "small"})
	_notify_gene_lord(u, side, boards)

## 基因领主：己方进化随从每次质变 → 混沌始祖永久+2/+2，并给全队进化+1/+1
func _notify_gene_lord(source, side: String, boards: Dictionary) -> void:
	for lord in _alive_units(boards[side]):
		if lord == source or lord.skill.is_empty():
			continue
		if String(lord.skill.get("e", "")) != "evo-devourer":
			continue
		var team_bonus := int(lord.skill.get("team", 1))
		lord.gain(2, 2)
		_emit({"t": "buff", "id": lord.uid, "a": 2, "h": 2})
		for ally in _alive_units(boards[side]):
			if ally.race == "evolve":
				ally.gain(team_bonus, team_bonus)
				_emit({"t": "buff", "id": ally.uid, "a": team_bonus, "h": team_bonus})
		_log("%s 吞噬 %s 的质变" % [lord.card_name, source.card_name])
		return

func _emit(ev: Dictionary) -> void:
	events.append(ev)

func _log(text: String) -> void:
	log_lines.append(text)


## ---------- 献祭·债务 ----------

func _debt_tier(v: int) -> int:
	if v >= 32: return 3
	if v >= 18: return 2
	if v >= 8: return 1
	return 0

func _debt_payoff_info(v: int) -> Dictionary:
	if v >= 32: return {"need": 32, "mult": 3, "bonus": 8, "tier": 3}
	if v >= 18: return {"need": 18, "mult": 2, "bonus": 3, "tier": 2}
	if v >= 8: return {"need": 8, "mult": 1, "bonus": 1, "tier": 1}
	return {"need": min(4, v), "mult": 1, "bonus": 0, "tier": 0}

func _debt_ramp() -> float:
	return clampf(0.35 + float(round_no - 1) * 0.065, 0.35, 1.0)

func _prepare_debt(side: String, boards: Dictionary) -> void:
	var n := 0
	for u in _alive_units(boards[side]):
		var e := String(u.skill.get("e", ""))
		var is_payoff: bool = e == "debt-payoff" or int(u.skill.get("debtMax", 0)) > 0
		if is_payoff:
			n += 1
			u.pay_a = u.atk
			u.pay_h = u.hp
	debt_pay_bonus[side] = 1.0 + minf(0.6, float(max(0, n - 1)) * 0.2)

## 同族共鸣：同一族 ≥3 只时，该族全体 +1/+1（战斗开始，先于随从技能）
func _apply_race_synergy(side: String, boards: Dictionary) -> void:
	var counts := {}
	for u in _alive_units(boards[side]):
		if u.race == "neutral":
			continue
		counts[u.race] = int(counts.get(u.race, 0)) + 1
	for race in counts.keys():
		if int(counts[race]) >= 3:
			for u in _alive_units(boards[side]):
				if u.race == race:
					u.gain(1, 1)
					_emit({"t": "buff", "id": u.uid, "a": 1, "h": 1})
			_log("同族共鸣：%s +1/+1" % race)

func _add_debt(side: String, n: int) -> void:
	debt[side] = max(0, int(debt[side]) + n)
	var nt := _debt_tier(int(debt[side]))
	var old: int = int(debt_tier[side])
	if nt > old:
		var bonus := [0, 1, 3, 6]
		for ti in range(old + 1, nt + 1):
			debt[side] = int(debt[side]) + int(bonus[ti])
		debt_tier[side] = nt
	_emit({"t": "debt", "side": side, "debt": int(debt[side]), "tier": int(debt_tier[side])})

func _settle_debt(side: String, boards: Dictionary, u) -> void:
	if bool(debt_settled[side]):
		return
	var info := _debt_payoff_info(int(debt[side]))
	var need := int(info["need"])
	if need <= 0:
		return
	var base := float(need * int(info["mult"]) + int(info["bonus"])) * float(debt_pay_bonus[side])
	var ga := int(round(base * (1.0 + minf(0.5, float(u.pay_a) / 50.0)) * _debt_ramp() / 3.0))
	var gh := int(round(base * (1.0 + minf(0.5, float(u.pay_h) / 50.0)) * _debt_ramp() / 3.0))
	for ally in _alive_units(boards[side]):
		if ally.race == "sacrifice":
			ally.gain(ga, gh)
			_emit({"t": "buff", "id": ally.uid, "a": ga, "h": gh})
	debt[side] = max(0, int(debt[side]) - need)
	debt_tier[side] = _debt_tier(int(debt[side]))
	_debt_node_bonus(side, boards, need)
	debt_settled[side] = true
	_emit({"t": "debt_settle", "side": side, "need": need, "a": ga, "h": gh, "debt": int(debt[side])})
	_log("%s：债务节点 %d 结算，全献祭 +%d/+%d" % [u.card_name, int(info["tier"]), ga, gh])

func _debt_node_bonus(side: String, boards: Dictionary, used: int) -> void:
	var tb := 0
	for u in _alive_units(boards[side]):
		if String(u.skill.get("e", "")) == "debt-totem":
			tb = 2 if u.gold_card else 1
			break
	if tb > 0:
		var ga: int = max(1, int(round(float(used) * 0.11 * float(tb))))
		for ally in _alive_units(boards[side]):
			if ally.race == "sacrifice":
				ally.gain(ga, ga)
				_emit({"t": "buff", "id": ally.uid, "a": ga, "h": ga})
	for u in _alive_units(boards[side]):
		var rate := float(u.skill.get("debt", 0.0))
		if rate > 0.0:
			var gg: int = max(1, int(round(float(used) * rate)))
			u.gain(gg, gg)
			_emit({"t": "buff", "id": u.uid, "a": gg, "h": gg})

func _kill(dead, side: String, boards: Dictionary) -> void:
	dead.alive = false
	_emit({"t": "death", "id": dead.uid, "name": dead.card_name})
	death_stat_a += max(0, dead.atk)
	death_stat_h += max(0, dead.hp)
	# 食骸者：每次友方死亡按 rate 继承该随从数值（至少 +1/+1）
	for u in _alive_units(boards[side]):
		if u == dead or String(u.skill.get("e", "")) != "inherit":
			continue
		if u.skill.has("rate"):
			var r := float(u.skill.get("rate", 0.0))
			var ia: int = max(1, int(floor(float(dead.atk) * r)))
			var ih: int = max(1, int(floor(float(dead.hp) * r)))
			u.gain(ia, ih)
			_emit({"t": "buff", "id": u.uid, "a": ia, "h": ih})
	# 契印结算：目标死亡 → 债务
	if int(contract_id[side]) == dead.uid:
		var dbb := 0
		for u in _alive_units(boards[side]):
			if String(u.skill.get("e", "")) == "debt-boost":
				dbb += int(u.skill.get("a", 0))
		var raw := int(ceil(float(dead.atk + dead.hp) / 6.0) + floor(float(round_no) / 4.0) + float(dbb + int(contract_bonus[side])) + floor(float(round_no) / 8.0))
		raw = clampi(raw, 1, 24)
		var tot := 0.0
		for u in _alive_units(boards[side]):
			if String(u.skill.get("e", "")) == "debt-totem":
				tot = maxf(tot, 1.5 if u.gold_card else 1.17)
		if tot > 0.0:
			raw = int(round(float(raw) * tot))
		if devour_boost > 0:
			raw = int(ceil(float(raw) * 1.17))
			devour_boost = 0
		_add_debt(side, raw)
		contract_id[side] = -1
		contract_bonus[side] = 0
		_log("契印结算：债务 +%d" % raw)


## ---------- 星灵连锁 ----------

func _after_attack_star(atk, side: String, foe: String, boards: Dictionary) -> void:
	if atk.race != "star":
		return
	chain[side] = int(chain[side]) + 1
	var echoes: Array = []
	for u in _alive_units(boards[side]):
		if String(u.skill.get("e", "")) == "star-echo":
			echoes.append(u)
	for i in range(echoes.size()):
		var pool := _alive_units(boards[foe])
		if pool.is_empty():
			break
		var target = pool[rng.randi_range(0, pool.size() - 1)]
		var ratio: float = float(ECHO_RATIOS[min(i, ECHO_RATIOS.size() - 1)])
		var ed: int = max(1, int(round(float(chain[side]) * ratio)))
		target.hp -= ed
		_emit({"t": "damage", "src": echoes[i].uid, "dst": target.uid, "dmg": ed, "hp": max(0, target.hp), "echo": 1})
		_log("星光回响：%s 受到 %d 伤害" % [target.card_name, ed])
		if target.hp <= 0 and target.alive:
			_kill(target, foe, boards)


## 出手调度：我方按格位序列轮转，敌方随机（对齐 Web）
func _next_actor(board: Array):
	var first = null
	for u in board:
		if u == null or not u.alive:
			continue
		if first == null:
			first = u
		if not u.attacked_this_round:
			u.attacked_this_round = true
			return u
	for u in board:
		if u != null and u.alive:
			u.attacked_this_round = false
	if first != null:
		first.attacked_this_round = true
	return first

func _random_actor(board: Array):
	var alive := _alive_units(board)
	if alive.is_empty():
		return null
	var u = alive[rng.randi_range(0, alive.size() - 1)]
	u.attacked_this_round = true
	return u

func _swing(u, side: String, foe: String, boards: Dictionary) -> void:
	_charge_tick(u, side, boards)
	var swings := 2 if u.has_kw("w") else 1
	for swing in range(swings):
		if not u.alive:
			break
		var target = _pick_target(boards[foe])
		if target == null:
			break
		_attack(u, target, side, foe, boards, swing == 0)


## ---------- 机械：充能 ----------

func _charge_tick(u, side: String, boards: Dictionary) -> void:
	var max_charge: int = u.charge_max
	if max_charge <= 0:
		return
	var cur: int = u.charge + 1
	u.charge = cur
	_emit({"t": "ch", "id": u.uid, "c": cur, "cm": max_charge})
	if cur < max_charge:
		return
	u.charge = 0
	var fx: String = u.charge_fx
	var ba: int = u.charge_a
	var bh: int = u.charge_h
	if bh == 0:
		bh = ba
	match fx:
		"shield":
			u.shield = true
			_log("%s：充能完成，展开圣盾" % u.card_name)
		"heal":
			var hv: int = max(1, int(floor(float(u.max_hp) * 0.15)))
			var old: int = u.hp
			u.hp = min(u.hp + hv, u.max_hp)
			_emit({"t": "heal", "id": u.uid, "val": u.hp - old})
			_log("%s：充能修复 %d HP" % [u.card_name, u.hp - old])
		"rally":
			for ally in _alive_units(boards[side]):
				if ally.race == "mech":
					ally.gain(max(1, ba), max(1, bh))
					_emit({"t": "buff", "id": ally.uid, "a": max(1, ba), "h": max(1, bh)})
			_log("%s：充能集结，全机械 +%d/+%d" % [u.card_name, max(1, ba), max(1, bh)])
		_:
			u.gain(ba, bh)
			_emit({"t": "buff", "id": u.uid, "a": ba, "h": bh})
			_log("%s：充能强化 +%d/+%d" % [u.card_name, ba, bh])
