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

func resolve(p_board: Array, e_board: Array, seed_value: int = 1, max_rounds: int = 30) -> Dictionary:
	rng.seed = seed_value
	events.clear()
	log_lines.clear()
	var boards := {SIDE_P: _clean(p_board), SIDE_E: _clean(e_board)}

	_run_start_skills(SIDE_P, boards)
	_run_start_skills(SIDE_E, boards)

	var round := 0
	while _alive_count(boards[SIDE_P]) > 0 and _alive_count(boards[SIDE_E]) > 0 and round < max_rounds:
		round += 1
		for side in [SIDE_P, SIDE_E]:
			var foe: String = SIDE_E if side == SIDE_P else SIDE_P
			for u in boards[side]:
				if u == null or not u.alive:
					continue
				var swings := 2 if u.has_kw("w") else 1
				for _s in range(swings):
					if not u.alive:
						break
					var target = _pick_target(boards[foe])
					if target == null:
						break
					_attack(u, target, side, foe, boards)
			if _alive_count(boards[SIDE_P]) == 0 or _alive_count(boards[SIDE_E]) == 0:
				break

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

func _attack(attacker, target, side: String, foe: String, boards: Dictionary) -> void:
	var dmg: int = attacker.atk
	_emit({"t": "attack", "src": attacker.uid, "dst": target.uid, "atk": dmg})
	if target.shield:
		target.shield = false
		_emit({"t": "shield_break", "id": target.uid})
		dmg = 0
	if target.taunt_active:
		target.taunt_active = false
		_emit({"t": "taunt_break", "id": target.uid})
	if dmg > 0:
		target.hp -= dmg
		_emit({"t": "damage", "src": attacker.uid, "dst": target.uid, "dmg": dmg, "hp": max(0, target.hp)})
		_log("%s 攻击 %s，造成 %d 伤害" % [attacker.card_name, target.card_name, dmg])
		_on_damaged(target, side, foe, boards)
	_on_attacked(attacker, side, boards)
	if target.hp <= 0 and target.alive:
		target.alive = false
		_emit({"t": "death", "id": target.uid, "name": target.card_name})
		_log("%s 阵亡" % target.card_name)

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
