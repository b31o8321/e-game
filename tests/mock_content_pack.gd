class_name MockContentPack extends ContentPackBase

func _init() -> void:
	pack_id = "mock_pack"
	pack_name = "Mock Content Pack"
	subject = "english"
	grades = [4, 5, 6]

func get_attack_types() -> Array[Dictionary]:
	return [
		{ "id": "vocabulary", "name": "词汇", "icon": "📚", "color": "#667eea", "element": "fire" },
		{ "id": "grammar", "name": "语法", "icon": "📝", "color": "#f5576c", "element": "ice" },
	]

func get_question(attack_type_id: String, difficulty: int, exclude_ids: Array[String]) -> Dictionary:
	return {
		"id": "q_mock_001",
		"attack_type_id": attack_type_id,
		"question": "What does 'brave' mean?",
		"options": ["勇敢的", "聪明的", "安静的", "友善的"],
		"correct_index": 0,
		"explanation": "Brave [breɪv] · 形容词 · 勇敢的\n例句：The brave knight saved the village.",
		"audio_text": "brave",
		"difficulty": difficulty,
	}

func get_gate_questions(gate_id: String, count: int) -> Array[Dictionary]:
	var questions: Array[Dictionary] = []
	for i in range(count):
		questions.append({
			"id": "q_gate_%d" % i,
			"attack_type_id": "vocabulary",
			"question": "Mock gate question %d" % i,
			"options": ["Option A", "Option B", "Option C", "Option D"],
			"correct_index": 0,
			"explanation": "This is a mock explanation.",
			"audio_text": "mock",
			"difficulty": 2,
		})
	return questions

func get_gates() -> Array[Dictionary]:
	return [{
		"gate_id": "gate_mock_01",
		"gate_name": "模拟大关",
		"required_knowledge_level": 1,
		"wave_count": 1,
		"questions_per_wave": 2,
		"wave_enemy": {
			"enemy_name": "模拟哨兵",
			"max_hp": 20,
			"base_attack": 3,
			"weaknesses": ["vocabulary"],
			"multipliers": { "vocabulary": 1.5 },
		},
		"boss_script_path": "",
		"boss_enemy": {
			"enemy_name": "模拟Boss",
			"max_hp": 50,
			"base_attack": 5,
			"weaknesses": [],
			"multipliers": {},
		},
		"unlock_knowledge_level": 2,
		"unlock_area_ids": [],
	}]

func on_question_answered(question_id: String, correct: bool) -> void:
	pass

func get_question_by_id(question_id: String) -> Dictionary:
	if question_id.begins_with("q_mock") or question_id.begins_with("q_gate"):
		return get_question("vocabulary", 1, [])
	return {}

func get_buildings() -> Array[Dictionary]:
	return [
		{
			"id": "vocabulary_library",
			"name": "词汇图书馆",
			"max_level": 3,
			"upgrade_costs": {
				1: { "vocabulary_crystal": 3 },
				2: { "vocabulary_crystal": 8 },
				3: { "vocabulary_crystal": 15 },
			}
		},
		{
			"id": "grammar_academy",
			"name": "语法学院",
			"max_level": 3,
			"upgrade_costs": {
				1: { "grammar_ore": 3 },
				2: { "grammar_ore": 8 },
				3: { "grammar_ore": 15 },
			}
		}
	]

func get_skills(bd_path: String) -> Array[Dictionary]:
	return []

func get_equipment() -> Array[Dictionary]:
	return []

func get_puzzle_scene_path(knowledge_id: String) -> String:
	return ""

func get_audio(text: String) -> AudioStream:
	return null
