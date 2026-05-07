## CutsceneScene — 剧情面板渲染 UI（CanvasLayer 顶层）
##
## 节点结构（与 cutscene_scene.tscn 对应）：
##   CutsceneScene (CanvasLayer)
##   ├─ BackgroundLayer/BackgroundColorRect
##   ├─ BackgroundLayer/BackgroundImage (TextureRect)
##   ├─ PortraitLayer/PortraitLeft (Sprite2D)
##   ├─ PortraitLayer/PortraitRight (Sprite2D)
##   ├─ DialogueLayer/DialoguePanel/VBox/SpeakerNameLabel
##   ├─ DialogueLayer/DialoguePanel/VBox/TextLabel (RichTextLabel)
##   ├─ DialogueLayer/DialoguePanel/VBox/ContinueIndicator (Label)
##   ├─ ControlLayer/SkipButton (Button)
##   ├─ ControlLayer/BgClickArea (Button, 全屏)
##   └─ AudioPlayers/{BgmStream, SfxStream}
##
## 暴露给 CutscenePlayer 的接口：
##   render_panel(panel: CutscenePanel)
##   fade_out()
##
## UX：
##   - 点击 / BgClickArea：文字打字中 → 立即显示完；已显示完 → 推进
##   - SkipButton：弹确认（已读则直跳）
##
## 参考: docs/superpowers/specs/2026-05-04-cutscene-system-design.md
class_name CutsceneScene extends CanvasLayer

signal advance_requested
signal skip_requested

# ---- 节点引用（onready，scene 中提供）----
@onready var bg_color_rect: ColorRect = $BackgroundLayer/BackgroundColorRect
@onready var bg_image: TextureRect = $BackgroundLayer/BackgroundImage
@onready var portrait_left: Sprite2D = $PortraitLayer/PortraitLeft
@onready var portrait_right: Sprite2D = $PortraitLayer/PortraitRight
@onready var speaker_name_label: Label = $DialogueLayer/DialoguePanel/VBox/SpeakerNameLabel
@onready var text_label: RichTextLabel = $DialogueLayer/DialoguePanel/VBox/TextLabel
@onready var continue_indicator: Label = $DialogueLayer/DialoguePanel/VBox/ContinueIndicator
@onready var skip_button: Button = $ControlLayer/SkipButton
@onready var bg_click_area: Button = $ControlLayer/BgClickArea
@onready var bgm_stream: AudioStreamPlayer = $AudioPlayers/BgmStream
@onready var sfx_stream: AudioStreamPlayer = $AudioPlayers/SfxStream

var _current_bgm_path: String = ""
var _typing_tween: Tween = null
var _typing_done: bool = true
var _current_panel: CutscenePanel = null
var _indicator_tween: Tween = null


func _ready() -> void:
	if bg_click_area:
		bg_click_area.pressed.connect(_on_bg_click)
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
	if continue_indicator:
		continue_indicator.visible = false
	_start_indicator_blink()


## CutscenePlayer 调用：渲染一个面板
func render_panel(panel: CutscenePanel) -> void:
	_current_panel = panel
	if panel == null:
		return
	_apply_background(panel)
	_apply_portraits(panel)
	_apply_audio(panel)
	_apply_speaker(panel)
	_run_typewriter(panel)


## CutscenePlayer 调用：退出动画（淡出）
func fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(self, "offset", offset, 0.3)  # placeholder; CanvasLayer offset trick
	# 使用 modulate via root control alpha 替代：找到第一个 Control 子节点统一淡出
	for child in get_children():
		if child is CanvasItem:
			var t := create_tween()
			t.tween_property(child, "modulate:a", 0.0, 0.3)
	await get_tree().create_timer(0.35).timeout
	if is_inside_tree():
		queue_free()


# ---- 背景 ----

func _apply_background(panel: CutscenePanel) -> void:
	if bg_color_rect:
		bg_color_rect.color = panel.background_color
	if not panel.background_image_path.is_empty() and bg_image:
		var tex = load(panel.background_image_path)
		if tex is Texture2D:
			bg_image.texture = tex
			bg_image.visible = true
	# 空 path = 沿用上一张，不动 bg_image


# ---- 立绘 ----

func _apply_portraits(panel: CutscenePanel) -> void:
	_apply_portrait(portrait_left, panel.portrait_left_path)
	_apply_portrait(portrait_right, panel.portrait_right_path)


func _apply_portrait(node: Sprite2D, path: String) -> void:
	if node == null:
		return
	if path.is_empty():
		node.visible = false
		return
	var tex = load(path)
	if tex is Texture2D:
		node.texture = tex
		node.visible = true


# ---- 音频 ----

func _apply_audio(panel: CutscenePanel) -> void:
	# BGM：仅在路径变化时切换；缺失文件 → 保持静默不报错
	if not panel.bgm_path.is_empty() and panel.bgm_path != _current_bgm_path:
		if ResourceLoader.exists(panel.bgm_path):
			var stream = load(panel.bgm_path)
			if stream is AudioStream and bgm_stream:
				bgm_stream.stream = stream
				bgm_stream.play()
				_current_bgm_path = panel.bgm_path
		else:
			push_warning("[CutsceneScene] missing BGM: %s (silent fallback)" % panel.bgm_path)
	# SFX：每次进入面板若有就播一次；缺失文件 → 静默
	if not panel.sfx_path.is_empty() and sfx_stream:
		if ResourceLoader.exists(panel.sfx_path):
			var sfx = load(panel.sfx_path)
			if sfx is AudioStream:
				sfx_stream.stream = sfx
				sfx_stream.play()
		else:
			push_warning("[CutsceneScene] missing SFX: %s (silent fallback)" % panel.sfx_path)


# ---- 说话人 ----

func _apply_speaker(panel: CutscenePanel) -> void:
	if speaker_name_label == null:
		return
	if panel.speaker_name.is_empty():
		speaker_name_label.text = ""
		speaker_name_label.visible = false
	else:
		speaker_name_label.text = panel.speaker_name
		speaker_name_label.visible = true


# ---- 打字机 ----

func _run_typewriter(panel: CutscenePanel) -> void:
	if text_label == null:
		return
	# 取消上一次未完成的 tween
	if _typing_tween != null and _typing_tween.is_valid():
		_typing_tween.kill()
	_typing_tween = null
	_typing_done = false
	if continue_indicator:
		continue_indicator.visible = false

	text_label.bbcode_enabled = true
	text_label.text = panel.text
	var total: int = panel.text.length()
	text_label.visible_characters = 0
	if panel.text_speed <= 0.0 or total == 0:
		text_label.visible_characters = total
		_on_typing_finished()
		return
	var duration: float = float(total) / panel.text_speed
	_typing_tween = create_tween()
	_typing_tween.tween_property(text_label, "visible_characters", total, duration)
	_typing_tween.finished.connect(_on_typing_finished)


func _on_typing_finished() -> void:
	_typing_done = true
	if continue_indicator:
		continue_indicator.visible = true


func _complete_typing_immediately() -> void:
	if _typing_tween != null and _typing_tween.is_valid():
		_typing_tween.kill()
	_typing_tween = null
	if text_label and _current_panel:
		text_label.visible_characters = _current_panel.text.length()
	_on_typing_finished()


# ---- 闪烁箭头 ----

func _start_indicator_blink() -> void:
	if continue_indicator == null:
		return
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(continue_indicator, "modulate:a", 0.2, 0.5)
	_indicator_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.5)


# ---- 输入处理 ----

func _on_bg_click() -> void:
	if not _typing_done:
		_complete_typing_immediately()
		return
	advance_requested.emit()
	# 同时尝试推进 CutscenePlayer 单例（autoload）
	_try_advance_player()


func _on_skip_pressed() -> void:
	skip_requested.emit()
	_try_skip_player()


func _try_advance_player() -> void:
	var player := _resolve_cutscene_player()
	if player != null and player.has_method("advance"):
		player.advance()


func _try_skip_player() -> void:
	var player := _resolve_cutscene_player()
	if player != null and player.has_method("skip"):
		player.skip()


func _resolve_cutscene_player() -> Node:
	if not is_inside_tree():
		return null
	var root := get_tree().root
	if root.has_node("CutscenePlayer"):
		return root.get_node("CutscenePlayer")
	return null
