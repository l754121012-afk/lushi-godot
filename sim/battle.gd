extends RefCounted
## 战斗结算内核（P1a）：纯逻辑、无节点依赖、带事件序列输出。
## 事件序列给后续表现层订阅（动画/飘字/音效），逻辑本身可无头批量跑。
##
## 已覆盖：出手顺序、嘲讽、圣盾、风怒、剧毒、伤害/死亡、进化条（攒格→质变）、
##         进化大师（推进器）、混沌始祖（吞噬基因 / 基因领主）、回合开始光环。
## 待接入（P1b）：机械合体与磁力、献祭契印与债务、星灵连锁、法术、金卡三连、AI 运营。

const UnitScript := preload("res://sim/unit.gd")
const Sacrifice := preload("res://sim/sacrifice.gd")
const Quest := preload("res://sim/quest.gd")

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
var dragon_layer := {"p": 0, "e": 0}
var death_tick := {"p": 0, "e": 0}
var death_start := {"p": 0, "e": 0}
var prev_death_tick := {"p": 0, "e": 0}
var phase := {"p": 0, "e": 0}

# 星灵连锁
var chain := {"p": 0, "e": 0}
var star_amp := {"p": 0, "e": 0}
const ECHO_RATIOS := [1.5, 1.0, 0.7, 0.5, 0.4, 0.3, 0.25]

func resolve(p_board: Array, e_board: Array, seed_value: int = 1, max_rounds: int = 30, opts: Dictionary = {}) -> Dictionary:
	rng.seed = seed_value
	events.clear()
	log_lines.clear()
	round_no = int(opts.get("round", 1))
	devour_boost = 0
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
		dragon_layer[side] = int(opts.get("dragonLayer" + suffix, 0))
		prev_death_tick[side] = int(opts.get("prevDeathTick" + suffix, 0))
		death_tick[side] = int(opts.get("undeadTick" + suffix, 0))
		death_start[side] = int(death_tick[side])
		phase[side] = int(opts.get("phase" + suffix, 0))
	var boards := {SIDE_P: _clean(p_board), SIDE_E: _clean(e_board)}
	var quest_ids: Dictionary = {
		SIDE_P: String(opts.get("questP", "")),
		SIDE_E: String(opts.get("questE", "")),
	}
	var initial_units: Dictionary = {
		SIDE_P: boards[SIDE_P].duplicate(),
		SIDE_E: boards[SIDE_E].duplicate(),
	}
	# 顺序与 Web 一致：同族共鸣 → 再快照债务结算基准（血祭司祭/祭坛大师的攻击/生命）
	_apply_race_synergy(SIDE_P, boards)
	_apply_race_synergy(SIDE_E, boards)
	_prepare_debt(SIDE_P, boards)
	_prepare_debt(SIDE_E, boards)

	_run_start_skills(SIDE_P, boards)
	_run_start_skills(SIDE_E, boards)
	_arm_defenses(SIDE_P, boards)
	_arm_defenses(SIDE_E, boards)

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
				if _pick_target(boards[SIDE_P]) != null:
					_swing(e, SIDE_E, SIDE_P, boards, int(p.uid))

	var p_alive := _alive_count(boards[SIDE_P])
	var e_alive := _alive_count(boards[SIDE_E])
	var winner := "draw"
	if p_alive > 0 and e_alive == 0:
		winner = SIDE_P
	elif e_alive > 0 and p_alive == 0:
		winner = SIDE_E
	if winner != "draw":
		for u in boards[winner]:
			if u == null or not u.alive:
				continue
			_emit({
				"t": "hero_attack",
				"id": u.uid,
				"side": winner,
				"star": maxi(1, int(u.star)),
				"name": u.card_name,
			})
	var quest_stats: Dictionary = {
		SIDE_P: Quest.evaluate(events, SIDE_P, initial_units[SIDE_P], initial_units[SIDE_E],
			boards[SIDE_P]),
		SIDE_E: Quest.evaluate(events, SIDE_E, initial_units[SIDE_E], initial_units[SIDE_P],
			boards[SIDE_E]),
	}
	var quest_ok: Dictionary = {SIDE_P: false, SIDE_E: false}
	var quest_reward_ticks: Dictionary = {SIDE_P: 0, SIDE_E: 0}
	for side in [SIDE_P, SIDE_E]:
		var quest_id: String = String(quest_ids.get(side, ""))
		if quest_id == "" or not _board_has_race(initial_units[side], "evolve"):
			continue
		var complete: bool = Quest.is_complete(quest_id, quest_stats[side])
		quest_ok[side] = complete
		quest_reward_ticks[side] = Quest.reward_ticks(complete)
	# Web 顺序：先按战斗结果结算宣言奖励，再做胜利方的 progress 孵化。
	if winner == SIDE_P:
		_run_progress_victory(SIDE_P, boards)
	elif winner == SIDE_E:
		_run_progress_victory(SIDE_E, boards)
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
		"amp_p": int(star_amp[SIDE_P]),
		"amp_e": int(star_amp[SIDE_E]),
		"armor_p": int(armor[SIDE_P]),
		"armor_e": int(armor[SIDE_E]),
		"dragon_layer_p": int(dragon_layer[SIDE_P]),
		"dragon_layer_e": int(dragon_layer[SIDE_E]),
		"undead_tick_p": int(death_tick[SIDE_P]),
		"undead_tick_e": int(death_tick[SIDE_E]),
		"death_delta_p": int(death_tick[SIDE_P]) - int(death_start[SIDE_P]),
		"death_delta_e": int(death_tick[SIDE_E]) - int(death_start[SIDE_E]),
		"quest_stats_p": quest_stats[SIDE_P],
		"quest_stats_e": quest_stats[SIDE_E],
		"quest_ok_p": bool(quest_ok[SIDE_P]),
		"quest_ok_e": bool(quest_ok[SIDE_E]),
		"quest_reward_ticks_p": int(quest_reward_ticks[SIDE_P]),
		"quest_reward_ticks_e": int(quest_reward_ticks[SIDE_E]),
	}

func _clean(board: Array) -> Array:
	var out: Array = []
	for u in board:
		if u != null:
			u.alive = u.hp > 0
			u.attacked_this_round = false
			u._atkDone = false
			u._poisonAtk = false
			u._dHit = 0
			u._atkT = 0
			u._dAtk = 0
			u._phA = 0
			u._phH = 0
			out.append(u)
		else:
			out.append(null)
	return out

func _arm_defenses(side: String, boards: Dictionary) -> void:
	for u in _alive_units(boards[side]):
		if u.has_kw("d"):
			u.shield = true
		if u.has_kw("t"):
			u.taunt_active = true

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

func _pick_target_for_swing(foe_board: Array, preferred_uid: int) -> Variant:
	var alive := _alive_units(foe_board)
	if alive.is_empty():
		return null
	var taunts: Array = []
	for u in alive:
		if u.taunt_active:
			taunts.append(u)
	if not taunts.is_empty():
		return taunts[rng.randi_range(0, taunts.size() - 1)]
	if preferred_uid >= 0:
		for u in alive:
			if int(u.uid) == preferred_uid:
				return u
	return alive[rng.randi_range(0, alive.size() - 1)]

func _restore_regen_taunts(board: Array) -> Array:
	var restored: Array = []
	for u in board:
		if u == null or not u.alive or not u.has_kw("t"):
			continue
		var regen := bool(u.source_card.get("regenTaunt", false)) or bool(u.skill.get("regenTaunt", false))
		if regen:
			u.taunt_active = true
			restored.append(u)
	return restored

func _attack(attacker, target, side: String, foe: String, boards: Dictionary) -> void:
	var dmg: int = attacker.atk
	var chain_bonus := 0
	# 星灵连锁：星灵随从/星灵斗士的额外连锁伤害（连锁层数×1.5×星界增幅）
	var sk_e := String(attacker.skill.get("e", ""))
	if attacker.race == "star" or sk_e == "chain-dmg":
		var amp := int(star_amp[side]) + 1
		var bonus := int(round(float(chain[side]) * 1.5 * float(amp)))
		if attacker.race == "star":
			dmg += bonus
			chain_bonus += bonus
		if sk_e == "chain-dmg":
			dmg += bonus
			chain_bonus += bonus
	_emit({"t": "attack", "src": attacker.uid, "dst": target.uid, "atk": dmg,
		"swing": int(attacker._dAtk), "chain_bonus": chain_bonus})
	var blocked := false
	if target.shield and target.has_kw("d"):
		target.shield = false
		dmg = 0
		blocked = true
		_emit({"t": "shield_break", "id": target.uid})
	if target.taunt_active and dmg > 0:
		target.taunt_active = false
		_emit({"t": "taunt_break", "id": target.uid})
	# 剧毒：仅首挥生效，绕过锁血与护甲；圣盾先于剧毒处理。
	if attacker.has_kw("p") and attacker._poisonAtk and dmg > 0:
		target.hp = 0
		_emit({"t": "poison", "src": attacker.uid, "dst": target.uid})
		_emit({"t": "damage", "src": attacker.uid, "dst": target.uid, "dmg": dmg,
			"hp": 0, "poison": true, "swing": int(attacker._dAtk)})
		_log("%s 剧毒击杀 %s" % [attacker.card_name, target.card_name])
		_kill(target, foe, boards)
		return
	if dmg <= 0:
		if blocked:
			_emit({"t": "damage", "src": attacker.uid, "dst": target.uid, "dmg": 0,
				"hp": target.hp, "blocked": true, "swing": int(attacker._dAtk)})
		return
	# 受击主线顺序：锁血减伤 → 维修护甲 → 扣血 → 充能 → 合体受击成长
	# → on-dmg → 吸血/血族治疗 → 夜间进化 → 死亡检查。
	if String(target.skill.get("e", "")) == "lockhp" and target.hp < target.max_hp * 0.5:
		dmg = int(ceil(float(dmg) * 0.67))
	var absorbed := 0
	var unit_armor: int = int(target.battle_armor)
	if unit_armor > 0 and dmg > 0:
		var take: int = mini(dmg, unit_armor)
		target.battle_armor -= take
		dmg -= take
		absorbed += take
	var side_armor: int = int(armor[foe])
	if side_armor > 0 and dmg > 0:
		var take2: int = mini(dmg, side_armor)
		armor[foe] = side_armor - take2
		dmg -= take2
		absorbed += take2
	if absorbed > 0:
		_emit({"t": "armor", "side": foe, "absorbed": absorbed,
			"left": int(armor[foe]) + int(target.battle_armor)})
		_log("维修护甲吸收 %d（剩余 %d）" % [absorbed, int(armor[foe]) + int(target.battle_armor)])
	target.hp -= dmg
	_emit({"t": "damage", "src": attacker.uid, "dst": target.uid, "dmg": dmg,
		"hp": max(0, target.hp), "swing": int(attacker._dAtk)})
	_log("%s 攻击 %s，造成 %d 伤害" % [attacker.card_name, target.card_name, dmg])
	_charge_tick(target, foe, boards)
	_apply_mech_damage_growth(target)
	_run_on_damage_skill(target, foe, boards)
	_apply_lifesteal(attacker, side, boards, dmg)
	if int(phase[foe]) == 1 and target.race == "evolve" and target._phH < 3:
		target._phH += 1
		_evolve_tick(target, foe, boards)
	if target.hp <= 0 and target.alive:
		_kill(target, foe, boards)
		_log("%s 阵亡" % target.card_name)

func _apply_mech_damage_growth(u) -> void:
	if u.mech_dmg_grow <= 0:
		return
	var gain_value: int = u.mech_dmg_grow
	u.gain(gain_value, gain_value)
	_emit({"t": "buff", "id": u.uid, "a": gain_value, "h": gain_value, "source": "mech_dmg"})
	_log("%s：合体肢体受击 +%d/+%d" % [u.card_name, gain_value, gain_value])

func _run_on_damage_skill(u, side: String, boards: Dictionary) -> void:
	var sk: Dictionary = u.skill
	if sk.is_empty() or String(sk.get("t", "")) != "on-dmg":
		return
	match String(sk.get("e", "")):
		"self-buff":
			var a := int(sk.get("a", 0))
			var h := int(sk.get("h", 0))
			if bool(sk.get("grow", false)):
				u._dHit += 1
				a += u._dHit - 1
				h += (u._dHit - 1) * 2
			u.atk += a
			u.hp += h
			u.max_hp += h
			_emit({"t": "buff", "id": u.uid, "a": a, "h": h,
				"source": "vampire-on-dmg" if u.race == "vampire" else "on_dmg"})
		"maxhp-buff":
			u._mhT += 1
			var scale: int = 1 + (u._mhT - 1 if bool(sk.get("grow", false)) else 0)
			var a2 := int(sk.get("a", 2)) * scale
			var h2 := int(sk.get("h", 2)) * scale
			u.max_hp += h2
			u.hp += h2
			u.atk += a2
			_emit({"t": "buff", "id": u.uid, "a": a2, "h": h2, "maxhp": h2, "source": "maxhp-buff"})
		"race-buff":
			u._t += 1
			var multiplier: int = u._t + u._gb if bool(sk.get("grow", false)) else 1
			var race := String(sk.get("race", u.race))
			var a3 := int(sk.get("a", 0)) * multiplier
			var h3 := int(sk.get("h", 0)) * multiplier
			for ally in _alive_units(boards[side]):
				if ally.race == race:
					ally.gain(a3, h3)
					_emit({"t": "buff", "id": ally.uid, "a": a3, "h": h3,
						"source": "vampire-on-dmg" if race == "vampire" else "on_dmg"})
		"evolve":
			_evolve_tick(u, side, boards)

func _apply_lifesteal(attacker, side: String, boards: Dictionary, damage: int) -> void:
	if not attacker.has_kw("l") or damage <= 0:
		return
	var amount: int = maxi(1, int(floor(float(damage) / 2.0)))
	if String(attacker.skill.get("e", "")) == "race-heal":
		for ally in _alive_units(boards[side]):
			if ally.race == "vampire" and ally.hp < ally.max_hp:
				var old: int = ally.hp
				ally.hp = mini(ally.hp + amount, ally.max_hp)
				_emit({"t": "heal", "id": ally.uid, "val": ally.hp - old, "source": "race-heal"})
		return
	var old_self: int = attacker.hp
	attacker.hp = mini(attacker.hp + amount, attacker.max_hp)
	if attacker.hp > old_self:
		_emit({"t": "heal", "id": attacker.uid, "val": attacker.hp - old_self, "source": "lifesteal"})

func _run_start_skills(side: String, boards: Dictionary) -> void:
	# Web 在普通开场技能前先累计龙威，再按“龙威层 × 场上龙数”统一给龙加成。
	for u in _alive_units(boards[side]):
		if String(u.skill.get("e", "")) == "dragon-aura":
			dragon_layer[side] += int(u.skill.get("times", 1))
	var dragon_count := 0
	for u in _alive_units(boards[side]):
		if u.race == "dragon":
			dragon_count += 1
	if dragon_count > 0:
		var aura_gain: int = int(dragon_layer[side]) * dragon_count
		for u in _alive_units(boards[side]):
			if u.race == "dragon":
				u.gain(aura_gain, aura_gain)
				_emit({"t": "buff", "id": u.uid, "a": aura_gain, "h": aura_gain, "source": "dragon-aura"})
		_log("龙威：全龙 +%d/+%d（层数 %d × 龙数 %d）" % [
			aura_gain, aura_gain, int(dragon_layer[side]), dragon_count])
	for u in _alive_units(boards[side]):
		var sk: Dictionary = u.skill
		if sk.is_empty():
			continue
		var t := String(sk.get("t", ""))
		var e := String(sk.get("e", ""))
		if t != "start" and t != "battle":
			continue
		if e == "death-race-buff":
			var death_count: int = mini(int(prev_death_tick[side]),
				mini(6, 2 + int(debt_tier[side]) * 2))
			if death_count > 0:
				var a_d := maxi(1, int(round(float(int(sk.get("a", 1)) * death_count) / 3.0)))
				var h_d := maxi(1, int(round(float(int(sk.get("h", 1)) * death_count) / 3.0)))
				_gain_race(side, "sacrifice", a_d, h_d, boards, "death-race-buff")
			if int(sk.get("debtMax", 0)) > 0:
				_settle_debt(side, boards, u)
		elif e == "debt-lord":
			var tier: int = int(debt_tier[side])
			if tier > 0:
				var gain_lord: int = int(round(float(tier * (tier + 1) / 2) * float(sk.get("a", 2)) / 3.0))
				gain_lord = maxi(1, gain_lord)
				_gain_race(side, "sacrifice", gain_lord, gain_lord, boards, "debt-lord")
				_log("%s：债务节点 %d，全献祭 +%d/+%d" % [u.card_name, tier, gain_lord, gain_lord])
		elif e == "contract-set":
			_set_contract(side, boards, u)
		elif e == "debt-payoff":
			_settle_debt(side, boards, u)
		elif e == "evo-advance":
			u._t += 1
			var a: int = int(sk.get("a", 1)) * (u._t if bool(sk.get("grow", false)) else 1)
			var h: int = int(sk.get("h", 1)) * (u._t if bool(sk.get("grow", false)) else 1)
			for ally in _alive_units(boards[side]):
				if ally.race == "evolve":
					ally.gain(a, h)
					_emit({"t": "buff", "id": ally.uid, "a": a, "h": h})
					if not ally.skill.is_empty() and String(ally.skill.get("e", "")).begins_with("evolve"):
						_evolve_tick(ally, side, boards)
			_log("%s 推进全场进化" % u.card_name)
		elif e == "evo-devourer":
			var max_gene := int(sk.get("max", 5))
			if u.gene < max_gene:
				u.gene += 1
				var a2 := int(sk.get("a", 2))
				var h2 := int(sk.get("h", 2))
				u.gain(a2, h2)
				_emit({"t": "gene", "id": u.uid, "gene": u.gene, "a": a2, "h": h2})
		elif e == "progress":
			# progress 是战斗胜利结算，不应在开场技能阶段提前推进。
			if String(sk.get("t", "")) != "battle":
				_progress_step(u)
		elif e == "chain-start":
			chain[side] = int(chain[side]) + 1
			_emit({"t": "chain", "id": u.uid, "value": int(chain[side]), "source": "start"})
			_log("%s：连锁 +1（当前 %d）" % [u.card_name, int(chain[side])])
		elif e == "star-amp":
			chain[side] = int(chain[side]) + 1
			star_amp[side] = int(star_amp[side]) + 1
			_emit({"t": "amp", "id": u.uid, "chain": int(chain[side]), "amp": int(star_amp[side])})
			_log("%s：连锁 +1，星灵连锁伤害翻倍（增幅 %d）" % [u.card_name, int(star_amp[side])])
		elif e == "dragon-aura":
			pass
		elif e == "dragon-aura-minor":
			if dragon_count >= 1:
				var minor_gain: int = maxi(1, int(floor(
					float(dragon_layer[side]) * float(dragon_count) * float(sk.get("a", 1)) * 3.0 / 4.0)))
				_gain_race(side, "dragon", minor_gain, minor_gain, boards, "dragon-aura-minor")
				_log("龙威号角：全龙 +%d/+%d" % [minor_gain, minor_gain])
		elif e == "undead-rebirth":
			var rebirth_slot: int = boards[side].find(u)
			u._t += 1
			var rebirth_a: int = (int(sk.get("a", 0)) + u._gb) * (u._t if bool(sk.get("grow", false)) else 1)
			var rebirth_h: int = (int(sk.get("h", 0)) + u._gb) * (u._t if bool(sk.get("grow", false)) else 1)
			u.gain(rebirth_a, rebirth_h)
			var saved_hp: int = u.hp
			u.hp = 0
			_kill(u, side, boards)
			u.hp = saved_hp
			u.alive = true
			if rebirth_slot >= 0 and rebirth_slot < boards[side].size() and boards[side][rebirth_slot] == null:
				boards[side][rebirth_slot] = u
			else:
				var empty_slot: int = boards[side].find(null)
				if empty_slot >= 0:
					boards[side][empty_slot] = u
			var undead_a: int = maxi(1, int(floor(float(rebirth_a) / 2.0)))
			var undead_h: int = maxi(1, int(floor(float(rebirth_h) / 2.0)))
			for ally in _alive_units(boards[side]):
				if ally.race == "undead" and ally != u:
					ally.gain(undead_a, undead_h)
					_emit({"t": "buff", "id": ally.uid, "a": undead_a, "h": undead_h})
			_emit({"t": "rebirth", "id": u.uid, "a": rebirth_a, "h": rebirth_h})
			_log("%s：死亡重生 +%d/+%d，全亡灵 +%d/+%d" % [
				u.card_name, rebirth_a, rebirth_h, undead_a, undead_h])
		elif e == "multihit":
			var times: int = int(sk.get("times", 1))
			u._hit += times
			u._t += times
			u._atkLeft = u._hit
			_log("%s：本回合攻击 %d 次，每次共鸣恶魔 +%d/+%d" % [u.card_name, u._hit, u._t, u._t])
		elif e == "double-rnd":
			var pool := _alive_units(boards[side])
			if not pool.is_empty():
				var target = pool[rng.randi_range(0, pool.size() - 1)]
				target.atk *= 2
				target.hp = target.hp * 2
				target.max_hp = target.hp
				_emit({"t": "buff", "id": target.uid, "a": target.atk / 2, "h": target.hp / 2})
		elif e == "double-all":
			var multiplier: int = int(sk.get("d", 1)) * (1 + rng.randi_range(0, 1))
			for ally in _alive_units(boards[side]):
				var old_a: int = ally.atk
				var old_h: int = ally.hp
				ally.atk *= multiplier
				ally.hp *= multiplier
				ally.max_hp = ally.hp
				_emit({"t": "buff", "id": ally.uid, "a": ally.atk - old_a, "h": ally.hp - old_h})
			_emit({"t": "gamble", "id": u.uid, "success": multiplier > 1, "mult": multiplier, "scope": "all"})
		elif e == "race-buff":
			var race := String(sk.get("race", u.race))
			if race == "star":
				chain[side] = int(chain[side]) + 1
			u._t += 1
			var a3: int
			var h3: int
			if race == "star":
				a3 = int(round(float(maxi(1, int(chain[side]))) * float(sk.get("statScale", 1.0))))
				h3 = a3
			else:
				a3 = int(sk.get("a", 1)) * (u._t if bool(sk.get("grow", false)) else 1)
				h3 = int(sk.get("h", 1)) * (u._t if bool(sk.get("grow", false)) else 1)
			for ally in _alive_units(boards[side]):
				if ally.race == race:
					ally.gain(a3, h3)
					_emit({"t": "buff", "id": ally.uid, "a": a3, "h": h3})
		elif e == "gamble":
			_roll_gamble(u, side, boards)
		elif e == "evolve" or e == "evolve-step":
			_evolve_tick(u, side, boards)
		elif e == "self-buff":
			var a4: int = int(sk.get("a", 0)) + u._gb
			var h4: int = int(sk.get("h", 0)) + u._gb
			u.gain(a4, h4)
			_emit({"t": "buff", "id": u.uid, "a": a4, "h": h4})
		elif e == "growth-self":
			u._g += int(sk.get("times", 1))
			var grow: int = u._g + u._gb
			u.gain(grow, grow)
			_emit({"t": "buff", "id": u.uid, "a": grow, "h": grow})
		elif e == "ally-all-buff":
			u._t += int(sk.get("times", 1))
			for ally in _alive_units(boards[side]):
				ally.gain(u._t, u._t)
				_emit({"t": "buff", "id": ally.uid, "a": u._t, "h": u._t})
			_log("%s：全体 +%d/+%d" % [u.card_name, u._t, u._t])
		elif e == "dmg-allies":
			var times2: int = int(sk.get("times", 1))
			for i in range(times2):
				for ally in _alive_units(boards[side]):
					if ally == u:
						continue
					_apply_direct_damage(ally, side, boards, int(sk.get("d", 1)), u.uid)

func _set_contract(side: String, boards: Dictionary, source) -> void:
	if int(contract_id[side]) >= 0:
		return
	var contract_target = null
	for ally in _alive_units(boards[side]):
		if ally == source or ally.race != "sacrifice":
			continue
		if contract_target == null or ally.atk + ally.hp < contract_target.atk + contract_target.hp:
			contract_target = ally
	if contract_target == null:
		return
	contract_id[side] = contract_target.uid
	var debt_bonus := int(source.skill.get("debtBonus", 3))
	contract_bonus[side] = int(contract_bonus[side]) + debt_bonus
	_emit({"t": "contract", "side": side, "id": contract_target.uid, "debtBonus": debt_bonus})
	_log("%s：契印 → %s（额外债务 +%d）" % [
		source.card_name, contract_target.card_name, debt_bonus])

func _gain_race(side: String, race: String, a: int, h: int, boards: Dictionary,
		source: String = "") -> void:
	for ally in _alive_units(boards[side]):
		if ally.race == race:
			ally.gain(a, h)
			var ev := {"t": "buff", "id": ally.uid, "a": a, "h": h}
			if source != "":
				ev["source"] = source
			_emit(ev)

## progress：战斗胜利再 +1；满 5 格替换为 7 星混沌始祖（8 + 层数×3），保留层数并以基因数起步。
func _progress_step(u) -> bool:
	u._pr += 1
	_emit({"t": "progress", "id": u.uid, "progress": u._pr, "need": 5})
	if u._pr < 5:
		return false
	_emit({"t": "progress_full", "id": u.uid})
	return true


func _board_has_race(board: Array, race: String) -> bool:
	for u in board:
		if u != null and String(u.race) == race:
			return true
	return false


func _run_progress_victory(side: String, boards: Dictionary) -> void:
	var board: Array = boards[side]
	for i in range(board.size()):
		var u = board[i]
		if u == null or not u.alive:
			continue
		if String(u.skill.get("t", "")) != "battle" or String(u.skill.get("e", "")) != "progress":
			continue
		if not _progress_step(u):
			continue
		var layers: int = mini(5, int(u._pr))
		var body_value: int = 8 + layers * 3
		var evolved = UnitScript.from_card({
			"n": "混沌始祖", "a": body_value, "h": body_value, "star": 7, "race": "evolve",
			"sk": {"t": "start", "e": "evo-devourer", "a": 2, "h": 2, "team": 1, "max": 5},
			"sc": {"t": "spell-cast", "e": "self-growth-boost"},
			"_gene": layers,
			"mh": body_value,
		}, u.uid)
		evolved._side = side
		board[i] = evolved
		_emit({"t": "progress_hatch", "id": evolved.uid, "layers": layers,
			"a": body_value, "h": body_value, "name": evolved.card_name})
		_log("孵化！混沌始祖，继承 %d 层基因（%d/%d）" % [layers, body_value, body_value])

func _roll_gamble(u, side: String, boards: Dictionary) -> void:
	var sk: Dictionary = u.skill
	var success_rate := float(sk.get("succ", 0.65))
	var low := int(sk.get("ml", sk.get("times", 1)))
	var high := int(sk.get("mh", low + 1))
	var success := rng.randf() < success_rate
	var multiplier: int = 0
	if success:
		multiplier = low + rng.randi_range(0, maxi(0, high - low))
	var base_a := int(sk.get("a", 1))
	var base_h := int(sk.get("h", base_a))
	var scope := String(sk.get("scope", "all"))
	_emit({"t": "gamble", "id": u.uid, "success": success, "mult": multiplier, "scope": scope})
	if not success:
		return
	var pool: Array = []
	if scope == "rnd":
		var alive := _alive_units(boards[side])
		if alive.is_empty():
			return
		pool = [alive[rng.randi_range(0, alive.size() - 1)]]
	elif scope == "race":
		for ally in _alive_units(boards[side]):
			if ally.race == "gambler":
				pool.append(ally)
	else:
		pool = _alive_units(boards[side])
	for target in pool:
		var gain_a: int = base_a * multiplier
		var gain_h: int = base_h * multiplier
		target.gain(gain_a, gain_h)
		_emit({"t": "buff", "id": target.uid, "a": gain_a, "h": gain_h, "gamble": true})

func _apply_direct_damage(target, side: String, boards: Dictionary, damage: int, source_uid: int) -> void:
	if target == null or not target.alive:
		return
	target.hp -= damage
	_emit({"t": "damage", "src": source_uid, "dst": target.uid, "dmg": damage,
		"hp": maxi(0, target.hp), "direct": true})
	if target.hp <= 0:
		_kill(target, side, boards)
	else:
		_charge_tick(target, side, boards)
		_apply_mech_damage_growth(target)
		_run_on_damage_skill(target, side, boards)

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
	u._ev += 1
	u._evoGainTick += 1
	# 进化条每次推进；即时属性成长改为每2次触发结算一次。
	if u._evoGainTick % 2 == 1:
		if String(sk.get("t", "")) == "on-dmg":
			u.atk += u.stat_gain
			_emit({"t": "buff", "id": u.uid, "a": u.stat_gain, "h": 0})
		else:
			u.gain(u.stat_gain, u.stat_gain)
			_emit({"t": "buff", "id": u.uid, "a": u.stat_gain, "h": u.stat_gain})
	if u.evo < need:
		_emit({"t": "evop", "id": u.uid, "evo": u.evo, "need": need, "total": u._ev})
		return
	u.evo = 0
	_emit({"t": "evo_full", "id": u.uid, "total": u._ev})
	if String(sk.get("t", "")) == "on-dmg":
		var max_c := int(sk.get("maxC", 3))
		if u.vc < max_c:
			u.vc += 1
			u.atk = int(round(u.atk * 1.5))
		else:
			u.atk += 4
		_emit({"t": "evolve", "id": u.uid, "kind": "atk_x1.5", "atk": u.atk, "total": u._ev})
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
			_emit({"t": "evolve", "id": u.uid, "kind": "stat_x2", "total": u._ev})
		else:
			var ga := int(sk.get("a", 2))
			var gh := int(sk.get("h", 2))
			u.gain(ga, gh)
			_emit({"t": "buff", "id": u.uid, "a": ga, "h": gh})
			_emit({"t": "evolve", "id": u.uid, "kind": "small", "total": u._ev})
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
	return int(Sacrifice.debt_tier(v))

func _debt_payoff_info(v: int) -> Dictionary:
	return Sacrifice.payoff_info(v)

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
					_emit({"t": "buff", "id": u.uid, "a": 1, "h": 1, "source": "race-synergy"})
			_log("同族共鸣：%s +1/+1" % race)

func _add_debt(side: String, n: int, source_uid: int = -1, reason: String = "effect") -> Dictionary:
	var change: Dictionary = Sacrifice.add_debt(int(debt[side]), n)
	debt[side] = int(change["new"])
	debt_tier[side] = int(change["tier"])
	var ev := {
		"t": "debt",
		"side": side,
		"src": source_uid,
		"reason": reason,
		"delta": int(change["delta"]),
		"old": int(change["old"]),
		"debt": int(debt[side]),
		"tier": int(debt_tier[side]),
		"node_rewards": change["node_rewards"].duplicate(),
	}
	_emit(ev)
	for reward in change["node_rewards"]:
		_log("债务节点跃迁：额外 +%d 债务" % int(reward))
	return ev

func _settle_debt(side: String, boards: Dictionary, u) -> void:
	if bool(debt_settled[side]):
		return
	var info := _debt_payoff_info(int(debt[side]))
	var need := int(info["need"])
	if need <= 0:
		return
	var gain := Sacrifice.payoff_gain(
		info, float(debt_pay_bonus[side]), int(u.pay_a), int(u.pay_h),
		_debt_ramp(), 2 if u.gold_card else 1)
	var ga := gain.x
	var gh := gain.y
	var old_debt: int = int(debt[side])
	debt[side] = max(0, old_debt - need)
	debt_tier[side] = _debt_tier(int(debt[side]))
	debt_settled[side] = true
	_emit({
		"t": "debt_settle",
		"side": side,
		"src": u.uid,
		"reason": "payoff",
		"need": need,
		"tier": int(info["tier"]),
		"a": ga,
		"h": gh,
		"old": old_debt,
		"debt": int(debt[side]),
	})
	for ally in _alive_units(boards[side]):
		if ally.race == "sacrifice":
			ally.gain(ga, gh)
			_emit({"t": "buff", "id": ally.uid, "a": ga, "h": gh, "source": "debt-payoff"})
	_debt_node_bonus(side, boards, need)
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
				_emit({"t": "buff", "id": ally.uid, "a": ga, "h": ga, "source": "debt-totem"})
	for u in _alive_units(boards[side]):
		var rate := float(u.skill.get("debt", 0.0))
		if rate > 0.0:
			var gg: int = max(1, int(round(float(used) * rate)))
			u.gain(gg, gg)
			_emit({"t": "buff", "id": u.uid, "a": gg, "h": gg, "source": "debt-battery"})

func _kill(dead, side: String, boards: Dictionary) -> void:
	if dead == null:
		return
	var was_alive: bool = bool(dead.alive)
	dead.alive = false
	var dead_index: int = boards[side].find(dead)
	if dead_index >= 0:
		boards[side][dead_index] = null
	if not was_alive:
		return
	death_tick[side] += 1
	if dead.race == "undead":
		pass
	_emit({"t": "death", "id": dead.uid, "name": dead.card_name,
		"a": int(dead.atk), "h": int(dead.hp)})
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
			_emit({"t": "buff", "id": u.uid, "a": ia, "h": ih, "source": "inherit"})
	# 契印结算：目标死亡 → 债务
	if int(contract_id[side]) == dead.uid:
		var dbb := 0
		for u in _alive_units(boards[side]):
			if String(u.skill.get("e", "")) == "debt-boost":
				dbb += int(u.skill.get("a", 0))
		var tot := 0.0
		for u in _alive_units(boards[side]):
			if String(u.skill.get("e", "")) == "debt-totem":
				tot = maxf(tot, 1.5 if u.gold_card else 1.17)
		var devoured_contract := devour_boost > 0
		var raw: int = Sacrifice.contract_debt_raw(
			dead, round_no, dbb, int(contract_bonus[side]), tot, devoured_contract)
		if devoured_contract:
			devour_boost = 0
		var debt_event: Dictionary = _add_debt(side, raw, dead.uid, "contract_death")
		debt_event["contract_bonus"] = int(contract_bonus[side])
		debt_event["totem_multiplier"] = tot
		debt_event["devoured_contract"] = devoured_contract
		contract_id[side] = -1
		contract_bonus[side] = 0
		_log("契印结算：债务 +%d" % raw)
	# 死亡技能：召唤、随机族裔成长、全族成长与债务增幅。
	var death_skill: Dictionary = dead.skill
	if String(death_skill.get("t", "")) == "death":
		match String(death_skill.get("e", "")):
			"summon":
				var count := int(death_skill.get("count", 1))
				for i in range(count):
					var skeleton_card := {
						"n": "骷髅兵", "a": 1, "h": 1, "s": 1, "race": "undead",
						"t": "m", "_summoned": true,
					}
					var skeleton = UnitScript.from_card(skeleton_card, 900000 + events.size())
					var slot: int = _place_summon(boards, side, skeleton)
					if slot >= 0:
						_emit({"t": "summon", "src": dead.uid, "id": skeleton.uid, "slot": slot,
							"side": side, "name": skeleton.card_name, "a": skeleton.atk,
							"h": skeleton.hp, "s": skeleton.star, "race": skeleton.race})
			"rnd-race-buff":
				var race_r := String(death_skill.get("race", dead.race))
				var pool_r: Array = []
				for ally in _alive_units(boards[side]):
					if ally.race == race_r and ally != dead:
						pool_r.append(ally)
				if not pool_r.is_empty():
					var target_r = pool_r[rng.randi_range(0, pool_r.size() - 1)]
					var a_r := int(death_skill.get("a", 1))
					var h_r := int(death_skill.get("h", 1))
					if race_r == "undead":
						var delta_r: int = maxi(0, int(death_tick[side]) - int(dead._udBase))
						a_r += int(ceil(float(delta_r) / 2.0))
						h_r += int(ceil(float(delta_r) / 2.0))
					target_r.gain(a_r, h_r)
					_emit({"t": "buff", "id": target_r.uid, "a": a_r, "h": h_r, "source": dead.uid})
			"race-buff":
				var race_b := String(death_skill.get("race", dead.race))
				var a_b := int(death_skill.get("a", 0))
				var h_b := int(death_skill.get("h", 0))
				if race_b == "undead":
					var delta_b: int = maxi(0, int(death_tick[side]) - int(dead._udBase))
					a_b += int(ceil(float(delta_b) / 2.0))
					h_b += int(ceil(float(delta_b) / 2.0))
				_gain_race(side, race_b, a_b, h_b, boards,
					"undead-death" if race_b == "undead" else "death-race-buff")
				if String(death_skill.get("sum", "")) == "general":
					var general_value := 5 * int(death_skill.get("times", 1)) + a_b
					var general = UnitScript.from_card({
						"n": "骷髅将军", "a": general_value, "h": general_value + h_b, "s": 6,
						"race": "undead", "t": "m", "mh": general_value + h_b,
						"sk": {"t": "aura", "e": "skeleton-army"},
					}, 910000 + events.size())
					general._skipOnce = true
					var general_slot: int = _place_summon(boards, side, general)
					if general_slot >= 0:
						_emit({"t": "summon", "src": dead.uid, "id": general.uid, "slot": general_slot,
							"side": side, "name": general.card_name, "a": general.atk,
							"h": general.hp, "s": general.star, "race": general.race})
					for skeleton in _alive_units(boards[side]):
						if skeleton.card_name == "骷髅兵":
							skeleton.gain(1, 1)
							_emit({"t": "buff", "id": skeleton.uid, "a": 1, "h": 1})
	for undead_listener in _alive_units(boards[side]):
		if String(undead_listener.skill.get("e", "")) == "skeleton-army":
			if undead_listener._skipOnce:
				undead_listener._skipOnce = false
			else:
				undead_listener.gain(1, 1)
				_emit({"t": "buff", "id": undead_listener.uid, "a": 1, "h": 1})

func _place_summon(boards: Dictionary, side: String, unit) -> int:
	for slot in range(boards[side].size()):
		if boards[side][slot] == null or not boards[side][slot].alive:
			boards[side][slot] = unit
			return slot
	return -1


## ---------- 星灵连锁 ----------

func _after_attack_star(atk, side: String, foe: String, boards: Dictionary) -> void:
	if atk.race != "star":
		return
	chain[side] = int(chain[side]) + 1
	_emit({"t": "chain", "id": atk.uid, "value": int(chain[side]), "source": "attack"})
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
		if u._atkLeft > 1:
			u._atkLeft -= 1
			return u
		if not u._atkDone and not u._noTurn:
			u._atkDone = true
			return u
	for u in board:
		if u != null and u.alive:
			u._atkDone = false
	for u in _restore_regen_taunts(board):
		_emit({"t": "taunt_regen", "id": u.uid})
	for u in board:
		if u != null and u.alive and not u._noTurn:
			u._atkDone = true
			return u
	for u in board:
		if u != null and u.alive:
			return u
	return null

func _random_actor(board: Array):
	var pool: Array = []
	for u in board:
		if u != null and u.alive and not u._atkDone and not u._noTurn:
			pool.append(u)
	if pool.is_empty():
		for u in board:
			if u != null and u.alive:
				u._atkDone = false
		for u in _restore_regen_taunts(board):
			_emit({"t": "taunt_regen", "id": u.uid})
		for u in board:
			if u != null and u.alive and not u._noTurn:
				pool.append(u)
	if pool.is_empty():
		return null
	var actor = pool[rng.randi_range(0, pool.size() - 1)]
	actor._atkDone = true
	return actor

func _swing(u, side: String, foe: String, boards: Dictionary, preferred_uid: int = -1) -> int:
	var swings: int = (2 if u.has_kw("w") else 1) + maxi(0, int(u._extraAtk))
	var last_target_uid := -1
	var target = null
	for swing in range(swings):
		if not u.alive:
			break
		if preferred_uid >= 0 or target == null or not target.alive:
			target = _pick_target_for_swing(boards[foe], preferred_uid)
		if target == null:
			break
		u._dAtk = swing
		u._poisonAtk = swing == 0
		last_target_uid = target.uid
		_attack(u, target, side, foe, boards)
	# Web：全部挥击结束后才执行一次攻击尾部，再让机械协同随从跟随。
	_run_attack_tail(u, side, foe, boards)
	if u.mech_body:
		_mech_follow_attack(side, foe, u, boards, last_target_uid)
	return last_target_uid

func _run_attack_tail(u, side: String, foe: String, boards: Dictionary) -> void:
	if u == null:
		return
	_after_attack_star(u, side, foe, boards)
	if u.mech_head_grow > 0:
		var head_gain: int = u.mech_head_grow * (2 if u.head_double else 1)
		u.gain(head_gain, head_gain)
		_emit({"t": "buff", "id": u.uid, "a": head_gain, "h": head_gain, "source": "mech-head"})
	if u.charge_max > 0:
		_charge_tick(u, side, boards)
	if u.race == "evolve" and int(phase[side]) == 0 and u._phA < 2:
		u._phA += 1
		_evolve_tick(u, side, boards)
	for ally in _alive_units(boards[side]):
		if ally.race != "dragon":
			continue
		var sk: Dictionary = ally.skill
		if int(sk.get("atkGrow", 0)) > 0:
			ally._atkT += 1
			if ally._atkT <= 2:
				var grow: int = int(sk.get("atkGrow", 1))
				ally.gain(grow, grow)
				_emit({"t": "buff", "id": ally.uid, "a": grow, "h": grow, "source": "dragon-attack"})
		if String(sk.get("e", "")) == "atk-react":
			ally._atkT += 1
			if ally._atkT <= 4:
				var react_gain: int = int(sk.get("a", 2)) + maxi(0, ally._atkT - 1)
				ally.gain(react_gain, react_gain)
				_emit({"t": "buff", "id": ally.uid, "a": react_gain, "h": react_gain, "source": "atk-react"})
	if String(u.skill.get("e", "")) == "multihit":
		var resonance: int = maxi(1, int(u._t))
		for ally in _alive_units(boards[side]):
			if ally.race == "demon":
				ally.gain(resonance, resonance)
				_emit({"t": "buff", "id": ally.uid, "a": resonance, "h": resonance, "source": "multihit"})
	if not u.attack_skill.is_empty() and String(u.attack_skill.get("e", "")) == "self-race-buff":
		var self_race := String(u.attack_skill.get("race", u.race))
		var self_a := int(u.attack_skill.get("a", 0))
		var self_h := int(u.attack_skill.get("h", 0))
		for member in _alive_units(boards[side]):
			if member.race == self_race:
				member.gain(self_a, self_h)
				_emit({"t": "buff", "id": member.uid, "a": self_a, "h": self_h, "source": "atkSk"})
	for ally in _alive_units(boards[side]):
		var attack_skill: Dictionary = ally.skill
		if String(attack_skill.get("t", "")) != "attack":
			continue
		var ae := String(attack_skill.get("e", ""))
		if ae == "evolve-step":
			if ally == u:
				_evolve_tick(ally, side, boards)
		elif ae == "race-buff":
			var race_a := String(attack_skill.get("race", ally.race))
			var a_a := int(attack_skill.get("a", 0))
			var h_a := int(attack_skill.get("h", 0))
			_gain_race(side, race_a, a_a, h_a, boards, "atkSk")
		elif ae == "heal-race":
			var race_h := String(attack_skill.get("race", ally.race))
			var heal_value: int = maxi(1, int(u.atk)) * int(attack_skill.get("times", 1))
			for member in _alive_units(boards[side]):
				if member.race == race_h and member.hp < member.max_hp:
					var old_h: int = member.hp
					member.hp = mini(member.hp + heal_value, member.max_hp)
					_emit({"t": "heal", "id": member.uid, "val": member.hp - old_h, "source": "heal-race"})
			var a_h := int(attack_skill.get("a", 1))
			var h_h := int(attack_skill.get("h", 1))
			for member in _alive_units(boards[side]):
				if member.race == race_h:
					member.atk += a_h
					member.hp += h_h
					member.max_hp += int(attack_skill.get("mh", h_h))
					_emit({"t": "buff", "id": member.uid, "a": a_h, "h": h_h, "source": "heal-race"})
			if int(attack_skill.get("healMh", 0)) > 0:
				for member in _alive_units(boards[side]):
					if member.race == "vampire" and String(member.skill.get("e", "")) == "lockhp":
						member._hT += 1
						member.max_hp += int(attack_skill.get("healMh", 1))
						member.hp += int(attack_skill.get("healMh", 1))
						_emit({"t": "buff", "id": member.uid, "a": 0,
							"h": int(attack_skill.get("healMh", 1)), "source": "maxhp-buff"})
		elif ae == "race-heal" and ally == u:
			var blood_heal: int = maxi(1, int(floor(float(u.atk) / 2.0)))
			for member in _alive_units(boards[side]):
				if member.race == "vampire" and member.hp < member.max_hp:
					var old_v: int = member.hp
					member.hp = mini(member.hp + blood_heal, member.max_hp)
					_emit({"t": "heal", "id": member.uid, "val": member.hp - old_v, "source": "race-heal"})

## 协同攻击：合体体出手后，己方协同随从各打一次（strike 50% 合体攻击，其余 25%），
## 目标优先沿用合体体刚打的目标，其次嘲讽，再随机；不消耗协同随从自身出手。
func _mech_follow_attack(side: String, foe: String, body, boards: Dictionary, target_uid: int = -1) -> void:
	for u in _alive_units(boards[side]):
		if u.follow_type == "" or u == body or u.follow_body_id != body.uid:
			continue
		var pool := _alive_units(boards[foe])
		if pool.is_empty():
			break
		var target = null
		for candidate in pool:
			if candidate.uid == target_uid:
				target = candidate
				break
		if target == null:
			for candidate in pool:
				if candidate.taunt_active:
					target = candidate
					break
		if target == null:
			target = pool[rng.randi_range(0, pool.size() - 1)]
		var ratio := 0.5 if u.follow_type == "strike" else 0.25
		var dmg: int = max(1, int(ceil(float(body.atk) * ratio)))
		_emit({"t": "attack", "src": u.uid, "dst": target.uid, "atk": dmg, "follow": 1})
		var blocked := false
		if target.shield and target.has_kw("d"):
			target.shield = false
			dmg = 0
			blocked = true
			_emit({"t": "shield_break", "id": target.uid})
		if target.taunt_active and dmg > 0:
			target.taunt_active = false
			_emit({"t": "taunt_break", "id": target.uid})
		if int(armor[foe]) > 0 and dmg > 0:
			var absorbed: int = min(dmg, int(armor[foe]))
			armor[foe] = int(armor[foe]) - absorbed
			dmg -= absorbed
			_emit({"t": "armor", "side": foe, "absorbed": absorbed, "left": int(armor[foe])})
		if dmg > 0:
			target.hp -= dmg
			_emit({"t": "damage", "src": u.uid, "dst": target.uid, "dmg": dmg, "hp": max(0, target.hp), "follow": 1})
			if target.hp <= 0 and target.alive:
				_kill(target, foe, boards)
		if u.follow_type == "repair":
			var repair_value: int = maxi(1, int(ceil(float(body.atk) * 0.25)))
			var old_body_hp: int = body.hp
			body.hp = mini(body.hp + repair_value, body.max_hp)
			if body.hp > old_body_hp:
				_emit({"t": "heal", "id": body.uid, "val": body.hp - old_body_hp, "follow": 1})
		elif u.follow_type == "guard":
			u.shield = true
			u.taunt_active = true
			_emit({"t": "guard", "id": u.uid})
		_log("%s 协同攻击 %s（%d%s）" % [u.card_name, target.card_name, dmg,
			" 被圣盾挡下" if blocked else ""])


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
	_emit({"t": "ch", "id": u.uid, "c": 0, "cm": max_charge})
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
