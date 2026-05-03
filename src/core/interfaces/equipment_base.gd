class_name EquipmentBase extends Resource

@export var equipment_id: String = ""
@export var equipment_name: String = ""
@export var slot: String = ""   # "weapon" | "armor" | "accessory" | "mount"
@export var description: String = ""
@export var icon_path: String = ""

## 装备时应用效果到 battle_state
func on_equip(battle_state: Dictionary) -> void:
	pass

## 卸下时移除效果
func on_unequip(battle_state: Dictionary) -> void:
	pass

## 答对时触发
func on_correct(battle_state: Dictionary) -> void:
	pass

## 答错时触发
func on_wrong(battle_state: Dictionary) -> void:
	pass
