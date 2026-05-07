## DictationUI — 听写法术全屏 modal
##
## 流程：
##   1. setup(spice) 注入 DictationSpice 实例
##   2. 自动播放音频（spice.audio_path）；若空则显示提示文字
##   3. 玩家在输入框拼写 → 提交
##   4. spice.evaluate(input) → 显示成功 / 失败
##   5. 成功：绿色 + 反伤动画 → emit spice_completed → 关闭
##   6. 失败：红色 + 显示正确拼写（教学时刻） + 关闭
##
## 详见: docs/superpowers/specs/2026-05-04-battle-system-redesign.md
extends Control


signal spice_completed(result: SpiceResult)

const CLOSE_DELAY_SECONDS: float = 2.0

@onready var prompt_label: Label = $CenterCard/VBox/PromptLabel
@onready var play_button: Button = $CenterCard/VBox/PlayButton
@onready var input_field: LineEdit = $CenterCard/VBox/InputField
@onready var submit_button: Button = $CenterCard/VBox/HBox/SubmitButton
@onready var close_button: Button = $CenterCard/VBox/HBox/CloseButton
@onready var status_label: Label = $CenterCard/VBox/StatusLabel
@onready var correct_label: Label = $CenterCard/VBox/CorrectLabel

var _spice: DictationSpice = null
var _audio_player: AudioStreamPlayer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if submit_button:
		submit_button.pressed.connect(_on_submit_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if input_field:
		input_field.text_submitted.connect(func(_t): _on_submit_pressed())

	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)

	if status_label:
		status_label.text = ""
	if correct_label:
		correct_label.text = ""
		correct_label.visible = false


## 由战斗系统调用：注入 DictationSpice 实例
func setup(spice: DictationSpice) -> void:
	_spice = spice
	if prompt_label:
		prompt_label.text = "听音拼写"
	# 自动播一次
	_play_audio()


# ─── 音频播放 ─────────────────────────────────────────────────────

func _play_audio() -> void:
	if _spice == null or _audio_player == null:
		return
	var path: String = _spice.audio_path
	if path.is_empty() or not ResourceLoader.exists(path):
		_set_status("（音频缺失，请直接拼写：%s）" % _spice.target_word)
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		_set_status("（音频加载失败）")
		return
	_audio_player.stream = stream
	_audio_player.play()


# ─── 按钮事件 ─────────────────────────────────────────────────────

func _on_play_pressed() -> void:
	_play_audio()


func _on_submit_pressed() -> void:
	if _spice == null:
		_emit_completed(SpiceResult.make(false, 0.0, {}))
		return
	var user_input: String = input_field.text if input_field else ""
	var result: SpiceResult = _spice.evaluate(user_input)
	_show_result(result)


func _on_close_pressed() -> void:
	_emit_completed(SpiceResult.make(false, 0.0, {}))


# ─── 结果展示 ─────────────────────────────────────────────────────

func _show_result(result: SpiceResult) -> void:
	if result.success:
		_set_status("✓ 拼写正确！反伤已触发")
		await get_tree().create_timer(CLOSE_DELAY_SECONDS).timeout
		_emit_completed(result)
	else:
		_set_status("✗ 拼写错误")
		if correct_label and _spice:
			correct_label.text = "正确拼写：%s" % _spice.target_word
			correct_label.visible = true


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


func _emit_completed(result: SpiceResult) -> void:
	spice_completed.emit(result)
	queue_free()
