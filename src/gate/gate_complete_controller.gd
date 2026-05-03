extends Control

@onready var _title_label: Label = $TitleLabel
@onready var _dialogue_label: Label = $DialogueLabel
@onready var _next_button: Button = $NextButton
@onready var _return_button: Button = $ReturnButton

var _lines: Array[String] = []
var _line_index: int = 0

func _ready() -> void:
	_title_label.text = "大关通过！"
	_lines = GameState.gate_boss_defeat_lines.duplicate()
	if _lines.is_empty():
		_lines = ["恭喜通关！"]
	_show_current_line()
	_next_button.pressed.connect(_on_next_pressed)
	_return_button.pressed.connect(_on_return_pressed)
	_return_button.visible = false

func _show_current_line() -> void:
	if _lines.is_empty():
		if _dialogue_label:
			_dialogue_label.text = ""
		_next_button.visible = false
		_return_button.visible = true
		return
	if _dialogue_label:
		_dialogue_label.text = _lines[min(_line_index, _lines.size() - 1)]
	var is_last: bool = _line_index >= _lines.size() - 1
	_next_button.visible = not is_last
	_return_button.visible = is_last

func _on_next_pressed() -> void:
	_line_index = min(_line_index + 1, _lines.size() - 1)
	_show_current_line()

func _on_return_pressed() -> void:
	GameState.pending_gate_id = ""
	GameState.pending_gate_config = {}
	GameState.gate_boss_defeat_lines = []
	get_tree().change_scene_to_file("res://src/exploration/exploration_scene.tscn")
