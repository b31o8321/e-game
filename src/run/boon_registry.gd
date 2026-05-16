## BoonRegistry — Boon 注册表 + 效果应用器（静态类）
##
## 使用方式：
##   var all := BoonRegistry.get_all()
##   var b   := BoonRegistry.get_by_id("boon_hp_potion")
##   BoonRegistry.apply(boon)
class_name BoonRegistry

# ═══════════════════════════════════════════════════════════════════
# 内部数据表（懒加载单例）
# ═══════════════════════════════════════════════════════════════════

static var _cache: Array[Boon] = []


static func _build() -> void:
	if _cache.size() > 0:
		return

	var defs: Array[Dictionary] = [
		{
			"id": "boon_hp_potion",
			"display_name": "治愈药水",
			"description": "立即回复 20 HP。",
			"effect_type": "heal_now",
			"magnitude": 20,
			"icon": "🍷",
		},
		{
			"id": "boon_vitality",
			"display_name": "生命之源",
			"description": "最大 HP 永久 +15，同时回 15 血。",
			"effect_type": "max_hp_up",
			"magnitude": 15,
			"icon": "❤️",
		},
		{
			"id": "boon_treasure_pouch",
			"display_name": "财宝袋",
			"description": "立刻获得 25 词晶。",
			"effect_type": "crystal_now",
			"magnitude": 25,
			"icon": "💰",
		},
		{
			"id": "boon_ap_charm",
			"display_name": "AP 符",
			"description": "下回合 AP 上限 +1。",
			"effect_type": "ap_bonus_next_turn",
			"magnitude": 1,
			"icon": "⚡",
		},
		{
			"id": "boon_relic_chest",
			"display_name": "遗物宝箱",
			"description": "随机获得 1 个未装备遗物。",
			"effect_type": "extra_relic",
			"magnitude": 1,
			"icon": "📦",
		},
		{
			"id": "boon_polish_stone",
			"display_name": "磨砺石",
			"description": "库内所有攻击卡 base_damage +1。",
			"effect_type": "deck_polish_dmg",
			"magnitude": 1,
			"icon": "⛏",
		},
	]

	for d in defs:
		var b := Boon.new()
		b.id = d["id"]
		b.display_name = d["display_name"]
		b.description = d["description"]
		b.effect_type = d["effect_type"]
		b.magnitude = d["magnitude"]
		b.icon = d["icon"]
		_cache.append(b)


# ═══════════════════════════════════════════════════════════════════
# 公共 API
# ═══════════════════════════════════════════════════════════════════

## 返回全部 6 个 Boon 的副本列表。
static func get_all() -> Array[Boon]:
	_build()
	return _cache.duplicate()


## 按 id 查找；找不到返回 null。
static func get_by_id(id: String) -> Boon:
	_build()
	for b in _cache:
		if b.id == id:
			return b
	return null


# ═══════════════════════════════════════════════════════════════════
# 效果应用器
# ═══════════════════════════════════════════════════════════════════

## 应用 boon 到当前 RunState；返回是否成功。
static func apply(b: Boon) -> bool:
	if b == null:
		return false
	if typeof(RunState) == TYPE_NIL or RunState == null:
		return false
	match b.effect_type:
		"heal_now":
			RunState.player_hp = min(RunState.player_hp + b.magnitude, RunState.player_max_hp)
		"max_hp_up":
			RunState.player_max_hp += b.magnitude
			RunState.player_hp += b.magnitude
		"crystal_now":
			RunState.crystals_collected += b.magnitude
		"ap_bonus_next_turn":
			RunState.ap_bonus_next_turn += b.magnitude
		"extra_relic":
			var pool: Array[Relic] = []
			for r in RelicRegistry.get_all():
				if not RunState.has_relic(r.id):
					pool.append(r)
			pool.shuffle()
			for i in min(b.magnitude, pool.size()):
				RunState.add_relic(pool[i])
		"deck_polish_dmg":
			for c in RunState.current_deck:
				if c != null and c.base_damage > 0:
					c.base_damage += b.magnitude
		_:
			return false
	return true
