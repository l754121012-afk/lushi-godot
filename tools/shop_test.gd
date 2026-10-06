extends SceneTree
## 商店生成自检：godot --headless --path <项目> --script res://tools/shop_test.gd

const Shop := preload("res://sim/shop.gd")
var fails: Array[String] = []

func _init() -> void:
	_case_star_odds()
	_case_race_filter()
	_case_slots_and_repeatable()
	_case_no_offrace_fallback()
	_case_race_bias()
	if fails.is_empty():
		print("[shop_test] 通过：星级概率 / 种族池过滤 / 商店结构 / 无越界兜底 / 主族软偏向 5/5")
		quit(0)
	else:
		for f in fails:
			printerr("[shop_test] 失败：", f)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)

func _pool() -> Dictionary:
	var pool := {}
	for star in range(1, 8):
		var list: Array = []
		for i in range(10):
			list.append({"n": "T%d-%d" % [star, i], "a": star, "h": star, "race": "mech" if i % 2 == 0 else "elem"})
		list.append({"n": "中立%d" % star, "a": star, "h": star})
		pool[star] = list
	return pool

func _case_star_odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var seen := {}
	for i in range(400):
		seen[Shop.roll_star(1, rng)] = true
	var ok := true
	for s in seen.keys():
		if int(s) < 1 or int(s) > 7:
			ok = false
	_check(ok, "抽出的星级应在 1-7 之间")
	_check(seen.size() >= 1, "应至少抽到 1 个星级")
	print("[shop_test] 用例1 星级概率: 400 次抽到星级集合=", seen.keys())

func _case_race_filter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var pool := _pool()
	var races := ["mech"]
	var bad := 0
	for i in range(200):
		var c := Shop.roll_card(3, races, rng, pool)
		var race := String(c.get("race", ""))
		if race != "" and race != "mech":
			bad += 1
	_check(bad == 0, "种族池过滤失效：%d 张非本局种族" % bad)
	print("[shop_test] 用例2 种族过滤: 200 张中越界=", bad)

func _case_slots_and_repeatable() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var shop := Shop.roll_shop(3, ["mech", "elem"], rng, _pool(), [], 5)
	_check(shop.size() == 5, "商店应有 5 格，实际 %d" % shop.size())
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var shop2 := Shop.roll_shop(3, ["mech", "elem"], rng2, _pool(), [], 5)
	var same := true
	for i in range(min(shop.size(), shop2.size())):
		if String(shop[i].get("n", "")) != String(shop2[i].get("n", "")):
			same = false
	_check(same, "同种子应生成同样的商店（可复现）")
	# 法术概率：注入法术池后应能抽到法术格
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 7
	var has_spell := false
	for i in range(50):
		var s := Shop.roll_shop(2, ["mech"], rng3, _pool(), [{"n": "力祝"}], 5)
		for slot in s:
			if String(slot.get("t", "")) == "s":
				has_spell = true
	_check(has_spell, "注入法术池后应能出现法术格")
	print("[shop_test] 用例3 商店结构: 格数=", shop.size(), " 可复现=", same, " 含法术=", has_spell)

func _case_no_offrace_fallback() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260927
	var pool := {
		1: [
			{"n": "献祭者", "a": 1, "h": 1, "race": "sacrifice"},
			{"n": "其他献祭", "a": 1, "h": 1, "race": "sacrifice"},
			{"n": "本局机械", "a": 1, "h": 1, "race": "mech"},
		],
	}
	var bad := 0
	for i in range(500):
		var card := Shop.roll_card(1, ["mech"], rng, pool)
		if String(card.get("race", "")) == "sacrifice":
			bad += 1
	_check(bad == 0, "无献祭种族时仍从越界兜底抽到献祭牌：%d" % bad)
	var only_offrace := {1: [{"n": "献祭者", "a": 1, "h": 1, "race": "sacrifice"}]}
	var empty := Shop.roll_card(1, ["mech"], rng, only_offrace)
	_check(empty.is_empty(), "合法候选为空时应返回空，而不是塞入越界牌")
	print("[shop_test] 用例4 无越界兜底: 500 次越界=", bad, " 仅越界池返回空=", empty.is_empty())

func _case_race_bias() -> void:
	var star_pool: Array = []
	for i in range(5):
		star_pool.append({"n": "机械%d" % i, "a": 3, "h": 3, "race": "mech"})
	for i in range(5):
		star_pool.append({"n": "元素%d" % i, "a": 3, "h": 3, "race": "elem"})
	star_pool.append({"n": "中立", "a": 3, "h": 3})
	var pool := {3: star_pool}
	var base_hits := 0
	var biased_hits := 0
	var samples := 5000
	var base_rng := RandomNumberGenerator.new()
	var biased_rng := RandomNumberGenerator.new()
	base_rng.seed = 3103
	biased_rng.seed = 3103
	for i in range(samples):
		if String(Shop.roll_card(3, ["mech", "elem"], base_rng, pool).get("race", "")) == "mech":
			base_hits += 1
		if String(Shop.roll_card(
				3, ["mech", "elem"], biased_rng, pool, ["mech"], 2.5).get("race", "")) == "mech":
			biased_hits += 1
	var base_rate := float(base_hits) / float(samples)
	var biased_rate := float(biased_hits) / float(samples)
	_check(base_rate > 0.41 and base_rate < 0.50,
		"普通随机机械率应在 45%% 左右，实际 %.2f%%" % (base_rate * 100.0))
	_check(biased_rate > 0.62 and biased_rate < 0.73,
		"×2.5 主族软偏向机械率应在 68%% 左右，实际 %.2f%%" % (biased_rate * 100.0))
	print("[shop_test] 用例5 主族软偏向: 普通=%.2f%% ×2.5=%.2f%%" % [
		base_rate * 100.0, biased_rate * 100.0])
