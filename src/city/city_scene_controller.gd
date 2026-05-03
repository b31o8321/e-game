extends Control

var _city_controller: CityController = CityController.new()

@onready var _resource_bar: Label = $ResourceBar
@onready var _building_container: VBoxContainer = $BuildingContainer
@onready var _start_button: Button = $StartExpeditionButton
@onready var _back_button: Button = $BackToMenuButton

func _ready() -> void:
	add_child(_city_controller)
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	if pack:
		_city_controller.setup(pack)
		_build_building_slots()
	_start_button.pressed.connect(_on_start_expedition)
	_back_button.pressed.connect(_on_back_to_menu)
	_city_controller.building_upgraded.connect(_on_any_building_upgraded)
	var practice_btn: Button = Button.new()
	practice_btn.text = "训练道场"
	practice_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://src/city/practice_arena_scene.tscn"))
	add_child(practice_btn)
	_update_resource_bar()

func _build_building_slots() -> void:
	var slot_scene: PackedScene = load("res://src/city/building_slot.tscn")
	for building_def in _city_controller.get_buildings():
		var slot: BuildingSlot = slot_scene.instantiate() as BuildingSlot
		slot.upgrade_requested.connect(_on_upgrade_requested)
		_building_container.add_child(slot)
		slot.setup(_city_controller, building_def)

func _on_upgrade_requested(building_id: String) -> void:
	_city_controller.upgrade_building(building_id)
	_update_resource_bar()

func _on_any_building_upgraded(_building_id: String, _level: int) -> void:
	_update_resource_bar()

func _update_resource_bar() -> void:
	var parts: Array[String] = []
	for k in GameState.inventory_resources:
		parts.append("%s: %d" % [k, GameState.inventory_resources[k]])
	_resource_bar.text = "背包: " + (", ".join(parts) if not parts.is_empty() else "空")

func _on_start_expedition() -> void:
	get_tree().change_scene_to_file("res://src/battle/expedition_setup.tscn")

func _on_back_to_menu() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu.tscn")
