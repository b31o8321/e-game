## TTS 后端接口。子类实现：
##   - is_available()  返回是否可用（二进制存在/网络通等）
##   - get_id()        返回唯一标识，例如 "piper" / "stub"
##   - synthesize()    text 合成 AudioStream，async
##   - get_cache_path() 缓存文件路径（sha256(text+lang)）
class_name IVoiceTtsBackend extends RefCounted

func is_available() -> bool:
	return false

func get_id() -> String:
	push_error("IVoiceTtsBackend.get_id() not overridden")
	return ""

## 合成音频；子类必须 override
func synthesize(_text: String, _lang: String = "en") -> AudioStream:
	push_error("IVoiceTtsBackend.synthesize() not overridden")
	return null

func get_cache_path(text: String, lang: String = "en") -> String:
	var key = "%s|%s|%s" % [get_id(), lang, text]
	var hash = key.sha256_text()
	return "user://tts_cache/%s.wav" % hash
