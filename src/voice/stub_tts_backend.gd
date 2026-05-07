## 静音 TTS 兜底：无法获取真实音频时返回 0.5 秒静音流
class_name StubTtsBackend extends IVoiceTtsBackend

func is_available() -> bool:
	return true

func get_id() -> String:
	return "stub_tts"

func synthesize(_text: String, _lang: String = "en") -> AudioStream:
	var stream = AudioStreamWAV.new()
	# 0.5 秒 22050Hz mono 静音
	var samples := PackedByteArray()
	samples.resize(22050 * 2 / 2)  # 0.5s
	samples.fill(0)
	stream.data = samples
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	return stream
