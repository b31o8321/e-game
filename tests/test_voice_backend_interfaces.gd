extends GutTest

const IVoiceTtsBackend = preload("res://src/voice/i_voice_tts_backend.gd")
const IVoiceSttBackend = preload("res://src/voice/i_voice_stt_backend.gd")

func test_tts_base_class_has_required_methods():
	var b = IVoiceTtsBackend.new()
	assert_has_method(b, "is_available")
	assert_has_method(b, "get_id")
	assert_has_method(b, "synthesize")
	assert_has_method(b, "get_cache_path")

func test_stt_base_class_has_required_methods():
	var b = IVoiceSttBackend.new()
	assert_has_method(b, "is_available")
	assert_has_method(b, "get_id")
	assert_has_method(b, "transcribe")
