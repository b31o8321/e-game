extends GutTest

const PiperTtsBackend = preload("res://src/voice/piper_tts_backend.gd")

func test_id():
	assert_eq(PiperTtsBackend.new().get_id(), "piper")

func test_not_available_when_binary_missing():
	# 假设测试环境没有 piper 二进制
	var b = PiperTtsBackend.new()
	b._binary_path_override = "/tmp/nonexistent_piper"
	assert_false(b.is_available())

func test_synthesize_returns_null_when_unavailable():
	var b = PiperTtsBackend.new()
	b._binary_path_override = "/tmp/nonexistent_piper"
	var stream = await b.synthesize("hello")
	assert_null(stream)

func test_get_cache_path_uses_id_in_key():
	var b = PiperTtsBackend.new()
	var p1 = b.get_cache_path("hello", "en")
	var p2 = b.get_cache_path("hello", "en")
	assert_eq(p1, p2)
	# Different text → different path
	var p3 = b.get_cache_path("world", "en")
	assert_ne(p1, p3)
