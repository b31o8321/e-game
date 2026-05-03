class_name LibrarianBoss extends BossBase

var _phase2_sealed: bool = false

func _init() -> void:
	boss_id = "librarian"
	max_hp = 150
	gate_id = "gate_en_01_basics"

func get_intro_dialogue() -> Array[String]:
	return [
		"这里是遗忘之渊的最后屏障。",
		"你以为凭一点记忆就能通过？",
		"让我来测试你——你真的记住了吗？",
	]

func get_phase_count() -> int:
	return 2

func on_phase_start(phase: int, battle_state: Dictionary) -> void:
	if phase == 2 and not _phase2_sealed:
		_phase2_sealed = true
		var seals: Array = battle_state.get("seal_types", [])
		seals.append("vocabulary")
		battle_state["seal_types"] = seals

func on_player_correct(attack_type: String, combo: int) -> Dictionary:
	if combo >= 5:
		return { "message": "…不可能，你怎么记得这么清楚！" }
	return {}

func on_player_wrong(attack_type: String) -> Dictionary:
	return { "message": "遗忘侵蚀你的记忆…" }

func boss_action(battle_state: Dictionary) -> Dictionary:
	var phase: int = battle_state.get("phase", 1)
	var combo: int = battle_state.get("combo", 0)
	if phase == 2:
		if combo >= 3:
			return { "type": "shuffle_options", "value": true, "message": "图书管理员打乱了选项！" }
		return { "type": "damage", "value": 12, "message": "遗忘之力强化侵袭！" }
	if combo >= 3:
		return { "type": "shuffle_options", "value": true, "message": "图书管理员打乱了选项！" }
	return { "type": "damage", "value": 8, "message": "遗忘之力侵蚀你的记忆…" }

func get_defeat_dialogue() -> Array[String]:
	return [
		"…不可思议。记忆…竟然如此顽强。",
		"你通过了遗忘的考验。",
		"大关已解封。更深处的知识，等待你去发现。",
	]
