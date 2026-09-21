extends SceneTree
## 数据自检：godot --headless --path <项目> --script res://tools/selftest.gd
## 校验导出数据是否完整（卡池、种族、经济配置、宣言池），失败返回非 0。

func _init() -> void:
	var problems: Array[String] = []
	var cards_doc := _load("res://data/cards.json")
	var races_doc := _load("res://data/races.json")
	var config_doc := _load("res://data/config.json")
	var quests_doc := _load("res://data/quests.json")
	var odds_doc := _load("res://data/star_odds.json")

	if cards_doc.is_empty(): problems.append("cards.json 读取失败")
	if races_doc.is_empty(): problems.append("races.json 读取失败")
	if config_doc.is_empty(): problems.append("config.json 读取失败")

	var races: Dictionary = races_doc.get("races", {})
	var tiers: Array = cards_doc.get("tiers", [])
	var total := 0
	var per_star: Array[String] = []
	var by_race: Dictionary = {}
	for tier in tiers:
		var star := int(tier.get("star", 0))
		var list: Array = tier.get("cards", [])
		total += list.size()
		per_star.append("%d★=%d" % [star, list.size()])
		for c in list:
			var race := String(c.get("race", "neutral"))
			by_race[race] = int(by_race.get(race, 0)) + 1
			if not c.has("n"):
				problems.append("卡牌缺少名称字段: " + JSON.stringify(c))
			if race != "neutral" and not races.has(race):
				problems.append("未知种族 %s（卡：%s）" % [race, String(c.get("n", "?"))])
			if String(c.get("t", "m")) != "s" and (not c.has("a") or not c.has("h")):
				problems.append("随从缺少攻/血数值: " + String(c.get("n", "?")))

	var evolve_names: Array[String] = []
	for c in (cards_doc.get("tiers", []) as Array):
		for card in (c.get("cards", []) as Array):
			if String(card.get("race", "")) == "evolve":
				evolve_names.append(String(card.get("n", "?")))

	var cfg: Dictionary = config_doc.get("config", {})
	if not cfg.has("levelCost") or (cfg["levelCost"] as Array).is_empty():
		problems.append("config.levelCost 缺失")
	if not cfg.has("baseGold") or (cfg["baseGold"] as Array).size() < 10:
		problems.append("config.baseGold 不足 10 回合")
	if not cfg.has("interest") or (cfg["interest"] as Array).size() < 5:
		problems.append("config.interest 缺失")
	if odds_doc.get("starOdds", []).is_empty():
		problems.append("star_odds.json 为空")
	if quests_doc.get("quests", {}).is_empty():
		problems.append("quests.json 为空")

	print("[selftest] 卡池总数 = ", total)
	print("[selftest] 星级分布 = ", " ".join(per_star))
	var race_line: Array[String] = []
	for r in by_race.keys():
		race_line.append("%s=%d" % [races.get(r, {}).get("name", String(r)), by_race[r]])
	race_line.sort()
	print("[selftest] 种族分布 = ", " ".join(race_line))
	print("[selftest] 进化随从 = ", " ".join(evolve_names))
	print("[selftest] 酒馆升级花费 = ", cfg.get("levelCost", []))
	print("[selftest] 宣言池 = ", quests_doc.get("quests", {}).keys())

	if evolve_names.size() != 5:
		problems.append("进化随从应为 5 张（方案2 后），实际 %d 张" % evolve_names.size())
	if not evolve_names.has("终极进化体"):
		problems.append("进化随从缺少终极进化体")
	if evolve_names.has("变异幼体"):
		problems.append("变异幼体应已删除")

	if problems.is_empty():
		print("[selftest] 通过：数据完整")
		quit(0)
	else:
		for p in problems:
			printerr("[selftest] 问题：", p)
		quit(1)

func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		printerr("[selftest] 文件不存在: ", path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("[selftest] 解析失败: ", path)
		return {}
	return parsed
