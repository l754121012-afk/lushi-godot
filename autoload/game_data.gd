extends Node
## 全局数据入口：统一读取 res://data/*.json，供卡牌浏览、商店、战斗等系统使用。
## 数据由 _diag_sac/extract_for_godot.cjs 从 lushi-like/index.html 导出，改数值请改源工程后重跑导出。

const DATA_DIR := "res://data/"

var cards: Array = []              # 全部卡牌，每张带 star 字段
var by_star: Dictionary = {}       # star(int) -> Array[Dictionary]
var by_race: Dictionary = {}       # race(String) -> Array[Dictionary]
var races: Dictionary = {}         # race_id -> {name, icon}
var quests: Dictionary = {}        # 进化双相宣言
var config: Dictionary = {}        # 经济/规则配置
var star_odds: Array = []          # 酒馆等级 -> 各星级出现权重
var keywords: Dictionary = {}      # 关键词图标/名称
var ai_templates: Array = []       # AI 阵容模板
var spells: Array = []             # 法术池

func _ready() -> void:
	reload()

func reload() -> void:
	cards.clear()
	by_star.clear()
	by_race.clear()

	var card_doc: Dictionary = _load_json("cards.json")
	for tier in card_doc.get("tiers", []):
		var star: int = int(tier.get("star", 0))
		var list: Array = tier.get("cards", [])
		for c in list:
			var card: Dictionary = c.duplicate(true)
			card["star"] = star
			if not card.has("race"):
				card["race"] = "neutral"
			cards.append(card)
			if not by_star.has(star):
				by_star[star] = []
			by_star[star].append(card)
			var race: String = card["race"]
			if not by_race.has(race):
				by_race[race] = []
			by_race[race].append(card)

	races = _load_json("races.json").get("races", {})
	quests = _load_json("quests.json").get("quests", {})
	config = _load_json("config.json").get("config", {})
	star_odds = _load_json("star_odds.json").get("starOdds", [])
	keywords = _load_json("keywords.json").get("keywords", {})
	var ai_doc: Dictionary = _load_json("ai_templates.json")
	ai_templates = ai_doc.get("templates", [])
	spells = ai_doc.get("spells", [])

func _load_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		push_warning("数据文件缺失: " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("数据文件解析失败: " + path)
		return {}
	return parsed

## 查询：按种族 / 星级 / 关键字过滤
func filter_cards(race: String = "", star: int = 0, text: String = "") -> Array:
	var out: Array = []
	var needle := text.strip_edges().to_lower()
	for c in cards:
		if race != "" and race != "all" and c.get("race", "neutral") != race:
			continue
		if star > 0 and int(c.get("star", 0)) != star:
			continue
		if needle != "" and not String(c.get("n", "")).to_lower().contains(needle):
			continue
		out.append(c)
	return out

func race_name(race_id: String) -> String:
	if races.has(race_id):
		return String(races[race_id].get("name", race_id))
	if race_id == "neutral":
		return "中立"
	return race_id

func race_icon(race_id: String) -> String:
	if races.has(race_id):
		return String(races[race_id].get("icon", ""))
	return ""

## 卡面主技能 id（战斗系统按这个分发）
func skill_id(card: Dictionary) -> String:
	if card.has("sk") and card["sk"] is Dictionary:
		return String(card["sk"].get("e", card["sk"].get("t", "")))
	if card.has("e"):
		return String(card["e"])
	return ""
