## test_shop_resolver.gd — ShopResolver 内部纯逻辑测试
##
## 测试 _try_buy_relic / _try_buy_card helpers（不实例化 GUI）。
## 6 个核心断言：
##   1. 词晶不足时 _try_buy_relic 返 false，不扣词晶，不装备
##   2. 词晶足时 _try_buy_relic 返 true，扣词晶，装备遗物
##   3. 重复购买同一遗物（has_relic=true）返 false，不二次扣词晶
##   4. common 价格 30 生效
##   5. uncommon 价格 50 生效
##   6. rare 价格 80 生效
extends GutTest


# ─── helpers ──────────────────────────────────────────────────────

func _make_relic(id: String, rarity: String) -> Relic:
	var r := Relic.new()
	r.id = id
	r.display_name = id
	r.effect_type = "damage_boost"
	r.magnitude = 1
	r.rarity = rarity
	r.icon = "🔮"
	r.description = "test relic"
	return r


func _make_card(word: String) -> Card:
	var c := Card.new()
	c.text = word
	return c


func _rs_available() -> bool:
	return typeof(RunState) != TYPE_NIL and RunState != null


# ─── setup / teardown ─────────────────────────────────────────────

func after_each() -> void:
	if _rs_available():
		RunState.equipped_relics = []
		RunState.crystals_collected = 0
		RunState.current_deck = []


# ═══════════════════════════════════════════════════════════════════
# _try_buy_relic 测试
# ═══════════════════════════════════════════════════════════════════

func test_buy_relic_insufficient_crystals_returns_false() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 10   # common 需 30
	var relic := _make_relic("relic_test_common_a", "common")
	var result := ShopResolver._try_buy_relic(relic)
	assert_false(result, "should return false when crystals < price")
	assert_eq(RunState.crystals_collected, 10, "crystals should be unchanged")
	assert_false(RunState.has_relic("relic_test_common_a"), "relic should not be equipped")


func test_buy_relic_sufficient_crystals_returns_true() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 50
	var relic := _make_relic("relic_test_common_b", "common")
	var result := ShopResolver._try_buy_relic(relic)
	assert_true(result, "should return true when crystals >= price")
	assert_eq(RunState.crystals_collected, 20, "should deduct 30 for common")
	assert_true(RunState.has_relic("relic_test_common_b"), "relic should be equipped")


func test_buy_relic_duplicate_returns_false() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 200
	var relic := _make_relic("relic_test_dup", "common")
	# 第一次购买
	ShopResolver._try_buy_relic(relic)
	var crystals_after_first := RunState.crystals_collected
	# 第二次购买同一遗物
	var result := ShopResolver._try_buy_relic(relic)
	assert_false(result, "duplicate buy should return false (has_relic guard)")
	assert_eq(RunState.crystals_collected, crystals_after_first,
		"crystals should not be deducted on duplicate buy")


# ═══════════════════════════════════════════════════════════════════
# 价格 rarity 覆盖
# ═══════════════════════════════════════════════════════════════════

func test_common_relic_costs_30() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 30
	var relic := _make_relic("relic_price_common", "common")
	ShopResolver._try_buy_relic(relic)
	assert_eq(RunState.crystals_collected, 0, "common relic should cost exactly 30")


func test_uncommon_relic_costs_50() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 80
	var relic := _make_relic("relic_price_uncommon", "uncommon")
	ShopResolver._try_buy_relic(relic)
	assert_eq(RunState.crystals_collected, 30, "uncommon relic should cost exactly 50")


func test_rare_relic_costs_80() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 100
	var relic := _make_relic("relic_price_rare", "rare")
	ShopResolver._try_buy_relic(relic)
	assert_eq(RunState.crystals_collected, 20, "rare relic should cost exactly 80")


# ═══════════════════════════════════════════════════════════════════
# _try_buy_card 测试
# ═══════════════════════════════════════════════════════════════════

func test_buy_card_insufficient_crystals_returns_false() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 5   # CARD_COST = 10
	var card := _make_card("test_word")
	var result := ShopResolver._try_buy_card(card, 3)
	assert_false(result, "should return false when crystals < CARD_COST")
	assert_eq(RunState.crystals_collected, 5, "crystals should be unchanged")
	assert_eq(RunState.current_deck.size(), 0, "card should not be added to deck")


func test_buy_card_sufficient_crystals_adds_to_deck() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 20
	var card := _make_card("hello")
	var result := ShopResolver._try_buy_card(card, 5)
	assert_true(result, "should return true when crystals >= CARD_COST")
	assert_eq(RunState.crystals_collected, 10, "should deduct 10")
	assert_eq(RunState.current_deck.size(), 1, "card should be in deck")


func test_buy_card_null_returns_false() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 50
	var result := ShopResolver._try_buy_card(null, 3)
	assert_false(result, "null card should return false")
	assert_eq(RunState.crystals_collected, 50, "crystals unchanged")


func test_buy_card_empty_pool_returns_false() -> void:
	if not _rs_available():
		pending("RunState autoload not available")
		return
	RunState.crystals_collected = 50
	var card := _make_card("word")
	var result := ShopResolver._try_buy_card(card, 0)
	assert_false(result, "pool_size=0 should return false")
	assert_eq(RunState.crystals_collected, 50, "crystals unchanged")
