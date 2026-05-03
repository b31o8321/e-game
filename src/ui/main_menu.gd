extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var city_button: Button = $VBoxContainer/CityButton
@onready var gate_button: Button = $VBoxContainer/GateButton
@onready var explore_button: Button = $VBoxContainer/ExploreButton
@onready var _settings_button: Button = $VBoxContainer/SettingsButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	city_button.pressed.connect(_on_city_pressed)
	gate_button.pressed.connect(_on_gate_pressed)
	gate_button.disabled = GameState.content_loader.get_active_pack() == null
	explore_button.pressed.connect(_on_explore_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://src/battle/expedition_setup.tscn")

func _on_city_pressed() -> void:
	get_tree().change_scene_to_file("res://src/city/city_scene.tscn")

func _on_gate_pressed() -> void:
	# Phase 5: switch to knowledge gate scene
	pass

func _on_explore_pressed() -> void:
	get_tree().change_scene_to_file("res://src/exploration/exploration_scene.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/settings_scene.tscn")
