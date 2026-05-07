extends GutTest

const WhisperCppSttBackend = preload("res://src/voice/whisper_cpp_stt_backend.gd")

func test_id():
	assert_eq(WhisperCppSttBackend.new().get_id(), "whisper_cpp")

func test_not_available_when_binary_missing():
	var b = WhisperCppSttBackend.new()
	b._binary_path_override = "/tmp/nonexistent_whisper"
	assert_false(b.is_available())

func test_transcribe_returns_empty_when_unavailable():
	var b = WhisperCppSttBackend.new()
	b._binary_path_override = "/tmp/nonexistent_whisper"
	var s = await b.transcribe(null)
	assert_eq(s, "")

func test_audio_to_temp_wav():
	var b = WhisperCppSttBackend.new()
	# 伪 stream
	var s = AudioStreamWAV.new()
	s.data = PackedByteArray([0, 0, 0, 0])
	s.mix_rate = 16000
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.stereo = false
	var path = b._write_temp_wav(s)
	assert_true(FileAccess.file_exists(path))
	# Cleanup
	DirAccess.remove_absolute(path)
