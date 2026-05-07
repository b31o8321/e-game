## STT 后端：调用本地 whisper-cli 二进制 + ggml 模型
##
## 输入：AudioStream（先序列化为临时 WAV 文件）
## 输出：transcript 字符串
class_name WhisperCppSttBackend extends IVoiceSttBackend

const VoicePaths = preload("res://src/voice/voice_paths.gd")

const TEMP_WAV := "user://stt_temp.wav"
const TEMP_TXT_BASE := "user://stt_temp.wav"

var _binary_path_override: String = ""
var _model_path_override: String = ""

func get_id() -> String:
	return "whisper_cpp"

func is_available() -> bool:
	return FileAccess.file_exists(_binary_path()) and FileAccess.file_exists(_model_path())

func _binary_path() -> String:
	if _binary_path_override != "":
		return _binary_path_override
	return VoicePaths.get_whisper_binary()

func _model_path() -> String:
	if _model_path_override != "":
		return _model_path_override
	return VoicePaths.get_whisper_default_model()

func transcribe(audio: AudioStream, _lang: String = "en") -> String:
	if not is_available() or audio == null:
		return ""
	var wav_path := _write_temp_wav(audio)
	if wav_path == "":
		return ""
	var output_basename := ProjectSettings.globalize_path(TEMP_TXT_BASE)
	var args := [
		"-m", _model_path(),
		"-f", ProjectSettings.globalize_path(wav_path),
		"-otxt",
		"-nt",
		"-of", output_basename,
	]
	var output := []
	var ec := OS.execute(_binary_path(), args, output, true, false)
	if ec != 0:
		push_error("whisper-cli failed (ec=%d)" % ec)
		return ""
	# whisper-cli writes <of>.txt
	var txt_path := output_basename + ".txt"
	if not FileAccess.file_exists(txt_path):
		return ""
	var f = FileAccess.open(txt_path, FileAccess.READ)
	if not f:
		return ""
	var transcript: String = f.get_as_text().strip_edges()
	f.close()
	return transcript

func _write_temp_wav(audio: AudioStream) -> String:
	if not (audio is AudioStreamWAV):
		push_error("Only AudioStreamWAV supported")
		return ""
	var s: AudioStreamWAV = audio
	var f = FileAccess.open(TEMP_WAV, FileAccess.WRITE)
	if not f:
		return ""
	var data: PackedByteArray = s.data
	var sample_rate: int = s.mix_rate
	var bits: int = 16 if s.format == AudioStreamWAV.FORMAT_16_BITS else 8
	var channels: int = 2 if s.stereo else 1
	var byte_rate: int = sample_rate * channels * bits / 8
	# RIFF header
	f.store_buffer("RIFF".to_utf8_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVE".to_utf8_buffer())
	# fmt chunk
	f.store_buffer("fmt ".to_utf8_buffer())
	f.store_32(16)
	f.store_16(1)         # PCM
	f.store_16(channels)
	f.store_32(sample_rate)
	f.store_32(byte_rate)
	f.store_16(channels * bits / 8)
	f.store_16(bits)
	# data chunk
	f.store_buffer("data".to_utf8_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	return TEMP_WAV
