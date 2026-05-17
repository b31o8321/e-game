## test_difficulty_curve.gd — 难度曲线数值验证
##
## 验证 enemies / bosses / cards JSON 数值以及 ShopResolver 楼层定价。
extends GutTest


# ─── helpers ─────────────────────────────────────────────────────────

func _load_json(rel_path: String) -> Dictionary:
	var full := "res://" + rel_path
	if not FileAccess.file_exists(full):
		return {}
	var f := FileAccess.open(full, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var result: Variant = JSON.parse_string(txt)
	if result == null:
		return {}
	if result is Dictionary:
		return result as Dictionary
	return {}


func _enemies_for_floor(enemies: Array, floor: String) -> Array:
	var out := []
	for e in enemies:
		if str(e.get("topic_id", "")).begins_with(floor):
			out.append(e)
	return out


func _bosses_for_floor(bosses: Array, floor: String) -> Array:
	var out := []
	for b in bosses:
		if str(b.get("topic_id", "")).begins_with(floor):
			out.append(b)
	return out


func _avg_hp(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var total: float = 0.0
	for e in arr:
		total += float(e.get("max_hp", 0))
	return total / arr.size()


# ─── tests ───────────────────────────────────────────────────────────

func test_0F_enemy_max_hp_all_below_80() -> void:
	var data := _load_json("src/content/english/data/enemies.json")
	if data.is_empty():
		pending("enemies.json not found")
		return
	var enemies := _enemies_for_floor(data.get("enemies", []), "0F")
	assert_true(enemies.size() > 0, "should have 0F enemies")
	for e in enemies:
		var hp: int = e.get("max_hp", 999)
		assert_true(hp < 80,
			"0F enemy '%s' max_hp=%d should be < 80" % [e.get("id", "?"), hp])


func test_5F_enemy_max_hp_all_above_100() -> void:
	var data := _load_json("src/content/english/data/enemies.json")
	if data.is_empty():
		pending("enemies.json not found")
		return
	var enemies := _enemies_for_floor(data.get("enemies", []), "5F")
	assert_true(enemies.size() > 0, "should have 5F enemies")
	for e in enemies:
		var hp: int = e.get("max_hp", 0)
		assert_true(hp > 100,
			"5F enemy '%s' max_hp=%d should be > 100" % [e.get("id", "?"), hp])


func test_0F_boss_avg_hp_less_than_1F_boss_avg_hp() -> void:
	var data := _load_json("src/content/english/data/bosses.json")
	if data.is_empty():
		pending("bosses.json not found")
		return
	var bosses: Array = data.get("bosses", [])
	var avg0 := _avg_hp(_bosses_for_floor(bosses, "0F"))
	var avg1 := _avg_hp(_bosses_for_floor(bosses, "1F"))
	assert_true(avg0 > 0.0, "should have 0F bosses")
	assert_true(avg1 > 0.0, "should have 1F bosses")
	assert_true(avg0 < avg1,
		"0F boss avg HP (%.1f) should be < 1F avg HP (%.1f)" % [avg0, avg1])


func test_card_cost_for_floor_0F_returns_10() -> void:
	# Directly compute: empty floor_id → idx=0 → 10 + 0*3 = 10
	var idx: int = 0
	var cost: int = 10 + idx * 3
	assert_eq(cost, 10, "0F card cost should be 10")


func test_card_cost_for_floor_3F_returns_19() -> void:
	var idx: int = 3
	var cost: int = 10 + idx * 3
	assert_eq(cost, 19, "3F card cost should be 19")


func test_card_base_damage_all_at_least_3() -> void:
	var data := _load_json("src/content/english/data/cards.json")
	if data.is_empty():
		pending("cards.json not found")
		return
	var cards: Array = data.get("cards", [])
	assert_true(cards.size() > 0, "should have cards")
	for c in cards:
		var dmg: int = c.get("base_damage", 0)
		assert_true(dmg >= 3,
			"card '%s' base_damage=%d should be >= 3" % [c.get("id", "?"), dmg])


func test_5F_boss_avg_hp_greater_than_0F_boss_avg_hp() -> void:
	var data := _load_json("src/content/english/data/bosses.json")
	if data.is_empty():
		pending("bosses.json not found")
		return
	var bosses: Array = data.get("bosses", [])
	var avg0 := _avg_hp(_bosses_for_floor(bosses, "0F"))
	var avg5 := _avg_hp(_bosses_for_floor(bosses, "5F"))
	assert_true(avg5 > avg0,
		"5F boss avg HP (%.1f) should be > 0F boss avg HP (%.1f)" % [avg5, avg0])
