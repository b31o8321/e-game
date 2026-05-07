## DictationSpice — 英语 · 听写法术
##
## 播放 target_word 音频 → 玩家拼写 → 比对（小写） → 成功则反伤 counter_damage。
##
## 详见: docs/superpowers/specs/2026-05-04-battle-system-redesign.md
class_name DictationSpice extends "res://src/battle/spices/subject_spice_base.gd"


@export var target_word: String = ""
@export var counter_damage: int = 25
## 音频路径（可选）；若为空，UI 层可走 TTS 兜底
@export var audio_path: String = ""

const _UI_SCENE: PackedScene = preload("res://src/content/english/spices/dictation_ui.tscn")


func get_id() -> String:
	return "dictation"


func get_display_name() -> String:
	return "听写法术"


func get_description() -> String:
	return "听音拼写；成功则反弹伤害给敌人"


func get_ui_scene() -> PackedScene:
	return _UI_SCENE


## evaluate 接受用户输入字符串；小写比对。
func evaluate(input_data) -> SpiceResult:
	var user_input: String = ""
	if input_data is String:
		user_input = input_data
	elif input_data is Dictionary and input_data.has("input"):
		user_input = str(input_data["input"])

	var normalized_user: String = user_input.strip_edges().to_lower()
	var normalized_target: String = target_word.strip_edges().to_lower()

	if not normalized_target.is_empty() and normalized_user == normalized_target:
		return SpiceResult.make(true, 1.0, {"counter_attack": counter_damage})
	return SpiceResult.make(false, 0.0, {})
