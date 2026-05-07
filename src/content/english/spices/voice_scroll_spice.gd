## VoiceScrollSpice — 英语 · 口语卷轴
##
## 玩家朗读 target_phrase；通过 STT 识别 → 计算匹配质量 → 成功则附加 buff。
##
## 评估算法（MVP）：
##   - 按空格切分 target_phrase 为单词集合
##   - 对每个 target 单词：在 transcript 中（小写、去标点）出现 → 命中 +1
##   - quality = 命中数 / 目标单词总数
##   - success = quality >= 0.6
##
## 详见: docs/superpowers/specs/2026-05-04-battle-system-redesign.md
class_name VoiceScrollSpice extends "res://src/battle/spices/subject_spice_base.gd"


@export var target_phrase: String = ""
@export var buff_id: String = "atk_up"
@export var buff_value: int = 30
@export var buff_duration: int = 3

const SUCCESS_THRESHOLD: float = 0.6

const _UI_SCENE: PackedScene = preload("res://src/content/english/spices/voice_scroll_ui.tscn")


func get_id() -> String:
	return "voice_scroll"


func get_display_name() -> String:
	return "口语卷轴"


func get_description() -> String:
	return "朗读卷轴上的短语；成功则获得攻击 BUFF"


func get_ui_scene() -> PackedScene:
	return _UI_SCENE


## evaluate 接受识别出的 transcript 字符串，计算匹配质量。
func evaluate(input_data) -> SpiceResult:
	var transcript: String = ""
	if input_data is String:
		transcript = input_data
	elif input_data is Dictionary and input_data.has("transcript"):
		transcript = str(input_data["transcript"])

	var quality: float = _compute_match_quality(target_phrase, transcript)
	var ok: bool = quality >= SUCCESS_THRESHOLD
	var payload: Dictionary = {}
	if ok:
		payload = {
			"buff": {
				"id": buff_id,
				"value": buff_value,
				"duration": buff_duration,
			}
		}
	return SpiceResult.make(ok, quality, payload)


# ─── 内部：模糊匹配 ────────────────────────────────────────────────

static func _compute_match_quality(target: String, transcript: String) -> float:
	var tgt_words: Array[String] = _tokenize(target)
	if tgt_words.is_empty():
		return 0.0
	var tr_words: Array[String] = _tokenize(transcript)
	if tr_words.is_empty():
		return 0.0
	var hits: int = 0
	for w in tgt_words:
		if w in tr_words:
			hits += 1
	return float(hits) / float(tgt_words.size())


static func _tokenize(s: String) -> Array[String]:
	var out: Array[String] = []
	if s.is_empty():
		return out
	# 小写 + 用正则去除非字母数字（保留空格）
	var lower: String = s.to_lower()
	var regex: RegEx = RegEx.new()
	regex.compile("[^a-z0-9\\s']")
	var clean: String = regex.sub(lower, " ", true)
	for w in clean.split(" ", false):
		var t: String = w.strip_edges()
		if not t.is_empty():
			out.append(t)
	return out
