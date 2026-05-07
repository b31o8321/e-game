## VoiceClient — TTS/STT 路由 autoload
##
## 启动时按优先级选最佳可用后端：
##   TTS: Piper > LocalMp3Cache > Stub
##   STT: WhisperCpp > Stub
##
## 提供统一调用入口：
##   await VoiceClient.tts("brave")
##   await VoiceClient.stt(audio_stream)
##
## 设置切换：VoiceClient.switch_tts("stub_tts") / switch_stt(...)
extends Node

const PiperTtsBackend = preload("res://src/voice/piper_tts_backend.gd")
const LocalMp3CacheBackend = preload("res://src/voice/local_mp3_cache_backend.gd")
const StubTtsBackend = preload("res://src/voice/stub_tts_backend.gd")
const WhisperCppSttBackend = preload("res://src/voice/whisper_cpp_stt_backend.gd")
const StubSttBackend = preload("res://src/voice/stub_stt_backend.gd")

const TTS_PRIORITY := ["piper", "local_mp3_cache", "stub_tts"]
const STT_PRIORITY := ["whisper_cpp", "stub_stt"]

var tts_backend: IVoiceTtsBackend = null
var stt_backend: IVoiceSttBackend = null

var _all_tts: Dictionary = {}
var _all_stt: Dictionary = {}


func _ready() -> void:
	_init_backends()


func _init_backends() -> void:
	_all_tts = {
		"piper": PiperTtsBackend.new(),
		"local_mp3_cache": LocalMp3CacheBackend.new(),
		"stub_tts": StubTtsBackend.new(),
	}
	_all_stt = {
		"whisper_cpp": WhisperCppSttBackend.new(),
		"stub_stt": StubSttBackend.new(),
	}
	tts_backend = _pick_first_available(_all_tts, TTS_PRIORITY) as IVoiceTtsBackend
	stt_backend = _pick_first_available(_all_stt, STT_PRIORITY) as IVoiceSttBackend


static func _pick_first_available(map: Dictionary, priority: Array) -> RefCounted:
	for id in priority:
		var b = map.get(id, null)
		if b and b.is_available():
			return b
	# 退化到第一个
	for id in priority:
		if map.has(id):
			return map[id]
	return null


func switch_tts(id: String) -> bool:
	if not _all_tts.has(id):
		return false
	tts_backend = _all_tts[id]
	return true


func switch_stt(id: String) -> bool:
	if not _all_stt.has(id):
		return false
	stt_backend = _all_stt[id]
	return true


func tts(text: String, lang: String = "en") -> AudioStream:
	if tts_backend == null:
		return null
	return await tts_backend.synthesize(text, lang)


func stt(audio: AudioStream, lang: String = "en") -> String:
	if stt_backend == null:
		return ""
	return await stt_backend.transcribe(audio, lang)
