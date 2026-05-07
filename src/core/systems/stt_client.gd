## STTClient — 语音识别客户端（Whisper API + 离线占位双模式）
##
## 责任：
##   - 启动期 / 首次调用时检测可用模式：
##       * WHISPER_API：SaveSystem.stt_settings.api_key 非空（联通性懒检测）
##       * OFFLINE_STUB：无 key 或 HTTP 调用失败时回退
##   - transcribe(audio_path) 是 awaitable；返回识别出的字符串。
##   - 离线占位策略：返回 self.target_phrase_hint（外部预设），让 dev mode
##     可以无 API key 也能跑通整条流水线。
##
## 详见: docs/superpowers/specs/2026-05-04-battle-system-redesign.md
class_name STTClient extends Node


enum Mode {
	WHISPER_API,
	OFFLINE_STUB,
}

const WHISPER_ENDPOINT: String = "https://api.openai.com/v1/audio/transcriptions"
const DEFAULT_TIMEOUT: float = 5.0

## 离线 stub 模式下，transcribe() 直接返回此字符串（一般设为 target_phrase
## 以模拟"成功识别"）。外部调用方可在 transcribe 前设置。
var target_phrase_hint: String = ""

## 运行时模式；首次调用 detect_mode() 后定型
var _mode: int = -1


func _ready() -> void:
	# 启动时主动探测一次（结果可被覆盖；HTTP 失败时会动态回退）
	detect_mode()


## 探测当前可用模式。无 API key → OFFLINE_STUB；有 key → WHISPER_API
## （联通性等待第一次实际调用时再判定，此处不做网络探测）。
func detect_mode() -> int:
	var key: String = _read_api_key()
	if key.is_empty():
		_mode = Mode.OFFLINE_STUB
	else:
		_mode = Mode.WHISPER_API
	return _mode


func get_mode() -> int:
	if _mode == -1:
		detect_mode()
	return _mode


## 强制覆盖模式（测试用）
func set_mode(m: int) -> void:
	_mode = m


## 主入口；async / awaitable。失败保护：返回空字符串而非崩溃。
func transcribe(audio_path: String) -> String:
	var mode: int = get_mode()
	if mode == Mode.OFFLINE_STUB:
		return _transcribe_stub(audio_path)
	return await _transcribe_whisper(audio_path)


# ─── OFFLINE_STUB 实现 ─────────────────────────────────────────────

func _transcribe_stub(_audio_path: String) -> String:
	# 占位：返回外部预设的提示串（一般是 target_phrase 本身），
	# 让 dev mode 下评估始终成功。
	return target_phrase_hint


# ─── WHISPER_API 实现 ──────────────────────────────────────────────

func _transcribe_whisper(audio_path: String) -> String:
	if not FileAccess.file_exists(audio_path):
		push_warning("[STTClient] audio file not found: %s; falling back to stub" % audio_path)
		return _transcribe_stub(audio_path)

	var key: String = _read_api_key()
	if key.is_empty():
		return _transcribe_stub(audio_path)

	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = DEFAULT_TIMEOUT
	add_child(http)

	var boundary: String = "----GodotSTTClient%d" % Time.get_ticks_msec()
	var body: PackedByteArray = _build_multipart_body(audio_path, boundary)
	if body.is_empty():
		http.queue_free()
		return _transcribe_stub(audio_path)

	var headers: PackedStringArray = PackedStringArray([
		"Authorization: Bearer " + key,
		"Content-Type: multipart/form-data; boundary=" + boundary,
	])
	var err: int = http.request_raw(WHISPER_ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("[STTClient] HTTPRequest.request_raw error: %d" % err)
		http.queue_free()
		return _transcribe_stub(audio_path)

	var response: Array = await http.request_completed
	http.queue_free()
	# response = [result, response_code, headers, body]
	var result_code: int = response[0] if response.size() > 0 else -1
	var status: int = response[1] if response.size() > 1 else 0
	var raw: PackedByteArray = response[3] if response.size() > 3 else PackedByteArray()
	if result_code != HTTPRequest.RESULT_SUCCESS or status < 200 or status >= 300:
		push_warning("[STTClient] Whisper API error result=%d status=%d" % [result_code, status])
		return _transcribe_stub(audio_path)

	var text: String = raw.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and parsed.has("text"):
		return str(parsed["text"]).strip_edges()
	push_warning("[STTClient] Whisper response missing 'text' field: %s" % text)
	return _transcribe_stub(audio_path)


# ─── multipart/form-data 构造 ─────────────────────────────────────

func _build_multipart_body(audio_path: String, boundary: String) -> PackedByteArray:
	var f: FileAccess = FileAccess.open(audio_path, FileAccess.READ)
	if f == null:
		push_warning("[STTClient] cannot open audio file: %s" % audio_path)
		return PackedByteArray()
	var audio_bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()

	var crlf: String = "\r\n"
	var pre: String = ""
	# model field
	pre += "--%s%s" % [boundary, crlf]
	pre += "Content-Disposition: form-data; name=\"model\"%s%s" % [crlf, crlf]
	pre += "whisper-1%s" % crlf
	# file field header
	pre += "--%s%s" % [boundary, crlf]
	pre += "Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"%s" % crlf
	pre += "Content-Type: audio/wav%s%s" % [crlf, crlf]

	var post: String = "%s--%s--%s" % [crlf, boundary, crlf]

	var body: PackedByteArray = PackedByteArray()
	body.append_array(pre.to_utf8_buffer())
	body.append_array(audio_bytes)
	body.append_array(post.to_utf8_buffer())
	return body


# ─── 配置读取 ─────────────────────────────────────────────────────

## 优先从 SaveSystem.stt_settings.api_key 读；否则尝试 user://config.cfg
func _read_api_key() -> String:
	# SaveSystem 是非 autoload，按 spec 这里只做最小读取：环境变量 + config.cfg
	var env_key: String = OS.get_environment("OPENAI_API_KEY")
	if not env_key.is_empty():
		return env_key

	var cfg_path: String = "user://config.cfg"
	if FileAccess.file_exists(cfg_path):
		var cfg: ConfigFile = ConfigFile.new()
		if cfg.load(cfg_path) == OK:
			var v: Variant = cfg.get_value("stt", "api_key", "")
			if v is String and not (v as String).is_empty():
				return v
			# 兼容老 spec 字段名
			var v2: Variant = cfg.get_value("voice", "stt_api_key", "")
			if v2 is String and not (v2 as String).is_empty():
				return v2
	return ""
