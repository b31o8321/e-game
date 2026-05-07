extends GutTest

const StubTtsBackend = preload("res://src/voice/stub_tts_backend.gd")
const StubSttBackend = preload("res://src/voice/stub_stt_backend.gd")

func test_stub_tts_is_available():
	assert_true(StubTtsBackend.new().is_available())

func test_stub_tts_id():
	assert_eq(StubTtsBackend.new().get_id(), "stub_tts")

func test_stub_tts_synthesize_returns_silent_stream():
	var b = StubTtsBackend.new()
	var stream = await b.synthesize("hello")
	assert_not_null(stream)
	assert_true(stream is AudioStreamWAV)

func test_stub_stt_is_available():
	assert_true(StubSttBackend.new().is_available())

func test_stub_stt_returns_target_phrase():
	var b = StubSttBackend.new()
	b.target_phrase_hint = "I am strong"
	var t = await b.transcribe(null)
	assert_eq(t, "I am strong")
