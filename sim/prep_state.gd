extends RefCounted
## P2-4：备战期状态机（把已迁移的规则层接起来）
## 经济(sim/economy) + 商店(sim/shop) + 三连金卡(sim/gild) + 合体判定(sim/fusion) + 磁力喂料(sim/prep)
## UI 之后只需要调用这里的 buy / reroll / level_up / place / sell / try_gild，不再重复写规则。

const Economy := preload("res://sim/economy.gd")
const Shop := preload("res://sim/shop.gd")
const Gild := preload("res://sim/gild.gd")
const Fusion := preload("res://sim/fusion.gd")
const Prep := preload("res://sim/prep.gd")
const Sacrifice := preload("res://sim/sacrifice.gd")
const UnitScript := preload("res://sim/unit.gd")
const Quest := preload("res://sim/quest.gd")
const BattleScript := preload("res://sim/battle.gd")

const BOARD_SLOTS := 7
const SHOP_SLOTS := 5
const HAND_LIMIT := 10
const NORMAL_BUY_COST := 3
const HIGH_STAR_BUY_COST := 4
const SELL_REFUND := 2
const SPELL_BUY_COST := 3
const SHOP_BIAS_MIN_COUNT := 3
const SHOP_BIAS_BASE := 1.5
const SHOP_BIAS_STEP := 0.5
const SHOP_BIAS_MAX := 2.5

var round_no: int = 1
var gold: int = 0
var level: int = 1
var win_streak: int = 0
var lose_streak: int = 0
var free_refresh: int = 0
var shop_frozen := false
var shop_bias_enabled := true
var free_spell_next: int = 0
var spell_boost := {"a": 0, "h": 0}
var shop_boost := {"a": 0, "h": 0}
var spell_refund := 0
var spell_count := 0
var spent := 0
var _coin_tick := 0
var _sb_alt := 0
var mech_level: int = 0
var mat_boost_a: int = 0
var mat_boost_h: int = 0
var mech_repair: int = 0
var mag_t: int = 0
var chain: int = 0
var star_amp: int = 0
var debt: int = 0
var contract_id: int = -1
var contract_bonus: int = 0
var dragon_layer: int = 0
var prev_death_tick: int = 0
var undead_tick: int = 0
var phase: int = 0
var quest_pool: Dictionary = {}
var quest_id: String = ""
var quest_index: int = 0
var evo_prog: Dictionary = {"cur": 0, "need": 0}
var ai_plan: Dictionary = {}
var last_message: String = ""
var last_battlecry_results: Array[Dictionary] = []
var races: Array = []
var pool_by_star: Dictionary = {}
var spells: Array = []
var shop: Array = []
var hand: Array = []
var board: Array = []
var rng := RandomNumberGenerator.new()
var _mech_save: Dictionary = {}
var _battlecry_dead: Array[Dictionary] = []
var _nid: int = 0

func _next_id() -> int:
	_nid += 1
	return 100000 + _nid

func setup(p_round: int, p_races: Array, p_pool: Dictionary, p_spells: Array = [],
		seed_value: int = 1, p_quests: Dictionary = {}) -> void:
	round_no = p_round
	level = 1
	win_streak = 0
	lose_streak = 0
	free_refresh = 0
	shop_frozen = false
	free_spell_next = 0
	spell_boost = {"a": 0, "h": 0}
	shop_boost = {"a": 0, "h": 0}
	spell_refund = 0
	spell_count = 0
	spent = 0
	_coin_tick = 0
	_sb_alt = 0
	mech_level = 0
	mat_boost_a = 0
	mat_boost_h = 0
	mech_repair = 0
	mag_t = 0
	chain = 0
	star_amp = 0
	debt = 0
	contract_id = -1
	contract_bonus = 0
	dragon_layer = 0
	prev_death_tick = 0
	undead_tick = 0
	phase = 0
	quest_pool = p_quests.duplicate(true)
	quest_id = ""
	quest_index = 0
	evo_prog = {"cur": 0, "need": 0}
	ai_plan = {}
	last_message = ""
	last_battlecry_results = []
	_mech_save = {}
	_battlecry_dead = []
	races = p_races.duplicate()
	pool_by_star = p_pool
	spells = p_spells
	rng.seed = seed_value
	hand = []
	board = []
	for i in range(BOARD_SLOTS):
		board.append(null)
	ensure_quest()
	gold = Economy.round_income(round_no, win_streak, lose_streak)
	roll_shop()

func roll_shop(force: bool = false) -> void:
	if shop_frozen and not force:
		return
	var bias := shop_bias_info() if shop_bias_enabled else {"races": [], "multiplier": 1.0}
	shop = Shop.roll_shop(
		level, races, rng, pool_by_star, spells, SHOP_SLOTS,
		bias.get("races", []), float(bias.get("multiplier", 1.0)))
	_apply_shop_boost_to_shop()

func buy_cost(card: Dictionary) -> int:
	if String(card.get("t", "")) == "s":
		return SPELL_BUY_COST
	var star := int(card.get("star", card.get("s", 1)))
	var cost := HIGH_STAR_BUY_COST if star >= 6 else NORMAL_BUY_COST
	var race := String(card.get("race", ""))
	if race != "" and race != "neutral" and _race_count(race) >= 3:
		cost = maxi(2, cost - 1)
	return cost

## 买牌：扣钱 → 进手牌 → 商店该格清空。手牌满或钱不够则失败
func buy(index: int) -> Dictionary:
	last_message = ""
	if index < 0 or index >= shop.size() or shop[index] == null:
		return {"ok": false, "reason": "empty"}
	if hand.size() >= HAND_LIMIT:
		return {"ok": false, "reason": "hand_full"}
	var card: Dictionary = shop[index]
	var race := String(card.get("race", ""))
	if not races.is_empty() and race != "" and race != "neutral" and not races.has(race):
		return {"ok": false, "reason": "off_race"}
	var is_spell := String(card.get("t", "")) == "s"
	var free_cast := is_spell and free_spell_next > 0
	var cost := 0 if free_cast else buy_cost(card)
	if gold < cost:
		return {"ok": false, "reason": "no_gold", "cost": cost}
	if free_cast:
		free_spell_next -= 1
	gold -= cost
	_spend_gold(cost)
	hand.append(card)
	shop[index] = null
	var refund := 0
	if is_spell and spell_refund == 0:
		spell_refund = 1
		refund = 1
		gold += refund
	var gild: Dictionary = {"ok": false}
	if not is_spell:
		gild = try_gild_in_hand()
	if bool(gild.get("ok", false)):
		last_message = "三连金卡：%s" % String(gild.get("name", "随从"))
	return {"ok": true, "card": card, "cost": cost, "refund": refund, "free": free_cast, "gild": gild}

## 刷新：优先用免费次数，否则 1 金
func reroll() -> bool:
	if shop_frozen:
		return false
	if free_refresh > 0:
		free_refresh -= 1
	else:
		var cost := Economy.refresh_cost()
		if gold < cost:
			return false
		gold -= cost
		_spend_gold(cost)
	roll_shop()
	return true

func level_up() -> bool:
	if not Economy.can_level_up(level, gold):
		return false
	gold -= Economy.level_up_cost(level)
	_spend_gold(Economy.level_up_cost(level))
	level += 1
	roll_shop()
	return true

## 手牌上场：空位放置（合体区就是前 4 格，交给 UI 高亮）。
## opponent_board 用于战吼的敌方目标；AI/UI 应传对方棋盘，未传时随机敌方效果只报无目标。
func place(hand_index: int, slot: int, opponent_board: Array = []) -> bool:
	last_message = ""
	last_battlecry_results = []
	if hand_index < 0 or hand_index >= hand.size():
		return false
	if String(hand[hand_index].get("t", "")) == "s":
		return false
	if slot < 0 or slot >= BOARD_SLOTS or board[slot] != null:
		return false
	var card: Dictionary = hand[hand_index]
	card["_udBase"] = undead_tick
	board[slot] = card
	hand.remove_at(hand_index)
	if card.has("bc"):
		last_battlecry_results.append(_exec_battlecry(card, slot, card["bc"], opponent_board))
	var gild := try_gild_in_board()
	if bool(gild.get("ok", false)):
		last_message = "三连金卡：%s" % String(gild.get("name", "随从"))
	return true

func place_first_empty(hand_index: int, opponent_board: Array = []) -> int:
	if hand_index < 0 or hand_index >= hand.size():
		return -1
	if String(hand[hand_index].get("t", "")) == "s":
		return -1
	for slot in range(BOARD_SLOTS):
		if board[slot] == null and place(hand_index, slot, opponent_board):
			return slot
	return -1

func sell(slot: int) -> bool:
	last_message = ""
	if slot < 0 or slot >= BOARD_SLOTS or board[slot] == null:
		return false
	gold += SELL_REFUND
	board[slot] = null
	return true

## 法术：普通法术增加目标身材；法力洪流永久强化之后所有法术。
func cast_spell(hand_index: int, target_slot: int = -1) -> Dictionary:
	last_message = ""
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false, "reason": "no_card"}
	var spell: Dictionary = hand[hand_index]
	if String(spell.get("t", "")) != "s":
		return {"ok": false, "reason": "not_spell"}
	var fx := String(spell.get("fx", ""))
	if fx == "spell-boost":
		spell_boost["a"] = int(spell_boost.get("a", 0)) + 1
		spell_boost["h"] = int(spell_boost.get("h", 0)) + 1
		hand.remove_at(hand_index)
		_on_spell_cast()
		return {"ok": true, "spell": spell, "boost": spell_boost.duplicate(), "target": null}
	var effect_raw: Variant = spell.get("e", "")
	if effect_raw is String and String(effect_raw) == "gild-target":
		if target_slot < 0 or target_slot >= BOARD_SLOTS or board[target_slot] == null:
			return {"ok": false, "reason": "no_target"}
		var target_before: Dictionary = board[target_slot]
		if bool(target_before.get("g", false)):
			return {"ok": false, "reason": "already_gold"}
		board[target_slot] = Gild.gild(target_before)
		hand.remove_at(hand_index)
		_on_spell_cast()
		last_message = "点金：%s 升为金卡" % String(board[target_slot].get("n", "随从"))
		return {"ok": true, "spell": spell, "target": board[target_slot], "gilded": true}
	if target_slot < 0 or target_slot >= BOARD_SLOTS or board[target_slot] == null:
		return {"ok": false, "reason": "no_target"}
	var effect: Dictionary = {}
	if effect_raw is Dictionary:
		effect = effect_raw
	var add_a := int(effect.get("a", 0)) + int(spell_boost.get("a", 0))
	var add_h := int(effect.get("h", 0)) + int(spell_boost.get("h", 0))
	var target: Dictionary = board[target_slot]
	target["a"] = int(target.get("a", 0)) + add_a
	target["h"] = int(target.get("h", 0)) + add_h
	if target.has("mh"):
		target["mh"] = int(target.get("mh", 0)) + add_h
	hand.remove_at(hand_index)
	_on_spell_cast()
	return {
		"ok": true,
		"spell": spell,
		"target": target,
		"a": add_a,
		"h": add_h,
	}

func _on_spell_cast() -> void:
	spell_count += 1
	if spell_count % 3 == 0:
		free_refresh += 1
	_apply_spell_cast_skills()

func _spend_gold(amount: int) -> void:
	if amount <= 0:
		return
	spent += amount
	while spent >= 5:
		spent -= 5
		for card in board:
			if card == null or not card.has("sk"):
				continue
			var sk: Dictionary = card["sk"]
			if String(sk.get("t", "")) != "gold" or String(sk.get("e", "")) != "coin-spell-boost":
				continue
			var times := int(sk.get("times", 1))
			_coin_tick += times
			_sb_alt += 1
			if _sb_alt % 2 == 1:
				spell_boost["a"] = int(spell_boost.get("a", 0)) + _coin_tick
			else:
				spell_boost["h"] = int(spell_boost.get("h", 0)) + _coin_tick
			last_message = "%s：每 5 金强化法术，当前 %d 次" % [String(card.get("n", "铸币巨兽")), _sb_alt]
			break

func _apply_shop_boost_to_shop() -> void:
	var ba := int(shop_boost.get("a", 0))
	var bh := int(shop_boost.get("h", 0))
	if ba == 0 and bh == 0:
		return
	for card in shop:
		if card == null or String(card.get("t", "")) != "m":
			continue
		card["a"] = int(card.get("a", 0)) + ba
		card["h"] = int(card.get("h", 0)) + bh
		if card.has("mh"):
			card["mh"] = int(card.get("mh", 0)) + bh
		card["_sbA"] = int(card.get("_sbA", 0)) + ba
		card["_sbH"] = int(card.get("_sbH", 0)) + bh

func _gain_card(card: Dictionary, a: int, h: int) -> void:
	card["a"] = int(card.get("a", 0)) + a
	card["h"] = int(card.get("h", 0)) + h
	if card.has("mh") and h != 0:
		card["mh"] = int(card.get("mh", 0)) + h

func _board_cards() -> Array:
	var out: Array = []
	for card in board:
		if card != null:
			out.append(card)
	return out

func _is_growth_target(sk: Dictionary) -> bool:
	var t := String(sk.get("t", ""))
	var e := String(sk.get("e", ""))
	if t == "start" and e in ["growth-self", "self-buff", "undead-rebirth"]:
		return true
	if t == "on-dmg" and e == "race-buff" and bool(sk.get("grow", false)):
		return true
	if t == "spell-cast" and e == "spell-core":
		return true
	return false

func _apply_spell_cast_skills() -> void:
	var cards := _board_cards()
	# 大秘术师：先给成长类效果增加全局成长层 _gb。
	for card in cards:
		var sk: Dictionary = card.get("sk", {})
		if String(sk.get("e", "")) == "growth-boost":
			var boost := int(sk.get("times", 1))
			for target in cards:
				var target_sk: Dictionary = target.get("sk", {})
				if _is_growth_target(target_sk):
					target["_gb"] = int(target.get("_gb", 0)) + boost
	for card in cards:
		var sk: Dictionary = card.get("sk", {})
		var sc: Dictionary = card.get("sc", {})
		var sc_sk: Dictionary = card.get("scSk", {})
		if int(sk.get("spellRefresh", 0)) > 0:
			var need := int(sk.get("spellRefresh", 1))
			card["_srT"] = int(card.get("_srT", 0)) + 1
			if int(card.get("_srT", 0)) % need == 0:
				free_refresh += 1
		if String(sc.get("t", "")) == "spell-cast" and String(sc.get("e", "")) == "self-growth-boost":
			card["_gb"] = int(card.get("_gb", 0)) + int(sc.get("times", 1))
		if String(sc_sk.get("t", "")) == "spell-cast" and String(sc_sk.get("e", "")) == "self-buff":
			_gain_card(card, int(sc_sk.get("a", 0)), int(sc_sk.get("h", 0)))
		elif String(sk.get("t", "")) == "on-dmg" and int(sk.get("spellMh", 0)) > 0:
			_gain_card(card, 0, int(sk.get("spellMh", 0)))
		elif String(sc_sk.get("t", "")) == "spell-cast" and String(sc_sk.get("e", "")) == "race-buff":
			var race_r := String(sc_sk.get("race", "neutral"))
			for target in cards:
				if String(target.get("race", "")) == race_r:
					_gain_card(target, int(sc_sk.get("a", 0)), int(sc_sk.get("h", 0)))
		if String(sk.get("t", "")) != "spell-cast":
			continue
		match String(sk.get("e", "")):
			"self-buff":
				_gain_card(card, int(sk.get("a", 0)), int(sk.get("h", 0)))
			"spell-race-grow":
				var ice := int(card.get("_iceT", 0)) + 1
				if int(sk.get("max", 0)) > 0:
					ice = mini(ice, int(sk.get("max", 0)))
				card["_iceT"] = ice
				var ga := int(sk.get("a", 0)) + ice - 1
				var gh := int(sk.get("h", 0)) + ice - 1
				for target in cards:
					if String(target.get("race", "")) == "elem":
						_gain_card(target, ga, gh)
			"spell-core":
				var core := int(card.get("_coreT", 0)) + 1
				card["_coreT"] = core
				var ca := int(sk.get("a", 0)) + core - 1 + int(card.get("_gb", 0))
				var ch := int(sk.get("h", 0)) + core - 1 + int(card.get("_gb", 0))
				_gain_card(card, ca, ch)
				var ra := int(sk.get("raceA", sk.get("a", 0)))
				var rh := int(sk.get("raceH", sk.get("h", 0)))
				for target in cards:
					if String(target.get("race", "")) == "elem":
						_gain_card(target, ra, rh)
			"race-buff":
				var race_b := String(sk.get("race", card.get("race", "neutral")))
				if race_b == "star":
					chain += 1
				var target_pool: Array = []
				for target in cards:
					if String(target.get("race", "")) == race_b:
						target_pool.append(target)
				if String(sk.get("scope", "")) == "rnd" and not target_pool.is_empty():
					target_pool = [target_pool[rng.randi_range(0, target_pool.size() - 1)]]
				var ba := int(sk.get("a", 0))
				var bh := int(sk.get("h", 0))
				if race_b == "star":
					ba = int(round(float(maxi(1, chain)) * float(sk.get("statScale", 1.0))))
					bh = ba
				for target in target_pool:
					_gain_card(target, ba, bh)
			"ally-all-buff":
				card["_sc"] = int(card.get("_sc", 0)) + 1
				var value := int(sk.get("d", 1)) + int(card.get("_sc", 0)) - 1
				for target in cards:
					_gain_card(target, value, value)

func apply_prep_round_skills() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var cards := _board_cards()
	for card in cards:
		var sk: Dictionary = card.get("sk", {})
		if String(sk.get("e", "")) == "spell-race-grow":
			card["_iceT"] = 0
	for card in cards:
		var sk: Dictionary = card.get("sk", {})
		var e := String(sk.get("e", ""))
		if e == "spell-boost-grow":
			card["_g"] = int(card.get("_g", 0)) + 1
			var ga := int(sk.get("a", 0)) + int(card.get("_g", 0)) - 1
			var gh := int(sk.get("h", 0)) + int(card.get("_g", 0)) - 1
			spell_boost["a"] = int(spell_boost.get("a", 0)) + ga
			spell_boost["h"] = int(spell_boost.get("h", 0)) + gh
			events.append({"effect": e, "card": card.get("n", ""), "a": ga, "h": gh})
		elif e == "shop-buff":
			var ba := int(sk.get("a", 0))
			var bh := int(sk.get("h", 0))
			shop_boost["a"] = int(shop_boost.get("a", 0)) + ba
			shop_boost["h"] = int(shop_boost.get("h", 0)) + bh
			var race_filter := String(sk.get("race", ""))
			for target in shop:
				if target == null or String(target.get("t", "")) != "m":
					continue
				if race_filter != "" and String(target.get("race", "")) != race_filter:
					continue
				_gain_card(target, ba, bh)
			events.append({"effect": e, "card": card.get("n", ""), "a": ba, "h": bh})
		elif e == "devour-shop":
			var candidates: Array = []
			for i in range(shop.size()):
				var target = shop[i]
				if target != null and String(target.get("t", "")) == "m":
					candidates.append(i)
			if not candidates.is_empty():
				var pick: int = candidates[rng.randi_range(0, candidates.size() - 1)]
				var eaten: Dictionary = shop[pick]
				var times := int(sk.get("times", 1))
				_gain_card(card, int(eaten.get("a", 0)) * times, int(eaten.get("h", 0)) * times)
				shop[pick] = null
				events.append({"effect": e, "card": card.get("n", ""), "eaten": eaten.get("n", "")})
		elif e == "mech-supply":
			var count := int(sk.get("count", 1))
			for i in range(count):
				var material := _pick_mech_material()
				if not material.is_empty():
					hand.append(material)
					events.append({"effect": e, "card": card.get("n", ""), "material": material.get("n", "")})
		elif e == "debt-interest":
			card["_di"] = int(card.get("_di", 0)) + 1
			var amount := int(sk.get("count", 1)) + (int(card.get("_di", 0)) - 1) * int(sk.get("grow", 0))
			debt += maxi(0, amount)
			var self_grow := int(sk.get("selfGrow", 0))
			_gain_card(card, self_grow, self_grow)
			events.append({"effect": e, "card": card.get("n", ""), "debt": amount, "self": self_grow})
	if ensure_auto_contract():
		events.append({"effect": "contract-auto", "card": last_message})
	return events

func _pick_mech_material() -> Dictionary:
	var pool: Array = []
	for star_value in pool_by_star.keys():
		for card_value in pool_by_star[star_value]:
			var card: Dictionary = card_value
			var name := String(card.get("n", ""))
			if bool(card.get("material", false)) and name in ["装甲模块", "磁暴模块", "超载模块"]:
				pool.append(card)
	if pool.is_empty():
		return {}
	var picked: Dictionary = pool[rng.randi_range(0, pool.size() - 1)].duplicate(true)
	picked["b"] = 0
	if not picked.has("t"):
		picked["t"] = "m"
	return picked

func _race_count(race: String) -> int:
	var count := 0
	for card in board:
		if card != null and String(card.get("race", "")) == race:
			count += 1
	return count

## 3 只同族起对商店做递增软偏向；只取场上数量最多的合法主族。
func shop_bias_info() -> Dictionary:
	var best_race := ""
	var best_count := 0
	for card in board:
		if card == null:
			continue
		var race := String(card.get("race", ""))
		if race == "" or race == "neutral" or not races.has(race):
			continue
		var count := _race_count(race)
		if count > best_count:
			best_race = race
			best_count = count
	if best_race == "" or best_count < SHOP_BIAS_MIN_COUNT:
		return {"races": [], "multiplier": 1.0, "count": best_count}
	var multiplier := minf(SHOP_BIAS_MAX,
		SHOP_BIAS_BASE + float(best_count - SHOP_BIAS_MIN_COUNT) * SHOP_BIAS_STEP)
	return {"races": [best_race], "multiplier": multiplier, "count": best_count}

func majority_race() -> String:
	var counts: Dictionary = {}
	var best := ""
	var best_count := 0
	for card in board:
		if card == null:
			continue
		var race := String(card.get("race", ""))
		if race == "":
			continue
		counts[race] = int(counts.get(race, 0)) + 1
		if int(counts[race]) > best_count:
			best = race
			best_count = int(counts[race])
	if best != "":
		return best
	if not races.is_empty():
		return String(races[rng.randi_range(0, races.size() - 1)])
	return ""

## 回合节点奖励：规则层直接处理三选一，UI 只负责选择与倒计时。
func apply_round_choice(round_value: int, option_index: int) -> Dictionary:
	last_message = ""
	if round_value != 3 and round_value != 6 and round_value != 9:
		return {"ok": false, "reason": "no_choice"}
	if option_index < 0 or option_index > 2:
		return {"ok": false, "reason": "bad_option"}
	var gain := (round_value / 3) * 2
	if option_index == 0:
		gold += gain
		last_message = "回合选择：+%d金" % gain
		return {"ok": true, "label": "+%d金" % gain}
	if option_index == 1:
		var free_count := 1 if round_value == 3 else 2
		free_refresh += free_count
		last_message = "回合选择：免费刷新+%d" % free_count
		return {"ok": true, "label": "免费刷新+%d" % free_count}
	if round_value == 3:
		free_spell_next = 1
		last_message = "回合选择：下回合法术免费"
		return {"ok": true, "label": "下回合法术免费"}
	if round_value == 6:
		var core := grant_core_card()
		if bool(core.get("ok", false)):
			last_message = "节点奖励：获得%s" % String(core.get("name", "阵容核心牌"))
		return core
	var gild := grant_gild_card()
	last_message = "节点奖励：获得自选点金卡"
	return gild

## 按场上多数种族发放一张核心牌，优先 4★ 以上的可用随从。
func grant_core_card() -> Dictionary:
	var race := majority_race()
	if race == "":
		return {"ok": false, "reason": "no_race"}
	var candidates: Array = []
	for star_value in pool_by_star.keys():
		var cards: Array = pool_by_star[star_value]
		for card_value in cards:
			var card: Dictionary = card_value
			if String(card.get("race", "")) != race:
				continue
			if bool(card.get("material", false)) or String(card.get("support", "")) != "" or bool(card.get("_mechBody", false)):
				continue
			if int(star_value) >= 4:
				candidates.append(card)
	if candidates.is_empty():
		for star_value in pool_by_star.keys():
			var cards: Array = pool_by_star[star_value]
			for card_value in cards:
				var card: Dictionary = card_value
				if String(card.get("race", "")) != race:
					continue
				if bool(card.get("material", false)) or String(card.get("support", "")) != "" or bool(card.get("_mechBody", false)):
					continue
				candidates.append(card)
	if candidates.is_empty():
		return {"ok": false, "reason": "no_core_card", "race": race}
	var picked: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)
	picked["b"] = 0
	hand.append(picked)
	return {"ok": true, "name": String(picked.get("n", "阵容核心牌")), "card": picked, "race": race}

func grant_gild_card() -> Dictionary:
	var card := {"n": "自选点金", "t": "s", "e": "gild-target", "x": "选择一个随从升金"}
	hand.append(card)
	return {"ok": true, "name": String(card["n"]), "card": card}

## 手牌三连：合成后金卡留在原数组里（手牌/棋盘各自可调用）
func try_gild_in_hand() -> Dictionary:
	var res := Gild.merge_in_place(hand)
	if bool(res["ok"]):
		# 清掉空位，保持手牌紧凑
		var packed_hand: Array = []
		for c in hand:
			if c != null:
				packed_hand.append(c)
		hand = packed_hand
	return res

func try_gild_in_board() -> Dictionary:
	return Gild.merge_in_place(board)

func has_formation() -> bool:
	return Fusion.find_formation(board) >= 0

## 合体准备（开打前调用）：返回替换后的棋盘 + 协同随从 + 带入的维修护甲
func prepare_fusion(mech_level: int = 0, mag_t: int = 0, mech_repair: int = 0) -> Dictionary:
	var body_id := _next_id()
	var res := Fusion.prepare(board, mech_level, mag_t, mech_repair, body_id, body_id, body_id * 10)
	if bool(res.get("ok", false)):
		var idx := int(res.get("index", -1))
		var saved_parts: Array = []
		if idx >= 0:
			for i in range(4):
				saved_parts.append(board[idx + i])
		_mech_save = {"index": idx, "parts": saved_parts}
		board = res["board"]
	return res

## 合体结束后恢复四个原始部位；存活时按原版提升出击等级并永久强化零件。
func finish_fusion(alive: bool) -> Dictionary:
	if _mech_save.is_empty():
		return {"ok": false}
	var idx := int(_mech_save.get("index", -1))
	var parts: Array = _mech_save.get("parts", [])
	var gain := 0
	if alive:
		mech_level += 1
		gain = 4 * mech_level
		for part in parts:
			if part == null:
				continue
			part["a"] = int(part.get("a", 0)) + gain
			part["h"] = int(part.get("h", 0)) + gain
			if part.has("mh"):
				part["mh"] = int(part.get("mh", 0)) + gain
			part["_mg"] = int(part.get("_mg", 0)) + gain
	if idx >= 0:
		for i in range(parts.size()):
			if idx + i < board.size():
				board[idx + i] = parts[i]
	_mech_save = {}
	if gain > 0:
		last_message = "合体存活：出击 Lv%d，零件 +%d/+%d" % [mech_level, gain, gain]
	return {"ok": true, "alive": alive, "gain": gain, "level": mech_level}

## 磁力喂料：把手牌里的材料牌喂给棋盘上的机械
func feed(hand_index: int, slot: int, state: Dictionary = {}) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false}
	if slot < 0 or slot >= BOARD_SLOTS or board[slot] == null:
		return {"ok": false}
	var mat: Dictionary = hand[hand_index]
	if not mat.has("magA") and not mat.has("magH"):
		return {"ok": false, "reason": "not_material"}
	if String(board[slot].get("race", "")) != "mech":
		return {"ok": false, "reason": "not_mech"}
	if String(board[slot].get("part", "")) == "":
		return {"ok": false, "reason": "no_part"}
	if state.is_empty():
		state = _magnet_state()
	var gained := Prep.magnet_feed(mat, board[slot], board, state)
	hand.remove_at(hand_index)
	_apply_magnet_state(state)
	return {"ok": true, "gained": gained, "target": board[slot]}

## 棋盘材料牌直接喂给另一只机械，供真实拖放使用。
func feed_board(source_slot: int, target_slot: int) -> Dictionary:
	last_message = ""
	if source_slot < 0 or source_slot >= BOARD_SLOTS or target_slot < 0 or target_slot >= BOARD_SLOTS:
		return {"ok": false}
	if source_slot == target_slot or board[source_slot] == null or board[target_slot] == null:
		return {"ok": false}
	var mat: Dictionary = board[source_slot]
	if not mat.has("magA") and not mat.has("magH"):
		return {"ok": false, "reason": "not_material"}
	if String(board[target_slot].get("race", "")) != "mech":
		return {"ok": false, "reason": "not_mech"}
	if String(board[target_slot].get("part", "")) == "":
		return {"ok": false, "reason": "no_part"}
	var state := _magnet_state()
	var gained := Prep.magnet_feed(mat, board[target_slot], board, state)
	board[source_slot] = null
	_apply_magnet_state(state)
	return {"ok": true, "gained": gained, "target": board[target_slot]}

func _magnet_state() -> Dictionary:
	return {
		"matBoostA": mat_boost_a,
		"matBoostH": mat_boost_h,
		"mechLevel": mech_level,
		"mechRepair": mech_repair,
		"_magT": mag_t,
	}

func _apply_magnet_state(state: Dictionary) -> void:
	mat_boost_a = int(state.get("matBoostA", mat_boost_a))
	mat_boost_h = int(state.get("matBoostH", mat_boost_h))
	mech_repair = int(state.get("mechRepair", mech_repair))
	mag_t = int(state.get("_magT", mag_t))

## 同部位低星零件升级高星零件：只继承该零件此前累计的成长。
func upgrade_part(source_slot: int, target_slot: int) -> Dictionary:
	last_message = ""
	if source_slot == target_slot or source_slot < 0 or target_slot < 0:
		return {"ok": false}
	var source = board[source_slot]
	var target = board[target_slot]
	if source == null or target == null:
		return {"ok": false}
	if String(source.get("race", "")) != "mech" or String(target.get("race", "")) != "mech":
		return {"ok": false, "reason": "not_mech"}
	var part := String(source.get("part", ""))
	if part == "" or part != String(target.get("part", "")):
		return {"ok": false, "reason": "part_mismatch"}
	if int(source.get("s", source.get("star", 1))) >= int(target.get("s", target.get("star", 1))):
		return {"ok": false, "reason": "star_order"}
	var gain := int(source.get("_mg", 0))
	target["a"] = int(target.get("a", 0)) + gain
	target["h"] = int(target.get("h", 0)) + gain
	if target.has("mh"):
		target["mh"] = int(target.get("mh", 0)) + gain
	target["_mg"] = int(target.get("_mg", 0)) + gain
	board[source_slot] = null
	last_message = "零件升级：继承成长 +%d/+%d" % [gain, gain]
	return {"ok": true, "gain": gain, "target": target}

func magnet_merge(source_slot: int, target_slot: int) -> Dictionary:
	last_message = ""
	if source_slot == target_slot or source_slot < 0 or target_slot < 0:
		return {"ok": false}
	var source = board[source_slot]
	var target = board[target_slot]
	if source == null or target == null:
		return {"ok": false}
	if String(source.get("race", "")) != "mech" or not bool(target.get("magnet", false)):
		return {"ok": false}
	target["a"] = int(target.get("a", 0)) + int(source.get("a", 0))
	target["h"] = int(target.get("h", 0)) + int(source.get("h", 0))
	if target.has("mh"):
		target["mh"] = int(target.get("mh", 0)) + int(source.get("h", 0))
	board[source_slot] = null
	last_message = "磁力合体：%s → %s" % [String(source.get("n", "")), String(target.get("n", ""))]
	return {"ok": true, "target": target}

func swap_slots(a: int, b: int) -> bool:
	last_message = ""
	if a < 0 or b < 0 or a >= BOARD_SLOTS or b >= BOARD_SLOTS or a == b:
		return false
	var tmp = board[a]
	board[a] = board[b]
	board[b] = tmp
	return true

func contract_bonus_for_board() -> int:
	var bonus := 0
	for card in board:
		if card == null:
			continue
		var sk: Dictionary = card.get("sk", {})
		if String(sk.get("e", "")) == "contract-set":
			bonus = maxi(bonus, int(sk.get("debtBonus", 3)))
	return bonus

func ensure_auto_contract() -> bool:
	for card in board:
		if card != null and bool(card.get("_contract", false)):
			contract_bonus = contract_bonus_for_board()
			return false
	var caster: Dictionary = {}
	for card in board:
		if card == null:
			continue
		var sk: Dictionary = card.get("sk", {})
		if String(sk.get("e", "")) == "contract-set":
			caster = card
			break
	if caster.is_empty():
		return false
	var target: Dictionary = {}
	for card in board:
		if card == null or card == caster or String(card.get("race", "")) != "sacrifice":
			continue
		if target.is_empty() or int(card.get("a", 0)) + int(card.get("h", 0)) < int(target.get("a", 0)) + int(target.get("h", 0)):
			target = card
	if target.is_empty():
		return false
	target["_contract"] = true
	contract_bonus = int(caster.get("sk", {}).get("debtBonus", 3))
	last_message = "契印：%s" % String(target.get("n", "献祭随从"))
	return true

func consume_contract_devour(prey: Dictionary) -> Dictionary:
	if prey == null or not bool(prey.get("_contract", false)):
		return {}
	var debt_boost := 0
	var totem := 0.0
	for card in board:
		if card == null:
			continue
		var sk: Dictionary = card.get("sk", {})
		if String(sk.get("e", "")) == "debt-boost":
			debt_boost += int(sk.get("a", 0))
		elif String(sk.get("e", "")) == "debt-totem":
			totem = maxf(totem, 1.5 if bool(card.get("g", false)) else 1.17)
	var raw := Sacrifice.contract_debt_raw_values(
		int(prey.get("a", 0)), int(prey.get("h", 0)), round_no,
		debt_boost, contract_bonus, totem, true)
	var change := Sacrifice.add_debt(debt, raw)
	debt = int(change["new"])
	contract_bonus = 0
	prey.erase("_contract")
	last_message = "契印吞噬：债务+%d" % int(change["delta"])
	return {
		"raw": raw,
		"delta": int(change["delta"]),
		"debt": debt,
		"tier": int(change["tier"]),
		"node_rewards": change["node_rewards"].duplicate(),
	}

## 吞噬：拖动/点击献祭者到友方随从，获得目标全部当前身材。
func devour_ally(eater_slot: int, prey_slot: int) -> Dictionary:
	last_message = ""
	if eater_slot == prey_slot or eater_slot < 0 or prey_slot < 0:
		return {"ok": false}
	var eater = board[eater_slot]
	var prey = board[prey_slot]
	if eater == null or prey == null:
		return {"ok": false}
	if not bool(eater.get("_devourReady", false)):
		return {"ok": false, "reason": "not_ready"}
	var bc: Dictionary = eater.get("bc", {})
	eater["a"] = int(eater.get("a", 0)) + int(prey.get("a", 0)) + int(bc.get("a", 0))
	eater["h"] = int(eater.get("h", 0)) + int(prey.get("h", 0)) + int(bc.get("h", 0))
	eater["mh"] = int(eater.get("mh", eater.get("h", 0)))
	eater["_devourReady"] = false
	var contract := consume_contract_devour(prey)
	board[prey_slot] = null
	last_message = "吞噬：%s → %s" % [String(prey.get("n", "")), String(eater.get("n", ""))]
	if not contract.is_empty():
		last_message += "（契印债务+%d）" % int(contract.get("delta", 0))
	return {"ok": true, "eater": eater, "prey": prey, "contract": contract}

## 手牌献祭者拖到友方：该手牌在当前格变成吞噬者，目标被吞噬移除。
func devour_from_hand(hand_index: int, prey_slot: int) -> Dictionary:
	last_message = ""
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false}
	if prey_slot < 0 or prey_slot >= BOARD_SLOTS or board[prey_slot] == null:
		return {"ok": false}
	var eater: Dictionary = hand[hand_index].duplicate(true)
	var bc: Dictionary = eater.get("bc", {})
	if String(bc.get("e", "")) != "devour":
		return {"ok": false, "reason": "not_devour"}
	var prey: Dictionary = board[prey_slot]
	eater["t"] = "m"
	if not eater.has("mh"):
		eater["mh"] = int(eater.get("h", 0))
	eater["a"] = int(eater.get("a", 0)) + int(prey.get("a", 0)) + int(bc.get("a", 0))
	eater["h"] = int(eater.get("h", 0)) + int(prey.get("h", 0)) + int(bc.get("h", 0))
	eater["mh"] = int(eater.get("mh", eater.get("h", 0)))
	eater["_devourReady"] = false
	var contract := consume_contract_devour(prey)
	hand.remove_at(hand_index)
	board[prey_slot] = eater
	last_message = "吞噬：%s → %s" % [String(prey.get("n", "")), String(eater.get("n", ""))]
	if not contract.is_empty():
		last_message += "（契印债务+%d）" % int(contract.get("delta", 0))
	return {"ok": true, "eater": eater, "prey": prey, "slot": prey_slot, "contract": contract}


## 确保当前相位有一个合法宣言。阶段切换后发现旧任务不属于新池时，回落到池首。
func ensure_quest() -> bool:
	var pool: Array = Quest.pool_for_phase(quest_pool, phase)
	if pool.is_empty():
		quest_id = ""
		quest_index = 0
		evo_prog = {"cur": 0, "need": 0}
		return false
	var resolved_index: int = -1
	for i in range(pool.size()):
		var entry = pool[i]
		if entry is Dictionary and String(entry.get("id", "")) == quest_id:
			resolved_index = i
			break
	if resolved_index < 0:
		resolved_index = 0
		quest_id = String(Dictionary(pool[0]).get("id", ""))
		evo_prog = {"cur": 0, "need": Quest.need_for_id(quest_id)}
	elif int(evo_prog.get("need", 0)) != Quest.need_for_id(quest_id):
		evo_prog = {"cur": 0, "need": Quest.need_for_id(quest_id)}
	quest_index = resolved_index
	return true


func quest_definition() -> Dictionary:
	ensure_quest()
	return Quest.find_quest(quest_pool, phase, quest_id)


func select_quest(index: int) -> Dictionary:
	var pool: Array = Quest.pool_for_phase(quest_pool, phase)
	if pool.is_empty():
		return {"ok": false, "reason": "no_pool"}
	var resolved: int = index
	if resolved < 0 or resolved >= pool.size():
		return {"ok": false, "reason": "invalid_index"}
	var entry = pool[resolved]
	if not (entry is Dictionary):
		return {"ok": false, "reason": "invalid_entry"}
	quest_index = resolved
	quest_id = String(entry.get("id", ""))
	evo_prog = {"cur": 0, "need": Quest.need_for_id(quest_id)}
	last_message = "宣言选择:%s" % String(entry.get("n", quest_id))
	return {"ok": true, "id": quest_id, "index": quest_index, "quest": entry}


func apply_quest_stats(stats: Dictionary) -> void:
	if not ensure_quest():
		return
	evo_prog = {
		"cur": Quest.current_for(quest_id, stats),
		"need": Quest.need_for_id(quest_id),
	}


## 宣言奖励在备战期结算，目标是我方持久棋盘卡牌，不在战斗尸体上结算。
## 返回奖励目标，供 UI 播放“宣言源 → 绿光球 → 受益随从”的过程。
func apply_quest_reward(complete: bool) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var ticks: int = Quest.reward_ticks(complete)
	var battle = BattleScript.new()
	for slot in range(board.size()):
		var card = board[slot]
		if card == null or String(card.get("race", "")) != "evolve":
			continue
		var skill: Dictionary = card.get("sk", {})
		var effect := String(skill.get("e", ""))
		if effect == "evolve" or effect == "evolve-step":
			var unit = UnitScript.from_card(card, 200000 + slot)
			var mini_board: Dictionary = {"p": [unit], "e": []}
			for _tick in range(ticks):
				battle._evolve_tick(unit, "p", mini_board)
			card["a"] = unit.atk
			card["h"] = unit.hp
			card["mh"] = unit.max_hp
			UnitScript.sync_runtime_to_card(card, unit)
			targets.append({
				"slot": slot,
				"name": String(card.get("n", "")),
				"ticks": ticks,
				"effect": effect,
			})
		elif effect == "progress":
			card["_pr"] = int(card.get("_pr", 0)) + ticks
			targets.append({
				"slot": slot,
				"name": String(card.get("n", "")),
				"ticks": ticks,
				"effect": effect,
			})
	return targets


func battle_options(side: String = "p") -> Dictionary:
	var suffix: String = "P" if side == "p" else "E"
	ensure_quest()
	return {
		"round": round_no,
		"debt" + suffix: debt,
		"contract" + suffix: contract_id,
		"contractBonus" + suffix: contract_bonus,
		"chain" + suffix: chain,
		"amp" + suffix: star_amp,
		"armor" + suffix: mech_repair,
		"dragonLayer" + suffix: dragon_layer,
		"prevDeathTick" + suffix: prev_death_tick,
		"undeadTick" + suffix: undead_tick,
		"phase" + suffix: phase,
		"quest" + suffix: quest_id,
		"questIndex" + suffix: quest_index,
	}

## 战斗结束后按 uid 把跨阶段运行态写回备战卡牌。
## units 的 uid 由调用方按非空槽位顺序分配，base_uid 对应第一张上场牌。
func sync_runtime_from_units(units: Array, base_uid: int = 1, include_dead: bool = false) -> int:
	var by_uid: Dictionary = {}
	for u in units:
		if u != null and (include_dead or bool(u.alive)):
			by_uid[int(u.uid)] = u
	var dense_index := 0
	var copied := 0
	for slot in range(board.size()):
		var card = board[slot]
		if card == null:
			continue
		var uid := base_uid + dense_index
		dense_index += 1
		if by_uid.has(uid):
			UnitScript.sync_runtime_to_card(card, by_uid[uid])
			copied += 1
	return copied

func _exec_battlecry(card: Dictionary, source_slot: int, bc: Dictionary, opponent_board: Array = []) -> Dictionary:
	var effect := String(bc.get("e", ""))
	var result := {"effect": effect, "source_slot": source_slot, "card": card.duplicate(true)}
	match effect:
		"self":
			card["a"] = int(card.get("a", 0)) + int(bc.get("a", 0))
			card["h"] = int(card.get("h", 0)) + int(bc.get("h", 0))
			if card.has("mh"):
				card["mh"] = int(card.get("mh", 0)) + int(bc.get("h", 0))
			last_message = "战吼：自身 +%d/+%d" % [int(bc.get("a", 0)), int(bc.get("h", 0))]
			result.merge({"a": int(bc.get("a", 0)), "h": int(bc.get("h", 0))}, true)
		"ally-rnd", "ally-atk":
			var candidates: Array[int] = []
			for i in range(board.size()):
				if board[i] != null:
					candidates.append(i)
			if candidates.is_empty():
				last_message = "战吼：没有友方随从"
				return result
			var target_slot: int = candidates[rng.randi_range(0, candidates.size() - 1)]
			var target: Dictionary = board[target_slot]
			target["a"] = int(target.get("a", 0)) + int(bc.get("a", 0))
			if effect == "ally-rnd":
				target["h"] = int(target.get("h", 0)) + int(bc.get("h", 0))
				if target.has("mh"):
					target["mh"] = int(target.get("mh", 0)) + int(bc.get("h", 0))
				last_message = "战吼：%s +%d/+%d" % [String(target.get("n", "友方")), int(bc.get("a", 0)), int(bc.get("h", 0))]
			else:
				last_message = "战吼：%s +%d攻" % [String(target.get("n", "友方")), int(bc.get("a", 0))]
			result.merge({
				"target_slot": target_slot,
				"target": target.duplicate(true),
				"a": int(bc.get("a", 0)),
				"h": int(bc.get("h", 0)) if effect == "ally-rnd" else 0,
			}, true)
		"gold":
			var gain := int(bc.get("g", 1))
			gold += gain
			last_message = "战吼：获得 %d 金" % gain
			result["gold"] = gain
		"free-refresh":
			free_refresh += 1
			last_message = "战吼：免费刷新 +1"
			result["free_refresh"] = 1
		"spell-boost":
			spell_boost["a"] = int(spell_boost.get("a", 0)) + int(bc.get("a", 0))
			spell_boost["h"] = int(spell_boost.get("h", 0)) + int(bc.get("h", 0))
			last_message = "战吼：法术效果 +%d/+%d" % [int(bc.get("a", 0)), int(bc.get("h", 0))]
			result.merge({"a": int(bc.get("a", 0)), "h": int(bc.get("h", 0))}, true)
		"dmg-rnd":
			var candidates: Array[int] = []
			for i in range(opponent_board.size()):
				if opponent_board[i] != null:
					candidates.append(i)
			if candidates.is_empty():
				last_message = "战吼：没有敌方目标"
				return result
			var target_slot: int = candidates[rng.randi_range(0, candidates.size() - 1)]
			var target: Dictionary = opponent_board[target_slot]
			var damage := int(bc.get("d", 1))
			var snapshot: Dictionary = target.duplicate(true)
			target["h"] = maxi(0, int(target.get("h", 0)) - damage)
			var killed := int(target["h"]) <= 0
			if killed:
				_battlecry_dead.append(snapshot)
				opponent_board[target_slot] = null
				last_message = "战吼：消灭 %s" % String(snapshot.get("n", "敌方"))
			else:
				last_message = "战吼：%d 伤 → %s（%d）" % [damage, String(target.get("n", "敌方")), int(target["h"])]
			result.merge({
				"target_slot": target_slot,
				"target": snapshot,
				"damage": damage,
				"killed": killed,
			}, true)
		"devour":
			card["_devourReady"] = true
			last_message = "请拖动或点击这只献祭者吞噬一名友方"
			result["ready"] = true
	return result

## 战吼造成的死亡会在战斗结束后回到对方第一个空位；恢复生命按 Web 的 mh 规则。
func restore_battlecry_dead(target_board: Array) -> Array[Dictionary]:
	var restored: Array[Dictionary] = []
	for snapshot in _battlecry_dead:
		var card: Dictionary = snapshot.duplicate(true)
		var max_hp := int(card.get("mh", 0))
		if max_hp > 0:
			card["h"] = max_hp
		var slot := -1
		for i in range(target_board.size()):
			if target_board[i] == null:
				slot = i
				break
		if slot < 0:
			continue
		target_board[slot] = card
		restored.append(card)
	_battlecry_dead.clear()
	return restored
