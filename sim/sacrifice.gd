extends RefCounted
## 献祭共享规则：契印、债务节点与节点收益信息。
## 战斗和备战表现层共用，避免公式与事件口径各写一份。

const DEBT_TIERS := [8, 18, 32]
const TIER_BONUS := [0, 1, 3, 6]

static func debt_tier(value: int) -> int:
	if value >= 32:
		return 3
	if value >= 18:
		return 2
	if value >= 8:
		return 1
	return 0

static func payoff_info(value: int) -> Dictionary:
	if value >= 32:
		return {"need": 32, "mult": 3, "bonus": 8, "tier": 3}
	if value >= 18:
		return {"need": 18, "mult": 2, "bonus": 3, "tier": 2}
	if value >= 8:
		return {"need": 8, "mult": 1, "bonus": 1, "tier": 1}
	return {"need": mini(4, maxi(0, value)), "mult": 1, "bonus": 0, "tier": 0}

static func contract_debt_raw(dead, round_no: int, debt_boost: int, contract_bonus: int,
		totem_multiplier: float, devoured_contract: bool) -> int:
	return contract_debt_raw_values(int(dead.atk), int(dead.hp), round_no, debt_boost,
		contract_bonus, totem_multiplier, devoured_contract)

static func contract_debt_raw_values(atk: int, hp: int, round_no: int, debt_boost: int,
		contract_bonus: int, totem_multiplier: float, devoured_contract: bool) -> int:
	var raw := int(ceil(float(atk + hp) / 6.0) +
		floor(float(round_no) / 4.0) +
		float(debt_boost + contract_bonus) +
		floor(float(round_no) / 8.0))
	raw = clampi(raw, 1, 24)
	if totem_multiplier > 0.0:
		raw = int(round(float(raw) * totem_multiplier))
	if devoured_contract:
		raw = int(ceil(float(raw) * 1.17))
	return maxi(1, raw)

static func add_debt(current: int, delta: int) -> Dictionary:
	var old_value := maxi(0, current)
	var new_value := maxi(0, old_value + delta)
	var old_tier := debt_tier(old_value)
	var new_tier := debt_tier(new_value)
	var rewards: Array[int] = []
	if new_tier > old_tier:
		for tier in range(old_tier + 1, new_tier + 1):
			var reward := int(TIER_BONUS[tier])
			new_value += reward
			rewards.append(reward)
		new_tier = debt_tier(new_value)
	return {
		"old": old_value,
		"new": new_value,
		"delta": new_value - old_value,
		"old_tier": old_tier,
		"tier": new_tier,
		"node_rewards": rewards,
	}

static func payoff_gain(info: Dictionary, payoff_bonus: float, pay_a: int, pay_h: int,
		ramp: float, gold_multiplier: int = 1) -> Vector2i:
	var need := int(info.get("need", 0))
	if need <= 0:
		return Vector2i.ZERO
	var base := float(need * int(info.get("mult", 1)) + int(info.get("bonus", 0))) \
		* payoff_bonus * float(maxi(1, gold_multiplier))
	var ga := int(round(base * (1.0 + minf(0.5, float(pay_a) / 50.0)) * ramp / 2.0))
	var gh := int(round(base * (1.0 + minf(0.5, float(pay_h) / 50.0)) * ramp / 2.0))
	return Vector2i(ga, gh)
