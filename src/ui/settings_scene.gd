extends Control

@onready var _grade4_button: Button = $Grade4Button
@onready var _grade5_button: Button = $Grade5Button
@onready var _grade6_button: Button = $Grade6Button
@onready var _back_button: Button = $BackButton

func _ready() -> void:
	_grade4_button.pressed.connect(_on_grade4_pressed)
	_grade5_button.pressed.connect(_on_grade5_pressed)
	_grade6_button.pressed.connect(_on_grade6_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_update_grade_buttons()

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
