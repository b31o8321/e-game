## 反馈弹窗 — 玩家点击 🚩 按钮触发，记录题/卡问题到 FeedbackSystem
extends CanvasLayer

signal submitted(type: String, reason: String, comment: String)
signal canceled

const REASONS_QUESTION := [
	{"id": "dialogue_unclear", "label": "题目描述不清"},
	{"id": "answer_unreasonable", "label": "答案不合理"},
	{"id": "translation_wrong", "label": "中文翻译有错"},
	{"id": "audio_missing", "label": "音频缺失/错误"},
	{"id": "other", "label": "其他"},
]

const REASONS_CARD := [
	{"id": "meaning_wrong", "label": "中文释义有错"},
	{"id": "tag_wrong", "label": "标签/词性有错"},
	{"id": "pronunciation_wrong", "label": "发音/音标有错"},
	{"id": "other", "label": "其他"},
]

var _type: String = ""
var _id: String = ""

@onready var _header: Label = $Card/VBox/HeaderLabel
@onready var _content: Label = $Card/VBox/ContentLabel
@onready var _reason_options: VBoxContainer = $Card/VBox/ReasonOptions
@onready var _comment: TextEdit = $Card/VBox/CommentEdit
@onready var _submit_btn: Button = $Card/VBox/HBox/SubmitButton
@onready var _cancel_btn: Button = $Card/VBox/HBox/CancelButton


func _ready() -> void:
	if _submit_btn:
		_submit_btn.pressed.connect(_on_submit_clicked)
	if _cancel_btn:
		_cancel_btn.pressed.connect(_on_cancel_clicked)


func setup(type: String, id: String, content: String) -> void:
	_type = type
	_id = id
	if not is_node_ready():
		await ready
	var label_text = "题" if type == "question" else "卡"
	_header.text = "🚩 反馈这%s" % label_text
	_content.text = content
	_populate_reasons()


func _populate_reasons() -> void:
	if _reason_options == null:
		return
	for child in _reason_options.get_children():
		child.queue_free()
	var reasons: Array = REASONS_CARD if _type == "card" else REASONS_QUESTION
	for r in reasons:
		var btn := CheckBox.new()
		btn.text = r["label"]
		btn.set_meta("reason_id", r["id"])
		_reason_options.add_child(btn)


func _on_submit_clicked() -> void:
	var picked := ""
	if _reason_options:
		for child in _reason_options.get_children():
			if child is CheckBox and child.button_pressed:
				picked = child.get_meta("reason_id")
				break
	var comment_text := _comment.text if _comment else ""
	_on_submit(picked, comment_text)


func _on_submit(reason: String, comment: String) -> void:
	submitted.emit(_type, reason, comment)
	# Auto-dispatch to autoload if available
	var fb = get_node_or_null("/root/FeedbackSystem")
	if fb and fb.has_method("report"):
		fb.report(_type, _id, reason, comment)
	queue_free()


func _on_cancel_clicked() -> void:
	canceled.emit()
	queue_free()
