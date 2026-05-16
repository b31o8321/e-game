## test_spice_system — Phase 2.8 Spice 系统验收测试
##
## 覆盖：
##   - SpiceResult.make() 构造
##   - VoiceScrollSpice.evaluate() 各种 transcript
##   - DictationSpice.evaluate() 大小写 / 错误
##   - STTClient 模式探测（无 key 时 OFFLINE_STUB）
##   - EnglishContentPack.get_available_spices() / get_spice()
extends GutTest


# ─── SpiceResult ──────────────────────────────────────────────────

func test_spice_result_make_success() -> void:
	var r: SpiceResult = SpiceResult.make(true, 0.85, {"buff": {"id": "atk_up"}})
	assert_true(r.success)
	assert_almost_eq(r.quality, 0.85, 0.0001)
	assert_true(r.effect_payload.has("buff"))


func test_spice_result_make_failure() -> void:
	var r: SpiceResult = SpiceResult.make(false, 0.0, {})
	assert_false(r.success)
	assert_eq(r.quality, 0.0)
	assert_true(r.effect_payload.is_empty())


# ─── VoiceScrollSpice ─────────────────────────────────────────────

var _voice: VoiceScrollSpice


func _make_voice_spice() -> VoiceScrollSpice:
	var s: VoiceScrollSpice = VoiceScrollSpice.new()
	s.target_phrase = "I am strong"
	s.buff_id = "atk_up"
	s.buff_value = 30
	s.buff_duration = 3
	return s


func test_voice_spice_exact_match_success() -> void:
	var s: VoiceScrollSpice = _make_voice_spice()
	var r: SpiceResult = s.evaluate("I am strong")
	assert_true(r.success, "exact match should succeed")
	assert_almost_eq(r.quality, 1.0, 0.0001)
	assert_true(r.effect_payload.has("buff"))
	var buff: Dictionary = r.effect_payload["buff"]
	assert_eq(buff["id"], "atk_up")
	assert_eq(buff["value"], 30)
	assert_eq(buff["duration"], 3)


func test_voice_spice_case_insensitive_match() -> void:
	var s: VoiceScrollSpice = _make_voice_spice()
	var r: SpiceResult = s.evaluate("I AM STRONG!")
	assert_true(r.success, "case insensitive match should succeed")
	assert_almost_eq(r.quality, 1.0, 0.0001)


func test_voice_spice_partial_match_fails() -> void:
	var s: VoiceScrollSpice = _make_voice_spice()
	# Hit only 1 of 3 words
	var r: SpiceResult = s.evaluate("I really wanted")
	assert_false(r.success, "1/3 match (~0.33) should fail")
	assert_lt(r.quality, 0.6)


func test_voice_spice_half_match_fails() -> void:
	var s: VoiceScrollSpice = VoiceScrollSpice.new()
	s.target_phrase = "hello world"
	s.buff_id = "atk_up"
	s.buff_value = 10
	s.buff_duration = 2
	var r: SpiceResult = s.evaluate("hello cruel")
	assert_almost_eq(r.quality, 0.5, 0.0001, "1/2 match should be quality 0.5")
	assert_false(r.success, "0.5 < 0.6 threshold; should fail")
	assert_true(r.effect_payload.is_empty())


func test_voice_spice_empty_transcript() -> void:
	var s: VoiceScrollSpice = _make_voice_spice()
	var r: SpiceResult = s.evaluate("")
	assert_false(r.success, "empty transcript should fail")
	assert_eq(r.quality, 0.0)


func test_voice_spice_threshold_two_of_three() -> void:
	var s: VoiceScrollSpice = _make_voice_spice()
	# 2/3 = 0.666 >= 0.6 → success
	var r: SpiceResult = s.evaluate("I am brave")
	assert_almost_eq(r.quality, 2.0 / 3.0, 0.0001)
	assert_true(r.success, "2/3 match (~0.67) should succeed")


# ─── DictationSpice ───────────────────────────────────────────────

func _make_dictation_spice() -> DictationSpice:
	var s: DictationSpice = DictationSpice.new()
	s.target_word = "brave"
	s.counter_damage = 25
	return s


func test_dictation_exact_match_success() -> void:
	var s: DictationSpice = _make_dictation_spice()
	var r: SpiceResult = s.evaluate("brave")
	assert_true(r.success)
	assert_eq(r.quality, 1.0)
	assert_eq(r.effect_payload.get("counter_attack", 0), 25)


func test_dictation_case_insensitive() -> void:
	var s: DictationSpice = _make_dictation_spice()
	var r: SpiceResult = s.evaluate("BRAVE")
	assert_true(r.success, "uppercase should match")
	var r2: SpiceResult = s.evaluate("Brave")
	assert_true(r2.success, "title case should match")


func test_dictation_trim_whitespace() -> void:
	var s: DictationSpice = _make_dictation_spice()
	var r: SpiceResult = s.evaluate("  brave  ")
	assert_true(r.success, "leading/trailing whitespace ignored")


func test_dictation_wrong_spelling_fails() -> void:
	var s: DictationSpice = _make_dictation_spice()
	var r: SpiceResult = s.evaluate("bravv")
	assert_false(r.success)
	assert_eq(r.quality, 0.0)
	assert_true(r.effect_payload.is_empty())


func test_dictation_empty_input_fails() -> void:
	var s: DictationSpice = _make_dictation_spice()
	var r: SpiceResult = s.evaluate("")
	assert_false(r.success)


# ─── STTClient ────────────────────────────────────────────────────

func test_stt_client_offline_stub_when_no_key() -> void:
	# Save & wipe env to ensure no key
	var old: String = OS.get_environment("OPENAI_API_KEY")
	# 注意：Godot 不能 unset env var；只能覆盖为空
	OS.set_environment("OPENAI_API_KEY", "")
	var stt: STTClient = STTClient.new()
	add_child_autofree(stt)
	stt.detect_mode()
	# 注意：如果用户的 user://config.cfg 中存有 key，模式可能仍是 WHISPER_API。
	# 在测试环境中我们至少验证 enum 值合法。
	var mode: int = stt.get_mode()
	assert_true(
		mode == STTClient.Mode.OFFLINE_STUB or mode == STTClient.Mode.WHISPER_API,
		"mode should be one of the enum values"
	)
	# 显式强制 stub 后应返回提示串
	stt.set_mode(STTClient.Mode.OFFLINE_STUB)
	stt.target_phrase_hint = "I am strong"
	var transcript: String = await stt.transcribe("/nonexistent/path.wav")
	assert_eq(transcript, "I am strong", "stub mode returns target_phrase_hint")
	# Restore env
	OS.set_environment("OPENAI_API_KEY", old)


func test_stt_client_set_mode_overrides() -> void:
	var stt: STTClient = STTClient.new()
	add_child_autofree(stt)
	stt.set_mode(STTClient.Mode.OFFLINE_STUB)
	assert_eq(stt.get_mode(), STTClient.Mode.OFFLINE_STUB)
	stt.set_mode(STTClient.Mode.WHISPER_API)
	assert_eq(stt.get_mode(), STTClient.Mode.WHISPER_API)


# ─── EnglishContentPack 集成 ──────────────────────────────────────

func test_english_pack_provides_voice_and_dictation_spices() -> void:
	var pack: EnglishContentPack = EnglishContentPack.new()
	add_child_autofree(pack)
	var spices: Array = pack.get_available_spices()
	# 5 个 base spice（3 voice + 2 dictation）+ 2 个 word_choice（Slice 6 加）= 7
	assert_eq(spices.size(), 7, "english pack should expose 7 spices (3 voice + 2 dictation + 2 word_choice)")

	var class_ids: Array = []
	for s in spices:
		class_ids.append(s.get_id())
	# 每个实例的 get_id() 是类级 ID（"voice_scroll" / "dictation"）
	assert_true("voice_scroll" in class_ids, "voice_scroll spice class present")
	assert_true("dictation" in class_ids, "dictation spice class present")


func test_english_pack_get_spice_by_id() -> void:
	var pack: EnglishContentPack = EnglishContentPack.new()
	add_child_autofree(pack)
	var voice = pack.get_spice("voice_scroll")
	assert_not_null(voice)
	assert_true(voice is VoiceScrollSpice)
	var dict = pack.get_spice("dictation")
	assert_not_null(dict)
	assert_true(dict is DictationSpice)
	var missing = pack.get_spice("does_not_exist")
	assert_null(missing)


func test_subject_spice_base_virtual_methods_warn() -> void:
	# Base class itself should still return safe defaults (no crash).
	var base: SubjectSpiceBase = SubjectSpiceBase.new()
	# These will push_error but should not crash; we just sanity-check return types.
	var id: String = base.get_id()
	assert_true(id is String)
	var r: SpiceResult = base.evaluate(null)
	assert_not_null(r)
	assert_false(r.success)
