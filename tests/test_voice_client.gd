extends GutTest

const VoiceClientScript = preload("res://src/voice/voice_client.gd")

func _make_client() -> Node:
	var c = VoiceClientScript.new()
	add_child_autofree(c)
	return c

func test_default_backends_picked():
	var c = _make_client()
	c._init_backends()
	assert_not_null(c.tts_backend)
	assert_not_null(c.stt_backend)

func test_tts_falls_back_to_local_then_stub():
	var c = _make_client()
	c._init_backends()
	# 在大多数 dev 环境下，piper 没装 → 应退到 local_mp3_cache 或 stub
	var ids = ["piper", "local_mp3_cache", "stub_tts"]
	assert_true(c.tts_backend.get_id() in ids)

func test_switch_backend_replaces_active():
	var c = _make_client()
	c._init_backends()
	c.switch_tts("stub_tts")
	assert_eq(c.tts_backend.get_id(), "stub_tts")

func test_tts_returns_audio_stream():
	var c = _make_client()
	c._init_backends()
	c.switch_tts("stub_tts")
	var stream = await c.tts("hello")
	assert_not_null(stream)
