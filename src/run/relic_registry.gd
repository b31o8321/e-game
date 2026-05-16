## RelicRegistry — 遗物注册表（静态类，提供全局 10 个起始遗物）
##
## 使用方式：
##   var all := RelicRegistry.get_all()
##   var r   := RelicRegistry.get_by_id("relic_word_amulet")
##
## 效果生效逻辑在 Slice 2 实现；此处只管数据。
class_name RelicRegistry

# ═══════════════════════════════════════════════════════════════════
# 内部数据表（懒加载单例，避免重复构建）
# ═══════════════════════════════════════════════════════════════════

static var _cache: Array[Relic] = []


static func _build() -> void:
	if _cache.size() > 0:
		return

	var defs: Array[Dictionary] = [
		# ── damage_boost ──────────────────────────────────────────────
		{
			"id": "relic_word_amulet",
			"display_name": "词晶护符",
			"description": "每次攻击基础伤害 +2。",
			"effect_type": "damage_boost",
			"magnitude": 2,
			"icon": "📿",
			"rarity": "common",
		},
		{
			"id": "relic_blaze_emblem",
			"display_name": "火焰徽章",
			"description": "每次攻击基础伤害 +4。",
			"effect_type": "damage_boost",
			"magnitude": 4,
			"icon": "🔥",
			"rarity": "uncommon",
		},
		{
			"id": "relic_fist_of_war",
			"display_name": "战神之拳",
			"description": "每次攻击基础伤害 +6。",
			"effect_type": "damage_boost",
			"magnitude": 6,
			"icon": "👊",
			"rarity": "rare",
		},
		# ── heal_per_turn ─────────────────────────────────────────────
		{
			"id": "relic_light_of_knowledge",
			"display_name": "知识之光",
			"description": "每回合结束回血 3。",
			"effect_type": "heal_per_turn",
			"magnitude": 3,
			"icon": "💡",
			"rarity": "common",
		},
		{
			"id": "relic_holy_brooch",
			"display_name": "圣光胸针",
			"description": "每回合结束回血 5。",
			"effect_type": "heal_per_turn",
			"magnitude": 5,
			"icon": "✨",
			"rarity": "uncommon",
		},
		# ── shield_per_turn ───────────────────────────────────────────
		{
			"id": "relic_guardian_wall",
			"display_name": "守护铁壁",
			"description": "每回合开始获得 2 护盾。",
			"effect_type": "shield_per_turn",
			"magnitude": 2,
			"icon": "🛡️",
			"rarity": "common",
		},
		{
			"id": "relic_silence_seal",
			"display_name": "静默符",
			"description": "每回合开始获得 5 护盾。",
			"effect_type": "shield_per_turn",
			"magnitude": 5,
			"icon": "🔒",
			"rarity": "uncommon",
		},
		# ── combo_extra_chance ────────────────────────────────────────
		{
			"id": "relic_combo_string",
			"display_name": "连击之弦",
			"description": "连击触发额外暴击概率 +15%。",
			"effect_type": "combo_extra_chance",
			"magnitude": 15,
			"icon": "🎵",
			"rarity": "common",
		},
		# ── crystal_bonus ─────────────────────────────────────────────
		{
			"id": "relic_merchant_ring",
			"display_name": "商人指环",
			"description": "战斗结算词晶 +2。",
			"effect_type": "crystal_bonus",
			"magnitude": 2,
			"icon": "💍",
			"rarity": "common",
		},
		{
			"id": "relic_scholar_mirror",
			"display_name": "学者镜",
			"description": "战斗结算词晶 +5。",
			"effect_type": "crystal_bonus",
			"magnitude": 5,
			"icon": "🪞",
			"rarity": "uncommon",
		},
	]

	for d in defs:
		var r := Relic.new()
		r.id = d["id"]
		r.display_name = d["display_name"]
		r.description = d["description"]
		r.effect_type = d["effect_type"]
		r.magnitude = d["magnitude"]
		r.icon = d["icon"]
		r.rarity = d["rarity"]
		_cache.append(r)


# ═══════════════════════════════════════════════════════════════════
# 公共 API
# ═══════════════════════════════════════════════════════════════════

## 返回全部 10 个起始遗物的副本列表（保证顺序稳定）。
static func get_all() -> Array[Relic]:
	_build()
	return _cache.duplicate()


## 按 id 查找遗物；找不到返回 null。
static func get_by_id(id: String) -> Relic:
	_build()
	for r in _cache:
		if r.id == id:
			return r
	return null
