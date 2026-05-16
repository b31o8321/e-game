## Boon — 一次性增益（rest 节点抽，立刻生效）
##
## effect_type 枚举：
##   heal_now           — 立即回血 magnitude HP
##   max_hp_up          — max_hp 永久 +magnitude（同时回 magnitude 血）
##   crystal_now        — 立刻 crystals_collected +magnitude
##   ap_bonus_next_turn — 下回合 AP 上限 +magnitude
##   extra_relic        — 立刻随机赠送 magnitude 个未装备 relic
##   deck_polish_dmg    — 库内所有 base_damage > 0 的卡 base_damage +magnitude
class_name Boon extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var effect_type: String = ""
@export var magnitude: int = 0
@export var icon: String = "🎁"
