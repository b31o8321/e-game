## Relic — 遗物数据模型（Run 内装备，提供被动增益）
##
## effect_type 枚举：
##   damage_boost       — 每次攻击基础伤害 +magnitude
##   heal_per_turn      — 每回合结束回血 magnitude
##   shield_per_turn    — 每回合开始获得 magnitude 护盾
##   combo_extra_chance — 连击触发额外暴击概率 +magnitude%
##   crystal_bonus      — 战斗结算词晶 +magnitude
##
## 效果生效逻辑在 Slice 2（BattleController）里实现，这里只是数据容器。
class_name Relic extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var effect_type: String = ""  # damage_boost / heal_per_turn / shield_per_turn / combo_extra_chance / crystal_bonus
@export var magnitude: int = 0
@export var icon: String = "🎁"  # emoji
@export var rarity: String = "common"  # common / uncommon / rare
