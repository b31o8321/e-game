class_name CityController extends Node

var _pack: ContentPackBase = null
var _buildings_cache: Array[Dictionary] = []

signal building_upgraded(building_id: String, new_level: int)

func setup(pack: ContentPackBase) -> void:
	_pack = pack
	_buildings_cache = _pack.get_buildings()

func get_buildings() -> Array[Dictionary]:
	return _buildings_cache

func get_current_level(building_id: String) -> int:
	return GameState.city_building_levels.get(building_id, 0)

## 升级建筑。返回 true = 成功，false = 资源不足或已满级
func upgrade_building(building_id: String) -> bool:
	var building: Dictionary = _get_building_def(building_id)
	if building.is_empty():
		return false
	var current_level: int = get_current_level(building_id)
	var max_level: int = building.get("max_level", 3)
	if current_level >= max_level:
		return false
	var next_level: int = current_level + 1
	var cost: Dictionary = _get_upgrade_cost(building, next_level)
	if not _has_resources(cost):
		return false
	_deduct_resources(cost)
	GameState.city_building_levels[building_id] = next_level
	building_upgraded.emit(building_id, next_level)
	return true

## 检查是否能负担下一级升级费用
func can_afford_upgrade(building_id: String) -> bool:
	var building: Dictionary = _get_building_def(building_id)
	if building.is_empty():
		return false
	var current_level: int = get_current_level(building_id)
	var max_level: int = building.get("max_level", 3)
	if current_level >= max_level:
		return false
	var next_level: int = current_level + 1
	var cost: Dictionary = _get_upgrade_cost(building, next_level)
	return _has_resources(cost)

func _get_building_def(building_id: String) -> Dictionary:
	for b in _buildings_cache:
		if b.get("id", "") == building_id:
			return b
	return {}

func _get_upgrade_cost(building: Dictionary, level: int) -> Dictionary:
	var costs: Dictionary = building.get("upgrade_costs", {})
	return costs.get(level, {})

func _has_resources(cost: Dictionary) -> bool:
	for resource_id in cost:
		if GameState.inventory_resources.get(resource_id, 0) < cost[resource_id]:
			return false
	return true

func _deduct_resources(cost: Dictionary) -> void:
	for resource_id in cost:
		GameState.inventory_resources[resource_id] = \
			GameState.inventory_resources.get(resource_id, 0) - cost[resource_id]
