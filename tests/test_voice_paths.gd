extends GutTest

const VoicePaths = preload("res://src/voice/voice_paths.gd")

func test_get_voice_dir_returns_non_empty():
	var p = VoicePaths.get_voice_dir()
	assert_true(p.length() > 0)

func test_get_piper_binary_returns_path_under_voice_dir():
	var p = VoicePaths.get_piper_binary()
	var v = VoicePaths.get_voice_dir()
	assert_true(p.begins_with(v))

func test_get_whisper_binary_returns_path():
	var p = VoicePaths.get_whisper_binary()
	assert_true(p.length() > 0)

func test_get_piper_default_model_path():
	var p = VoicePaths.get_piper_default_model()
	assert_true(p.ends_with(".onnx"))
