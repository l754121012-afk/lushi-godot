extends RefCounted
## P2-7：对局循环（无头）
## 双方各用 sim/ai.gd 运营 → 开打（sim/battle.gd）→ 结算败方掉血与连胜连败 → 下一回合收入与商店
## 有了它就能在没有界面的情况下把整局跑完，用来做平衡模拟与回归。

const PrepState := preload("res://sim/prep_state.gd")
const AI := preload("res://sim/ai.gd")
const BattleScript := preload("res://sim/battle.gd")
const UnitScript := preload("res://sim/unit.gd")
const Economy := preload("res://sim/economy.gd")
const Quest := preload("res://sim/quest.gd")

const START_HP := 100

var round_no: int = 1
var hp := {"p": START_HP, "e": START_HP}
var win_streak := 0
var lose_streak := 0        # 玩家视角；AI 的连胜即玩家连败
var p_ps
var e_ps
var rng := RandomNumberGenerator.new()
var log_lines: Array[String] = []
var last_battle_options: Dictionary = {}
var ai_templates: Array = []
var ai_difficulty: int = 2

func setup(races: Array, pool: Dictionary, spells: Array = [], seed_value: int = 1,
		templates: Array = [], quests: Dictionary = {}, difficulty: int = 2) -> void:
	rng.seed = seed_value
	round_no = 1
	hp = {"p": START_HP, "e": START_HP}
	win_streak = 0
	lose_streak = 0
	log_lines = []
	last_battle_options = {}
	ai_templates = templates.duplicate(true)
	ai_difficulty = clampi(difficulty, 1, 3)
	p_ps = PrepState.new()
	e_ps = PrepState.new()
	p_ps.setup(1, races, pool, spells, seed_value, quests)
	e_ps.setup(1, races, pool, spells, seed_value + 777, quests)
	p_ps.shop_bias_enabled = false
	e_ps.shop_bias_enabled = false
	p_ps.ensure_quest()
	e_ps.ensure_quest()

## 跑一个完整回合，返回 {round, winner, damage, hp, gold}
func play_round() -> Dictionary:
	# 1) 双方 AI 运营（复用玩家侧同一套规则）
	AI.run_turn(p_ps, p_ps.races, 5, 8, e_ps.board, ai_templates)
	var ai_actions: int = [16, 40, 60][clampi(ai_difficulty - 1, 0, 2)]
	AI.run_turn(e_ps, e_ps.races, 5, ai_actions, p_ps.board, ai_templates)
	# 2) 合体（就绪才生效）
	var p_prep: Dictionary = p_ps.prepare_fusion(p_ps.level / 2, 0, 0)
	var e_prep: Dictionary = e_ps.prepare_fusion(e_ps.level / 2, 0, 0)
	# 3) 战斗
	var p_board := _to_units(p_ps.board, 1)
	var e_board := _to_units(e_ps.board, 101)
	var winner := "draw"
	var dmg := 0
	if _has_units(p_board) and _has_units(e_board):
		last_battle_options = battle_options()
		var r: Dictionary = BattleScript.new().resolve(p_board, e_board, int(rng.randi()), 30, last_battle_options)
		winner = String(r["winner"])
		p_ps.sync_runtime_from_units(r["p_board"], 1)
		e_ps.sync_runtime_from_units(r["e_board"], 101)
		if int(r.get("quest_reward_ticks_p", 0)) > 0:
			p_ps.apply_quest_reward(bool(r.get("quest_ok_p", false)))
		if int(r.get("quest_reward_ticks_e", 0)) > 0:
			e_ps.apply_quest_reward(bool(r.get("quest_ok_e", false)))
		p_ps.apply_quest_stats(r.get("quest_stats_p", {}))
		e_ps.apply_quest_stats(r.get("quest_stats_e", {}))
		p_ps.dragon_layer = int(r.get("dragon_layer_p", p_ps.dragon_layer))
		e_ps.dragon_layer = int(r.get("dragon_layer_e", e_ps.dragon_layer))
		p_ps.undead_tick = int(r.get("undead_tick_p", p_ps.undead_tick))
		e_ps.undead_tick = int(r.get("undead_tick_e", e_ps.undead_tick))
		p_ps.prev_death_tick = int(r.get("death_delta_p", p_ps.prev_death_tick))
		e_ps.prev_death_tick = int(r.get("death_delta_e", e_ps.prev_death_tick))
		if bool(p_prep.get("ok", false)):
			p_ps.finish_fusion(_fusion_alive(r["p_board"], int(p_prep.get("index", -1))))
		if bool(e_prep.get("ok", false)):
			e_ps.finish_fusion(_fusion_alive(r["e_board"], int(e_prep.get("index", -1))))
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
	elif not _has_units(p_board) and _has_units(e_board):
		winner = "e"
		dmg = _star_sum(e_board)
		hp["p"] -= dmg
		lose_streak += 1
	elif _has_units(p_board) and not _has_units(e_board):
		winner = "p"
		dmg = _star_sum(p_board)
		hp["e"] -= dmg
		win_streak += 1
	p_ps.restore_battlecry_dead(e_ps.board)
	e_ps.restore_battlecry_dead(p_ps.board)
	var line := "R%d %s 掉血%d → HP %d/%d 金币 %d" % [round_no, winner, dmg, hp["p"], hp["e"], p_ps.gold]
	log_lines.append(line)
	# 4) 进入下一回合（金币不结转，按表结算；商店重roll，棋盘保留）
	round_no += 1
	p_ps.round_no = round_no
	e_ps.round_no = round_no
	p_ps.gold = Economy.round_income(round_no, win_streak, lose_streak)
	e_ps.gold = Economy.ai_round_income(round_no, lose_streak, win_streak, ai_difficulty)
	p_ps.roll_shop()
	e_ps.roll_shop()
	p_ps.apply_prep_round_skills()
	e_ps.apply_prep_round_skills()
	if _board_has_race(p_ps.board, "evolve"):
		p_ps.phase = 1 - p_ps.phase
		p_ps.select_quest(0)
	else:
		p_ps.ensure_quest()
	if _board_has_race(e_ps.board, "evolve"):
		e_ps.phase = 1 - e_ps.phase
		var e_pool: Array = Quest.pool_for_phase(e_ps.quest_pool, e_ps.phase)
		var e_index: int = e_ps.rng.randi_range(0, e_pool.size() - 1) if not e_pool.is_empty() else 0
		e_ps.select_quest(e_index)
	else:
		e_ps.ensure_quest()
	return {"round": round_no - 1, "winner": winner, "damage": dmg, "hp": hp.duplicate(), "gold": p_ps.gold}

func play(rounds: int) -> Array:
	var out: Array = []
	for i in range(rounds):
		if hp["p"] <= 0 or hp["e"] <= 0:
			break
		out.append(play_round())
	return out

func battle_options() -> Dictionary:
	var opts: Dictionary = p_ps.battle_options("p")
	opts.merge(e_ps.battle_options("e"), true)
	return opts

func _to_units(board: Array, base_uid: int) -> Array:
	var out: Array = []
	var uid := base_uid
	for c in board:
		if c == null:
			out.append(null)
			continue
		out.append(UnitScript.from_card(c, uid))
		uid += 1
	while out.size() < 7:
		out.append(null)
	return out

func _has_units(board: Array) -> bool:
	for unit in board:
		if unit != null:
			return true
	return false

func _star_sum(board: Array) -> int:
	var n := 0
	for c in board:
		if c != null:
			n += int(c.get("s", c.get("star", 1)))
	return n

func _board_has_race(board: Array, race: String) -> bool:
	for card in board:
		if card != null and String(card.get("race", "")) == race:
			return true
	return false

func _fusion_alive(board: Array, index: int) -> bool:
	if index < 0 or index >= board.size():
		return false
	var body = board[index]
	return body != null and bool(body.alive)
