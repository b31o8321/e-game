class_name SaveSystem extends Node

var save_path: String = "user://save.json"

func save(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func load_save() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	if result == null:
		return {}
	return result

func save_game_state() -> void:
	var data: Dictionary = {
		"player_hp": GameState.player_hp,
		"player_max_hp": GameState.player_max_hp,
		"knowledge_level": GameState.knowledge_level,
		"unlocked_knowledge_ids": GameState.unlocked_knowledge_ids,
		"completed_gate_ids": GameState.completed_gate_ids,
		"city_building_levels": GameState.city_building_levels,
		"inventory_resources": GameState.inventory_resources,
		"equipment_slots": GameState.equipment_slots,
		"player_grade": GameState.player_grade,
		"saved_at": Time.get_unix_time_from_system()
	}
	save(data)

func load_game_state() -> void:
	var data: Dictionary = load_save()
	if data.is_empty():
		return
	GameState.player_hp = data.get("player_hp", 100)
	GameState.player_max_hp = data.get("player_max_hp", 100)
	GameState.knowledge_level = data.get("knowledge_level", 1)
	GameState.unlocked_knowledge_ids = data.get("unlocked_knowledge_ids", [])
	GameState.completed_gate_ids = data.get("completed_gate_ids", [])
	GameState.city_building_levels = data.get("city_building_levels", {})
	GameState.inventory_resources = data.get("inventory_resources", {})
	GameState.equipment_slots = data.get("equipment_slots", {
		"weapon": "", "armor": "", "accessory": "", "mount": ""
	})
	GameState.player_grade = data.get("player_grade", 5)
