## EntityAbility — 实体能力（敌人 / 玩家共享接口）
##
## 抽象敌人特性（自动回血、自给护盾、多动等）和将来玩家技能/装备效果。
## 每个能力声明：触发时机 + 效果 payload。
##
## 触发时机 (trigger):
##   "turn_start"        敌人/玩家回合开始时
##   "turn_end"          回合结束时
##   "on_hp_threshold"   HP 跌破阈值时（一次性）
##   "on_damage_taken"   被攻击时
##   "on_attack"         发起攻击前
##
## 效果类型 (effect):
##   "heal"              N HP
##   "shield"            N 盾
##   "extra_action"      多 N 次行动（敌人 = 多攻；玩家 = 多抽，待后续 hook）
##   "reflect"           反伤 X% 给攻击者
class_name EntityAbility extends Resource

@export var id: String = ""
@export var trigger: String = ""
@export var effect_type: String = ""
@export var magnitude: int = 0
## hp_threshold trigger 用：50 表示 HP 跌到 ≤50% 时触发（一次性）。
@export var threshold: int = 0
@export var description_zh: String = ""
@export var icon: String = "✨"

## 一次性触发标记（如 on_hp_threshold 触发后置 true，整场战斗不再触发）。
var _triggered_once: bool = false


## 是否应在当前阶段触发。
##  state 字典需带：
##    "hp": 当前 HP
##    "max_hp": 最大 HP
func should_trigger(state: Dictionary) -> bool:
	match trigger:
		"turn_start", "turn_end", "on_attack", "on_damage_taken":
			return true
		"on_hp_threshold":
			if _triggered_once:
				return false
			var max_hp_v: int = int(state.get("max_hp", 1))
			if max_hp_v <= 0:
				return false
			var hp_v: int = int(state.get("hp", 0))
			var ratio: float = float(hp_v) / float(max_hp_v)
			return ratio * 100.0 <= float(threshold)
	return false


## 计算效果输出。返回 Dictionary：
##   "healed"           int  +HP
##   "shielded"         int  +Shield
##   "extra_actions"    int  额外行动次数
##   "reflected_damage" int  反伤百分比（调用方按攻击伤害自行换算）
func apply(_target_state: Dictionary) -> Dictionary:
	var result := {
		"healed": 0,
		"shielded": 0,
		"extra_actions": 0,
		"reflected_damage": 0,
	}
	match effect_type:
		"heal":
			result["healed"] = magnitude
		"shield":
			result["shielded"] = magnitude
		"extra_action":
			result["extra_actions"] = magnitude
		"reflect":
			result["reflected_damage"] = magnitude
	return result


## 一次性触发标记（如 on_hp_threshold 用）。
func mark_triggered() -> void:
	_triggered_once = true


func is_triggered_once() -> bool:
	return _triggered_once


## 重置一次性标记（新战斗开始用）
func reset() -> void:
	_triggered_once = false
