extends RefCounted
## 进化宣言：昼夜任务池、战斗统计与达成阈值。
## 规则来自 Web 原版 EVO_Q，战斗层和表现层都只依赖这里的纯函数。

const NEEDS: Dictionary = {
	"hunt": 2,
	"press": 3,
	"frenzy": 4,
	"unyield": 5,
	"symbiosis": 2,
	"lurk": 15,
}

const STAT_KEYS: Array[String] = ["kills", "alive", "evoAlive", "evoAtk", "evoHit", "dmg"]


static func empty_stats() -> Dictionary:
	var result: Dictionary = {}
	for key in STAT_KEYS:
		result[key] = 0
	return result


static func pool_for_phase(quests: Dictionary, phase: int) -> Array:
	var pool_key: String = "day" if phase == 0 else "night"
	var pool_value = quests.get(pool_key, [])
	if pool_value is Array:
		return pool_value
	return []


static func find_quest(quests: Dictionary, phase: int, quest_id: String) -> Dictionary:
	var pool: Array = pool_for_phase(quests, phase)
	for value in pool:
		if value is Dictionary and String(value.get("id", "")) == quest_id:
			return value
	if not pool.is_empty() and pool[0] is Dictionary:
		return pool[0]
	return {}


static func need_for_id(quest_id: String) -> int:
	return int(NEEDS.get(quest_id, 0))


static func current_for(quest_id: String, stats: Dictionary) -> int:
	match quest_id:
		"hunt":
			return int(stats.get("kills", 0))
		"press":
			return int(stats.get("alive", 0))
		"frenzy":
			return int(stats.get("evoAtk", 0))
		"unyield":
			return int(stats.get("evoHit", 0))
		"symbiosis":
			return int(stats.get("evoAlive", 0))
		"lurk":
			return int(stats.get("dmg", 0))
	return 0


static func is_complete(quest_id: String, stats: Dictionary) -> bool:
	var need: int = need_for_id(quest_id)
	return need > 0 and current_for(quest_id, stats) >= need


static func reward_ticks(complete: bool) -> int:
	return 2 if complete else 1


## 按 Web 的 seq 语义统计战斗事件。
## own_initial / foe_initial 是开场棋盘，own_final 是当前或战斗结束时的己方棋盘。
static func evaluate(events: Array, _side: String, own_initial: Array, foe_initial: Array,
		own_final: Array) -> Dictionary:
	var own_races: Dictionary = _build_race_map(own_initial)
	var foe_races: Dictionary = _build_race_map(foe_initial)
	var kills: Dictionary = {}
	var evo_atk: int = 0
	var evo_hit: int = 0
	var damage_taken: int = 0
	var alive: int = 0
	var evo_alive: int = 0

	for value in own_final:
		if not _is_alive(value):
			continue
		alive += 1
		if _race_of(value) == "evolve":
			evo_alive += 1

	var pending_attacks: Array = []
	for event_value in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var kind: String = String(event.get("t", ""))
		if kind == "attack":
			pending_attacks.append({
				"src": int(event.get("src", -1)),
				"dst": int(event.get("dst", -1)),
				"swing": int(event.get("swing", -1)),
			})
		elif kind == "damage":
			var src: int = int(event.get("src", -1))
			var dst: int = int(event.get("dst", -1))
			var swing: int = int(event.get("swing", -1))
			var pending_index: int = _take_pending(pending_attacks, src, dst, swing)
			if pending_index < 0:
				continue
			var dealt: int = int(event.get("dmg", 0))
			if dealt > 0:
				if String(own_races.get(src, "")) == "evolve":
					evo_atk += 1
				if String(own_races.get(dst, "")) == "evolve":
					evo_hit += 1
			if own_races.has(dst):
				damage_taken += dealt
		elif kind == "death":
			var dead_id: int = int(event.get("id", -1))
			if dead_id >= 0 and foe_races.has(dead_id) and not own_races.has(dead_id):
				kills[dead_id] = true

	return {
		"kills": kills.size(),
		"alive": alive,
		"evoAlive": evo_alive,
		"evoAtk": evo_atk,
		"evoHit": evo_hit,
		"dmg": damage_taken,
	}


static func _take_pending(pending_attacks: Array, src: int, dst: int, swing: int) -> int:
	for i in range(pending_attacks.size()):
		var pending: Dictionary = pending_attacks[i]
		if int(pending.get("src", -1)) != src or int(pending.get("dst", -1)) != dst:
			continue
		var pending_swing: int = int(pending.get("swing", -1))
		if swing < 0 or pending_swing < 0 or pending_swing == swing:
			pending_attacks.remove_at(i)
			return i
	return -1


static func _build_race_map(units: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in units:
		if value == null:
			continue
		var uid: int = _uid_of(value)
		if uid >= 0:
			result[uid] = _race_of(value)
	return result


static func _uid_of(value: Variant) -> int:
	if value is Dictionary:
		return int(value.get("_uid", value.get("uid", -1)))
	return int(value.get("uid"))


static func _race_of(value: Variant) -> String:
	if value is Dictionary:
		return String(value.get("race", ""))
	return String(value.get("race"))


static func _is_alive(value: Variant) -> bool:
	if value == null:
		return false
	if value is Dictionary:
		if value.has("alive"):
			return bool(value.get("alive", false))
		return int(value.get("h", 0)) > 0
	return bool(value.get("alive"))
