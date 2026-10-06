extends RefCounted
## AI 备战运营：模板选型、核心牌评分、买牌/升级/刷新、满场换人与机械摆位。
## 所有经济与规则变化仍通过 sim/prep_state.gd 执行。

const Economy := preload("res://sim/economy.gd")

const BOARD_LIMIT := 7
const HAND_LIMIT := 10
const RESERVE_FOR_BUY := 3
const REROLL_MIN_GOLD := 4
const MIN_BUY_SCORE := 6


static func plan_turn(ps, comp_races: Array, _target_level: int = 4, templates: Array = []) -> Array:
	var plan: Dictionary = _choose_plan(ps, comp_races, templates)
	var board_count: int = _board_count(ps)
	var board_full: bool = board_count >= BOARD_LIMIT
	var desired_level: int = _desired_level(ps, 7)

	# 先形成基础战力，再决定是否运营。
	if board_count == 0:
		var opening_index: int = _best_hand_unit(ps, plan)
		if opening_index >= 0:
			return ["place", opening_index, _preferred_slot(ps, ps.hand[opening_index])]

	# 已有目标后使用手牌法术，优先法力洪流。
	var spell_index: int = _best_spell_index(ps)
	if spell_index >= 0:
		var spell: Dictionary = ps.hand[spell_index]
		var target_slot := -1
		if String(spell.get("fx", "")) != "spell-boost":
			target_slot = _best_spell_target(ps, plan)
		if target_slot >= 0 or String(spell.get("fx", "")) == "spell-boost":
			return ["cast_spell", spell_index, target_slot]

	# 4/7/10/13 回合是升酒馆节点；先升级，再考虑用低星牌填场。
	if ps.level < desired_level and ps.round_no in [4, 7, 10, 13]:
		if _can_upgrade(ps, plan):
			return ["level_up"]

	# 机械材料只喂给已有部位，不再当作普通随从买来占场。
	var feed_action: Array = _best_material_action(ps, plan)
	if not feed_action.is_empty():
		return feed_action
	if ps.hand.size() >= HAND_LIMIT:
		var discard_index: int = _weakest_hand_unit(ps, plan)
		if discard_index >= 0 and _score_card(ps.hand[discard_index], ps, plan) < _midgame_buy_bar(ps):
			return ["discard", discard_index]

	# 手牌随从按价值上场；满场时先踢掉最弱的离阵随从。
	var hand_unit: int = _best_hand_unit(ps, plan)
	if hand_unit >= 0:
		if not board_full and _empty_slot_count(ps) > 0:
			return ["place", hand_unit, _preferred_slot(ps, ps.hand[hand_unit])]
		if board_full:
			var hand_card: Dictionary = ps.hand[hand_unit]
			if _on_plan(hand_card, plan):
				var off_hand_slot: int = _weakest_off_plan_slot(ps, plan)
				if off_hand_slot >= 0:
					return ["sell", off_hand_slot]
			var sell_for_hand: int = _weakest_board_slot(ps, plan)
			if sell_for_hand >= 0 and _score_card(ps.hand[hand_unit], ps, plan) > _score_board_card(ps.board[sell_for_hand], ps, plan) + 4:
				return ["sell", sell_for_hand]

	# 升级节奏：中后期先保证等级，否则会一直用低星散牌填场。
	if ps.level < desired_level and _can_upgrade(ps, plan):
		return ["level_up"]

	# 满场时，如果商店有显著更强牌，先卖最弱再买。
	var best_shop_index: int = _best_buy_index(ps, plan, false)
	var best_shop_score: int = -1
	if best_shop_index >= 0:
		best_shop_score = _score_card(ps.shop[best_shop_index], ps, plan)
	if board_full and best_shop_index >= 0 and ps.hand.size() < HAND_LIMIT:
		var shop_card: Dictionary = ps.shop[best_shop_index]
		if _on_plan(shop_card, plan):
			var off_shop_slot: int = _weakest_off_plan_slot(ps, plan)
			if off_shop_slot >= 0:
				return ["sell", off_shop_slot]
		var weakest: int = _weakest_board_slot(ps, plan)
		if weakest >= 0 and best_shop_score > _score_board_card(ps.board[weakest], ps, plan) + 12:
			return ["sell", weakest]

	# 正常购买本模板内评分最高的牌。
	if best_shop_index >= 0 and ps.hand.size() < HAND_LIMIT and not board_full:
		return ["buy", best_shop_index]

	# 第 4 回合后做 Web 式整合：即使满场，也只在新牌明显更强时替换最弱牌。
	if ps.round_no >= 4 and ps.hand.size() < HAND_LIMIT:
		var consolidation_index: int = _best_buy_index(ps, plan, false, 6)
		if consolidation_index >= 0:
			var consolidation_card: Dictionary = ps.shop[consolidation_index]
			var consolidation_rank := _plan_rank(consolidation_card, plan)
			var consolidation_score: int = _score_card(consolidation_card, ps, plan)
			if not board_full:
				return ["buy", consolidation_index]
			var replace_slot: int = _weakest_board_slot(ps, plan)
			if replace_slot >= 0:
				var replace_rank := _plan_rank(ps.board[replace_slot], plan)
				var replace_score: int = _score_board_card(ps.board[replace_slot], ps, plan)
				if consolidation_rank > replace_rank or consolidation_score > replace_score + 4:
					return ["sell", replace_slot]

	# 无好牌时刷新找核心，优先免费刷新。
	if ps.free_refresh > 0 and _best_buy_score(ps, plan, true) < _midgame_buy_bar(ps):
		return ["reroll"]
	if ps.gold >= REROLL_MIN_GOLD + 1 and board_count > 0:
		return ["reroll"]

	# 最后兜底：不空转，买一张能形成战力的牌或升级。
	var fallback: int = _best_buy_index(ps, plan, true)
	if fallback >= 0 and ps.hand.size() < HAND_LIMIT:
		return ["buy", fallback]
	if ps.level < desired_level and _can_upgrade(ps, plan):
		return ["level_up"]
	return []


static func run_turn(ps, comp_races: Array, target_level: int = 4, max_actions: int = 8,
		opponent_board: Array = [], templates: Array = []) -> Array:
	var done: Array = []
	# AI 的备战战吼只能模拟对手盘，不能改写玩家真实棋盘。
	var opponent_view: Array = opponent_board.duplicate(true)
	for step in range(max_actions):
		var action: Array = plan_turn(ps, comp_races, target_level, templates)
		if action.is_empty():
			break
		match String(action[0]):
			"place":
				if not ps.place(int(action[1]), int(action[2]), opponent_view):
					break
				done.append("place")
			"sell":
				if not ps.sell(int(action[1])):
					break
				done.append("sell")
			"level_up":
				if not ps.level_up():
					break
				done.append("level_up")
			"buy":
				var bought: Dictionary = ps.buy(int(action[1]))
				if not bool(bought.get("ok", false)):
					break
				done.append("buy:" + String(bought.get("card", {}).get("n", "?")))
			"cast_spell":
				var cast: Dictionary = ps.cast_spell(int(action[1]), int(action[2]))
				if not bool(cast.get("ok", false)):
					break
				done.append("cast_spell:" + String(cast.get("spell", {}).get("n", "?")))
			"feed":
				var fed: Dictionary = ps.feed(int(action[1]), int(action[2]))
				if not bool(fed.get("ok", false)):
					break
				done.append("feed:" + String(fed.get("target", {}).get("n", "?")))
			"discard":
				var discard_index := int(action[1])
				if discard_index < 0 or discard_index >= ps.hand.size():
					break
				ps.hand.remove_at(discard_index)
				done.append("discard")
			"reroll":
				if not ps.reroll():
					break
				done.append("reroll")
	return done


static func _choose_plan(ps, comp_races: Array, templates: Array) -> Dictionary:
	if not ps.ai_plan.is_empty():
		return ps.ai_plan.duplicate(true)
	if templates.is_empty():
		var generic_plan: Dictionary = {
			"name": "本局种族",
			"races": comp_races.duplicate(),
			"core": [],
			"good": [],
			"fill": [],
		}
		ps.ai_plan = generic_plan.duplicate(true)
		return generic_plan
	var best: Dictionary = {}
	var best_score := -9999
	for template in templates:
		if not (template is Dictionary):
			continue
		var score := 0
		var races: Array = template.get("races", [])
		for race in races:
			if comp_races.has(race):
				score += 6
			else:
				score -= 4
		for race in comp_races:
			if not races.has(race):
				score -= 1
		for card in ps.board:
			if card != null and Array(template.get("core", [])).has(String(card.get("n", ""))):
				score += 5
			if card != null and races.has(String(card.get("race", ""))):
				score += 2
		if score > best_score:
			best_score = score
			best = template
	if best.is_empty() or best_score <= 0:
		var fallback_plan: Dictionary = {
			"name": "本局种族",
			"races": comp_races.duplicate(),
			"core": [],
			"good": [],
			"fill": [],
		}
		ps.ai_plan = fallback_plan.duplicate(true)
		return fallback_plan
	var chosen_plan: Dictionary = {
		"name": String(best.get("name", "AI阵容")),
		"races": Array(best.get("races", [])).duplicate(),
		"core": Array(best.get("core", [])).duplicate(),
		"good": Array(best.get("good", [])).duplicate(),
		"fill": Array(best.get("fill", [])).duplicate(),
	}
	ps.ai_plan = chosen_plan.duplicate(true)
	return chosen_plan


static func _desired_level(ps, target_level: int) -> int:
	var by_round := 2
	if ps.round_no >= 5:
		by_round = 3
	if ps.round_no >= 7:
		by_round = 4
	if ps.round_no >= 10:
		by_round = 5
	if ps.round_no >= 13:
		by_round = 6
	return clampi(maxi(target_level, by_round), 1, _level_cap(ps.round_no))

static func _level_cap(round_no: int) -> int:
	if round_no <= 3:
		return 2
	if round_no <= 5:
		return 3
	if round_no <= 7:
		return 4
	if round_no <= 9:
		return 5
	if round_no <= 11:
		return 6
	return 7

static func _can_upgrade(ps, plan: Dictionary) -> bool:
	if ps.level >= _desired_level(ps, 7):
		return false
	var cost := Economy.level_up_cost(ps.level)
	if cost <= 0 or ps.gold < cost + 1:
		return false
	var count := _board_count(ps)
	var on_plan := _on_plan_count(ps, plan)
	var minimum_units := mini(7, maxi(2, ps.level))
	var minimum_on_plan := 0 if ps.level <= 2 else (1 if ps.level <= 3 else (2 if ps.level <= 5 else 3))
	return count >= minimum_units and on_plan >= minimum_on_plan


static func _best_buy_index(ps, plan: Dictionary, allow_fallback: bool,
		min_score_override: int = -1) -> int:
	var best := -1
	var best_score := -1
	for i in range(ps.shop.size()):
		var card = ps.shop[i]
		if card == null:
			continue
		if ps.gold < ps.buy_cost(card):
			continue
		var race := String(card.get("race", ""))
		if allow_fallback and ps.round_no >= 4:
			var on_plan := race == "" or race == "neutral" \
				or Array(plan.get("races", [])).has(race) \
				or Array(plan.get("core", [])).has(String(card.get("n", ""))) \
				or Array(plan.get("good", [])).has(String(card.get("n", "")))
			if not on_plan:
				continue
		var score: int = _score_card(card, ps, plan)
		var buy_bar: int = min_score_override if min_score_override >= 0 else _buy_bar_for_card(ps, plan, card)
		if score < buy_bar and not allow_fallback:
			continue
		if score <= 0 or (allow_fallback and score < maxi(4, buy_bar - 10)):
			continue
		if score > best_score:
			best_score = score
			best = i
	return best


static func _best_buy_score(ps, plan: Dictionary, allow_fallback: bool) -> int:
	var index := _best_buy_index(ps, plan, allow_fallback)
	if index < 0:
		return -1
	return _score_card(ps.shop[index], ps, plan)


static func _best_hand_unit(ps, plan: Dictionary) -> int:
	var best := -1
	var best_score := -1
	for i in range(ps.hand.size()):
		var card: Dictionary = ps.hand[i]
		if String(card.get("t", "")) == "s":
			continue
		if card.has("magA") or card.has("magH"):
			continue
		if not bool(card.get("g", false)) and _count_name(ps, String(card.get("n", ""))) == 2 \
				and _board_count(ps) > 0:
			continue
		var score: int = _score_card(card, ps, plan)
		if score > best_score:
			best_score = score
			best = i
	return best


static func _weakest_hand_unit(ps, plan: Dictionary) -> int:
	var weakest := -1
	var weakest_score := 999999
	for i in range(ps.hand.size()):
		var card: Dictionary = ps.hand[i]
		if String(card.get("t", "")) == "s" or card.has("magA") or card.has("magH"):
			continue
		if _count_name(ps, String(card.get("n", ""))) == 2:
			continue
		var score: int = _score_card(card, ps, plan)
		if score < weakest_score:
			weakest_score = score
			weakest = i
	return weakest


static func _best_spell_index(ps) -> int:
	for i in range(ps.hand.size()):
		var card: Dictionary = ps.hand[i]
		if String(card.get("t", "")) != "s":
			continue
		if String(card.get("fx", "")) == "spell-boost":
			return i
		if _board_count(ps) > 0:
			return i
	return -1


static func _best_spell_target(ps, plan: Dictionary) -> int:
	var best := -1
	var best_score := -9999
	for i in range(ps.board.size()):
		var card = ps.board[i]
		if card == null:
			continue
		var score: int = _score_board_card(card, ps, plan)
		if score > best_score:
			best_score = score
			best = i
	return best


static func _score_card(card: Dictionary, ps, plan: Dictionary) -> int:
	if String(card.get("t", "")) == "s":
		return 5 + (3 if String(card.get("fx", "")) == "spell-boost" else 0)
	var name := String(card.get("n", ""))
	var race := String(card.get("race", ""))
	var star := int(card.get("star", card.get("s", 1)))
	var score := int(card.get("a", 0)) + int(card.get("h", 0)) + star
	var skill: Dictionary = card.get("sk", {})
	if not skill.is_empty():
		score += 3
		var effect_id := String(skill.get("e", ""))
		if effect_id in [
			"race-buff", "ally-all-buff", "growth-self", "shop-buff", "gamble",
			"chain-dmg", "undead-rebirth", "star-amp", "star-echo",
		]:
			score += 4
	if card.has("sc"):
		score += 3
	if card.has("bc"):
		score += 2
	var plan_races: Array = plan.get("races", [])
	var plan_rank := _plan_rank(card, plan)
	if plan_rank >= 3:
		score += 20
	elif plan_rank == 2:
		score += 14
	elif plan_rank == 1:
		score += 6
	var main_race := _main_race(plan)
	if main_race != "" and race == main_race:
		score += 18
	elif plan_races.has(race):
		score += 6
	elif race != "" and race != "neutral":
		score -= 12
	score += _race_balance(card, ps, plan)
	var copies := _count_name(ps, name)
	if copies > 0:
		var duplicate_ok: bool = plan_rank >= 2 or (star >= mini(7, ps.level) and plan_rank >= 1)
		if copies == 1:
			score += 10 if duplicate_ok else 2
		elif copies >= 2:
			score += 24 if duplicate_ok else 5
	if bool(card.get("material", false)):
		if _has_mech_part(ps):
			score += 8
		else:
			score -= 30
	return score


static func _score_board_card(card, ps, plan: Dictionary) -> int:
	if card == null:
		return -9999
	var score: int = _score_card(card, ps, plan)
	if String(card.get("part", "")) != "" and _board_has_race(ps, "mech"):
		score += 3
	return score


static func _count_name(ps, name: String) -> int:
	var n := 0
	for card in ps.hand:
		if card != null and String(card.get("n", "")) == name:
			n += 1
	for card in ps.board:
		if card != null and String(card.get("n", "")) == name:
			n += 1
	return n


static func _weakest_board_slot(ps, plan: Dictionary) -> int:
	var weakest := -1
	var weakest_score := 999999
	for i in range(ps.board.size()):
		if ps.board[i] == null:
			continue
		var score: int = _score_board_card(ps.board[i], ps, plan)
		if score < weakest_score:
			weakest_score = score
			weakest = i
	return weakest

static func _weakest_off_plan_slot(ps, plan: Dictionary) -> int:
	var weakest := -1
	var weakest_score := 999999
	for i in range(ps.board.size()):
		var card = ps.board[i]
		if card == null or _on_plan(card, plan):
			continue
		var score: int = _score_board_card(card, ps, plan)
		if score < weakest_score:
			weakest_score = score
			weakest = i
	return weakest


static func _preferred_slot(ps, card: Dictionary) -> int:
	var part := String(card.get("part", ""))
	if part != "":
		var preferred: int = int({"core": 0, "head": 1, "arm": 2, "leg": 3}.get(part, -1))
		if preferred >= 0 and preferred < ps.board.size() and ps.board[preferred] == null:
			return preferred
	for i in range(ps.board.size()):
		if ps.board[i] == null:
			return i
	return -1


static func _main_race(plan: Dictionary) -> String:
	var races: Array = plan.get("races", [])
	return String(races[0]) if not races.is_empty() else ""


static func _plan_rank(card: Dictionary, plan: Dictionary) -> int:
	var name := String(card.get("n", ""))
	if Array(plan.get("core", [])).has(name):
		return 3
	if Array(plan.get("good", [])).has(name):
		return 2
	if Array(plan.get("fill", [])).has(name):
		return 1
	var race := String(card.get("race", ""))
	if race != "" and Array(plan.get("races", [])).has(race):
		return 1
	return 0


static func _on_plan(card: Dictionary, plan: Dictionary) -> bool:
	var name := String(card.get("n", ""))
	if Array(plan.get("core", [])).has(name):
		return true
	if Array(plan.get("good", [])).has(name):
		return true
	if Array(plan.get("fill", [])).has(name):
		return true
	var race := String(card.get("race", ""))
	var main_race := _main_race(plan)
	if main_race == "mech" and race == "mech" \
			and (bool(card.get("material", false)) or String(card.get("part", "")) == ""):
		return false
	return race != "" and Array(plan.get("races", [])).has(race)

static func _on_plan_count(ps, plan: Dictionary) -> int:
	var count := 0
	for card in ps.board:
		if card != null and _on_plan(card, plan):
			count += 1
	return count

static func _race_balance(card: Dictionary, ps, plan: Dictionary) -> int:
	var main_race := _main_race(plan)
	var race := String(card.get("race", ""))
	if main_race == "" or race == "" or race == main_race:
		return 0
	if not Array(plan.get("races", [])).has(race):
		return 0
	var main_count := 0
	var secondary_count := 0
	for board_card in ps.board:
		if board_card == null:
			continue
		var board_race := String(board_card.get("race", ""))
		if board_race == main_race:
			main_count += 1
		elif Array(plan.get("races", [])).has(board_race):
			secondary_count += 1
	var already_on_board: bool = ps.board.has(card)
	var projected := secondary_count + (0 if already_on_board else 1)
	var cap := maxi(2, int(floor(float(main_count) * 0.6)))
	return -18 if projected > cap else 0

static func _has_mech_part(ps) -> bool:
	for card in ps.board:
		if card != null and String(card.get("race", "")) == "mech" \
				and String(card.get("part", "")) != "":
			return true
	return false

static func _best_material_action(ps, plan: Dictionary) -> Array:
	if not Array(plan.get("races", [])).has("mech") and not _has_mech_part(ps):
		return []
	var target_slot := -1
	var target_score := 999999
	for i in range(ps.board.size()):
		var card = ps.board[i]
		if card == null or String(card.get("race", "")) != "mech" or String(card.get("part", "")) == "":
			continue
		var score := int(card.get("a", 0)) + int(card.get("h", 0))
		if score < target_score:
			target_score = score
			target_slot = i
	if target_slot < 0:
		return []
	for i in range(ps.hand.size()):
		var hand_card: Dictionary = ps.hand[i]
		if hand_card.has("magA") or hand_card.has("magH"):
			return ["feed", i, target_slot]
	return []


static func _midgame_buy_bar(ps) -> int:
	return maxi(MIN_BUY_SCORE, 8)

static func _buy_bar_for_card(ps, plan: Dictionary, card: Dictionary) -> int:
	if _plan_rank(card, plan) >= 1:
		return 6
	return 8 if _board_count(ps) < 4 else 12


static func _board_count(ps) -> int:
	var n := 0
	for card in ps.board:
		if card != null:
			n += 1
	return n


static func _empty_slot_count(ps) -> int:
	return BOARD_LIMIT - _board_count(ps)


static func _board_has_race(ps, race: String) -> bool:
	for card in ps.board:
		if card != null and String(card.get("race", "")) == race:
			return true
	return false
