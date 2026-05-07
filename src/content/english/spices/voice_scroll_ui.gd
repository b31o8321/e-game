## VoiceScrollUI — 口语卷轴全屏 modal
##
## 流程：
##   1. setup(spice) 注入 VoiceScrollSpice 实例
##   2. 显示 target_phrase + 音标占位 + 🎤 按钮
##   3. 按住 🎤 录音（带 hold-to-record；最长 5 秒）
##   4. 松开 → 显示"识别中..." → 调用 STTClient.transcribe
##   5. evaluate(transcript) → 显示 quality + 成功/失败 UI
##   6. 成功：绿色提示 + 2 秒后关闭 → emit spice_completed(SpiceResult)
##   7. 失败：红色提示 + 重试（最多 2 次） / 关闭按钮
##
## 麦克风：使用 AudioServer + AudioEffectCapture 捕获到 AudioStreamWAV，
## 写入 user://temp_recording.wav。若 audio_input 不可用则降级为 hold-stub
## （按住 1.5 秒视为成功），方便 dev mode 在无麦克风环境跑流水线。
##
## 详见: docs/superpowers/specs/2026-05-04-battle-system-redesign.md
extends Control

const VoiceScrollSpiceClass = preload("res://src/content/english/spices/voice_scroll_spice.gd")
const SpiceResultClass = preload("res://src/battle/spices/spice_result.gd")
const STTClientClass = preload("res://src/core/systems/stt_client.gd")


signal spice_completed(result)

const TEMP_AUDIO_PATH: String = "user://temp_recording.wav"
const MAX_RECORD_SECONDS: float = 5.0
const MIN_HOLD_SECONDS: float = 0.3
const MAX_RETRIES: int = 2
const STUB_HOLD_SECONDS: float = 1.5
const CLOSE_DELAY_SECONDS: float = 2.0

@onready var phrase_label: Label = $CenterCard/VBox/PhraseLabel
@onready var phonetic_label: Label = $CenterCard/VBox/PhoneticLabel
@onready var record_button: Button = $CenterCard/VBox/RecordButton
@onready var status_label: Label = $CenterCard/VBox/StatusLabel
@onready var transcript_label: Label = $CenterCard/VBox/TranscriptLabel
@onready var retry_button: Button = $CenterCard/VBox/HBox/RetryButton
@onready var close_button: Button = $CenterCard/VBox/HBox/CloseButton

var _spice = null
var _stt = null
var _retries_left: int = MAX_RETRIES
var _is_recording: bool = false
var _record_start_msec: int = 0
var _record_timer: Timer = null

# 麦克风采集相关
var _capture_effect: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _mic_bus_idx: int = -1
var _mic_available: bool = false


func _ready() -> void:
	# 半透明黑底全屏遮罩
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if record_button:
		record_button.button_down.connect(_on_record_pressed)
		record_button.button_up.connect(_on_record_released)
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	# 录音超时计时器
	_record_timer = Timer.new()
	_record_timer.one_shot = true
	_record_timer.wait_time = MAX_RECORD_SECONDS
	add_child(_record_timer)
	_record_timer.timeout.connect(_on_record_timeout)

	_setup_microphone()
	_set_status("")
	if transcript_label:
		transcript_label.text = ""
	if retry_button:
		retry_button.visible = false


## 由战斗系统调用：注入 VoiceScrollSpice 实例与 STT 客户端
func setup(spice, stt = null) -> void:
	_spice = spice
	_stt = stt
	if _stt == null:
		_stt = STTClientClass.new()
		add_child(_stt)
	# 离线模式下让 stub 回成功路径
	_stt.target_phrase_hint = spice.target_phrase if spice else ""

	if _spice and phrase_label:
		phrase_label.text = _spice.target_phrase
	if phonetic_label:
		phonetic_label.text = "[音标占位]"
	_retries_left = MAX_RETRIES


# ─── 麦克风初始化（尽力实现；失败降级 stub）───────────────────────

func _setup_microphone() -> void:
	# audio_input 默认禁用（AudioServer 默认不开输入设备）；尝试启用
	var input_enabled: bool = ProjectSettings.get_setting("audio/driver/enable_input", false)
	if not input_enabled:
		# Godot 4.x 运行时不能改 ProjectSettings 启用输入；只能在
		# project.godot 中预先设 audio/driver/enable_input=true。
		# 这里直接降级 stub，避免崩溃。
		_mic_available = false
		return

	# 创建独立 mic bus + capture effect
	var bus_name: String = "MicCapture"
	_mic_bus_idx = AudioServer.get_bus_index(bus_name)
	if _mic_bus_idx == -1:
		AudioServer.add_bus()
		_mic_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_mic_bus_idx, bus_name)
		AudioServer.set_bus_mute(_mic_bus_idx, true)  # 不希望麦克风回放到喇叭

	_capture_effect = AudioEffectCapture.new()
	AudioServer.add_bus_effect(_mic_bus_idx, _capture_effect)

	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = bus_name
	add_child(_mic_player)
	_mic_available = true


func _start_recording() -> void:
	_record_start_msec = Time.get_ticks_msec()
	_is_recording = true
	_set_status("录音中...")
	if _mic_available and _mic_player:
		_capture_effect.clear_buffer()
		_mic_player.play()
		_record_timer.start()


func _stop_recording() -> String:
	if not _is_recording:
		return ""
	_is_recording = false
	_record_timer.stop()
	if _mic_available and _mic_player and _mic_player.playing:
		_mic_player.stop()

	var hold_ms: int = Time.get_ticks_msec() - _record_start_msec
	if hold_ms < int(MIN_HOLD_SECONDS * 1000.0):
		return ""

	if _mic_available and _capture_effect:
		var ok: bool = _save_capture_to_wav(TEMP_AUDIO_PATH)
		if ok:
			return TEMP_AUDIO_PATH
	# 麦克风不可用：返回空路径，让上层走 stub
	return ""


func _save_capture_to_wav(path: String) -> bool:
	if _capture_effect == null:
		return false
	var frames_available: int = _capture_effect.get_frames_available()
	if frames_available <= 0:
		return false
	var frames: PackedVector2Array = _capture_effect.get_buffer(frames_available)
	if frames.is_empty():
		return false
	# 转单声道 16-bit PCM
	var mix_rate: int = int(AudioServer.get_mix_rate())
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(frames.size() * 2)
	for i in range(frames.size()):
		var v: float = (frames[i].x + frames[i].y) * 0.5
		v = clamp(v, -1.0, 1.0)
		var s: int = int(v * 32767.0)
		pcm.encode_s16(i * 2, s)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = mix_rate
	wav.data = pcm
	var err: int = wav.save_to_wav(path)
	return err == OK


# ─── 按钮事件 ─────────────────────────────────────────────────────

func _on_record_pressed() -> void:
	_set_status("")
	if transcript_label:
		transcript_label.text = ""
	_start_recording()


func _on_record_released() -> void:
	if not _is_recording:
		return
	var audio_path: String = _stop_recording()
	await _process_recording(audio_path)


func _on_record_timeout() -> void:
	if _is_recording:
		var audio_path: String = _stop_recording()
		await _process_recording(audio_path)


func _on_retry_pressed() -> void:
	if _retries_left <= 0:
		return
	_retries_left -= 1
	_set_status("再来一次！按住 🎤 朗读")
	if transcript_label:
		transcript_label.text = ""
	if retry_button:
		retry_button.visible = false


func _on_close_pressed() -> void:
	_emit_completed(SpiceResultClass.make(false, 0.0, {}))


# ─── 识别 / 评估流程 ──────────────────────────────────────────────

func _process_recording(audio_path: String) -> void:
	_set_status("识别中...")

	var transcript: String = ""
	if audio_path.is_empty():
		# 没拿到真实音频：走 stub 路径（dev mode）
		if _stt:
			transcript = await _stt.transcribe("")
	else:
		if _stt:
			transcript = await _stt.transcribe(audio_path)

	if transcript_label:
		transcript_label.text = "识别：%s" % (transcript if not transcript.is_empty() else "（未识别到内容）")

	if _spice == null:
		_emit_completed(SpiceResultClass.make(false, 0.0, {}))
		return

	var result = _spice.evaluate(transcript)
	_show_result(result)


func _show_result(result) -> void:
	if result.success:
		_set_status("[color=#52c41a]成功！BUFF 已应用[/color]", true)
		if retry_button:
			retry_button.visible = false
		# 延迟关闭
		await get_tree().create_timer(CLOSE_DELAY_SECONDS).timeout
		_emit_completed(result)
	else:
		var msg: String = "[color=#ff4d4f]再试一次？(quality=%.2f)[/color]" % result.quality
		_set_status(msg, true)
		if _retries_left > 0 and retry_button:
			retry_button.visible = true
			retry_button.text = "重试 (%d)" % _retries_left
		else:
			# 没有重试机会：仍允许关闭
			if retry_button:
				retry_button.visible = false


func _set_status(text: String, rich: bool = false) -> void:
	if status_label == null:
		return
	# 简化：不区分 rich label，直接写文字（去掉 BBCode 标签）
	if rich:
		var stripped: String = text
		var regex: RegEx = RegEx.new()
		regex.compile("\\[/?[^\\]]+\\]")
		stripped = regex.sub(stripped, "", true)
		status_label.text = stripped
	else:
		status_label.text = text


func _emit_completed(result) -> void:
	spice_completed.emit(result)
	queue_free()
