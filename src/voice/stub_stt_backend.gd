## STT 兜底：直接返回目标短语（dev mode 走成功路径）
class_name StubSttBackend extends IVoiceSttBackend

var target_phrase_hint: String = ""

func is_available() -> bool:
	return true

func get_id() -> String:
	return "stub_stt"

func transcribe(_audio: AudioStream, _lang: String = "en") -> String:
	return target_phrase_hint
