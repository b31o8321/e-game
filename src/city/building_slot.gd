class_name BuildingSlot extends Control

var _controller: CityController = null
var _building_id: String = ""
var _building_def: Dictionary = {}

@onready var _name_label: Label = $VBoxContainer/NameLabel
@onready var _level_label: Label = $VBoxContainer/LevelLabel
@onready var _upgrade_button: Button = $VBoxContainer/UpgradeButton

signal upgrade_requested(building_id: String)

func setup(controller: CityController, building_def: Dictionary) -> void:
	_controller = controller
	_building_id = building_def.get("id", "")
	_building_def = building_def
	_controller.building_upgraded.connect(_on_building_upgraded)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	refresh()

func refresh() -> void:
	if not _name_label:
		return
	var current_level: int = _controller.get_current_level(_building_id)
	var max_level: int = _building_def.get("max_level", 3)
	_name_label.text = _building_def.get("name", _building_id)
	_level_label.text = "Lv %d / %d" % [current_level, max_level]
	_upgrade_button.disabled = not _controller.can_afford_upgrade(_building_id)
	if current_level >= max_level:
		_upgrade_button.text = "已满级"
		_upgrade_button.disabled = true
	else:
		var next: int = current_level + 1
		var cost_dict: Dictionary = _building_def.get("upgrade_costs", {}).get(next, {})
		var cost_str: String = _format_cost(cost_dict)
		_upgrade_button.text = "升级 (%s)" % cost_str

func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for k in cost:
		parts.append("%s×%d" % [k, cost[k]])
	return ", ".join(parts)

func _on_upgrade_pressed() -> void:
	upgrade_requested.emit(_building_id)

func _on_building_upgraded(building_id: String, _new_level: int) -> void:
	if building_id == _building_id:
		refresh()
