extends SceneTree
## 主族商店偏向测量：godot --headless --path <项目> --script res://tools/shop_bias_probe.gd
## 输出为“单次 5 格商店至少出现一张目标族随从”的比例。

const Shop := preload("res://sim/shop.gd")
const CARDS_PATH := "res://data/cards.json"
const RACES: Array[String] = [
	"undead", "elem", "dragon", "demon", "star", "mech",
	"vampire", "gambler", "evolve", "sacrifice",
]

func _init() -> void:
	var doc = JSON.parse_string(FileAccess.get_file_as_string(CARDS_PATH))
	if typeof(doc) != TYPE_DICTIONARY:
		printerr("[shop_bias_probe] cards.json 读取失败")
		quit(1)
		return
	var pool := {}
	for tier in doc.get("tiers", []):
		pool[int(tier.get("star", 0))] = tier.get("cards", [])
	var odds := Shop.odds()
	print("[shop_bias_probe] 5格商店至少出现1张目标族随从（3只×1.5 / 4只×2.0 / 5只×2.5）")
	for level in [4, 5, 6]:
		print("Lv%d" % level)
		for target in RACES:
			var values := _target_average(level, target, pool, odds)
			print("  %-9s base=%5.1f%%  3只=%5.1f%%  4只=%5.1f%%  5只=%5.1f%%" % [
				target,
				float(values["base"]) * 100.0,
				float(values["x15"]) * 100.0,
				float(values["x20"]) * 100.0,
				float(values["x25"]) * 100.0,
			])
	quit()

func _target_average(level: int, target: String, pool: Dictionary, odds: Array) -> Dictionary:
	var others: Array[String] = []
	for race in RACES:
		if race != target:
			others.append(race)
	var combos := _combinations(others, 5)
	var totals := {"base": 0.0, "x15": 0.0, "x20": 0.0, "x25": 0.0}
	for combo in combos:
		var opened: Array[String] = [target]
		opened.append_array(combo)
		totals["base"] += _presence(level, opened, target, pool, odds, 1.0)
		totals["x15"] += _presence(level, opened, target, pool, odds, 1.5)
		totals["x20"] += _presence(level, opened, target, pool, odds, 2.0)
		totals["x25"] += _presence(level, opened, target, pool, odds, 2.5)
	var divisor := float(combos.size())
	return {
		"base": float(totals["base"]) / divisor,
		"x15": float(totals["x15"]) / divisor,
		"x20": float(totals["x20"]) / divisor,
		"x25": float(totals["x25"]) / divisor,
	}

func _presence(level: int, opened: Array, target: String, pool: Dictionary,
		odds: Array, multiplier: float) -> float:
	var per_slot := 0.0
	for star in range(1, 8):
		var cards: Array = pool.get(star, [])
		if cards.is_empty():
			continue
		var total_weight := 0.0
		var target_weight := 0.0
		for value in cards:
			var card: Dictionary = value
			var race := String(card.get("race", ""))
			if not (race == "" or race == "neutral" or opened.has(race)):
				continue
			var weight := multiplier if race == target else 1.0
			total_weight += weight
			if race == target:
				target_weight += weight
		if total_weight > 0.0:
			per_slot += _star_probability(level, star, odds) * (target_weight / total_weight) * 0.8
	return 1.0 - pow(1.0 - per_slot, 5.0)

func _star_probability(level: int, star: int, odds: Array) -> float:
	var idx := clampi(level, 0, max(0, odds.size() - 1))
	var weights: Array = odds[idx] if not odds.is_empty() else []
	if weights.is_empty():
		return 0.0
	var total := 0.0
	for weight in weights:
		total += float(weight)
	if total <= 0.0:
		return 0.0
	var probability := 0.0
	for i in range(weights.size()):
		var base := float(weights[i]) / total
		var source_star := i + 1
		if source_star == star:
			probability += base * 0.92
		if level < 7 and source_star + 1 == star:
			probability += base * 0.08
	return probability

func _combinations(values: Array[String], count: int) -> Array:
	var out: Array = []
	_combine_recursive(values, count, 0, [], out)
	return out

func _combine_recursive(values: Array[String], count: int, start: int,
		current: Array[String], out: Array) -> void:
	if current.size() == count:
		out.append(current.duplicate())
		return
	for i in range(start, values.size()):
		current.append(values[i])
		_combine_recursive(values, count, i + 1, current, out)
		current.pop_back()
