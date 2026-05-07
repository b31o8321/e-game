extends GutTest

const LocalMp3CacheBackend = preload("res://src/voice/local_mp3_cache_backend.gd")

func test_id():
	assert_eq(LocalMp3CacheBackend.new().get_id(), "local_mp3_cache")

func test_is_available_when_audio_dir_exists():
	var b = LocalMp3CacheBackend.new()
	# 默认指 res://src/content/english/audio/
	assert_true(b.is_available())

func test_synthesize_existing_word_returns_loaded_stream():
	var b = LocalMp3CacheBackend.new()
	# 假设 cat.mp3 存在
	var stream = await b.synthesize("cat")
	assert_not_null(stream)

func test_synthesize_unknown_word_returns_null():
	var b = LocalMp3CacheBackend.new()
	var stream = await b.synthesize("xyz_doesnt_exist")
	assert_null(stream)

func test_letter_lookup():
	var b = LocalMp3CacheBackend.new()
	var stream = await b.synthesize("a")
	# 'a' is letter, should hit letters/a.mp3
	assert_not_null(stream)
