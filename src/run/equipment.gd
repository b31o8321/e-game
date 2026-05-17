## Equipment — 装备数据模型（Run 内被动增益）
##
## effect_type 枚举：
##   damage_boost       — 每次攻击基础伤害 +magnitude
##   shield_per_turn    — 每回合开始获得 magnitude 护盾
##   heal_per_turn      — 每回合结束回血 magnitude
##   crystal_bonus      — 战斗结算词晶 +magnitude
##   max_hp_plus        — 起始 max_hp 永久 +magnitude（start_floor 时应用）
##
## 装备按 slot（weapon / shield / ring）各占一格，同时只能装一件。
## 效果消费逻辑由 RunState.get_combined_magnitude + BattleController 钩子完成。
class_name Equipment extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var slot: String = ""  # weapon / shield / ring
@export var effect_type: String = ""  # damage_boost / shield_per_turn / heal_per_turn / crystal_bonus / max_hp_plus
@export var magnitude: int = 0
@export var icon: String = "⚔"
@export var rarity: String = "common"  # common / uncommon / rare
