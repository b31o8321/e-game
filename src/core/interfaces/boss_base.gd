class_name BossBase extends Node

## Boss 唯一标识
@export var boss_id: String = ""
## 最大HP
@export var max_hp: int = 500
## 所属大关
@export var gate_id: String = ""
## 反舒适区：终局 Boss 必须覆盖的子主题 ID 列表（A + B + C）。
## ChallengeSelector 在选 Boss Challenge 时会强制至少覆盖此处所有 sub_topic，
## 漏一个 = 那道题没卡填 = 必受伤。
@export var requires_topic_coverage: Array[String] = []

# ── 通关流程钩子（引擎调用）────────────────────────────────────

## 入场台词（引擎逐句展示）
func get_intro_dialogue() -> Array[String]:
	return []

## 阶段数（1-3），HP阶段触发：2阶段在50% HP，3阶段在66%和33%
func get_phase_count() -> int:
	return 1

## 每阶段开始时调用，可修改 battle_state 中的规则
## phase: 1-based
func on_phase_start(phase: int, battle_state: Dictionary) -> void:
	pass

## 玩家答对时回调
## attack_type: 攻击类型ID
## combo: 当前连击数
## 返回 Boss 的即时反应（空 = 无反应）
func on_player_correct(attack_type: String, combo: int) -> Dictionary:
	return {}

## 玩家答错时回调
## 返回 Boss 的即时反应
func on_player_wrong(attack_type: String) -> Dictionary:
	return {}

## Boss 回合行动（每轮玩家行动后调用）
## battle_state: { player_hp, boss_hp, combo, round, sealed_types }
## 返回 BossAction: { type, value, message }
## type: "damage" | "seal_attack" | "shuffle_options" | "shorten_timer" | "none"
func boss_action(battle_state: Dictionary) -> Dictionary:
	return { "type": "none", "value": 0, "message": "" }

## 死亡台词
func get_defeat_dialogue() -> Array[String]:
	return []
