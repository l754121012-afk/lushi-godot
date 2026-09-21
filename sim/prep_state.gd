extends RefCounted
## P2-4：备战期状态机（把已迁移的规则层接起来）
## 经济(sim/economy) + 商店(sim/shop) + 三连金卡(sim/gild) + 合体判定(sim/fusion) + 磁力喂料(sim/prep)
## UI 之后只需要调用这里的 buy / reroll / level_up / place / sell / try_gild，不再重复写规则。

const Economy := preload("res://sim/economy.gd")
const Shop := preload("res://sim/shop.gd")
const Gild := preload("res://sim/gild.gd")
const Fusion := preload("res://sim/fusion.gd")
const Prep := preload("res://sim/prep.gd")

const BOARD_SLOTS := 7
const SHOP_SLOTS := 5
const HAND_LIMIT := 10
const BUY_COST_PER_STAR := 1   # 购买价 = 星级 × 该值（与 Web 的商店定价保持同一常数，方便调整）

var round_no: int = 1
var gold: int = 0
var level: int = 1
var win_streak: int = 0
var lose_streak: int = 0
var free_refresh: int = 0
var races: Array = []
var pool_by_star: Dictionary = {}
var spells: Array = []
var shop: Array = []
var hand: Array = []
var board: Array = []
var rng := RandomNumberGenerator.new()

func setup(p_round: int, p_races: Array, p_pool: Dictionary, p_spells: Array = [], seed_value: int = 1) -> void:
	round_no = p_round
	races = p_races.duplicate()
	pool_by_star = p_pool
	spells = p_spells
	rng.seed = seed_value
	hand = []
	board = []
	for i in range(BOARD_SLOTS):
		board.append(null)
	gold = Economy.round_income(round_no, win_streak, lose_streak)
	roll_shop()

func roll_shop() -> void:
	shop = Shop.roll_shop(level, races, rng, pool_by_star, spells, SHOP_SLOTS)

func buy_cost(card: Dictionary) -> int:
	return max(1, int(card.get("star", 1)) * BUY_COST_PER_STAR)

## 买牌：扣钱 → 进手牌 → 商店该格清空。手牌满或钱不够则失败
func buy(index: int) -> Dictionary:
	if index < 0 or index >= shop.size() or shop[index] == null:
		return {"ok": false, "reason": "empty"}
	if hand.size() >= HAND_LIMIT:
		return {"ok": false, "reason": "hand_full"}
	var card: Dictionary = shop[index]
	var cost := buy_cost(card)
	if gold < cost:
		return {"ok": false, "reason": "no_gold", "cost": cost}
	gold -= cost
	hand.append(card)
	shop[index] = null
	return {"ok": true, "card": card, "cost": cost}

## 刷新：优先用免费次数，否则 1 金
func reroll() -> bool:
	if free_refresh > 0:
		free_refresh -= 1
	else:
		var cost := Economy.refresh_cost()
		if gold < cost:
			return false
		gold -= cost
	roll_shop()
	return true

func level_up() -> bool:
	if not Economy.can_level_up(level, gold):
		return false
	gold -= Economy.level_up_cost(level)
	level += 1
	return true

## 手牌上场：空位放置（合体区就是前 4 格，交给 UI 高亮）
func place(hand_index: int, slot: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
		return false
	if slot < 0 or slot >= BOARD_SLOTS or board[slot] != null:
		return false
	board[slot] = hand[hand_index]
	hand.remove_at(hand_index)
	return true

func sell(slot: int) -> bool:
	if slot < 0 or slot >= BOARD_SLOTS or board[slot] == null:
		return false
	gold += buy_cost(board[slot])
	board[slot] = null
	return true

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

func has_formation() -> bool:
	return Fusion.find_formation(board) >= 0

## 合体准备（开打前调用）：返回替换后的棋盘 + 协同随从 + 带入的维修护甲
func prepare_fusion(mech_level: int = 0, mag_t: int = 0, mech_repair: int = 0) -> Dictionary:
	var res := Fusion.prepare(board, mech_level, mag_t, mech_repair)
	if bool(res.get("ok", false)):
		board = res["board"]
	return res

## 磁力喂料：把手牌里的材料牌喂给棋盘上的机械
func feed(hand_index: int, slot: int, state: Dictionary = {}) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false}
	if slot < 0 or slot >= BOARD_SLOTS or board[slot] == null:
		return {"ok": false}
	var mat: Dictionary = hand[hand_index]
	if not mat.has("magA") and not mat.has("magH"):
		return {"ok": false, "reason": "not_material"}
	var gained := Prep.magnet_feed(mat, board[slot], board, state)
	hand.remove_at(hand_index)
	return {"ok": true, "gained": gained, "target": board[slot]}
