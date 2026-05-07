## AbilitiesRegistry — 能力 ID → EntityAbility 实例工厂
##
## 战斗 / 装备 / 技能系统统一通过 make(id) 拿到一个全新的 EntityAbility 实例。
## 数据写在静态 _DEFAULT_DATA，方便后续迁出到 JSON。
##
## 使用示例：
##   var a := AbilitiesRegistry.make("regen_2")
##   if a != null and a.should_trigger({"hp": 10, "max_hp": 30}):
##       var r := a.apply({})
##       # r["healed"] == 2
class_name AbilitiesRegistry extends RefCounted


const _DEFAULT_DATA := {
	"regen_2": {
		"trigger": "turn_start",
		"effect_type": "heal",
		"magnitude": 2,
		"description_zh": "每回合自动回血 +2 HP",
		"icon": "💚",
	},
	"regen_3": {
		"trigger": "turn_start",
		"effect_type": "heal",
		"magnitude": 3,
		"description_zh": "每回合自动回血 +3 HP",
		"icon": "💚",
	},
	"shield_each_turn_5": {
		"trigger": "turn_start",
		"effect_type": "shield",
		"magnitude": 5,
		"description_zh": "每回合自给护盾 +5",
		"icon": "🛡",
	},
	"multi_action_2": {
		"trigger": "turn_start",
		"effect_type": "extra_action",
		"magnitude": 1,
		"description_zh": "每回合行动 2 次",
		"icon": "⚡",
	},
	"multi_action_3": {
		"trigger": "turn_start",
		"effect_type": "extra_action",
		"magnitude": 2,
		"description_zh": "每回合行动 3 次",
		"icon": "⚡",
	},
	"shield_at_50": {
		"trigger": "on_hp_threshold",
		"effect_type": "shield",
		"magnitude": 20,
		"threshold": 50,
		"description_zh": "HP ≤ 50% 时一次性获得 +20 盾",
		"icon": "🛡",
	},
	"reflect_25": {
		"trigger": "on_damage_taken",
		"effect_type": "reflect",
		"magnitude": 25,
		"description_zh": "受到伤害时反弹 25%",
		"icon": "🔁",
	},
}


## 已知能力 ID 列表（测试 / 调试用）。
static func known_ids() -> Array[String]:
	var out: Array[String] = []
	for k in _DEFAULT_DATA.keys():
		out.append(str(k))
	return out


## 用 ID 创建一个 EntityAbility。未知 ID 返回 null。
static func make(id: String) -> EntityAbility:
	var data: Dictionary = _DEFAULT_DATA.get(id, {})
	if data.is_empty():
		return null
	var a := EntityAbility.new()
	a.id = id
	a.trigger = str(data.get("trigger", ""))
	a.effect_type = str(data.get("effect_type", ""))
	a.magnitude = int(data.get("magnitude", 0))
	a.threshold = int(data.get("threshold", 0))
	a.description_zh = str(data.get("description_zh", ""))
	a.icon = str(data.get("icon", "✨"))
	return a


## 把一个 ability_ids 列表批量构造为 EntityAbility 实例（跳过未知 ID）。
static func make_many(ids: Array) -> Array[EntityAbility]:
	var out: Array[EntityAbility] = []
	for v in ids:
		var a := make(str(v))
		if a != null:
			out.append(a)
	return out
