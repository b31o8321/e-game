class_name EnemyEncounterNode extends Button

## 遭遇的敌人数据，由场景控制器在 spawn 时设置
var enemy_data: EnemyData = null

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if enemy_data == null:
		push_error("EnemyEncounterNode: enemy_data not set")
		return
	GameState.pending_enemy = enemy_data
	GameState.expedition_return_scene = "res://src/exploration/exploration_scene.tscn"
	get_tree().change_scene_to_file("res://src/battle/battle_scene.tscn")
