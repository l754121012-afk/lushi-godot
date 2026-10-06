extends RefCounted
## P2-2：商店生成（对齐 Web 的 gs()）
## 规则：5 个格子；每格 20% 出法术牌；否则按酒馆等级查星级概率抽星级（8% 概率 +1 星），
##       再从该星级卡池里取一张——只取本局种族池内的牌（无种族的牌不受限）。
##       主族软偏向通过调用方传入 bias_races / bias_multiplier 注入，不会裁掉其他合法种族。
## 纯逻辑：卡池与法术池由调用方注入，RNG 由调用方提供（可播种复现）。

const ODDS_PATH := "res://data/star_odds.json"
static var _odds: Array = []
static var _odds_loaded := false

static func odds() -> Array:
	if not _odds_loaded:
		_odds_loaded = true
		if FileAccess.file_exists(ODDS_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(ODDS_PATH))
			if typeof(parsed) == TYPE_DICTIONARY:
				_odds = parsed.get("starOdds", [])
	return _odds

## 按酒馆等级抽星级（权重累加 + 8% 概率提升一星）
static func roll_star(level: int, rng: RandomNumberGenerator) -> int:
	var table := odds()
	var idx := clampi(level, 0, max(0, table.size() - 1))
	var weights: Array = table[idx] if table.size() > 0 else []
	var star := 1
	if not weights.is_empty():
		var total := 0.0
		for w in weights:
			total += float(w)
		var r := rng.randf() * total
		var acc := 0.0
		for j in range(weights.size()):
			acc += float(weights[j])
			if r < acc:
				star = j + 1
				break
	if level < 7 and rng.randf() < 0.08:
		star += 1
	return clampi(star, 1, 7)

## 抽一张牌：先从本局合法种族里建立候选池，再随机。
## bias_races 使用软权重，不裁掉其他合法种族；bias_multiplier<=1 时等价普通随机。
static func roll_card(star: int, races: Array, rng: RandomNumberGenerator, pool_by_star: Dictionary,
		bias_races: Array = [], bias_multiplier: float = 1.0) -> Dictionary:
	var pool: Array = pool_by_star.get(star, [])
	if pool.is_empty():
		return {}
	var candidates: Array = []
	for value in pool:
		var c: Dictionary = value
		var race := String(c.get("race", ""))
		if races.is_empty() or race == "" or race == "neutral" or races.has(race):
			candidates.append(c)
	if candidates.is_empty():
		return {}
	if bias_races.is_empty() or bias_multiplier <= 1.0:
		return Dictionary(candidates[rng.randi_range(0, candidates.size() - 1)]).duplicate(true)
	var total_weight := 0.0
	for value in candidates:
		var c: Dictionary = value
		total_weight += bias_multiplier if bias_races.has(String(c.get("race", ""))) else 1.0
	var pick := rng.randf() * total_weight
	for value in candidates:
		var c: Dictionary = value
		pick -= bias_multiplier if bias_races.has(String(c.get("race", ""))) else 1.0
		if pick < 0.0:
			return Dictionary(c).duplicate(true)
	return Dictionary(candidates[candidates.size() - 1]).duplicate(true)

static func roll_shop(level: int, races: Array, rng: RandomNumberGenerator, pool_by_star: Dictionary,
		spells: Array = [], slots: int = 5, bias_races: Array = [], bias_multiplier: float = 1.0) -> Array:
	var out: Array = []
	for i in range(slots):
		if not spells.is_empty() and rng.randf() < 0.2:
			var sp: Dictionary = (spells[rng.randi_range(0, spells.size() - 1)] as Dictionary).duplicate(true)
			sp["t"] = "s"
			out.append(sp)
			continue
		var star := roll_star(level, rng)
		var card := roll_card(star, races, rng, pool_by_star, bias_races, bias_multiplier)
		if card.is_empty():
			continue
		card["star"] = star
		out.append(card)
	return out
