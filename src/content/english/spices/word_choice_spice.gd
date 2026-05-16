## WordChoiceSpice — 英语 · 选词法术
##
## 玩家面对一个中文释义，从 4 个英文候选词里选对的那个 → 成功则给敌人 deal extra damage。
##
## evaluate(input_data):
##   - input_data 是 String（玩家选的 word）或 Dict{"choice": String}
##   - 与 target_word 小写比对
##   - 命中 → SpiceResult(true, 1.0, {extra_damage: damage_bonus})
##   - 错 → SpiceResult(false, 0.0, {})
##
## 适合不愿张嘴朗读 / 拼写 不熟的玩家——以纯认知挑战提供 spice 多样性。
class_name WordChoiceSpice extends "res://src/battle/spices/subject_spice_base.gd"


@export var target_word: String = ""
@export var prompt_meaning: String = ""  # 中文释义（UI 显示）
@export var choices: Array[String] = []  # 4 个英文候选；包含 target_word
@export var damage_bonus: int = 20


func get_id() -> String:
	return "word_choice"


func get_display_name() -> String:
	return "选词法术"


func get_description() -> String:
	return "从 4 个候选词里挑出释义对应的那个；命中给敌人额外伤害"


## evaluate 接受玩家选择的字符串；小写比对。
func evaluate(input_data) -> SpiceResult:
	var user_choice: String = ""
	if input_data is String:
		user_choice = input_data
	elif input_data is Dictionary and input_data.has("choice"):
		user_choice = str(input_data["choice"])

	var normalized_user: String = user_choice.strip_edges().to_lower()
	var normalized_target: String = target_word.strip_edges().to_lower()

	if not normalized_target.is_empty() and normalized_user == normalized_target:
		return SpiceResult.make(true, 1.0, {"extra_damage": damage_bonus})
	return SpiceResult.make(false, 0.0, {})
