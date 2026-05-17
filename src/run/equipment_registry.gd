## EquipmentRegistry — 装备注册表（静态类，12 件起始装备）
##
## 使用方式：
##   var all := EquipmentRegistry.get_all()
##   var eq  := EquipmentRegistry.get_by_id("eq_iron_sword")
##   var weapons := EquipmentRegistry.get_for_slot("weapon")
##
## 各 slot 各 4 件，共 12 件。
class_name EquipmentRegistry

static var _cache: Array[Equipment] = []


static func _build() -> void:
	if _cache.size() > 0:
		return

	var defs: Array[Dictionary] = [
		# ── weapon × 4 ─────────────────────────────────────────────────
		{
			"id": "eq_wooden_sword",
			"display_name": "木剑",
			"description": "每次攻击基础伤害 +1。",
			"slot": "weapon",
			"effect_type": "damage_boost",
			"magnitude": 1,
			"icon": "🗡",
			"rarity": "common",
		},
		{
			"id": "eq_iron_sword",
			"display_name": "铁剑",
			"description": "每次攻击基础伤害 +3。",
			"slot": "weapon",
			"effect_type": "damage_boost",
			"magnitude": 3,
			"icon": "⚔",
			"rarity": "uncommon",
		},
		{
			"id": "eq_crystal_sword",
			"display_name": "魔晶剑",
			"description": "每次攻击基础伤害 +5。",
			"slot": "weapon",
			"effect_type": "damage_boost",
			"magnitude": 5,
			"icon": "💎",
			"rarity": "rare",
		},
		{
			"id": "eq_dictionary",
			"display_name": "词典",
			"description": "每次攻击基础伤害 +2。",
			"slot": "weapon",
			"effect_type": "damage_boost",
			"magnitude": 2,
			"icon": "📖",
			"rarity": "common",
		},
		# ── shield × 4 ─────────────────────────────────────────────────
		{
			"id": "eq_grass_shield",
			"display_name": "草盾",
			"description": "每回合开始获得 1 护盾。",
			"slot": "shield",
			"effect_type": "shield_per_turn",
			"magnitude": 1,
			"icon": "🪨",
			"rarity": "common",
		},
		{
			"id": "eq_iron_shield",
			"display_name": "铁盾",
			"description": "每回合开始获得 3 护盾。",
			"slot": "shield",
			"effect_type": "shield_per_turn",
			"magnitude": 3,
			"icon": "🛡",
			"rarity": "uncommon",
		},
		{
			"id": "eq_magic_mirror",
			"display_name": "魔镜",
			"description": "每回合开始获得 5 护盾。",
			"slot": "shield",
			"effect_type": "shield_per_turn",
			"magnitude": 5,
			"icon": "🪞",
			"rarity": "rare",
		},
		{
			"id": "eq_wooden_shield",
			"display_name": "木盾",
			"description": "每回合结束回血 2。",
			"slot": "shield",
			"effect_type": "heal_per_turn",
			"magnitude": 2,
			"icon": "🌳",
			"rarity": "common",
		},
		# ── ring × 4 ───────────────────────────────────────────────────
		{
			"id": "eq_crystal_ring",
			"display_name": "词晶戒",
			"description": "战斗结算词晶 +2。",
			"slot": "ring",
			"effect_type": "crystal_bonus",
			"magnitude": 2,
			"icon": "💍",
			"rarity": "common",
		},
		{
			"id": "eq_sage_ring",
			"display_name": "智者戒",
			"description": "战斗结算词晶 +5。",
			"slot": "ring",
			"effect_type": "crystal_bonus",
			"magnitude": 5,
			"icon": "🔮",
			"rarity": "uncommon",
		},
		{
			"id": "eq_life_ring",
			"display_name": "生命戒",
			"description": "起始最大 HP +15。",
			"slot": "ring",
			"effect_type": "max_hp_plus",
			"magnitude": 15,
			"icon": "❤️",
			"rarity": "uncommon",
		},
		{
			"id": "eq_ancient_ring",
			"display_name": "古老戒",
			"description": "每次攻击基础伤害 +1，起始最大 HP +10。",
			"slot": "ring",
			"effect_type": "damage_boost",
			"magnitude": 1,
			"icon": "🌀",
			"rarity": "rare",
			# 注：古老戒双效果，damage_boost magnitude=1 + 隐含 max_hp_plus=10
			# 因 Equipment 单 effect_type 字段，max_hp_plus 效果通过 _extra_effect 键实现
			"_extra_effect_type": "max_hp_plus",
			"_extra_magnitude": 10,
		},
	]

	for d in defs:
		var eq := Equipment.new()
		eq.id = d["id"]
		eq.display_name = d["display_name"]
		eq.description = d["description"]
		eq.slot = d["slot"]
		eq.effect_type = d["effect_type"]
		eq.magnitude = d["magnitude"]
		eq.icon = d["icon"]
		eq.rarity = d["rarity"]
		_cache.append(eq)


# ═══════════════════════════════════════════════════════════════════
# 公共 API
# ═══════════════════════════════════════════════════════════════════

## 返回全部 12 件装备（稳定顺序）。
static func get_all() -> Array[Equipment]:
	_build()
	return _cache.duplicate()


## 按 id 查找装备；找不到返回 null。
static func get_by_id(id: String) -> Equipment:
	_build()
	for eq in _cache:
		if eq.id == id:
			return eq
	return null


## 按 slot 过滤（weapon / shield / ring）。
static func get_for_slot(slot: String) -> Array[Equipment]:
	_build()
	var out: Array[Equipment] = []
	for eq in _cache:
		if eq.slot == slot:
			out.append(eq)
	return out
