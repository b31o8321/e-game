extends Control

@onready var _grade4_button: Button = $VBoxContainer/Grade4Button
@onready var _grade5_button: Button = $VBoxContainer/Grade5Button
@onready var _grade6_button: Button = $VBoxContainer/Grade6Button
@onready var _back_button: Button = $VBoxContainer/BackButton
@onready var _feedback_count_label: Label = $VBoxContainer/FeedbackCountLabel
@onready var _export_feedback_button: Button = $VBoxContainer/ExportFeedbackButton
@onready var _clear_feedback_button: Button = $VBoxContainer/ClearFeedbackButton

func _ready() -> void:
	_grade4_button.pressed.connect(_on_grade4_pressed)
	_grade5_button.pressed.connect(_on_grade5_pressed)
	_grade6_button.pressed.connect(_on_grade6_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	if _export_feedback_button != null:
		_export_feedback_button.pressed.connect(_on_export_feedback_pressed)
	if _clear_feedback_button != null:
		_clear_feedback_button.pressed.connect(_on_clear_feedback_pressed)
	_update_grade_buttons()
	_refresh_feedback_count()

func _update_grade_buttons() -> void:
	_grade4_button.button_pressed = GameState.player_grade == 4
	_grade5_button.button_pressed = GameState.player_grade == 5
	_grade6_button.button_pressed = GameState.player_grade == 6

func _on_grade4_pressed() -> void:
	GameState.player_grade = 4
	GameState.save_system.save_game_state()
	_update_grade_buttons()

func _on_grade5_pressed() -> void:
	GameState.player_grade = 5
	GameState.save_system.save_game_state()
	_update_grade_buttons()

func _on_grade6_pressed() -> void:
	GameState.player_grade = 6
	GameState.save_system.save_game_state()
	_update_grade_buttons()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")


# ──────────────────────────────────────────────────────────────────────
# 反馈管理：导出 / 清空
# ──────────────────────────────────────────────────────────────────────

func _refresh_feedback_count() -> void:
	if _feedback_count_label == null:
		return
	var fb = get_node_or_null("/root/FeedbackSystem")
	if fb == null:
		_feedback_count_label.text = "已记录 0 条反馈"
		return
	var count: int = fb.get_all().size()
	_feedback_count_label.text = "已记录 %d 条反馈" % count


func _on_export_feedback_pressed() -> void:
	var fb = get_node_or_null("/root/FeedbackSystem")
	if fb == null:
		return
	var json: String = fb.export_json()
	DisplayServer.clipboard_set(json)
	var count: int = fb.get_all().size()
	OS.alert("反馈数据已复制到剪贴板（共 %d 条）" % count, "导出成功")


func _on_clear_feedback_pressed() -> void:
	var fb = get_node_or_null("/root/FeedbackSystem")
	if fb == null:
		return
	fb.clear()
	_refresh_feedback_count()
