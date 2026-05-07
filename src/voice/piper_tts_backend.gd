## Piper TTS 后端：通过 OS.execute 调用本地 piper 二进制 + onnx 模型
##
## 用法：
##   var b := PiperTtsBackend.new()
##   if b.is_available():
##     var stream = await b.synthesize("brave")
##
## 缓存策略：sha256(id|lang|text) → user://tts_cache/<hash>.wav
class_name PiperTtsBackend extends IVoiceTtsBackend

const VoicePaths = preload("res://src/voice/voice_paths.gd")

var _binary_path_override: String = ""   # 测试用
var _model_path_override: String = ""

func get_id() -> String:
	return "piper"

func is_available() -> bool:
	return FileAccess.file_exists(_binary_path()) and FileAccess.file_exists(_model_path())

func _binary_path() -> String:
	if _binary_path_override != "":
		return _binary_path_override
	return VoicePaths.get_piper_binary()

func _model_path() -> String:
	if _model_path_override != "":
		return _model_path_override
	return VoicePaths.get_piper_default_model()

func synthesize(text: String, lang: String = "en") -> AudioStream:
	var cache_path := get_cache_path(text, lang)
	if FileAccess.file_exists(cache_path):
		return _load_wav(cache_path)
	if not is_available():
		return null
	# 子进程调用
	DirAccess.make_dir_recursive_absolute(cache_path.get_base_dir())
	var output := []
	# 用 bash -c 让 stdin 通过 echo pipe 传给 piper（macOS/Linux）
	# Windows 后续可加分支
	var cmd := "echo \"%s\" | \"%s\" --model \"%s\" --output_file \"%s\"" % [
		text.replace("\"", "\\\""),
		_binary_path(),
		_model_path(),
		ProjectSettings.globalize_path(cache_path)
	]
	var ec := OS.execute("bash", ["-c", cmd], output, true, false)
	if ec != 0:
		push_error("Piper failed (ec=%d): %s" % [ec, "\n".join(output)])
		return null
	if not FileAccess.file_exists(cache_path):
		push_error("Piper produced no output file")
		return null
	return _load_wav(cache_path)

func _load_wav(path: String) -> AudioStream:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		return null
	var data = f.get_buffer(f.get_length())
	f.close()
	return _parse_wav_to_stream(data)

static func _parse_wav_to_stream(raw: PackedByteArray) -> AudioStream:
	# 跳过 RIFF header (44 bytes 标准 PCM WAV)
	# Piper 通常输出 22050Hz 16-bit mono
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	if raw.size() > 44:
		stream.data = raw.slice(44)
	else:
		stream.data = PackedByteArray()
	return stream
