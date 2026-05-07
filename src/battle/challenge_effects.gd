## ChallengeEffects — 把 ChallengeTemplate.effect_type 翻译成具体战斗结果
##
## 多题面板设计的核心：每道题完成后产生一种效果（伤害 / 回血 / 护盾 / 抽牌 / 加题 ...），
## 玩家在棋盘上看到 3 道题、根据当前回合状况选哪道先解。
##
## 输入：BattleController（用于读 _enemy 等上下文）+ template + 已计算好的 base_damage
## 输出：一个结果 Dictionary，由 BattleController 逐字段应用并发对应信号。
##
## 详见 docs/superpowers/specs/2026-05-04-multi-challenge-board.md（任务 spec）。
class_name ChallengeEffects extends RefCounted


## 把 effect 类型翻译成结果。每字段独立，可叠加（譬如 weakness_strike 同时回护盾）。
##
## 返回的 Dictionary 字段：
##   damage_to_enemy: int       要打的伤害
##   heal_player:     int       要回的血
##   shield_added:    int       要加的护盾
##   cards_drawn:     int       要抽的卡数
##   questions_drawn: int       要给棋盘加的题数
##   modifier:        String    "next_x2" 等修饰符（影响下一题）
static func apply(controller, template: ChallengeTemplate, base_damage: int) -> Dictionary:
	var result := {
		"damage_to_enemy": 0,
		"heal_player": 0,
		"shield_added": 0,
		"cards_drawn": 0,
		"questions_drawn": 0,
		"modifier": "",
	}
	if template == null:
		return result
	var et: String = template.effect_type
	if et == "":
		et = "damage"
	var mag: int = template.effect_magnitude
	match et:
		"damage":
			# mag > 0 时直接用 mag；否则走基础公式（默认）
			if mag > 0:
				result["damage_to_enemy"] = mag
			else:
				result["damage_to_enemy"] = base_damage
		"heal":
			result["heal_player"] = max(1, mag)
		"shield":
			result["shield_added"] = max(1, mag)
		"draw_card":
			result["cards_drawn"] = max(1, mag)
		"draw_question":
			result["questions_drawn"] = max(1, mag)
		"weakness_strike":
			var multi: float = 1.0
			if controller != null and controller._enemy != null:
				var enemy = controller._enemy
				if not enemy.weak_axes.is_empty():
					multi = 1.5
			result["damage_to_enemy"] = int(round(float(base_damage) * multi))
		"combo_boost":
			# 自身仍打基础伤害；同时设置 modifier 让下一题翻倍
			result["damage_to_enemy"] = base_damage
			result["modifier"] = "next_x2"
		_:
			# 未知类型 → 退回 damage 行为
			result["damage_to_enemy"] = base_damage
	return result


## 友好显示名（UI 标签 / 调试用）
static func display_name(effect_type: String) -> String:
	match effect_type:
		"damage", "":
			return "伤害"
		"heal":
			return "回血"
		"shield":
			return "护盾"
		"draw_card":
			return "抽牌"
		"draw_question":
			return "加题"
		"weakness_strike":
			return "弱点强击"
		"combo_boost":
			return "下击翻倍"
	return effect_type


## 友好图标（emoji）
static func icon(effect_type: String) -> String:
	match effect_type:
		"damage", "":
			return "⚔"
		"heal":
			return "💚"
		"shield":
			return "🛡"
		"draw_card":
			return "🎴"
		"draw_question":
			return "📚"
		"weakness_strike":
			return "🔥"
		"combo_boost":
			return "✨"
	return "?"
