extends RefCounted
## P2-7：对局循环（无头）
## 双方各用 sim/ai.gd 运营 → 开打（sim/battle.gd）→ 结算败方掉血与连胜连败 → 下一回合收入与商店
## 有了它就能在没有界面的情况下把整局跑完，用来做平衡模拟与回归。

const PrepState := preload("res://sim/prep_state.gd")
const AI := preload("res://sim/ai.gd")
const BattleScript := preload("res://sim/battle.gd")
const UnitScript := preload("res://sim/unit.gd")
const Economy := preload("res://sim/economy.gd")

const START_HP := 100

var round_no: int = 1
var hp := {"p": START_HP, "e": START_HP}
var win_streak := 0
var lose_streak := 0        # 玩家视角；AI 的连胜即玩家连败
var p_ps
var e_ps
var rng := RandomNumberGenerator.new()
var log_lines: Array[String] = []

func setup(races: Array, pool: Dictionary, spells: Array = [], seed_value: int = 1) -> void:
	rng.seed = seed_value
	round_no = 1
	hp = {"p": START_HP, "e": START_HP}
	win_streak = 0
	lose_streak = 0
	log_lines = []
	p_ps = PrepState.new()
	e_ps = PrepState.new()
	p_ps.setup(1, races, pool, spells, seed_value)
	e_ps.setup(1, races, pool, spells, seed_value + 777)

## 跑一个完整回合，返回 {round, winner, damage, hp, gold}
func play_round() -> Dictionary:
	# 1) 双方 AI 运营（复用玩家侧同一套规则）
	AI.run_turn(p_ps, p_ps.races, 5)
	AI.run_turn(e_ps, e_ps.races, 5)
	# 2) 合体（就绪才生效）
	p_ps.prepare_fusion(p_ps.level / 2, 0, 0)
	e_ps.prepare_fusion(e_ps.level / 2, 0, 0)
	# 3) 战斗
	var p_board := _to_units(p_ps.board, 1)
	var e_board := _to_units(e_ps.board, 101)
	var winner := "draw"
	var dmg := 0
	if not p_board.is_empty() and not e_board.is_empty():
		var r: Dictionary = BattleScript.new().resolve(p_board, e_board, int(rng.randi()))
		winner = String(r["winner"])
		# 败方掉血 = 胜方存活随从的星级之和（与 Web 一致）
		var p_surv := 0
		var e_surv := 0
		for u in r["p_board"]:
			if u != null and u.alive:
				p_surv += u.star
		for u in r["e_board"]:
			if u != null and u.alive:
				e_surv += u.star
		if winner == "p":
			dmg = p_surv
			hp["e"] -= dmg
			win_streak += 1
			lose_streak = 0
		elif winner == "e":
			dmg = e_surv
			hp["p"] -= dmg
			lose_streak += 1
			win_streak = 0
	elif p_board.is_empty() and not e_board.is_empty():
		winner = "e"
		dmg = _star_sum(e_board)
		hp["p"] -= dmg
		lose_streak += 1
	var line := "R%d %s 掉血%d → HP %d/%d 金币 %d" % [round_no, winner, dmg, hp["p"], hp["e"], p_ps.gold]
	log_lines.append(line)
	# 4) 进入下一回合（金币不结转，按表结算；商店重roll，棋盘保留）
	round_no += 1
	p_ps.round_no = round_no
	e_ps.round_no = round_no
	p_ps.gold = Economy.round_income(round_no, win_streak, lose_streak)
	e_ps.gold = Economy.round_income(round_no, lose_streak, win_streak)
	p_ps.roll_shop()
	e_ps.roll_shop()
	return {"round": round_no - 1, "winner": winner, "damage": dmg, "hp": hp.duplicate(), "gold": p_ps.gold}

func play(rounds: int) -> Array:
	var out: Array = []
	for i in range(rounds):
		if hp["p"] <= 0 or hp["e"] <= 0:
			break
		out.append(play_round())
	return out

func _to_units(board: Array, base_uid: int) -> Array:
	var out: Array = []
	var uid := base_uid
	for c in board:
		if c != null:
			out.append(UnitScript.from_card(c, uid))
			uid += 1
	return out

func _star_sum(board: Array) -> int:
	var n := 0
	for c in board:
		if c != null:
			n += int(c.get("s", c.get("star", 1)))
	return n
