## 解析 voice 二进制 + 模型路径
##
## 编辑器/headless：res://builds/voice/...
## 打包后 macOS：app/Contents/Resources/voice/...
## 打包后 Win/Linux：exe 同级 voice/...
class_name VoicePaths extends RefCounted

const PIPER_BINARY := "piper/piper"
const PIPER_DEFAULT_MODEL := "piper/models/en_US-lessac-medium.onnx"
const WHISPER_BINARY := "whisper/whisper-cli"
const WHISPER_DEFAULT_MODEL := "whisper/models/ggml-tiny.en.bin"


static func get_voice_dir() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://builds/voice/")
	var exe_dir := OS.get_executable_path().get_base_dir()
	if OS.get_name() == "macOS":
		return exe_dir.path_join("../Resources/voice/")
	return exe_dir.path_join("voice/")


static func _join(rel: String) -> String:
	return get_voice_dir().path_join(rel)


static func get_piper_binary() -> String:
	return _join(PIPER_BINARY)


static func get_piper_default_model() -> String:
	return _join(PIPER_DEFAULT_MODEL)


static func get_whisper_binary() -> String:
	return _join(WHISPER_BINARY)


static func get_whisper_default_model() -> String:
	return _join(WHISPER_DEFAULT_MODEL)
