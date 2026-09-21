extends RefCounted
## P2-6：AI 备战决策（薄决策层）
## 只负责"做什么"，具体规则（扣钱/进手牌/生成商店）全部交给 sim/prep_state.gd，
## 这样 AI 不会自己养出一套和玩家不一样的规则。
##
## 优先级（对齐 Web 的运营思路）：
##   1. 场上有空位且手牌有牌 → 上场（最低成本先形成战力）
##   2. 金币够升级且能留下买牌钱 → 升级
##   3. 商店里有本阵容种族的牌且买得起 → 买
##   4. 商店没有本族牌、金币富余 → 刷新
##   5. 否则攒钱（不乱花）

const Economy := preload("res://sim/economy.gd")

const RESERVE_FOR_BUY := 3   # 升级后至少留这么多钱买牌，避免把钱全砸在等级上
const REROLL_MIN_GOLD := 3   # 低于这个金额不刷新，先攒

static func plan_turn(ps, comp_races: Array, target_level: int = 4) -> Array:
	# 1) 手牌上场
	if ps.hand.size() > 0:
		for slot in range(ps.board.size()):
			if ps.board[slot] == null:
				return ["place", 0, slot]

	# 2) 升级（留够买牌钱）
	if ps.level < target_level:
		var cost := Economy.level_up_cost(ps.level)
		if cost > 0 and ps.gold >= cost + RESERVE_FOR_BUY:
			return ["level_up"]

	# 3) 买本阵容的牌
	var best := -1
	var best_star := -1
	for i in range(ps.shop.size()):
		var c = ps.shop[i]
		if c == null:
			continue
		var race := String(c.get("race", ""))
		if not comp_races.is_empty() and race != "" and not comp_races.has(race):
			continue
		if ps.gold < ps.buy_cost(c):
			continue
		var star := int(c.get("star", 1))
		if star > best_star:
			best_star = star
			best = i
	if best >= 0:
		return ["buy", best]

	# 4) 刷新找牌
	if ps.gold >= REROLL_MIN_GOLD and ps.free_refresh > 0:
		return ["reroll"]
	if ps.gold >= REROLL_MIN_GOLD + 1:
		return ["reroll"]

	# 5) 攒钱
	return []

## 把决策执行掉（返回实际执行的描述，便于日志与测试）
static func run_turn(ps, comp_races: Array, target_level: int = 4, max_actions: int = 8) -> Array:
	var done: Array = []
	for step in range(max_actions):
		var action: Array = plan_turn(ps, comp_races, target_level)
		if action.is_empty():
			break
		match String(action[0]):
			"place":
				if not ps.place(int(action[1]), int(action[2])):
					break
				done.append("place")
			"level_up":
				if not ps.level_up():
					break
				done.append("level_up")
			"buy":
				var r: Dictionary = ps.buy(int(action[1]))
				if not bool(r["ok"]):
					break
				done.append("buy:" + String(r["card"].get("n", "?")))
			"reroll":
				if not ps.reroll():
					break
				done.append("reroll")
	return done
