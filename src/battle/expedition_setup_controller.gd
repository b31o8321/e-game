class_name ExpeditionSetupController extends Control

## 从技能池随机抽 count 个，玩家选1个带入远征
var offered_skills: Array[Dictionary] = []
var selected_skill_id: String = ""

signal skill_chosen(skill_id: String)
signal setup_cancelled()

func offer_skills(all_skills: Array[Dictionary], count: int = 3) -> void:
	all_skills.shuffle()
	offered_skills = all_skills.slice(0, min(count, all_skills.size()))
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	var label: Label = Label.new()
	label.text = "选择本次远征的起始技能"
	add_child(label)
	for skill_dict in offered_skills:
		var btn: Button = Button.new()
		btn.text = skill_dict.get("skill_name", skill_dict.get("skill_id", ""))
		var sid: String = skill_dict.get("skill_id", "")
		btn.pressed.connect(func(): _on_skill_selected(sid))
		add_child(btn)

func _on_skill_selected(skill_id: String) -> void:
	selected_skill_id = skill_id
	GameState.active_bd_skills = [skill_id]
	GameState.start_expedition()
	skill_chosen.emit(skill_id)
	get_tree().change_scene_to_file("res://src/exploration/exploration_scene.tscn")
