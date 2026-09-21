extends RefCounted
## P2 起手：备战期经济（每回合基础金币 / 连胜连败利息 / 升级花费 / 刷新花费）
## 全部查 data/config.json，避免把数值写死在代码里
## 规则：金币不结转 —— 每回合收入 = 本回合基础 + 利息 + 节奏奖励（直接覆盖，不是累加）

const CONFIG_PATH := "res://data/config.json"
static var _cfg: Dictionary = {}

static func config() -> Dictionary:
	if _cfg.is_empty():
		if not FileAccess.file_exists(CONFIG_PATH):
			return {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if typeof(parsed) != TYPE_DICTIONARY:
			return {}
		_cfg = parsed.get("config", {})
	return _cfg

static func round_base_gold(round_no: int) -> int:
	for row in config().get("baseGold", []):
		if int(row.get("round", 0)) == round_no:
			return int(row.get("gold", 0))
	return 0

## 连胜/连败利息：只看连胜或连败数（与剩余本金无关）
static func streak_interest(win_streak: int, lose_streak: int) -> int:
	for row in config().get("interest", []):
		var s := int(row.get("streak", 0))
		if win_streak > 0 and s == win_streak:
			return int(row.get("gold", 0))
		if lose_streak > 0 and s == lose_streak:
			return int(row.get("loseGold", 0))
	return 0

static func round_income(round_no: int, win_streak: int = 0, lose_streak: int = 0, tempo_bonus: int = 0) -> int:
	return round_base_gold(round_no) + streak_interest(win_streak, lose_streak) + tempo_bonus

static func level_up_cost(level: int) -> int:
	var costs: Array = config().get("levelCost", [])
	if level < 0 or level >= costs.size():
		return 0
	return int(costs[level])

static func can_level_up(level: int, gold: int) -> bool:
	var cost := level_up_cost(level)
	return cost > 0 and gold >= cost

static func refresh_cost() -> int:
	return 1
