## MasterySystem — 卡片熟练度等级 + 伤害倍率
##
## 反"舒适区刷分"机制的核心：熟练卡伤害衰减、新卡伤害加成。
## 详见 docs/superpowers/specs/2026-05-04-battle-system-redesign.md
## 中"反舒适区刷分机制 → 熟练度伤害衰减"小节。
##
## 阈值（基于 SRSSystem.get_correct_count）：
##   0     → FRESH      ×1.5  🌱
##   1-3   → LEARNING   ×1.3  🌿
##   4-7   → PROFICIENT ×1.0  🌳
##   8+    → MASTERED   ×0.7  ⭐
class_name MasterySystem extends RefCounted


enum MasteryLevel { FRESH, LEARNING, PROFICIENT, MASTERED }


## 根据 SRS 答对次数返回熟练度等级。
## srs 为 null（无统计）时视为 FRESH。
static func get_level(card_id: String, srs: SRSSystem) -> MasteryLevel:
	if srs == null:
		return MasteryLevel.FRESH
	var correct: int = srs.get_correct_count(card_id)
	if correct <= 0:
		return MasteryLevel.FRESH
	elif correct <= 3:
		return MasteryLevel.LEARNING
	elif correct <= 7:
		return MasteryLevel.PROFICIENT
	else:
		return MasteryLevel.MASTERED


## 等级 → 伤害倍率
static func get_multiplier(level: MasteryLevel) -> float:
	match level:
		MasteryLevel.FRESH:
			return 1.5
		MasteryLevel.LEARNING:
			return 1.3
		MasteryLevel.PROFICIENT:
			return 1.0
		MasteryLevel.MASTERED:
			return 0.7
		_:
			return 1.0


## 等级 → 显示用 emoji 图标
static func get_icon(level: MasteryLevel) -> String:
	match level:
		MasteryLevel.FRESH:
			return "🌱"
		MasteryLevel.LEARNING:
			return "🌿"
		MasteryLevel.PROFICIENT:
			return "🌳"
		MasteryLevel.MASTERED:
			return "⭐"
		_:
			return ""


## 等级 → 中文显示名
static func get_display_name(level: MasteryLevel) -> String:
	match level:
		MasteryLevel.FRESH:
			return "新"
		MasteryLevel.LEARNING:
			return "学习中"
		MasteryLevel.PROFICIENT:
			return "熟练"
		MasteryLevel.MASTERED:
			return "掌握"
		_:
			return ""
